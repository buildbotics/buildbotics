/******************************************************************************\

                 This file is part of the Buildbotics Webserver.

                Copyright (c) 2014-2015, Cauldron Development LLC
                               All rights reserved.

        The Buildbotics Webserver is free software: you can redistribute
        it and/or modify it under the terms of the GNU General Public
        License as published by the Free Software Foundation, either
        version 2 of the License, or (at your option) any later version.

        The Buildbotics Webserver is distributed in the hope that it will
        be useful, but WITHOUT ANY WARRANTY; without even the implied
        warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
        PURPOSE.  See the GNU General Public License for more details.

        You should have received a copy of the GNU General Public License
        along with this software.  If not, see
        <http://www.gnu.org/licenses/>.

        In addition, BSD licensing may be granted on a case by case basis
        by written permission from at least one of the copyright holders.
        You may request written permission by emailing the authors.

                For information regarding this software email:
                               Joseph Coffland
                        joseph@cauldrondevelopment.com

\******************************************************************************/

#include "Transaction.h"
#include "App.h"
#include "AWS4Post.h"

#include <cbang/event/Client.h>
#include <cbang/event/Buffer.h>
#include <cbang/event/BufferDevice.h>
#include <cbang/event/Event.h>

#include <cbang/json/JSON.h>
#include <cbang/log/Logger.h>
#include <cbang/Catch.h>
#include <cbang/db/maria/EventDB.h>
#include <cbang/time/Timer.h>
#include <cbang/openssl/Digest.h>
#include <cbang/net/URI.h>
#include <cbang/io/StringInputSource.h>
#include <cbang/os/SystemUtilities.h>

#include <mysql/mysqld_error.h>

using namespace std;
using namespace cb;
using namespace Buildbotics;


Transaction::Transaction(App &app, Event::RequestMethod method, const URI &uri,
                         const Version &version) :
  Request(method, uri, version), Event::OAuth2Login(app.getEventClient()),
  app(app), jsonFields(0) {
  LOG_DEBUG(5, "Transaction()");
}


Transaction::~Transaction() {LOG_DEBUG(5, "~Transaction()");}


bool Transaction::lookupUser(bool skipAuthCheck) {
  if (!user.isNull()) return true;

  // Get session
  string session = findCookie(app.getSessionCookieName());
  if (session.empty() && inHas("Authorization"))
    session = inGet("Authorization").substr(6, 32);
  if (session.empty()) return false;

  // Check Authorization header matches first 32 bytes of session
  if (!skipAuthCheck) {
    if (!inHas("Authorization")) return false;

    string auth = inGet("Authorization");
    unsigned len = auth.length();

    if (len < 38 || auth.compare(0, 6, "Token ") ||
        session.compare(0, len - 6, auth.c_str() + 6)) return false;
  }

  // Get user
  user = app.getUserManager().get(session);

  // Check if we have a user and it's not expired
  if (user.isNull() || user->hasExpired()) {
    user.release();
    clearAuthCookie();
    return false;
  }

  // Check if the user auth is expiring soon
  if (user->isExpiring()) {
    app.getUserManager().updateSession(user);
    setAuthCookie();
  }

  LOG_DEBUG(3, "User: " << user->getName());

  return true;
}


User &Transaction::getUser() {
  if (!lookupUser()) pleaseLogin();
  return *user;
}


string Transaction::getViewID() {
  lookupUser();

  if (user.isNull()) {
    if (inHas("X-Real-IP")) return inGet("X-Real-IP");
    return getClientIP().toString();
  }

  return user->getName();
}


void Transaction::authorize(unsigned flags) {
  lookupUser();

  if (user.isNull() || !user->isAuthenticated()) pleaseLogin();
  if (user->getAuth() && AuthFlags::AUTH_ADMIN) return;
  if ((user->getAuth() & flags) != flags)
    THROWX("Not authorized", HTTP_UNAUTHORIZED);
}


