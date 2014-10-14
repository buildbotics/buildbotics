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
  // TODO clean up old Users
}


User &UserManager::create() {
  SmartPointer<User> user = new User(app);

  string id = user->generateID();
  user->setID(id);
  if (!users.insert(users_t::value_type(id, user)).second)
    THROWS("User ID already exists: " << id);

  return *user;
}


User *UserManager::get(const string &id) {
  users_t::iterator it = users.find(id);
  if (it != users.end()) return it->second.get();

  // Decode ID and create user if valid
  try {
    SmartPointer<User> user = new User(app, id);

    // TODO look up user profile in DB
    // TODO check timestamp and authentication

    // Add user
    users.insert(users_t::value_type(id, user));

    return user.get();
  } CATCH_ERROR;

  return 0;
}


void UserManager::updateID(User &user) {
  string newID = user.generateID();

  // Get user pointer
  users_t::iterator it = users.find(user.getID());
  if (it == users.end()) THROWS("User not found " << user.getID());
  SmartPointer<User> userPtr = it->second;

  if (!users.insert(users_t::value_type(newID, userPtr)).second)
    THROWS("User ID already exists " << newID);

  users.erase(user.getID());
  user.setID(newID);
}
