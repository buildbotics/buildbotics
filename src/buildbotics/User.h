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

#ifndef BUILDBOTICS_USER_H
#define BUILDBOTICS_USER_H

#include <cbang/json/Dict.h>

#include <string>

namespace cb {class KeyPair;}


namespace BuildBotics {
  class App;

  class User : public cb::JSON::Dict {
    App &app;

    std::string id;
    bool authenticated;

  public:
    User(App &app) : app(app), authenticated(false) {}
    User(App &app, const std::string &id);

    void setID(const std::string &id) {this->id = id;}
    const std::string &getID() const {return id;}

    std::string generateID() const;
    void decodeID(const std::string &id);

    std::string getName() const {return has("name") ? getString("name") : "";}

    bool isAuthenticated() const {return authenticated;}
    void setAuthenticated(bool x) {authenticated = x;}
  };
}

#endif // BUILDBOTICS_USER_H

