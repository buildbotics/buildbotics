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


#include "AuthFlags.h"

#include <cbang/event/Request.h>
#include <cbang/event/RequestMethod.h>
#include <cbang/event/OAuth2Login.h>
#include <cbang/db/maria/EventDB.h>


namespace cb {
  class OAuth2Login;
  namespace MariaDB {class EventDB;}
  namespace JSON {
    class Writer;
    class Value;
  }
}


namespace Buildbotics {
  class App;
  class User;
  class AWS4Post;

  class Transaction : public cb::Event::Request, public cb::Event::OAuth2Login {
    App &app;
    cb::SmartPointer<User> user;
    cb::SmartPointer<cb::MariaDB::EventDB> db;
    cb::SmartPointer<cb::JSON::Writer> writer;
    const char *jsonFields;
    std::string redirectTo;

  public:
    Transaction(App &app, cb::Event::RequestMethod method, const cb::URI &uri,
                const cb::Version &version);
    ~Transaction();

    bool lookupUser(bool skipAuthCheck = false);
    User &getUser();
    std::string getViewID();
    void authorize(unsigned flags = AuthFlags::AUTH_NONE);
    void authorize(unsigned flags, const std::string &name);
    void authorize(const std::string &name);

    void setAuthCookie();
    void clearAuthCookie(uint64_t expires = 0);

    bool hasTag(const std::string &tag) const;

    typedef typename cb::MariaDB::EventDB::Callback<Transaction>::member_t
    event_db_member_functor_t;
    void query(event_db_member_functor_t member, const std::string &s,
               const cb::SmartPointer<cb::JSON::Value> &dict = 0);

    bool apiError(int status, const std::string &msg);
    bool pleaseLogin();

    std::string postFile(const std::string &key, const std::string &file,
                         const std::string &type, uint32_t minSize,
                         uint32_t maxSize);

    // From cb::Event::Request
    using cb::Event::Request::sendError;
    void sendError(cb::Event::HTTPStatus code, const std::string &message);

    // From cb::Event::OAuth2Login
    void processProfile(cb::Event::Request &req,
                        const cb::SmartPointer<cb::JSON::Value> &profile);

    // Event::WebServer request callbacks
    bool apiAuthUser();
    bool apiAuthLogin();
    bool apiAuthLogout();

    bool apiGetInfo();

    bool apiGetPermissions();

    bool apiGetProfiles();
    bool apiProfileRegister();
    bool apiProfileAvailable();
    bool apiProfileSuggest();
    bool apiPutProfile();
    bool apiGetProfile();
    bool apiGetProfileAvatar();
    bool apiPutProfileAvatar();
    bool apiConfirmProfileAvatar();

    bool apiFollow();
    bool apiUnfollow();

    bool apiGetThings();
    bool apiThingAvailable();
    bool apiGetThing();
    bool apiPublishThing();
    bool apiPutThing();
    bool apiRenameThing();
    bool apiDeleteThing();

    bool apiStarThing();
    bool apiUnstarThing();

    bool apiTagThing();
    bool apiUntagThing();

    void commentAuth();
    bool apiPostComment();
    bool apiUpdateComment();
    bool apiDeleteComment();
    bool apiUpvoteComment();
    bool apiDownvoteComment();

    bool apiDownloadFile();
    bool apiUploadFile();
    bool apiUpdateFile();
    bool apiDeleteFile();
    bool apiConfirmFile();
    bool apiFileUp();
    bool apiFileDown();

    bool apiGetTags();
    bool apiGetTagThings();
    bool apiAddTag();
    bool apiDeleteTag();

    bool apiGetLicenses();

    bool apiGetEvents();

    bool apiNotFound();
    bool notFound();

    // MariaDB::EventDB callbacks
    std::string nextJSONField();

    void download(cb::MariaDB::EventDB::state_t state);
    void authUser(cb::MariaDB::EventDB::state_t state);
    void login(cb::MariaDB::EventDB::state_t state);
    void registration(cb::MariaDB::EventDB::state_t state);
    void returnOK(cb::MariaDB::EventDB::state_t state);
    void returnList(cb::MariaDB::EventDB::state_t state);
    void returnBool(cb::MariaDB::EventDB::state_t state);
    void returnU64(cb::MariaDB::EventDB::state_t state);
    void returnS64(cb::MariaDB::EventDB::state_t state);
    void returnJSON(cb::MariaDB::EventDB::state_t state);
    void returnJSONFields(cb::MariaDB::EventDB::state_t state);
    void returnReply(cb::MariaDB::EventDB::state_t state);
  };
}
