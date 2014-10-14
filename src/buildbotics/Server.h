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

#ifndef BUILDBOTICS_SERVER_H
#define BUILDBOTICS_SERVER_H

#include <cbang/event/WebServer.h>

#include <map>

namespace cb {
  namespace HTTP {class Session;}
  namespace Event {
    class Request;
    class PendingRequest;
  }
}


namespace BuildBotics {
  class App;

  class Server : public cb::Event::WebServer {
    App &app;

    typedef std::map<std::string, cb::SmartPointer<cb::HTTP::Session> >
    sessions_t;
    sessions_t sessions;

    cb::SmartPointer<cb::Event::PendingRequest> pending;

  public:
    Server(App &app);

    void init();

    // Event::WebServer request callbacks
    bool apiAuthUser(cb::Event::Request &req, const cb::JSON::ValuePtr &msg,
                     cb::JSON::Sync &sync);
    bool apiAuthGoogle(cb::Event::Request &req);
    bool apiNotFound(cb::Event::Request &req);
  };
}

#endif // BUILDBOTICS_SERVER_H

