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

#ifndef BUILDBOTICS_HTTPRE2_MATCHER_H
#define BUILDBOTICS_HTTPRE2_MATCHER_H

#include <cbang/event/HTTPHandler.h>

#include <re2/re2.h>


namespace Buildbotics {
  class HTTPRE2Matcher : public cb::Event::HTTPHandler {
    unsigned methods;
    bool matchAll;
    RE2 regex;
    std::string replace;
    cb::SmartPointer<cb::Event::HTTPHandler> child;

  public:
    HTTPRE2Matcher(unsigned methods, const std::string &search,
                   const std::string &replace,
                   const cb::SmartPointer<cb::Event::HTTPHandler> &child);

    // From cb::Event::HTTPHandler
    bool operator()(cb::Event::Request &req);
  };
}

#endif // BUILDBOTICS_HTTPRE2_MATCHER_H

