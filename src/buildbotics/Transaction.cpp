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

#include <cbang/event/Client.h>
#include <cbang/event/Buffer.h>
#include <cbang/event/BufferDevice.h>
#include <cbang/event/Event.h>

#include <cbang/json/JSON.h>
#include <cbang/log/Logger.h>
#include <cbang/util/DefaultCatch.h>
#include <cbang/db/maria/EventDB.h>

using namespace std;
using namespace cb;
using namespace BuildBotics;


Transaction::Transaction(App &app, evhttp_request *req) :
  Request(req), Event::OAuth2Login(app.getEventClient()), app(app) {}


void Transaction::lookupUser(bool skipAuthCheck) {
  if (!user.isNull()) return;

  // Get session ID
  string sid = findCookie(app.getSessionCookieName());
  if (sid.empty()) return;

  // Check Authorization header matches first 32 bytes of session ID
  if (!skipAuthCheck) {
    if (!inHas("Authorization")) return;

    string auth = inGet("Authorization");
    unsigned len = auth.length();

    if (len < 38 || auth.compare(0, 6, "Token ") ||
        sid.compare(0, len - 6, auth.c_str() + 6)) return;
  }

  // Get user
  user = app.getUserManager().get(sid);

  // Check if we have a user and it's not expired
  if (user.isNull() || user->hasExpired()) {
    user.release();
    setCookie(app.getSessionCookieName(), "", "", "/");
    return;
  }

  // Check if the user auth is expiring soon
  if (user->isExpiring()) {
    app.getUserManager().updateID(user);
    user->setCookie(*this);
  }
}


void Transaction::query(event_db_member_functor_t member, const string &s) {
  if (db.isNull()) db = app.getDBConnection();
  db->query(this, member, s);
}


void Transaction::apiError(int code, const string &msg) {
  LOG_ERROR(msg);

  // Reset output
  if (!writer.isNull()) writer->reset();
  getOutputBuffer().clear();

  // Error message
  writer = getJSONWriter();
  writer->beginDict();
  writer->insert("message", msg);
  writer->insert("code", code);
  writer->endDict();

  // Send it
  writer.release();
  setContentType("application/json");
  reply(code);
}


void Transaction::processProfile(const SmartPointer<JSON::Value> &profile) {
  if (!profile.isNull())
    try {
      // Update user
      user->setProfile(profile);
      app.getUserManager().updateID(user);
      user->setCookie(*this);

      // TODO Save user data to DB

    } CATCH_ERROR;

  // Redirect
  redirect("/");
}


bool Transaction::apiAuthUser(const JSON::ValuePtr &msg, JSON::Sync &sync) {
  lookupUser();

  if (!user.isNull() && user->isAuthenticated()) user->write(sync);
  else sync.writeNull();

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


bool Transaction::apiProjects() {
  query(&Transaction::returnList,
        "CALL FindThings(null, null, null, null, null, null)");
  return true;
}


bool Transaction::apiGetTags() {
  query(&Transaction::returnList, "CALL GetTags()");
  return true;
}


bool Transaction::apiAddTag() {
  string tag = getPathArg(0);
  query(&Transaction::returnOK, "CALL AddTag('" + tag + "')");
  return true;
}


bool Transaction::apiDeleteTag() {
  string tag = getPathArg(0);
  query(&Transaction::returnOK, "CALL DeleteTag('" + tag + "')");
  return true;
}


bool Transaction::apiNotFound() {
  apiError(HTTP_NOT_FOUND, "Invalid API method " + getURI().getPath());
  return true;
}


void Transaction::returnOK(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_DONE:
    getJSONWriter()->write("ok");
    setContentType("application/json");
    reply();
    break;

  case MariaDB::EventDBCallback::EVENTDB_ERROR: return returnJSON(state);

  default:
    apiError(HTTP_INTERNAL_SERVER_ERROR, "Unexpected DB response");
    return;
  }

}


void Transaction::returnList(MariaDB::EventDBCallback::state_t state) {
  returnJSON(state);

  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_ROW:
    writer->beginAppend();

    if (db->getFieldCount() == 1) db->writeField(*writer, 0);
    else db->writeRowList(*writer);
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


void Transaction::returnJSON(MariaDB::EventDBCallback::state_t state) {
  switch (state) {
  case MariaDB::EventDBCallback::EVENTDB_DONE:
    writer.release();
    setContentType("application/json");
    reply();
    break;

  case MariaDB::EventDBCallback::EVENTDB_ERROR:
    apiError(HTTP_INTERNAL_SERVER_ERROR, "DB: " + db->getError());
    break;

  case MariaDB::EventDBCallback::EVENTDB_BEGIN_RESULT:
    if (writer.isNull()) writer = getJSONWriter();
    break;

  default: break;
  }
}
