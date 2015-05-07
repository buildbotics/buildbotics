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
#include <cbang/util/DefaultCatch.h>
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


Transaction::Transaction(App &app, evhttp_request *req) :
  Request(req), Event::OAuth2Login(app.getEventClient()), app(app),
  jsonFields(0) {
  LOG_DEBUG(5, "Transaction()");
}


Transaction::~Transaction() {
  LOG_DEBUG(5, "~Transaction()");
}


SmartPointer<JSON::Dict> Transaction::parseArgsPtr() {
  return SmartPointer<JSON::Dict>::Null(&parseArgs());
}


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


void Transaction::query(event_db_member_functor_t member, const string &s,
                        const SmartPointer<JSON::Value> &dict) {
  if (db.isNull()) db = app.getDBConnection();
  db->query(this, member, s, dict);
}


bool Transaction::apiError(int status, const string &msg) {
  LOG_ERROR(msg);

  // Reset output
  if (!writer.isNull()) writer.release();
  getOutputBuffer().clear();

  // Drop DB connection
  if (!db.isNull()) db->close();

  // Send error message
  setContentType("text/plain");
  reply(status, msg);

  return true;
}


bool Transaction::pleaseLogin() {
  apiError(HTTP_UNAUTHORIZED, "Not authorized, please login");
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
  string guid = hash.toBase64();

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


void Transaction::processProfile(const SmartPointer<JSON::Value> &profile) {
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

      query(&Transaction::login, "CALL Login(%(provider)s, %(id)s, %(name)s, "
            "%(email)s, %(avatar)s);", profile);

      return;
    } CATCH_ERROR;

  redirect("/");
}


bool Transaction::apiAuthUser() {
  authorize();

  SmartPointer<JSON::Dict> dict = new JSON::Dict;
  dict->insert("provider", user->getProvider());
  dict->insert("id", user->getID());

  jsonFields = "*profile things followers following starred badges events auth";
  query(&Transaction::authUser, "CALL GetUser(%(provider)s, %(id)s)", dict);

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

  return OAuth2Login::authorize(*this, *auth, user->getToken());
}


bool Transaction::apiAuthLogout() {
  clearAuthCookie(1);
  getJSONWriter()->write("ok");
  setContentType("application/json");
  reply();
  return true;
}


bool Transaction::apiGetProfiles() {
  JSON::ValuePtr args = parseArgsPtr();
  query(&Transaction::returnList,
        "CALL FindProfiles(%(query)s, %(limit)u, %(offset)u)", args);
  return true;
}


bool Transaction::apiProfileRegister() {
  lookupUser();
  if (user.isNull()) return pleaseLogin();

  SmartPointer<JSON::Dict> dict = new JSON::Dict;
  dict->insert("profile", getArg("profile"));
  dict->insert("provider", user->getProvider());
  dict->insert("id", user->getID());

  query(&Transaction::registration,
        "CALL Register(%(profile)s, %(provider)s, %(id)s)", dict);
  return true;
}


bool Transaction::apiProfileAvailable() {
  query(&Transaction::returnBool, "CALL Available(%(profile)s)",
        parseArgsPtr());
  return true;
}


bool Transaction::apiProfileSuggest() {
  lookupUser();
  if (user.isNull()) return pleaseLogin();

  SmartPointer<JSON::Dict> dict = new JSON::Dict;
  dict->insert("provider", user->getProvider());
  dict->insert("id", user->getID());

  query(&Transaction::returnList, "CALL Suggest(%(provider)s, %(id)s, 5)",
        dict);

  return true;
}


bool Transaction::apiPutProfile() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL PutProfile(%(profile)s, %(fullname)s, %(location)s, %(url)s, "
        "%(bio)s)", args);

  return true;
}


bool Transaction::apiGetProfile() {
  jsonFields = "*profile things followers following starred badges events";

  query(&Transaction::returnJSONFields, "CALL GetProfile(%(profile)s)",
        parseArgsPtr());

  return true;
}


