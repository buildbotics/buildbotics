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

#include "AWS4Signature.h"

#include <cbang/String.h>
#include <cbang/security/Digest.h>

#include <cctype>

using namespace std;
using namespace cb;
using namespace BuildBotics;


AWS4Signature::AWS4Signature(unsigned expires, uint64_t ts,
                             const string &service, const string &region) :
  expires(expires), ts(ts), service(service), region(region) {}


string AWS4Signature::getScope() const {
  return getDate() + "/" + region + "/" + service + "/aws4_request";
}


string AWS4Signature::getCredential(const string &id) const {
  return id + "/" + getScope();
}


string AWS4Signature::getKey(const string &secret) const {
  string key = Digest::signHMAC("AWS4" + secret, getDate(), "sha256");
  key = Digest::signHMAC(key, region, "sha256");
  key = Digest::signHMAC(key, service, "sha256");
  return Digest::signHMAC(key, "aws4_request", "sha256");
}


string AWS4Signature::getSignature(const string &secret,
                                   const string &data) const {
  return String::hexEncode(Digest::signHMAC(getKey(secret), data, "sha256"));
}


string AWS4Signature::uriEncode(const string &s, bool encodeSlash) {
  // AWS specific URI encoding
  // See:
  // http://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html

  string result;

  for (string::const_iterator it = s.begin(); it != s.end(); it++)
    if (isalnum(*it) || *it == '_' || *it == '-' || *it == '~' ||
        *it == '.' || (*it == '/' && !encodeSlash))
      result.append(1, *it);

    else {
      result.append(1, '%');
        result.append(1, String::hexNibble(*it >> 4));
        result.append(1, String::hexNibble(*it));
    }

  return result;
}
