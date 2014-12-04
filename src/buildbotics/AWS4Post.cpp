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

#include "AWS4Post.h"

#include <cbang/json/JSON.h>
#include <cbang/net/Base64.h>

using namespace std;
using namespace cb;
using namespace Buildbotics;


void AWS4Post::Condition::write(JSON::Writer &writer) const {
  if (op == "eq") {
    writer.appendDict();
    writer.insert(name, value);
    writer.endDict();

  } else {
    writer.appendList();
    writer.append(op);
    writer.append("$" + name);
    writer.append(value);
    writer.endList();
  }
}


AWS4Post::AWS4Post(const string &bucket, const string &key, unsigned expires,
                   uint64_t ts, const string &service, const string &region) :
  AWS4Signature(expires, ts, service, region), minLength(-1), maxLength(-1) {

  // Bucket
  if (!bucket.empty()) addCondition("bucket", bucket);

  // Key
  if (!key.empty()) {
    insert("key", key, false);
    if (String::endsWith(key, "${filename}"))
      addCondition("key", key.substr(0, key.length() - 11), "starts-with");
    else addCondition("key", key);
  }
}


void AWS4Post::setLengthRange(int minLength, int maxLength) {
  this->minLength = minLength;
  this->maxLength = maxLength;
}


void AWS4Post::insert(const string &name, const string &value,
                      bool withCondition) {
  JSON::Dict::insert(name, value);
  if (withCondition) addCondition(name, value);
}


void AWS4Post::clearConditions() {
  conditions.clear();
}


void AWS4Post::addCondition(const string &name, const string &value,
                            const string &op) {
  conditions.push_back(Condition(name, value, op));
}


string AWS4Post::getPolicy(const string &id) const {
  JSON::BufferWriter writer(0, true);

  writer.beginDict();

  // Expiration
  writer.insert("expiration", getExpiration());

  // Conditions
  writer.insertList("conditions");

  // User supplied conditions
  for (unsigned i = 0; i < conditions.size(); i++) {
    writer.beginAppend();
    conditions[i].write(writer);
  }

  // Content length range condition
  if (0 <= minLength && 0 <= maxLength) {
    writer.appendList();
    writer.append("content-length-range");
    writer.append(minLength);
    writer.append(maxLength);
    writer.endList();
  }

  // Required conditions
  Condition("x-amz-algorithm", getAlgorithm()).write(writer);
  Condition("x-amz-credential", getCredential(id)).write(writer);
  Condition("x-amz-date", getDateTime()).write(writer);

  writer.endList();
  writer.endDict();

  return Base64('=', '+', '/', 0).encode(writer.toString());
}


void AWS4Post::sign(const std::string &id, const std::string &secret) {
  if (!hasString("key")) THROW("Missing required field 'key'");

  string policy = getPolicy(id);

  insert("policy", policy, false);
  insert("x-amz-algorithm", getAlgorithm(), false);
  insert("x-amz-credential", getCredential(id), false);
  insert("x-amz-date", getDateTime(), false);
  insert("x-amz-signature", getSignature(secret, policy), false);
}
