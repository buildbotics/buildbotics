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

#include <cbang/String.h>
#include <cbang/json/Dict.h>


namespace cb {namespace JSON {class Writer;}}


namespace Buildbotics {
  class AWS4Post : public AWS4Signature, public cb::JSON::Dict {
    int minLength;
    int maxLength;

    struct Condition {
      std::string name;
      std::string value;
      std::string op;

      Condition(const std::string &name, const std::string &value,
                const std::string &op = "eq") :
        name(cb::String::toLower(name)), value(value), op(op) {}

      void write(cb::JSON::Writer &writer) const;
      void append(cb::JSON::Writer &writer) const;
    };

    std::vector<Condition> conditions;

  public:
    AWS4Post(const std::string &bucket, const std::string &key,
             unsigned expires, uint64_t ts = cb::Time::now(),
             const std::string &service = "s3",
             const std::string &region = "us-east-1");

    void setLengthRange(int minLength, int maxLength);

    void insert(const std::string &name, const std::string &value,
                bool withCondition = true);

    void clearConditions();
    void addCondition(const std::string &name, const std::string &value,
                      const std::string &op = "eq");

    std::string getPolicy(const std::string &id) const;
    void sign(const std::string &id, const std::string &secret);
  };
}
