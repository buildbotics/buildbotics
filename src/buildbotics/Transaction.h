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
#include <cbang/event/OAuth2Login.h>
#include <cbang/db/maria/EventDBCallback.h>


namespace cb {
  class OAuth2Login;
  namespace MariaDB {class EventDB;}
  namespace JSON {
    class Sync;
    class Writer;
    class Value;
  }
}


namespace BuildBotics {
  class App;
  class User;

  class Transaction : public cb::Event::Request, public cb::Event::OAuth2Login {
    App &app;
    cb::SmartPointer<User> user;
    cb::SmartPointer<cb::MariaDB::EventDB> db;
    cb::SmartPointer<cb::JSON::Writer> writer;

  public:
    Transaction(App &app, evhttp_request *req);

    void lookupUser(bool skipAuthCheck = false);
    typedef typename cb::MariaDB::EventDBMemberFunctor<Transaction>::member_t
    event_db_member_functor_t;
    void query(event_db_member_functor_t member, const std::string &s,
               const cb::SmartPointer<cb::JSON::Value> &dict = 0);

    void apiError(int status, int code, const std::string &msg);
    bool pleaseLogin();

    // From cb::Event::OAuth2Login
    void processProfile(const cb::SmartPointer<cb::JSON::Value> &profile);

    // Event::WebServer request callbacks
    bool apiAuthUser();
    bool apiAuthLogin();
    bool apiAuthLogout();

    bool apiNameRegister();
    bool apiNameAvailable();
    bool apiNameSuggest();

    bool apiProjects();

    bool apiGetTags();
    bool apiAddTag();
    bool apiDeleteTag();

    bool apiNotFound();

    // MariaDB::EventDB callbacks
    void login(cb::MariaDB::EventDBCallback::state_t state);
    void getUser(cb::MariaDB::EventDBCallback::state_t state);
    void returnOK(cb::MariaDB::EventDBCallback::state_t state);
    void returnList(cb::MariaDB::EventDBCallback::state_t state);
    void returnBool(cb::MariaDB::EventDBCallback::state_t state);
    void returnJSON(cb::MariaDB::EventDBCallback::state_t state);
  };
}

#endif // BUILDBOTICS_TRANSACTION_H

