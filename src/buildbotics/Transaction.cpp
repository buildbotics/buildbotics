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
#include <cbang/http/Session.h>

using namespace std;
using namespace cb;
using namespace BuildBotics;


Transaction::Transaction(App &app, const Event::Request &source, User &user) :
  app(app), source(source), user(user) {}


bool Transaction::verify(Event::Request &req) {
  // Read response
  Event::Buffer input = req.getInputBuffer();
  Event::BufferStream<> istr(input);
  JSON::ValuePtr json = JSON::Reader(istr).parse();

  LOG_DEBUG(5, "Token Response: \n" << req.getResponseLine() << *json);

  // Process claims
  JSON::ValuePtr claims =
    app.getGoogleAuth().parseClaims(json->getString("id_token"));

  user.insert("email", claims->getString("email"));
  user.insert("auth", "google:" + claims->getString("sub"));
  user.setAuthenticated(true);

  LOG_INFO(1, "Authenticated: " << user.getName());
  LOG_DEBUG(3, "Claims: " << *claims);

  // Get profile
  string accessToken = json->getString("access_token");
  URI profileURI("https://www.googleapis.com/plus/v1/people/me"
                 "/openIdConnect");
  profileURI.set("access_token", accessToken);

  Event::Client &client = app.getEventClient();
  pending =
    client.callMember(profileURI, HTTP_GET, this, &Transaction::profile);
  pending->send();

  return true;
}


bool Transaction::profile(Event::Request &req) {
  // Read response
  Event::Buffer input = req.getInputBuffer();
  Event::BufferStream<> istr(input);
  JSON::ValuePtr json = JSON::Reader(istr).parse();

  LOG_DEBUG(3, *json);

  // Update user
  user.insert("name", json->getString("name"));
  user.insert("avatar", json->getString("picture"));

  // Update user ID
  app.getUserManager().updateID(user);
  source.setCookie(app.getSessionCookieName(), user.getID(), "", "/");

  // Redirect
  source.redirect("/");

  delete this;

  return true;
}
