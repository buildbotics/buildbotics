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

using namespace std;
using namespace cb;
using namespace BuildBotics;


Transaction::Transaction(App &app, evhttp_request *req) :
  Request(req), app(app) {}


void Transaction::lookupUser(bool skipAuthCheck) {
  if (!user.isNull()) return;

  // Get session ID
  string sid = findCookie(app.getSessionCookieName());
  if (sid.empty()) return;

  // Check Authorization header matches at least first 32 bytes of session ID
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


bool Transaction::apiAuthUser(const JSON::ValuePtr &msg, JSON::Sync &sync) {
  lookupUser(req);

  if (!user.isNull() && user->isAuthenticated()) user->write(sync);
  else sync.writeNull();

  return true;
}


bool Transaction::apiAuthGoogle() {
  const URI &uri = getURI();

  // Get user
  lookupUser(true);
  if (user.isNull()) user = app.getUserManager().create();
  if (user->isAuthenticated()) {
    redirect("/");
    return true;
  }

  if (!uri.has("state")) {
    user->setCookie(*this); // Set session cookie

    // Redirect
    redirect(app.getGoogleAuth().getRedirectURL
             (uri.getPath(), user->getToken(), "openid email profile"));

    return true;
  }

  // Verify auth
  URI postURI = app.getGoogleAuth().getVerifyURL(uri, user->getToken());
  LOG_DEBUG(5, "Token URI: " << postURI);

  // Extract query data
  string data = postURI.getQuery();
  postURI.setQuery("");

  // Verify authorization with OAuth2 server
  Event::Client &client = app.getEventClient();
  pending = client.callMember
    (postURI, HTTP_POST, data.data(), data.length(), this,
     &Transaction::verify);
  pending->setContentType("application/x-www-form-urlencoded");
  pending->send();

  return true;
}


bool Transaction::apiAuthLogout() {
  setCookie(app.getSessionCookieName(), "", "", "/", 1);
  redirect("/");
  return true;
}


bool Transaction::apiNotFound() {
  THROWCS("Invalid API method: " << getURI().getPath(), HTTP_NOT_FOUND);
}


bool Transaction::verify(Event::Request &req) {
  JSON::ValuePtr json = req.getInputJSON();

  LOG_DEBUG(5, "Token Response: \n" << req.getResponseLine() << *json);

  // Process claims
  JSON::ValuePtr claims =
    app.getGoogleAuth().parseClaims(json->getString("id_token"));

  user->insert("auth", "google:" + claims->getString("sub"));
  user->setAuthenticated(true);

  LOG_INFO(1, "Authenticated: " << claims->getString("email"));
  LOG_DEBUG(3, "Claims: " << *claims);

  // Get profile
  string accessToken = json->getString("access_token");
  URI profileURI("https://www.googleapis.com/plus/v1/people/me/openIdConnect");
  profileURI.set("access_token", accessToken);

  Event::Client &client = app.getEventClient();
  pending =
    client.callMember(profileURI, HTTP_GET, this, &Transaction::profile);
  pending->send();

  return true;
}


bool Transaction::profile(Event::Request &req) {
  JSON::ValuePtr json = req.getInputJSON();

  LOG_DEBUG(3, *json);

  // Update user
  user->insert("name", json->getString("name"));
  user->insert("avatar", json->getString("picture"));
  user->insert("email", json->getString("email"));

  // Update user ID
  app.getUserManager().updateID(user);
  user->setCookie(*this);

  // Redirect
  redirect("/");

  return true;
}
