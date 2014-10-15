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

  if (!users.insert(users_t::value_type(user->getID(), user)).second)
    THROWS("User ID already exists: " << user->getID());

  return user;
}


SmartPointer<User> UserManager::get(const string &id) {
  users_t::iterator it = users.find(id);
  if (it != users.end()) return it->second;

  // Decode ID and create user if valid
  try {
    SmartPointer<User> user = new User(app, id);

    // TODO look up user profile in DB

    // Add user
    return users.insert(users_t::value_type(id, user)).first->second;

  } CATCH_ERROR;

  return 0;
}


void UserManager::updateID(const SmartPointer<User> &user) {
  string oldID = user->getID();
  string newID = user->updateID();

  // Insert user under new ID
  if (!users.insert(users_t::value_type(newID, user)).second)
    THROWS("User ID already exists " << newID);

  // Remove user under old ID
  users.erase(oldID);
}