void Transaction::authorize(unsigned flags, const string &name) {
  authorize(flags);

  if (user->getAuth() & (AuthFlags::AUTH_ADMIN | AuthFlags::AUTH_MOD)) return;
  if (user->getName() != name) THROWX("Not authorized", HTTP_UNAUTHORIZED);
}


void Transaction::authorize(const string &name) {
  authorize(AuthFlags::AUTH_NONE, name);
}


void Transaction::setAuthCookie() {
  string session = user->getSession();
  setCookie(app.getSessionCookieName(), session, "", "/");
}


void Transaction::clearAuthCookie(uint64_t expires) {
  setCookie(app.getSessionCookieName(), "", "", "/", expires);
}


bool Transaction::hasTag(const string &tag) const {
  vector<string> tags;
  String::tokenize(getArgs()->getString("tags"), tags, ",");

  for (unsigned i = 0; i < tags.size(); i++)
    if (tags[i] == tag) return true;

  return false;
}


void Transaction::query(event_db_member_functor_t member, const string &s,
                        const SmartPointer<JSON::Value> &dict) {
  if (db.isNull()) db = app.getDBConnection();
  db->query(this, member, s, dict);
}


bool Transaction::pleaseLogin() {
  THROWX("Not authorized, please login", HTTP_UNAUTHORIZED);
  return true;
}


string Transaction::postFile(const std::string &path, const string &file,
                             const string &type, uint32_t minSize,
                             uint32_t maxSize) {
  // Create GUID
  Digest hash("sha256");
  hash.update(path);
  hash.update(file);
  hash.updateWith(Timer::now());
  string guid = hash.toURLBase64();

  // Create key
  string key = guid + "/" + file;

  // Create URLs
  string uploadURL = "https://" + app.getAWSBucket() + ".s3.amazonaws.com/";
  string fileURL = path + "/" + file;

  // Build POST
  AWS4Post post(app.getAWSBucket(), key, app.getAWSUploadExpires(),
                Time::now(), "s3", app.getAWSRegion());

  post.setLengthRange(minSize, maxSize);
  post.insert("Content-Type", type);
  post.insert("acl", "public-read");
  post.insert("success_action_status", "201");
  post.addCondition("name", file);
  post.sign(app.getAWSID(), app.getAWSSecret());

  // Write JSON
  setContentType("application/json");
  writer = getJSONWriter();
  writer->beginDict();
  writer->insert("upload_url", uploadURL);
  writer->insert("file_url", URI::encode(fileURL));
  writer->insert("guid", guid);
  writer->beginInsert("post");
  post.write(*writer);
  writer->endDict();
  writer.release();

  // Return URL
  return "/" + URI::encode(key);
}


void Transaction::sendError(Event::HTTPStatus code, const string &message) {
  // Release JSON writer
  writer.release();

  // Drop DB connection
  if (!db.isNull()) db->close();

  getOutputBuffer().clear();
  send(message);
  reply(code);
}


void Transaction::processProfile(Event::Request &req,
                                 const SmartPointer<JSON::Value> &profile) {
  if (!profile.isNull())
    try {
      // Authenticate user
      user->setProvider(profile->getString("provider"));
      user->setID(profile->getString("id"));

      // Fix up Facebook avatar
      if (profile->getString("provider") == "facebook")
        profile->insert("avatar", "http://graph.facebook.com/" +
                        profile->getString("id") + "/picture?type=small");

      // Fix up for GitHub name
      if ((!profile->has("name") ||
           String::trim(profile->getString("name")).empty()) &&
          profile->hasString("login"))
        profile->insert("name", profile->getString("login"));

      LOG_DEBUG(3, "Profile: " << *profile);

      query(&Transaction::login, "CALL Login(%(provider)S, %(id)S, %(name)S, "
            "%(email)S, %(avatar)S);", profile);

      return;
    } CATCH_ERROR;

  redirect("/");
}


bool Transaction::apiAuthUser() {
  authorize();

  SmartPointer<JSON::Value> dict = new JSON::Dict;
  dict->insert("provider", user->getProvider());
  dict->insert("id", user->getID());

  jsonFields = "*profile things followers following starred badges events auth";
  query(&Transaction::authUser, "CALL GetUser(%(provider)S, %(id)S)", dict);

  return true;
}