bool Transaction::apiGetProfileAvatar() {
  JSON::ValuePtr args = parseArgsPtr();
  query(&Transaction::download, "CALL GetProfileAvatar(%(profile)s)", args);
  return true;
}


bool Transaction::apiPutProfileAvatar() {
  JSON::ValuePtr args = parseArgsPtr();
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
        "CALL PutProfileAvatar(%(profile)s, %(url)s)", args);

  return true;
}


bool Transaction::apiConfirmProfileAvatar() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  string path = "/" + args->getString("profile");
  string file = args->getString("file");
  string guid = args->getString("guid");

  // Write to DB
  args->insert("url", "/" + guid + "/" + URI::encode(file));
  query(&Transaction::returnOK,
        "CALL ConfirmProfileAvatar(%(profile)s, %(url)s)", args);

  return true;
}


bool Transaction::apiFollow() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("user", user->getName());

  query(&Transaction::returnOK, "CALL Follow(%(user)s, %(profile)s)", args);

  return true;
}


bool Transaction::apiUnfollow() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("user", user->getName());

  query(&Transaction::returnOK, "CALL Unfollow(%(user)s, %(profile)s)", args);

  return true;
}


bool Transaction::apiGetThings() {
  JSON::ValuePtr args = parseArgsPtr();

  query(&Transaction::returnList,
        "CALL FindThings(%(query)s, %(license)s, %(limit)u, %(offset)u)", args);
  return true;
}


bool Transaction::apiThingAvailable() {
  query(&Transaction::returnBool, "CALL ThingAvailable(%(profile)s, %(thing)s)",
        parseArgsPtr());
  return true;
}


bool Transaction::apiGetThing() {
  JSON::ValuePtr args = parseArgsPtr();

  args->insert("view_id", getViewID());

  jsonFields = "*thing files comments stars";

  query(&Transaction::returnJSONFields,
        "CALL GetThing(%(profile)s, %(thing)s, %(view_id)s)", args);

  return true;
}


bool Transaction::apiPublishThing() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL PublishThing(%(profile)s, %(thing)s)", args);

  return true;
}


bool Transaction::apiPutThing() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  if (!args->hasString("type")) args->insert("type", "project");

  query(&Transaction::returnOK,
        "CALL PutThing(%(profile)s, %(thing)s, %(type)s, %(title)s, "
        "%(url)s, %(license)s, %(instructions)s)", args);

  return true;
}


bool Transaction::apiRenameThing() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL RenameThing(%(profile)s, %(thing)s, %(name)s)", args);

  return true;
}


bool Transaction::apiDeleteThing() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK, "CALL DeleteThing(%(profile)s, %(thing)s)",
        args);

  return true;
}


bool Transaction::apiStarThing() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("user", user->getName());

  query(&Transaction::returnOK,
        "CALL StarThing(%(user)s, %(profile)s, %(thing)s)", args);

  return true;
}


bool Transaction::apiUnstarThing() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("user", user->getName());

  query(&Transaction::returnOK,
        "CALL UnstarThing(%(user)s, %(profile)s, %(thing)s)", args);

  return true;
}


bool Transaction::apiTagThing() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();

  query(&Transaction::returnOK,
        "CALL MultiTagThing(%(profile)s, %(thing)s, %(tags)s)", args);

  return true;
}


bool Transaction::apiUntagThing() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL MultiUntagThing(%(profile)s, %(thing)s, %(tags)s)", args);

  return true;
}


bool Transaction::apiPostComment() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("owner", user->getName());

  query(&Transaction::returnU64,
        "CALL PostComment(%(owner)s, %(profile)s, %(thing)s, %(ref)u, "
        "%(text)s)", args);

  return true;
}


bool Transaction::apiUpdateComment() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("owner", user->getName());

  query(&Transaction::returnOK,
        "CALL UpdateComment(%(owner)s, %(comment)u, %(text)s)", args);

  return true;
}


bool Transaction::apiDeleteComment() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("owner", user->getName());

  query(&Transaction::returnOK, "CALL DeleteComment(%(owner)s, %(comment)u)",
        args);

  return true;
}


