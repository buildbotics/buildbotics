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

#include "App.h"

#include <cbang/util/DefaultCatch.h>
#include <cbang/util/SmartLock.h>

#include <cbang/os/SystemUtilities.h>

#include <cbang/security/SSLContext.h>
#include <cbang/time/Timer.h>
#include <cbang/time/Time.h>
#include <cbang/log/Logger.h>
#include <cbang/event/Event.h>
#include <cbang/db/maria/EventDB.h>

#include <stdlib.h>

using namespace BuildBotics;
using namespace cb;
using namespace std;


App::App() :
  cb::Application("BuildBotics"), dns(base), client(base, dns, new SSLContext),
  googleAuth(getOptions()), githubAuth(getOptions()),
  facebookAuth(getOptions()), server(*this), userManager(*this),
  sessionCookieName("buildbotics.sid"), authTimeout(Time::SEC_PER_DAY),
  authGraceperiod(Time::SEC_PER_HOUR), dbHost("localhost"),
  dbName("buildbotics"), dbPort(3306), dbTimeout(5) {

  options.pushCategory("BuildBotics Server");
  options.add("outbound-ip", "IP address for outbound connections.  Defaults "
              "to first http-address.");
  options.addTarget("session-cookie-name", sessionCookieName,
                    "Name of the HTTP session cookie.");
  options.addTarget("auth-timeout", authTimeout,
                    "Time in seconds before a user authorization times out.");
  options.addTarget("auth-graceperiod", authGraceperiod,
                    "Time in seconds before expiration at which the server "
                    "automatically refreshes a user's authorization.");
  options.add("document-root", "Serve files from this directory.");
  options.popCategory();

  options.pushCategory("Database");
  options.addTarget("db-host", dbHost, "DB host name");
  options.addTarget("db-user", dbUser, "DB user name");
  options.addTarget("db-pass", dbPass, "DB password");
  options.addTarget("db-name", dbName, "DB name");
  options.addTarget("db-port", dbPort, "DB port");
  options.addTarget("db-timeout", dbTimeout, "DB timeout");
  options.popCategory();

  // Seed random number generator
  srand48(Time::now());
}


SmartPointer<MariaDB::EventDB> App::getDBConnection() {
  // TODO Limit the total number of active connections

  SmartPointer<MariaDB::EventDB> db = new MariaDB::EventDB(base);

  // Configure
  db->setConnectTimeout(dbTimeout);
  db->setReadTimeout(dbTimeout);
  db->setWriteTimeout(dbTimeout);
  db->setReconnect(true);
  db->enableNonBlocking();

  // Connect
  db->connectNB(dbHost, dbUser, dbPass, dbName, dbPort);

  return db;
}


int App::init(int argc, char *argv[]) {
  int i = Application::init(argc, argv);
  if (i == -1) return -1;

  LOG_DEBUG(3, "MySQL client version: " << MariaDB::DB::getClientInfo());
  MariaDB::DB::libraryInit();
  MariaDB::DB::threadInit();

  server.init();

  // Initialized outbound IP
  if (options["outbound-ip"].hasValue())
    outboundIP = IPAddress(options["outbound-ip"]);
  outboundIP.setPort(0);

  // Read private key
  key.readPrivate(*SystemUtilities::iopen(options["private-key-file"]));

  // Check DB credentials
  if (dbUser.empty()) THROWS("db-user not set");
  if (dbPass.empty()) THROWS("db-pass not set");

  // Handle exit signal
  base.newSignal(SIGINT, this, &App::signalEvent).add();

  return 0;
}


void App::run() {
  try {
    base.dispatch();
    LOG_INFO(1, "Clean exit");
  } CATCH_ERROR;
}


void App::signalEvent(Event::Event &e, int signal, unsigned flags) {
  base.loopExit();
}