bool Transaction::apiAuthLogin() {
  const URI &uri = getURI();

  // Get user
  lookupUser(true);

  if (user.isNull()) user = app.getUserManager().create();
  if (user->isAuthenticated()) {
    redirect("/");
    return true;
  }

  // Set session cookie
  if (!uri.has("state")) setAuthCookie();

  OAuth2 *auth;
  string path = getURI().getPath();
  if (String::endsWith(path, "/callback"))
    path = path.substr(0, path.length() - 9);

  if (String::endsWith(path, "/google")) auth = &app.getGoogleAuth();
  else if (String::endsWith(path, "/github")) auth = &app.getGitHubAuth();
  else if (String::endsWith(path, "/facebook")) auth = &app.getFacebookAuth();
  else THROWC("Unsupported login provider", HTTP_BAD_REQUEST);

  setOAuth2(SmartPointer<OAuth2>::Phony(auth));
  return OAuth2Login::authorize(*this, user->getToken());
}


bool Transaction::apiAuthLogout() {
  clearAuthCookie(1);
  getJSONWriter()->write("ok");
  setContentType("application/json");
  reply();
  return true;
}


bool Transaction::apiGetInfo() {
  jsonFields = "permissions licenses";
  query(&Transaction::returnJSONFields, "CALL GetInfo()");
  return true;
}


bool Transaction::apiGetPermissions() {
  query(&Transaction::returnList, "CALL GetPermissions()");
  return true;
}


bool Transaction::apiGetProfiles() {
  JSON::ValuePtr args = parseArgs();
  query(&Transaction::returnList,
        "CALL FindProfiles(%(query)S, %(limit)u, %(offset)u)", args);
  return true;
}


bool Transaction::apiProfileRegister() {
  lookupUser();
  if (user.isNull()) return pleaseLogin();

  SmartPointer<JSON::Value> dict = new JSON::Dict;
  dict->insert("profile", getArgs()->getString("profile"));
  dict->insert("provider", user->getProvider());
  dict->insert("id", user->getID());

  query(&Transaction::registration,
        "CALL Register(%(profile)S, %(provider)S, %(id)S)", dict);
  return true;
}


bool Transaction::apiProfileAvailable() {
  query(&Transaction::returnBool, "CALL Available(%(profile)S)",
        parseArgs());
  return true;
}


bool Transaction::apiProfileSuggest() {
  lookupUser();
  if (user.isNull()) return pleaseLogin();

  SmartPointer<JSON::Value> dict = new JSON::Dict;
  dict->insert("provider", user->getProvider());
  dict->insert("id", user->getID());

  query(&Transaction::returnList, "CALL Suggest(%(provider)S, %(id)S, 5)",
        dict);

  return true;
}


bool Transaction::apiPutProfile() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL PutProfile(%(profile)S, %(fullname)S, %(location)S, %(url)S, "
        "%(bio)S)", args);

  return true;
}


bool Transaction::apiGetProfile() {
  jsonFields = "*profile things followers following starred badges events";

  query(&Transaction::returnJSONFields, "CALL GetProfile(%(profile)S)",
        parseArgs());

  return true;
}


bool Transaction::apiGetProfileAvatar() {
  JSON::ValuePtr args = parseArgs();
  query(&Transaction::download, "CALL GetProfileAvatar(%(profile)S)", args);
  return true;
}


bool Transaction::apiPutProfileAvatar() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  string path = "/" + args->getString("profile");
  string file = args->getString("file");
  string type = args->getString("type");
  uint32_t size = args->getU32("size");

  // Limit size
  if (5 * 1024 * 1024 < size) THROW("Avatar cannot be larger than 5MiB");

  // Write post data
  string url = postFile(path, file, type, size, size);

  // Write to DB
  args->insert("url", url);
  query(&Transaction::returnReply,
        "CALL PutProfileAvatar(%(profile)S, %(url)S)", args);

  return true;
}


