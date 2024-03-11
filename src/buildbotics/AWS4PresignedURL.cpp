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

#include "AWS4PresignedURL.h"

#include <cbang/openssl/Digest.h>

using namespace std;
using namespace cb;
using namespace Buildbotics;


AWS4PresignedURL::AWS4PresignedURL(
  const URI &resource, Event::RequestMethod method, unsigned expires,
  uint64_t ts, const string &service, const string &region) :
  AWS4Signature(expires, ts, service, region), URI(resource), method(method) {}


void AWS4PresignedURL::clearSignedHeaders() {
  signedHeaders.clear();
}


void AWS4PresignedURL::setSignedHeader(const string &name,
                                       const string &value) {
  signedHeaders[name] = value;
}


const string &AWS4PresignedURL::getSignedHeader(const string &name) const {
  return signedHeaders.at(name);
}


void AWS4PresignedURL::sign(const string &id, const string &secret) {
  string algorithm = getAlgorithm();
  string dateTime = getDateTime();

  // Set required signed header
  setSignedHeader("host", getHost());

  // Compute canonical headers
  string hdrs;
  string hdrNames;
  signed_headers_t::iterator it;

  for (it = signedHeaders.begin(); it != signedHeaders.end(); it++) {
    if (!hdrNames.empty()) hdrNames += ';';
    hdrNames += String::toLower(it->first);

    hdrs += String::toLower(it->first) + ':' + String::trim(it->second) + '\n';
  }

  // Set query parameters
  set("X-Amz-Algorithm", algorithm);
  set("X-Amz-Credential", getCredential(id));
  set("X-Amz-Date", dateTime);
  set("X-Amz-Expires", String(expires));
  set("X-Amz-SignedHeaders", hdrNames);

  // Compute canonical query
  string query;
  for (iterator it = begin(); it != end(); it++) {
    if (!query.empty()) query += '&';
    query += uriEncode(it->first) + '=' + uriEncode(it->second);
  }

  // Compute canonical request
  string request =
    method.toString() + '\n' +
    uriEncode(getPath(), false) + '\n' +
    query + '\n' +
    hdrs + '\n' +
    hdrNames + '\n' +
    "UNSIGNED-PAYLOAD";

  // Compute string to sign
  string data =
    algorithm + '\n' +
    dateTime + '\n' +
    getScope() + '\n' +
    String::hexEncode(Digest::hash(request, "sha256"));

  // Set signature
  set("X-Amz-Signature", getSignature(secret, data));
}
