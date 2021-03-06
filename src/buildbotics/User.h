/******************************************************************************\

                 This file is part of the Buildbotics Webserver.

                Copyright (c) 2014-2015, Cauldron Development LLC
                               All rights reserved.

        The Buildbotics Webserver is free software: you can redistribute
        it and/or modify it under the terms of the GNU General Public
        License as published by the Free Software Foundation, either
        version 2 of the License, or (at your option) any later version.

        The Buildbotics Webserver is distributed in the hope that it will
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

#pragma once


#include <cbang/json/Dict.h>

#include <string>

namespace cb {
  class KeyPair;
  namespace Event {class Request;}
}


namespace Buildbotics {
  class App;

  class User {
    App &app;

    std::string session;
    uint64_t expires;
    std::string provider;
    std::string id;
    std::string name;
    uint64_t auth;

  public:
    User(App &app);
    User(App &app, const std::string &session);

    void setSession(const std::string &session) {this->session = session;}
    const std::string &getSession() const {return session;}
    std::string getToken() const {return session.substr(0, 32);}

    std::string updateSession();
    void decodeSession(const std::string &session);

    bool hasExpired() const;
    bool isExpiring() const;

    void setProvider(const std::string &provider) {this->provider = provider;}
    const std::string &getProvider() const {return provider;}

    void setID(const std::string &id) {this->id = id;}
    const std::string &getID() const {return id;}

    void setName(const std::string &name) {this->name = name;}
    const std::string &getName() const {return name;}

    void setAuth(uint64_t auth) {this->auth = auth;}
    uint64_t getAuth() const {return auth;}

    bool isAuthenticated() const {return !provider.empty() && !id.empty();}
  };
}
