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

#include "UserManager.h"

#include <cbang/log/Logger.h>
#include <cbang/util/DefaultCatch.h>

using namespace std;
using namespace cb;
using namespace BuildBotics;


UserManager::UserManager(App &app) : app(app) {
  // TODO register cleanup event
}


void UserManager::cleanup() {
  // TODO clean up expired Users
}


SmartPointer<User> UserManager::create() {
  SmartPointer<User> user = new User(app);

  if (!users.insert(users_t::value_type(user->getToken(), user)).second)
    THROWS("User token already exists: " << user->getToken());

  return user;
}


SmartPointer<User> UserManager::get(const string &session) {
  string token = session.substr(0, 32);

  users_t::iterator it = users.find(token);
  if (it != users.end()) return it->second;

  // Decode session and create user if valid
  try {
    SmartPointer<User> user = new User(app, session);

    // TODO look up user profile in DB

    // Add user
    return users.insert(users_t::value_type(token, user)).first->second;

  } CATCH_ERROR;

  return 0;
}


void UserManager::updateSession(const SmartPointer<User> &user) {
  string oldToken = user->getToken();
  string newToken = user->updateSession();

  // Insert user under new token
  if (!users.insert(users_t::value_type(newToken, user)).second)
    THROWS("User token already exists " << newToken);

  // Remove user under old token
  users.erase(oldToken);
}