bool Transaction::apiConfirmProfileAvatar() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  string path = "/" + args->getString("profile");
  string file = args->getString("file");
  string guid = args->getString("guid");

  // Write to DB
  args->insert("url", "/" + guid + "/" + URI::encode(file));
  query(&Transaction::returnOK,
        "CALL ConfirmProfileAvatar(%(profile)S, %(url)S)", args);

  return true;
}


bool Transaction::apiFollow() {
  JSON::ValuePtr args = parseArgs();
  authorize();
  args->insert("user", user->getName());

  query(&Transaction::returnOK, "CALL Follow(%(user)S, %(profile)S)", args);

  return true;
}


bool Transaction::apiUnfollow() {
  JSON::ValuePtr args = parseArgs();
  authorize();
  args->insert("user", user->getName());

  query(&Transaction::returnOK, "CALL Unfollow(%(user)S, %(profile)S)", args);

  return true;
}


bool Transaction::apiGetThings() {
  JSON::ValuePtr args = parseArgs();

  query(&Transaction::returnList,
        "CALL FindThings(%(query)S, %(license)S, %(limit)u, %(offset)u)", args);
  return true;
}


bool Transaction::apiThingAvailable() {
  query(&Transaction::returnBool, "CALL ThingAvailable(%(profile)S, %(thing)S)",
        parseArgs());
  return true;
}


bool Transaction::apiGetThing() {
  JSON::ValuePtr args = parseArgs();

  args->insert("view_id", getViewID());

  jsonFields = "*thing files comments stars";

  query(&Transaction::returnJSONFields,
        "CALL GetThing(%(profile)S, %(thing)S, %(view_id)S)", args);

  return true;
}


bool Transaction::apiPublishThing() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL PublishThing(%(profile)S, %(thing)S)", args);

  return true;
}


bool Transaction::apiPutThing() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  if (!args->hasString("type")) args->insert("type", "project");

  query(&Transaction::returnOK,
        "CALL PutThing(%(profile)S, %(thing)S, %(type)S, %(title)S, "
        "%(license)S, %(instructions)S)", args);

  return true;
}


bool Transaction::apiRenameThing() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL RenameThing(%(profile)S, %(thing)S, %(name)S)", args);

  return true;
}


bool Transaction::apiDeleteThing() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK, "CALL DeleteThing(%(profile)S, %(thing)S)",
        args);

  return true;
}


bool Transaction::apiStarThing() {
  JSON::ValuePtr args = parseArgs();
  authorize();
  args->insert("user", user->getName());

  query(&Transaction::returnOK,
        "CALL StarThing(%(user)S, %(profile)S, %(thing)S)", args);

  return true;
}


bool Transaction::apiUnstarThing() {
  JSON::ValuePtr args = parseArgs();
  authorize();
  args->insert("user", user->getName());

  query(&Transaction::returnOK,
        "CALL UnstarThing(%(user)S, %(profile)S, %(thing)S)", args);

  return true;
}


bool Transaction::apiTagThing() {
  JSON::ValuePtr args = parseArgs();
  authorize(hasTag("featured") ? AuthFlags::AUTH_ADMIN : AuthFlags::AUTH_NONE);

  query(&Transaction::returnOK,
        "CALL MultiTagThing(%(profile)S, %(thing)S, %(tags)S)", args);

  return true;
}


