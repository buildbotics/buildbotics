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

#include "User.h"
#include "App.h"

#include <cbang/json/Reader.h>
#include <cbang/json/BufferWriter.h>

#include <cbang/String.h>
#include <cbang/time/Time.h>
#include <cbang/security/KeyContext.h>
#include <cbang/security/KeyPair.h>
#include <cbang/net/Base64.h>
#include <cbang/io/StringInputSource.h>
#include <cbang/log/Logger.h>
#include <cbang/event/Request.h>

#include <stdlib.h>

using namespace std;
using namespace cb;
using namespace BuildBotics;


User::User(App &app) : app(app), expires(0), auth(0) {
  updateSession();
}


User::User(App &app, const string &session) :
  app(app), session(session) {
  decodeSession(session);
}


string User::updateSession() {
  const KeyPair &key = app.getPrivateKey();
  JSON::BufferWriter buf;
  expires = Time::now() + app.getAuthTimeout();

  buf.beginDict();
  buf.insert("nonce", lrand48());
  buf.insert("expires", Time(expires).toString());
  if (!provider.empty()) buf.insert("provider", provider);
  if (!id.empty()) buf.insert("id", id);
  if (!name.empty()) buf.insert("name", name);
  buf.insert("auth", auth);
  buf.endDict();
  buf.flush();

  string state(buf.data(), buf.size());
  // TODO limit size so that it cannot exceed key size
  if (key.size() < state.length()) THROW("User data too long");
  state.resize(key.size(), ' '); // Pad with spaces

  KeyContext ctx(key);
  ctx.signInit();
  ctx.setRSAPadding(KeyContext::NO_PADDING);

  session = Base64('=', '-', '_', 0).encode(ctx.sign(state));

  return getToken();
}


void User::decodeSession(const string &session) {
  KeyContext ctx(app.getPrivateKey());

  ctx.verifyRecoverInit();
  ctx.setRSAPadding(KeyContext::NO_PADDING);

  string state = ctx.verifyRecover(Base64('=', '-', '_', 0).decode(session));
  LOG_DEBUG(5, "state = " << String::trim(state));
  JSON::ValuePtr data = JSON::Reader(StringInputSource(state)).parse();

  data->getNumber("nonce");
  expires = Time::parse(data->getString("expires"));
  if (hasExpired()) THROW("User auth expired");
  provider = data->getString("provider");
  id = data->getString("id");
  name = data->getString("name", "");
  auth = data->getNumber("auth", 0);
}


bool User::hasExpired() const {
  return expires < Time::now();
}


bool User::isExpiring() const {
  return expires < Time::now() + app.getAuthGraceperiod();
}


void User::authenticate(const string &provider, const string &id) {
  this->provider = provider;
  this->id = id;
}


void User::setCookie(Event::Request &req) const {
  req.setCookie(app.getSessionCookieName(), getSession(), "", "/");
}