bool Transaction::apiUpvoteComment() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("owner", user->getName());

  query(&Transaction::returnOK, "CALL UpvoteComment(%(owner)s, %(comment)u)",
        args);

  return true;
}


bool Transaction::apiDownvoteComment() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize();
  args->insert("owner", user->getName());

  query(&Transaction::returnOK, "CALL DownvoteComment(%(owner)s, %(comment)u)",
        args);

  return true;
}


bool Transaction::apiDownloadFile() {
  JSON::ValuePtr args = parseArgsPtr();

  query(&Transaction::download,
        "CALL DownloadFile(%(profile)s, %(thing)s, %(file)s, %(count)b)", args);

  return true;
}


bool Transaction::apiUploadFile() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  // Restrict by extension
  string file = args->getString("file");
  string ext = String::toLower(SystemUtilities::extension(file));
  if (ext == "exe" || ext == "com" || ext == "bat" || ext == "lnk" ||
      ext == "chm" || ext == "hta") {
    apiError(HTTP_UNAUTHORIZED, "Uploading ." + ext +
             " files is not allowed.");
    return true;
  }

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
      type == "vms/exe") {
    apiError(HTTP_UNAUTHORIZED, "Uploading files of type " + type +
             " not allowed.");
    return true;
  }

    // Compute path
  string path =
    "/" + args->getString("profile") + "/" + args->getString("thing");
  uint32_t size = args->getU32("size");

  // Write post data
  path = postFile(path, file, type, size, size);
  args->insert("path", path);

  query(&Transaction::returnReply,
        "CALL UploadFile(%(profile)s, %(thing)s, %(file)s, %(type)s, %(size)u, "
        "%(path)s, %(caption)s, %(visibility)s)", args);

  return true;
}


bool Transaction::apiUpdateFile() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  // Write to DB
  query(&Transaction::returnOK,
        "CALL UpdateFile(%(profile)s, %(thing)s, %(file)s, %(caption)s, "
        "%(visibility)s, %(rename)s)", args);

  return true;
}


bool Transaction::apiDeleteFile() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL DeleteFile(%(profile)s, %(thing)s, %(file)s)", args);

  return true;
}


bool Transaction::apiConfirmFile() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL ConfirmFile(%(profile)s, %(thing)s, %(file)s)", args);

  return true;
}


bool Transaction::apiFileUp() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL FileUp(%(profile)s, %(thing)s, %(file)s)", args);

  return true;
}


bool Transaction::apiFileDown() {
  JSON::ValuePtr args = parseArgsPtr();
  authorize(args->getString("profile"));

  query(&Transaction::returnOK,
        "CALL FileDown(%(profile)s, %(thing)s, %(file)s)", args);

  return true;
}


bool Transaction::apiGetTags() {
  JSON::ValuePtr args = parseArgsPtr();
  query(&Transaction::returnList, "CALL GetTags(%(limit)u)", args);
  return true;
}


bool Transaction::apiGetTagThings() {
  JSON::ValuePtr args = parseArgsPtr();
  query(&Transaction::returnList,
        "CALL FindThingsByTag(%(tag)s, %(limit)u, %(offset)u)", args);
  return true;
}


bool Transaction::apiGetLicenses() {
  query(&Transaction::returnList, "CALL GetLicenses()");
  return true;
}


bool Transaction::apiGetEvents() {
  JSON::ValuePtr args = parseArgsPtr();
  query(&Transaction::returnList, "CALL GetEvents(%(subject)s, %(action)s, "
        "%(object_type)s, %(object)s, %(owner)s, %(following)b, %(since)s, "
        "%(limit)u)", args);
  return true;
}


bool Transaction::apiNotFound() {
  apiError(HTTP_NOT_FOUND, "Invalid API method " + getURI().getPath());
  return true;
}


