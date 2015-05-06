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

#ifndef BUILDBOTICS_SERVER_H
#define BUILDBOTICS_SERVER_H

#include <cbang/event/WebServer.h>


namespace Buildbotics {
  class App;
  class User;

  class Server : public cb::Event::WebServer,
                 public cb::Event::HTTPHandlerFactory {
    App &app;

  public:
    Server(App &app);

    void init();


    // From cb::Event::HTTPHandler
    cb::Event::Request *createRequest(evhttp_request *req);

    // From cb::Event::HTTPHandlerFactory
    cb::SmartPointer<cb::Event::HTTPHandler>
    createMatcher(unsigned methods, const std::string &search,
                  const std::string &replace,
                  const cb::SmartPointer<cb::Event::HTTPHandler> &child);
    cb::SmartPointer<cb::Event::HTTPHandler>
    createHandler(const cb::Resource &res);
    cb::SmartPointer<cb::Event::HTTPHandler>
    createHandler(const std::string &path);
  };
}

#endif // BUILDBOTICS_SERVER_H

