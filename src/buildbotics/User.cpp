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

#include <stdlib.h>

using namespace std;
using namespace cb;
using namespace BuildBotics;


User::User(App &app, const string &id) :
  app(app), id(id), authenticated(false) {
  decodeID(id);
}


string User::generateID() const {
  const KeyPair &key = app.getPrivateKey();
  JSON::BufferWriter buf;

  buf.beginDict();
  buf.insert("nonce", lrand48());
  buf.insert("ts", Time().toString());
  if (has("name")) buf.insert("name", getString("name"));
  if (has("auth")) buf.insert("auth", getString("auth"));
  buf.endDict();
  buf.flush();

  string state(buf.data(), buf.size());
  // TODO limit size so that it cannot exceed key size
  if (key.size() < state.length()) THROW("User data too long");
  state.resize(key.size(), ' '); // Pad with spaces

  KeyContext ctx(key);
  ctx.signInit();
  ctx.setRSAPadding(KeyContext::NO_PADDING);

  return Base64('=', '-', '_', 0).encode(ctx.sign(state));
}


void User::decodeID(const string &id) {
  KeyContext ctx(app.getPrivateKey());

  ctx.verifyRecoverInit();
  ctx.setRSAPadding(KeyContext::NO_PADDING);

  string state = ctx.verifyRecover(Base64('=', '-', '_', 0).decode(id));
  LOG_DEBUG(5, "state = " << String::trim(state));
  JSON::ValuePtr data = JSON::Reader(StringInputSource(state)).parse();

  data->getNumber("nonce");
  insert("ts", Time::parse(data->getString("ts")).toString());
  if (data->has("name")) insert("name", data->getString("name"));
  if (data->has("auth")) insert("auth", data->getString("auth"));
}
