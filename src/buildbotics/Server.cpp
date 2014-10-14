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

#include "Server.h"
#include "App.h"
#include "Transaction.h"

#include <cbang/security/SSLContext.h>

#include <cbang/event/Request.h>
#include <cbang/event/PendingRequest.h>

#include <cbang/config/Options.h>
#include <cbang/util/Resource.h>
#include <cbang/json/JSON.h>
#include <cbang/log/Logger.h>

#include <stdlib.h>

using namespace cb;
using namespace std;
using namespace BuildBotics;

namespace BuildBotics {
  extern const DirectoryResource resource0;
}


Server::Server(App &app) :
  Event::WebServer(app.getOptions(), app.getEventBase(), new SSLContext),
  app(app) {

  // Event::HTTP request callbacks
  HTTPHandlerGroup &api = *addHandlerGroup(HTTP_ANY, "/api/.*");
  api.addMemberHandler(HTTP_GET, "/api/auth/user", this, &Server::apiAuthUser);
  api.addMemberHandler(HTTP_GET | HTTP_POST, "/api/auth/google(/callback)?",
                       this, &Server::apiAuthGoogle);
  api.addMemberHandler(this, &Server::apiNotFound);

  addHandler(*resource0.find("http"));
  addHandler(*resource0.find("http/index.html"));
}


void Server::init() {
  Event::WebServer::init();
}


bool Server::apiAuthUser(Event::Request &req, const JSON::ValuePtr &msg,
                         JSON::Sync &sync) {
  // Get session ID
  string sid = req.findCookie(app.getSessionCookieName());

  // Get user
  User *user = sid.empty() ? 0 : app.getUserManager().get(sid);

  if (user) user->write(sync);
  else sync.writeNull();

  return true;
}


bool Server::apiAuthGoogle(Event::Request &req) {
  const URI &uri = req.getURI();

  // Set no cache headers

  // Check that connection is secure (HTTPS)
  if (!req.isSecure()) ; // TODO

  // Get session ID
  string sid = req.findCookie(app.getSessionCookieName());

  // Get user
  User *user = app.getUserManager().get(sid);

  if (!user ||
      (uri.has("state") && uri.get("state") != sid) ||
      (!uri.has("state") && user && !user->isAuthenticated())) {
    // If no user or auth invalid, redirect to auth provider

    // Create user, if null
    if (!user) user = &app.getUserManager().create();

    // Set session cookie
    req.setCookie(app.getSessionCookieName(), user->getID(), "", "/");

    // Redirect
    URI redirectURL = app.getGoogleAuth().getRedirectURL
      (uri.getPath(), sid, "openid email profile");
    req.redirect(redirectURL);

  } else if (!user->isAuthenticated()) {
    // Verify auth
    URI postURI = app.getGoogleAuth().getVerifyURL(uri, sid);
    LOG_DEBUG(5, "Token URI: " << postURI);

    // Extract query data
    string data = postURI.getQuery();
    postURI.setQuery("");

    // Create new transaction
    SmartPointer<Transaction> tran = new Transaction(app, req, *user);

    // Verify authorization with OAuth2 server
    Event::Client &client = app.getEventClient();
    pending = client.callMember
      (postURI, HTTP_POST, data.data(), data.length(), tran.get(),
       &Transaction::verify);
    pending->setContentType("application/x-www-form-urlencoded");
    pending->send();

    // Connect pending
    tran->setPending(pending);
    tran.adopt(); // Deallocates self when done

  } else req.redirect("/"); // Otherwise redirect

  return true;
}


bool Server::apiNotFound(Event::Request &req) {
  THROWCS("Invalid API method: " << req.getURI().getPath(), HTTP_NOT_FOUND);
}
