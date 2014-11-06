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

#ifndef BUILDBOTICS_APP_H
#define BUILDBOTICS_APP_H

#include "Server.h"
#include "UserManager.h"

#include <cbang/Application.h>
#include <cbang/os/Mutex.h>
#include <cbang/net/IPAddress.h>
#include <cbang/security/KeyPair.h>

#include <cbang/auth/GoogleOAuth2.h>
#include <cbang/auth/GitHubOAuth2.h>
#include <cbang/auth/FacebookOAuth2.h>

#include <cbang/event/Base.h>
#include <cbang/event/DNSBase.h>
#include <cbang/event/Client.h>

namespace cb {
  namespace Event {class Event;}
  namespace MariaDB {class EventDB;}
}


namespace BuildBotics {
  class App : public cb::Application, public cb::Mutex {
    cb::Event::Base base;
    cb::Event::DNSBase dns;
    cb::Event::Client client;

    cb::GoogleOAuth2 googleAuth;
    cb::GitHubOAuth2 githubAuth;
    cb::FacebookOAuth2 facebookAuth;

    Server server;
    UserManager userManager;

    cb::IPAddress outboundIP;
    std::string sessionCookieName;
    uint64_t authTimeout;
    uint64_t authGraceperiod;
    cb::KeyPair key;

    std::string dbHost;
    std::string dbUser;
    std::string dbPass;
    std::string dbName;
    uint32_t dbPort;
    unsigned dbTimeout;

  public:
    App();

    cb::Event::Base &getEventBase() {return base;}
    cb::Event::DNSBase &getEventDNS() {return dns;}
    cb::Event::Client &getEventClient() {return client;}

    cb::GoogleOAuth2 &getGoogleAuth() {return googleAuth;}
    cb::GitHubOAuth2 &getGitHubAuth() {return githubAuth;}
    cb::FacebookOAuth2 &getFacebookAuth() {return facebookAuth;}

    Server &getServer() {return server;}
    UserManager &getUserManager() {return userManager;}

    cb::SmartPointer<cb::MariaDB::EventDB> getDBConnection();

    const cb::IPAddress &getOutboundIP() const {return outboundIP;}
    const std::string &getSessionCookieName() const {return sessionCookieName;}
    uint64_t getAuthTimeout() const {return authTimeout;}
    uint64_t getAuthGraceperiod() const {return authGraceperiod;}
    const cb::KeyPair &getPrivateKey() const {return key;}

    // From cb::Application
    int init(int argc, char *argv[]);
    void run();

    void signalEvent(cb::Event::Event &e, int signal, unsigned flags);
  };
}

#endif // BUILDBOTICS_APP_H

