/******************************************************************************\

                 This file is part of the BuildBotics Webserver.

                Copyright (c) 2014-2015, Cauldron Development LLC
                               All rights reserved.

        The BuildBotics Webserver is free software: you can redistribute
        it and/or modify it under the terms of the GNU General Public
        License as published by the Free Software Foundation, either
        version 2 of the License, or (at your option) any later version.

        The BuildBotics Webserver is distributed in the hope that it will
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
#include <cbang/security/Digest.h>

#include <mysql/mysqld_error.h>

using namespace std;
using namespace cb;
using namespace BuildBotics;


Transaction::Transaction(App &app, evhttp_request *req) :
  Request(req), Event::OAuth2Login(app.getEventClient()), app(app) {}


SmartPointer<JSON::Dict> Transaction::getArgsPtr() {
  return SmartPointer<JSON::Dict>::Null(&getArgs());
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
    setCookie(app.getSessionCookieName(), "", "", "/");
    return false;
  }

  // Check if the user auth is expiring soon
  if (user->isExpiring()) {
    app.getUserManager().updateSession(user);
    user->setCookie(*this);
  }

  LOG_DEBUG(3, "User: " << user->getName());

  return true;
}


void Transaction::requireUser() {
  lookupUser();
  if (user.isNull() || !user->isAuthenticated())
    THROWX("Not authorized, please login", HTTP_UNAUTHORIZED);
}


void Transaction::requireUser(const string &name) {
  requireUser();
  if (user->getName() != name) THROWX("Not authorized", HTTP_UNAUTHORIZED);
}


bool Transaction::isUser(const string &name) {
  return !user.isNull() && user->getName() == name;
}


void Transaction::query(event_db_member_functor_t member, const string &s,
                        const SmartPointer<JSON::Value> &dict) {
  if (db.isNull()) db = app.getDBConnection();
  db->query(this, member, s, dict);
}


bool Transaction::apiError(int status, int code, const string &msg) {
  LOG_ERROR(msg);

  // Reset output
  if (!writer.isNull()) {
    writer->reset();
    writer.release();
  }
  getOutputBuffer().clear();

  // Drop DB connection
  if (!db.isNull()) db->close();

  // Error message
  writer = getJSONWriter();
  writer->beginList();
  writer->appendDict();
  writer->insert("message", msg);
  writer->insert("code", code);
  writer->endDict();
  writer->endList();

  // Send it
  writer.release();
  setContentType("application/json");
  reply(status);

  return true;
}


bool Transaction::pleaseLogin() {
  apiError(HTTP_OK, HTTP_UNAUTHORIZED, "Not authorized, please login");
  return true;
}


void Transaction::processProfile(const SmartPointer<JSON::Value> &profile) {
  if (!profile.isNull())
    try {
      // Authenticate user
      user->authenticate(profile->getString("provider"),
                         profile->getString("id"));
      app.getUserManager().updateSession(user);

      query(&Transaction::login, "CALL Login(%(provider)s, %(id)s, %(name)s, "
            "%(email)s, %(avatar)s);", profile);

      return;
    } CATCH_ERROR;

  redirect("/");
}


bool Transaction::apiAuthUser() {
  lookupUser();

  if (!user.isNull() && user->isAuthenticated()) {
    SmartPointer<JSON::Dict> dict = new JSON::Dict;
    dict->insert("provider", user->getProvider());
    dict->insert("id", user->getID());

    query(&Transaction::profile, "CALL GetUser(%(provider)s, %(id)s)", dict);

  } else pleaseLogin();

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
  if (!uri.has("state")) user->setCookie(*this);

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
  setCookie(app.getSessionCookieName(), "", "", "/", 1);
  redirect("/");
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
  query(&Transaction::returnBool, "CALL Available(%(profile)s)", getArgsPtr());
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
  lookupUser();
  if (user.isNull()) return pleaseLogin();

  THROW("Not yet implemented");
}


bool Transaction::apiGetProfile() {
  lookupUser();
  JSON::ValuePtr args = getArgsPtr();
  args->insertBoolean("unpublished", isUser(args->getString("profile")));

  query(&Transaction::profile, "CALL GetProfile(%(profile)s, %(unpublished)b)",
        args);

  return true;
}


bool Transaction::apiGetThings() {
  query(&Transaction::returnList,
        "CALL FindThings(null, null, null, null, null, null)");
  return true;
}


bool Transaction::apiThingAvailable() {
  query(&Transaction::returnBool, "CALL ThingAvailable(%(profile)s, %(thing)s)",
        getArgsPtr());
  return true;
}


bool Transaction::apiGetThing() {
  lookupUser();
  JSON::ValuePtr args = getArgsPtr();
  args->insertBoolean("unpublished", isUser(args->getString("profile")));

  query(&Transaction::thing,
        "CALL GetThing(%(profile)s, %(thing)s, %(unpublished)b)", args);

  return true;
}


bool Transaction::apiPutThing() {
  JSON::Value &args = parseArgs();
  requireUser(args.getString("profile"));

  if (!args.hasString("type")) args.insert("type", "project");

  query(&Transaction::returnOK,
        "CALL PutThing(%(profile)s, %(thing)s, %(type)s, %(title)s, "
        "%(url)s, %(description)s, %(license)s, %(publish)b)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiDeleteThing() {
  THROW("Not yet implemented");
}


bool Transaction::apiStarThing() {
  JSON::Value &args = parseArgs();
  requireUser();
  args.insert("user", user->getName());

  query(&Transaction::returnOK,
        "CALL StarThing(%(user)s, %(profile)s, %(thing)s)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiUnstarThing() {
  JSON::Value &args = parseArgs();
  requireUser();
  args.insert("user", user->getName());

  query(&Transaction::returnOK,
        "CALL UnstarThing(%(user)s, %(profile)s, %(thing)s)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiTagThing() {
  JSON::Value &args = parseArgs();
  requireUser();

  query(&Transaction::returnOK,
        "CALL MultiTagThing(%(profile)s, %(thing)s, %(tags)s)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiUntagThing() {
  JSON::Value &args = parseArgs();
  requireUser(args.getString("profile"));

  query(&Transaction::returnOK,
        "CALL MultiUntagThing(%(profile)s, %(thing)s, %(tags)s)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiPostComment() {
  JSON::Value &args = parseArgs();
  requireUser();
  args.insert("owner", user->getName());

  query(&Transaction::returnU64,
        "CALL PostComment(%(owner)s, %(profile)s, %(thing)s, %(step)u, "
        "%(ref)u, %(text)s)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiUpdateComment() {
  JSON::Value &args = parseArgs();
  requireUser();
  args.insert("owner", user->getName());

  query(&Transaction::returnOK,
        "CALL UpdateComment(%(owner)s, %(comment)u, %(text)s)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiDeleteComment() {
  JSON::Value &args = parseArgs();
  requireUser();
  args.insert("owner", user->getName());

  query(&Transaction::returnOK, "CALL DeleteComment(%(owner)s, %(comment)u)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiDownloadFile() {
  JSON::Value &args = parseArgs();

  query(&Transaction::download,
        "CALL DownloadFile(%(profile)s, %(thing)s, %(file)s)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiGetFile() {
  THROW("Not yet implemented");
}


bool Transaction::apiPutFile() {
  JSON::Value &args = parseArgs();
  requireUser(args.getString("profile"));

  // Create GUID
  Digest hash("sha256");
  hash.update(args.getString("profile"));
  hash.update(args.getString("thing"));
  hash.update(args.getString("file"));
  hash.updateWith(Timer::now());
  string guid = hash.toBase64();

  // Create key
  string key = guid + "/" + args.getString("file");

  // Create URLs
  string uploadURL = "https://" + app.getAWSBucket() + ".s3.amazonaws.com/";
  string fileURL = "/" + args.getString("profile") + "/" +
    args.getString("thing") + "/" + args.getString("file");
  args.insert("url", uploadURL + key);

  // Build POST
  AWS4Post post(app.getAWSBucket(), key, app.getAWSUploadExpires(),
                Time::now(), "s3", app.getAWSRegion());

  uint32_t size = args.getU32("size");
  post.setLengthRange(size, size);
  post.insert("Content-Type", args.getString("type"));
  post.insert("acl", "public-read");
  post.insert("success_action_status", "201");
  post.addCondition("name", args.getString("file"));
  post.sign(app.getAWSID(), app.getAWSSecret());

  // Write JSON
  setContentType("application/json");
  writer = getJSONWriter();
  writer->beginDict();
  writer->insert("upload_url", uploadURL);
  writer->insert("file_url", fileURL);
  writer->insert("guid", guid);
  writer->beginInsert("post");
  post.write(*writer);
  writer->endDict();
  writer.release();

  // Write to DB
  query(&Transaction::returnReply,
        "CALL PutFile(%(profile)s, %(thing)s, %(file)s, %(step)s, %(type)s, "
        "%(size)u, %(url)s, %(caption)s, %(display)b)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiDeleteFile() {
  JSON::Value &args = parseArgs();
  requireUser(args.getString("profile"));

  query(&Transaction::returnOK,
        "CALL DeleteFile(%(profile)s, %(thing)s, %(file)s)",
        JSON::ValuePtr::Null(&args));

  return true;
}


bool Transaction::apiGetTags() {
  query(&Transaction::returnList, "CALL GetTags()");
  return true;
}


bool Transaction::apiAddTag() {
  string tag = getArg("tag");
  query(&Transaction::returnOK, "CALL AddTag('" + tag + "')");
  return true;
}


bool Transaction::apiDeleteTag() {
  string tag = getArg("tag");
  query(&Transaction::returnOK, "CALL DeleteTag('" + tag + "')");
  return true;
}


bool Transaction::apiGetLicenses() {
  query(&Transaction::returnList, "CALL GetLicenses()");
  return true;
}


bool Transaction::apiNotFound() {
  apiError(HTTP_OK, HTTP_NOT_FOUND, "Invalid API method " + getURI().getPath());
  return true;
}


void Transaction::download(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT:
  case MariaDB::EventDBCallback::EVENTDB_END_RESULT:
  case MariaDB::EventDBCallback::EVENTDB_DONE:
    break;

  case MariaDB::EventDBCallback::EVENTDB_ROW:
    redirect(db->getString(0));
    break;

  default: returnReply(state); return;
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
    user->setCookie(*this);

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
    user->setName(getArg("name"));
    app.getUserManager().updateSession(user);
    user->setCookie(*this);
    // Fall through

  default: returnOK(state); return;
  }
}


void Transaction::profile(MariaDB::EventDBCallback::state_t state) {
  string fieldName;
  if (db->haveResult() && db->getFieldCount())
    fieldName = db->getField(0).getName();

  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
    if (fieldName == "name") db->insertRow(*writer, 0, -1, false);
    else {
      writer->insertDict(db->getString(0));
      db->insertRow(*writer, 1, -1, false);
      writer->endDict();
    }
    break;

  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT:
    if (writer.isNull()) {
      writer = getJSONWriter();
      writer->beginDict();
    }

    if (fieldName == "thing") writer->insertDict("things");
    else if (fieldName == "follower") writer->insertDict("followers");
    else if (fieldName == "followed") writer->insertDict("following");
    else if (fieldName == "starred") writer->insertDict("starred");
    else if (fieldName == "badge") writer->insertDict("badges");
    else if (fieldName == "name") writer->insertDict("profile");
    else THROWS("Unexpected result set " << fieldName);
    break;

  case MariaDB::EventDBCallback::EVENTDB_END_RESULT:
    writer->endDict();
    break;

  case MariaDB::EventDBCallback::EVENTDB_DONE:
    writer->endDict();
    // Fall through

  default: return returnJSON(state);
  }
}


void Transaction::thing(MariaDB::EventDBCallback::state_t state) {
  string fieldName;
  if (db->haveResult() && db->getFieldCount())
    fieldName = db->getField(0).getName();

  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
    if (fieldName == "name") db->insertRow(*writer, 0, -1, false);
    else {
      writer->appendDict();
      db->insertRow(*writer, 0, -1, false);
      writer->endDict();
    }
    break;

  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT:
    if (writer.isNull()) {
      writer = getJSONWriter();
      writer->beginDict();
    }

    if (fieldName == "name") writer->insertDict("thing");
    else if (fieldName == "step") writer->insertList("steps");
    else if (fieldName == "file") writer->insertList("files");
    else if (fieldName == "comment") writer->insertList("comments");
    else if (fieldName == "profile") writer->insertList("stars");
    else THROWS("Unexpected result set " << fieldName);
    break;

  case MariaDB::EventDBCallback::EVENTDB_END_RESULT:
    if (writer->inList()) writer->endList();
    else writer->endDict();
    break;

  case MariaDB::EventDBCallback::EVENTDB_DONE:
    writer->endDict();
    // Fall through

  default: return returnJSON(state);
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


void Transaction::returnReply(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_DONE: {
    writer.release();
    reply();
    break;
  }

  case MariaDB::EventDBCallback::EVENTDB_ERROR: {
    int error = HTTP_INTERNAL_SERVER_ERROR;

    switch (db->getErrorNumber()) {
    case ER_SIGNAL_NOT_FOUND: error = HTTP_NOT_FOUND; break;
    default: break;
    }

    apiError(HTTP_OK, error,
             SSTR("DB:" << db->getErrorNumber() << ": " << db->getError()));
    break;
  }

  default:
    apiError(HTTP_INTERNAL_SERVER_ERROR, 0, "Unexpected DB response");
    return;
  }
}
