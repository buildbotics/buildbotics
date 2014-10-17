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

#include <cbang/json/JSON.h>
#include <cbang/log/Logger.h>
#include <cbang/util/DefaultCatch.h>

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
  if (user.isNull()) return;

  // Check if the user has expired
  if (user->hasExpired()) {
    user.release();
    return;
  }

  // Check if the user auth is expiring soon
  if (user->isExpiring()) {
    app.getUserManager().updateID(user);
    user->setCookie(*this);
  }
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


bool Transaction::apiNotFound() {
  THROWCS("Invalid API method: " << getURI().getPath(), HTTP_NOT_FOUND);
}
