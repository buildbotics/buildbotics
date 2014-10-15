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

#include <stdlib.h>

using namespace BuildBotics;
using namespace cb;
using namespace std;


App::App() :
  cb::Application("BuildBotics"), dns(base), client(base, dns, new SSLContext),
  googleAuth(getOptions()), server(*this), userManager(*this),
  sessionCookieName("buildbotics.sid"), authTimeout(Time::SEC_PER_DAY),
  authGraceperiod(Time::SEC_PER_HOUR) {

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

  // Seed random number generator
  srand48(Time::now());
}


int App::init(int argc, char *argv[]) {
  int i = Application::init(argc, argv);
  if (i == -1) return -1;

  server.init();

  // Initialized outbound IP
  if (options["outbound-ip"].hasValue())
    outboundIP = IPAddress(options["outbound-ip"]);
  outboundIP.setPort(0);

  // Read private key
  key.readPrivate(*SystemUtilities::iopen(options["private-key-file"]));

  // Handle exit signal
  sigEvent = base.newSignal(SIGINT, this, &App::signalEvent);
  sigEvent->add();

  return 0;
}


void App::run() {
  try {
    base.dispatch();
    LOG_INFO(1, "Clean exit");
  } CATCH_ERROR;
}


void App::signalEvent(int signal) {
  base.loopExit();
}