bool Transaction::apiUntagThing() {
  JSON::ValuePtr args = parseArgs();
  authorize(hasTag("featured") ? AuthFlags::AUTH_ADMIN : AuthFlags::AUTH_NONE,
            args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL MultiUntagThing(%(profile)S, %(thing)S, %(tags)S)", args);

  return true;
}


void Transaction::commentAuth() {
  auto &args = *parseArgs();

  string owner = args.getString("owner", "");
  if (owner.empty()) args.insert("owner", getUser().getName());

  authorize(args.getString("owner"));
}


bool Transaction::apiPostComment() {
  JSON::ValuePtr args = parseArgs();
  commentAuth();

  query(&Transaction::returnU64,
        "CALL PostComment(%(owner)S, %(profile)S, %(thing)S, %(parent)u, "
        "%(text)S)", args);

  return true;
}


bool Transaction::apiUpdateComment() {
  JSON::ValuePtr args = parseArgs();
  commentAuth();

  query(&Transaction::returnOK,
        "CALL UpdateComment(%(owner)S, %(comment)u, %(text)S)", args);

  return true;
}


bool Transaction::apiDeleteComment() {
  JSON::ValuePtr args = parseArgs();
  if (!args->hasString("owner")) args->insert("owner", getUser().getName());
  authorize(args->getString("owner"));

  query(&Transaction::returnOK, "CALL DeleteComment(%(owner)S, %(comment)u)",
        args);

  return true;
}


bool Transaction::apiUpvoteComment() {
  JSON::ValuePtr args = parseArgs();
  commentAuth();

  query(&Transaction::returnJSON, "CALL UpvoteComment(%(owner)S, %(comment)u)",
        args);

  return true;
}


bool Transaction::apiDownvoteComment() {
  JSON::ValuePtr args = parseArgs();
  commentAuth();

  query(&Transaction::returnJSON,
        "CALL DownvoteComment(%(owner)S, %(comment)u)", args);

  return true;
}


bool Transaction::apiDownloadFile() {
  JSON::ValuePtr args = parseArgs();

  query(&Transaction::download,
        "CALL DownloadFile(%(profile)S, %(thing)S, %(file)S, %(count)b)", args);

  return true;
}


bool Transaction::apiUploadFile() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  // Restrict by extension
  string file = args->getString("file");
  string ext = String::toLower(SystemUtilities::extension(file));
  if (ext == "exe" || ext == "com" || ext == "bat" || ext == "lnk" ||
      ext == "chm" || ext == "hta")
    THROWX("Uploading ." << ext << " files is not allowed.",
            HTTP_UNAUTHORIZED);

  // Restrict by media-type
  string type = args->getString("type");
  if (type == "application/x-msdownload" ||
      type == "application/x-msdos-program" ||
      type == "application/x-msdos-windows" ||
      type == "application/x-download" ||
      type == "application/bat" ||
      type == "application/x-bat" ||
      type == "application/com" ||
      type == "application/x-com" ||
      type == "application/exe" ||
      type == "application/x-exe" ||
      type == "application/x-winexe" ||
      type == "application/x-winhlp" ||
      type == "application/x-winhelp" ||
      type == "application/x-javascript" ||
      type == "application/hta" ||
      type == "application/x-ms-shortcut" ||
      type == "application/octet-stream" ||
      type == "vms/exe")
    THROWX("Uploading files of type " << type << " not allowed.",
            HTTP_UNAUTHORIZED);

    // Compute path
  string path =
    "/" + args->getString("profile") + "/" + args->getString("thing");
  uint32_t size = args->getU32("size");

  // Write post data
  path = postFile(path, file, type, size, size);
  args->insert("path", path);

  query(&Transaction::returnReply,
        "CALL UploadFile(%(profile)S, %(thing)S, %(file)S, %(type)S, %(size)u, "
        "%(path)S, %(caption)S, %(visibility)S)", args);

  return true;
}


bool Transaction::apiUpdateFile() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  // Write to DB
  query(&Transaction::returnOK,
        "CALL UpdateFile(%(profile)S, %(thing)S, %(file)S, %(caption)S, "
        "%(visibility)S, %(rename)S)", args);

  return true;
}


bool Transaction::apiDeleteFile() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL DeleteFile(%(profile)S, %(thing)S, %(file)S)", args);

  return true;
}


bool Transaction::apiConfirmFile() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL ConfirmFile(%(profile)S, %(thing)S, %(file)S)", args);

  return true;
}


bool Transaction::apiFileUp() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL FileUp(%(profile)S, %(thing)S, %(file)S)", args);

  return true;
}


bool Transaction::apiFileDown() {
  JSON::ValuePtr args = parseArgs();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL FileDown(%(profile)S, %(thing)S, %(file)S)", args);

  return true;
}


