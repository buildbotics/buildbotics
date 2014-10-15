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

#ifndef BUILDBOTICS_TRANSACTION_H
#define BUILDBOTICS_TRANSACTION_H

#include <cbang/event/Request.h>
#include <cbang/event/RequestMethod.h>
#include <cbang/event/PendingRequest.h>

#include <cbang/json/JSON.h>


namespace BuildBotics {
  class App;
  class User;

  class Transaction : public cb::Event::Request {
    App &app;
    cb::SmartPointer<User> user;
    cb::SmartPointer<cb::Event::PendingRequest> pending;

  public:
    Transaction(App &app, evhttp_request *req);

    void lookupUser(bool skipAuthCheck = false);

    // Event::WebServer request callbacks
    bool apiAuthUser(const cb::JSON::ValuePtr &msg, cb::JSON::Sync &sync);
    bool apiAuthGoogle();
    bool apiAuthLogout();
    bool apiNotFound();

    // Event::Client callbacks
    bool verify(cb::Event::Request &req);
    bool profile(cb::Event::Request &req);
  };
}

#endif // BUILDBOTICS_TRANSACTION_H

