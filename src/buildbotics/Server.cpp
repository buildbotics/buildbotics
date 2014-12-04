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

#define ADD_TM(METHODS, PATTERN, FUNC) \
  api.addMember<Transaction> (METHODS, PATTERN, &Transaction::FUNC)

  // Auth
  ADD_TM(HTTP_GET, "/api/auth/user", apiAuthUser);
  ADD_TM(HTTP_GET | HTTP_POST,
         "/api/auth/(?P<provider>(google)|(github)|(twitter)|(facebook))"
         "(/callback)?", apiAuthLogin);
  ADD_TM(HTTP_GET, "/api/auth/logout", apiAuthLogout);

  // Names
  ADD_TM(HTTP_PUT, "/api/name/register/(?P<name>[\\w_.]+)", apiNameRegister);
  ADD_TM(HTTP_GET, "/api/name/available/(?P<name>[\\w_.]+)", apiNameAvailable);
  ADD_TM(HTTP_GET, "/api/name/suggestions", apiNameSuggest);

  // Projects
  ADD_TM(HTTP_GET, "/api/projects", apiProjects);

  // Files
  const char *filePattern =
    "/api/profiles/(?P<profile>[\\w_.]+)/"
    "(?P<type>(projects)|(machines)|(tools))/"
    "(?P<thing>[\\w_.]+)/files/(?P<file>[\\w_.]+)";
  ADD_TM(HTTP_PUT, filePattern, apiPutFile);
  ADD_TM(HTTP_DELETE, filePattern, apiDeleteFile);

  // Tags
  ADD_TM(HTTP_GET, "/api/tags", apiGetTags);
  ADD_TM(HTTP_PUT, "/api/tags/(?P<tag>\\w+)", apiAddTag);
  ADD_TM(HTTP_DELETE, "/api/tags/(?P<tag>\\w+)", apiDeleteTag);

  // Not found
  ADD_TM(HTTP_ANY, "", apiNotFound);

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