bool Transaction::apiGetTags() {
  JSON::ValuePtr args = parseArgs();
  query(&Transaction::returnList, "CALL GetTags(%(limit)u)", args);
  return true;
}


bool Transaction::apiGetTagThings() {
  JSON::ValuePtr args = parseArgs();
  query(&Transaction::returnList,
        "CALL FindThingsByTag(%(tag)S, %(limit)u, %(offset)u)", args);
  return true;
}


bool Transaction::apiGetLicenses() {
  query(&Transaction::returnList, "CALL GetLicenses()");
  return true;
}


bool Transaction::apiGetEvents() {
  JSON::ValuePtr args = parseArgs();
  query(&Transaction::returnList, "CALL GetEvents(%(subject)S, %(action)S, "
        "%(object_type)S, %(object)S, %(owner)S, %(following)b, %(since)S, "
        "%(limit)u)", args);
  return true;
}


bool Transaction::apiNotFound() {
  THROWX("Invalid API method " << getURI().getPath(), HTTP_NOT_FOUND);
  return true;
}


bool Transaction::notFound() {
  THROWX("Not found " << getURI().getPath(), HTTP_NOT_FOUND);
  return true;
}


string Transaction::nextJSONField() {
  if (!jsonFields) return "";

  const char *start = jsonFields;
  const char *end = jsonFields;
  while (*end && *end != ' ') end++;

  jsonFields = *end ? end + 1 : 0;

  return string(start, end - start);
}


void Transaction::download(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_BEGIN_RESULT:
  case MariaDB::EventDB::EVENTDB_END_RESULT:
    break;

  case MariaDB::EventDB::EVENTDB_DONE:
    setCache(Time::SEC_PER_HOUR);
    redirect(redirectTo);
    break;

  case MariaDB::EventDB::EVENTDB_ROW: {
    string path = db->getString(0);
    string size = getArgs()->getString("size", "orig");

    // Is absolute URL?
    if (String::startsWith(path, "http://") ||
        String::startsWith(path, "https://")) {

      string pixels = "32"; // Thumb
      if (size == "alarge") pixels = "200";
      else if (size == "asmall") pixels = "150";

      URI url(path);

      if (url.getHost().find("github") != string::npos)
        url["s"] = pixels;

      else if (url.getHost().find("facebook") != string::npos) {
        url["width"] = pixels;
        url["height"] = pixels;

      } else if (url.getHost().find("google") != string::npos)
        url["sz"] = pixels;

      redirectTo = url.toString();
      break;
    }

    string type = 1 < db->getFieldCount() ? db->getString(1) : "";

    // Is resizable image?
    if (size != "orig" &&
        (type == "image/png" || type == "image/gif" || type == "image/jpeg" ||
         type == "avatar")) {
      redirectTo = app.getImageHost() + path + "?size=" + size;
      break;
    }

    redirectTo = "//" + app.getAWSBucket() + ".s3.amazonaws.com" + path;
    break;
  }

  default: returnReply(state); return;
  }
}


void Transaction::authUser(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_ERROR:
    // Not really logged in, clear cookie
    clearAuthCookie();

    // Fall through

  default: return returnJSONFields(state);
  }
}


void Transaction::login(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_BEGIN_RESULT:
  case MariaDB::EventDB::EVENTDB_END_RESULT:
    break;

  case MariaDB::EventDB::EVENTDB_ROW:
    user->setName(db->getString(0));
    user->setAuth(db->getU64(1));
    break;

  case MariaDB::EventDB::EVENTDB_DONE:
    app.getUserManager().updateSession(user);
    setAuthCookie();

    getJSONWriter()->write("ok");
    setContentType("application/json");
    redirect("/");
    break;

  default: returnReply(state); return;
  }
}


void Transaction::registration(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_DONE:
    user->setName(getArgs()->getString("profile"));
    app.getUserManager().updateSession(user);
    setAuthCookie();
    // Fall through

  default: returnOK(state); return;
  }
}


