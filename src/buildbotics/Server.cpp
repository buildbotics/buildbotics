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

#include "Server.h"
#include "App.h"
#include "Transaction.h"
#include "HTTPRE2Matcher.h"
#include "HTTPHandlerFactory.h"

#include <cbang/security/SSLContext.h>

#include <cbang/event/Request.h>
#include <cbang/event/PendingRequest.h>
#include <cbang/event/Buffer.h>
#include <cbang/event/RedirectSecure.h>

#include <cbang/config/Options.h>
#include <cbang/util/Resource.h>
#include <cbang/log/Logger.h>

#include <stdlib.h>

using namespace cb;
using namespace std;
using namespace BuildBotics;

namespace BuildBotics {
  extern const DirectoryResource resource0;
}


Server::Server(App &app) :
  Event::WebServer(app.getOptions(), app.getEventBase(), new SSLContext,
                   new HTTPHandlerFactory),
  app(app) {
}


void Server::init() {
  Event::WebServer::init();

  // Event::HTTP request callbacks
  HTTPHandlerGroup &api = *addGroup(HTTP_ANY, "/api/.*");

  // Force /api/auth/.* secure
  if (getNumSecureListenPorts()) {
    uint32_t port = getSecureListenPort(0).getPort();
    api.addHandler(HTTP_ANY, "/api/auth/.*", new Event::RedirectSecure(port));
  }

#define ADD_TM(GROUP, METHODS, PATTERN, FUNC)                           \
  (GROUP).addMember<Transaction>(METHODS, PATTERN, &Transaction::FUNC)

#define NAME_RE "[\\w_.]+"
#define FILENAME_RE ".+"
#define TAG_RE "[\\w. -]+"
#define PROFILE_RE "/api/profiles/(?P<profile>" NAME_RE ")"
#define THING_RE PROFILE_RE "/things/(?P<thing>" NAME_RE ")"
#define STAR_RE THING_RE "/star"
#define COMMENTS_RE THING_RE "/comments"
#define COMMENT_RE COMMENTS_RE "/(?P<comment>\\d+)"
#define FILE_RE THING_RE "/files/(?P<file>" FILENAME_RE ")"
#define THING_TAGS_RE THING_RE "/tags/(?P<tags>" TAG_RE "(," TAG_RE ")*)"
#define TAGS_RE "/api/tags"
#define TAG_PATH_RE "/(?P<tag>" TAG_RE ")"
#define FILE_URL_RE \
  "/(?P<profile>" NAME_RE ")/(?P<thing>" NAME_RE ")/(?P<file>" FILENAME_RE ")"

  // Auth
  ADD_TM(api, HTTP_GET, "/api/auth/user", apiAuthUser);
  ADD_TM(api, HTTP_GET | HTTP_POST,
         "/api/auth/(?P<provider>(google)|(github)|(twitter)|(facebook))"
         "(/callback)?", apiAuthLogin);
  ADD_TM(api, HTTP_GET, "/api/auth/logout", apiAuthLogout);

  // Profiles
  ADD_TM(api, HTTP_GET, "/api/profiles", apiGetProfiles);
  ADD_TM(api, HTTP_PUT, PROFILE_RE "/register", apiProfileRegister);
  ADD_TM(api, HTTP_GET, PROFILE_RE "/available", apiProfileAvailable);
  ADD_TM(api, HTTP_GET, "/api/suggest", apiProfileSuggest);
  ADD_TM(api, HTTP_PUT, PROFILE_RE, apiPutProfile);
  ADD_TM(api, HTTP_GET, PROFILE_RE, apiGetProfile);

  // Follow
  ADD_TM(api, HTTP_PUT, PROFILE_RE "/follow", apiFollow);
  ADD_TM(api, HTTP_DELETE, PROFILE_RE "/follow", apiUnfollow);

  // Things
  ADD_TM(api, HTTP_GET, "/api/things", apiGetThings);
  ADD_TM(api, HTTP_GET, THING_RE "/available", apiThingAvailable);
  ADD_TM(api, HTTP_GET, THING_RE, apiGetThing);
  ADD_TM(api, HTTP_PUT, THING_RE, apiPutThing);
  ADD_TM(api, HTTP_DELETE, THING_RE, apiDeleteThing);

  // Stars
  ADD_TM(api, HTTP_PUT, STAR_RE, apiStarThing);
  ADD_TM(api, HTTP_DELETE, STAR_RE, apiUnstarThing);

  // Comments
  ADD_TM(api, HTTP_POST, COMMENTS_RE, apiPostComment);
  ADD_TM(api, HTTP_PUT, COMMENT_RE, apiUpdateComment);
  ADD_TM(api, HTTP_DELETE, COMMENT_RE, apiDeleteComment);

  // Files
  ADD_TM(*this, HTTP_GET, FILE_URL_RE, apiDownloadFile);
  ADD_TM(api, HTTP_GET, FILE_RE, apiGetFile);
  ADD_TM(api, HTTP_PUT, FILE_RE, apiPutFile);
  ADD_TM(api, HTTP_DELETE, FILE_RE, apiDeleteFile);

  // Tags
  ADD_TM(api, HTTP_GET, TAGS_RE, apiGetTags);
  ADD_TM(api, HTTP_PUT, TAG_PATH_RE, apiAddTag);
  ADD_TM(api, HTTP_DELETE, TAG_PATH_RE, apiDeleteTag);
  ADD_TM(api, HTTP_PUT, THING_TAGS_RE, apiTagThing);
  ADD_TM(api, HTTP_DELETE, THING_TAGS_RE, apiUntagThing);

  // Licenses
  ADD_TM(api, HTTP_GET, "/api/licenses", apiGetLicenses);

  // Not found
  ADD_TM(api, HTTP_ANY, "", apiNotFound);

  if (app.getOptions()["document-root"].hasValue()) {
    string root = app.getOptions()["document-root"];

    addHandler(root);
    addHandler(root + "/index.html");

  } else {
    addHandler(*resource0.find("http"));
    addHandler(*resource0.find("http/index.html"));
  }
}


void Server::addHandler(unsigned methods, const string &pattern,
                        const SmartPointer<HTTPHandler> &handler) {
  addHandler(new HTTPRE2Matcher(methods, pattern, handler));
}


Event::Request *Server::createRequest(evhttp_request *req) {
  return new Transaction(app, req);
}
