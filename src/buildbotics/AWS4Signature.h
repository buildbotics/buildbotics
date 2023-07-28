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

#include <cbang/time/Time.h>

#include <string>
#include <cstdint>


namespace Buildbotics {
  class AWS4Signature {
  protected:
    unsigned expires;
    uint64_t ts;
    std::string service;
    std::string region;

  public:
    AWS4Signature(unsigned expires, uint64_t ts = cb::Time::now(),
                  const std::string &service = "s3",
                  const std::string &region = "us-east-1");

    void setExpires(unsigned expires) {this->expires = expires;}
    unsigned getExpires() const {return expires;}

    void setTS(uint64_t ts) {this->ts = ts;}
    uint64_t getTS() const {return ts;}

    void setService(const std::string &service) {this->service = service;}
    const std::string &getService() const {return service;}

    void setRegion(const std::string &region) {this->region = region;}
    const std::string &getRegion() const {return region;}

    const char *getAlgorithm() const {return "AWS4-HMAC-SHA256";}
    std::string getExpiration() const
    {return cb::Time(ts + expires, "%Y-%m-%dT%H:%M:%S.000Z");}
    std::string getDate() const {return cb::Time(ts, "%Y%m%d");}
    std::string getDateTime() const {return cb::Time(ts, "%Y%m%dT%H%M%SZ");}
    std::string getScope() const;
    std::string getCredential(const std::string &id) const;
    std::string getKey(const std::string &secret) const;
    std::string getSignature(const std::string &secret,
                             const std::string &data) const;

    static std::string uriEncode(const std::string &s, bool encodeSlash = true);
  };
}