void Transaction::returnOK(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_DONE:
    getJSONWriter()->write("ok");
    setContentType("application/json");
    reply();
    break;

  default: returnReply(state);
  }
}


void Transaction::returnList(MariaDB::EventDB::state_t state) {
  if (state != MariaDB::EventDB::EVENTDB_ROW) returnJSON(state);

  switch (state) {
  case MariaDB::EventDB::EVENTDB_ROW:
    writer->beginAppend();

    if (db->getFieldCount() == 1) db->writeField(*writer, 0);
    else db->writeRowDict(*writer);
    break;

  case MariaDB::EventDB::EVENTDB_BEGIN_RESULT:
    writer->beginList();
    break;

  case MariaDB::EventDB::EVENTDB_END_RESULT:
    writer->endList();
    break;

  default: break;
  }
}


void Transaction::returnBool(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_ROW:
    writer->writeBoolean(db->getBoolean(0));
    break;

  default: return returnJSON(state);
  }
}



void Transaction::returnU64(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_ROW:
    writer->write(db->getU64(0));
    break;

  default: return returnJSON(state);
  }
}


void Transaction::returnS64(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_ROW:
    writer->write(db->getS64(0));
    break;

  default: return returnJSON(state);
  }
}


void Transaction::returnJSON(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_ROW:
    if (db->getFieldCount() == 1) db->writeField(*writer, 0);
    else db->writeRowDict(*writer);
    break;

  case MariaDB::EventDB::EVENTDB_BEGIN_RESULT:
    setContentType("application/json");
    if (writer.isNull()) writer = getJSONWriter();
    break;

  case MariaDB::EventDB::EVENTDB_END_RESULT: break;

  default: return returnReply(state);
  }
}


void Transaction::returnJSONFields(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_ROW:
    if (writer->inDict()) db->insertRow(*writer, 0, -1, false);

    else if (db->getFieldCount() == 1) {
      writer->beginAppend();
      db->writeField(*writer, 0);

    } else {
      writer->appendDict();
      db->insertRow(*writer, 0, -1, false);
      writer->endDict();
    }
    break;

  case MariaDB::EventDB::EVENTDB_BEGIN_RESULT: {
    setContentType("application/json");
    if (writer.isNull()) {
      writer = getJSONWriter();
      writer->beginDict();
    }

    string field = nextJSONField();
    if (field.empty()) THROW("Unexpected result set");
    if (field[0] == '*') writer->insertDict(field.substr(1));
    else writer->insertList(field);
    break;
  }

  case MariaDB::EventDB::EVENTDB_END_RESULT:
    if (writer->inList()) writer->endList();
    else writer->endDict();
    break;

  case MariaDB::EventDB::EVENTDB_DONE:
    if (!writer.isNull()) writer->endDict();
    // Fall through

  default: return returnReply(state);
  }
}


void Transaction::returnReply(MariaDB::EventDB::state_t state) {
  switch (state) {
  case MariaDB::EventDB::EVENTDB_DONE:
    writer.release();
    reply();
    break;

  case MariaDB::EventDB::EVENTDB_RETRY:
    if (!writer.isNull()) writer->reset();
    getOutputBuffer().clear();
    break;

  case MariaDB::EventDB::EVENTDB_ERROR: {
    Event::HTTPStatus error = HTTP_INTERNAL_SERVER_ERROR;

    switch (db->getErrorNumber()) {
    case ER_SIGNAL_NOT_FOUND: error = HTTP_NOT_FOUND; break;
    case ER_SIGNAL_EXCEPTION: error = HTTP_BAD_REQUEST; break;
    default: break;
    }

    LOG_ERROR("DB:" << db->getErrorNumber() << ": " << db->getError());
    sendError(error, db->getError());
    THROWX(db->getError(), error);

    break;
  }

  default:
    getOutputBuffer().clear();
    sendError(HTTP_INTERNAL_SERVER_ERROR);
    THROWX("Unexpected DB response", HTTP_INTERNAL_SERVER_ERROR);
    return;
  }
}
