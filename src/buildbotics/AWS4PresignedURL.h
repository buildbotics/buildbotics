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


#include "AWS4Signature.h"

#include <cbang/net/URI.h>
#include <cbang/event/RequestMethod.h>

#include <map>


namespace Buildbotics {
  class AWS4PresignedURL : public AWS4Signature, public cb::URI {
    cb::HTTP::RequestMethod method;

    typedef std::map<std::string, std::string> signed_headers_t;
    signed_headers_t signedHeaders;

  public:
    AWS4PresignedURL(const cb::URI &resource, cb::HTTP::RequestMethod method,
                     unsigned expires, uint64_t ts = cb::Time::now(),
                     const std::string &service = "s3",
                     const std::string &region = "us-east-1");

    void setMethod(cb::HTTP::RequestMethod method) {this->method = method;}
    cb::HTTP::RequestMethod getMethod() const {return method;}

    void clearSignedHeaders();
    void setSignedHeader(const std::string &name, const std::string &value);
    const std::string &getSignedHeader(const std::string &name) const;

    void sign(const std::string &id, const std::string &secret);
  };
}