bool Transaction::notFound() {
  apiError(HTTP_NOT_FOUND, "Not found " + getURI().getPath());
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


void Transaction::download(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT:
  case MariaDB::EventDBCallback::EVENTDB_END_RESULT:
    break;

  case MariaDB::EventDBCallback::EVENTDB_DONE:
    setCache(Time::SEC_PER_HOUR);
    redirect(redirectTo);
    break;

  case MariaDB::EventDBCallback::EVENTDB_ROW: {
    string path = db->getString(0);
    string size = getArgs().getString("size", "orig");

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


void Transaction::authUser(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ERROR:
    // Not really logged in, clear cookie
    clearAuthCookie();

    // Fall through

  default: return returnJSONFields(state);
  }
}


void Transaction::login(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT:
  case MariaDB::EventDBCallback::EVENTDB_END_RESULT:
    break;

  case MariaDB::EventDBCallback::EVENTDB_ROW:
    user->setName(db->getString(0));
    user->setAuth(db->getU64(1));
    break;

  case MariaDB::EventDBCallback::EVENTDB_DONE:
    app.getUserManager().updateSession(user);
    setAuthCookie();

    getJSONWriter()->write("ok");
    setContentType("application/json");
    redirect("/");
    break;

  default: returnReply(state); return;
  }
}


void Transaction::registration(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_DONE:
    user->setName(getArg("profile"));
    app.getUserManager().updateSession(user);
    setAuthCookie();
    // Fall through

  default: returnOK(state); return;
  }
}


void Transaction::returnOK(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_DONE:
    getJSONWriter()->write("ok");
    setContentType("application/json");
    reply();
    break;

  default: returnReply(state);
  }

}


void Transaction::returnList(MariaDB::EventDBCallback::state_t state) {
  if (state != MariaDB::EventDBCallback::EVENTDB_ROW) returnJSON(state);

  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
    writer->beginAppend();

    if (db->getFieldCount() == 1) db->writeField(*writer, 0);
    else db->writeRowDict(*writer);
    break;

  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT:
    writer->beginList();
    break;

  case MariaDB::EventDBCallback::EVENTDB_END_RESULT:
    writer->endList();
    break;

  default: break;
  }
}


void Transaction::returnBool(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
    writer->writeBoolean(db->getBoolean(0));
    break;

  default: return returnJSON(state);
  }
}



void Transaction::returnU64(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
    writer->write(db->getU64(0));
    break;

  default: return returnJSON(state);
  }
}


void Transaction::returnS64(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
    writer->write(db->getS64(0));
    break;

  default: return returnJSON(state);
  }
}


void Transaction::returnJSON(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
    if (db->getFieldCount() == 1) db->writeField(*writer, 0);
    else db->writeRowDict(*writer);
    break;

  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT:
    setContentType("application/json");
    if (writer.isNull()) writer = getJSONWriter();
    break;

  case MariaDB::EventDBCallback::EVENTDB_END_RESULT: break;

  default: return returnReply(state);
  }
}


void Transaction::returnJSONFields(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
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

  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT: {
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

  case MariaDB::EventDBCallback::EVENTDB_END_RESULT:
    if (writer->inList()) writer->endList();
    else writer->endDict();
    break;

  case MariaDB::EventDBCallback::EVENTDB_DONE:
    if (!writer.isNull()) writer->endDict();
    // Fall through

  default: return returnReply(state);
  }
}


void Transaction::returnReply(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_DONE:
    writer.release();
    reply();
    break;

  case MariaDB::EventDBCallback::EVENTDB_RETRY:
    if (!writer.isNull()) writer->reset();
    getOutputBuffer().clear();
    break;

  case MariaDB::EventDBCallback::EVENTDB_ERROR: {
    int error = HTTP_INTERNAL_SERVER_ERROR;

    switch (db->getErrorNumber()) {
    case ER_SIGNAL_NOT_FOUND: error = HTTP_NOT_FOUND; break;
    default: break;
    }

    LOG_ERROR("DB:" << db->getErrorNumber() << ": " << db->getError());
    apiError(error, db->getError());

    break;
  }

  default:
    apiError(HTTP_INTERNAL_SERVER_ERROR, "Unexpected DB response");
    return;
  }
}
