#ifndef CBANG_ENUM_EXPAND
#ifndef FAH_AUTH_FLAGS_H
#define FAH_AUTH_FLAGS_H

#define CBANG_ENUM_NAME AuthFlags
#define CBANG_ENUM_PATH buildbotics
#define CBANG_ENUM_NAMESPACE Buildbotics
//#define CBANG_ENUM_PREFIX 0
#include <cbang/enum/MakeEnumeration.def>

#endif // FAH_AUTH_FLAGS_H
#else // CBANG_ENUM_EXPAND

CBANG_ENUM_VALUE(AUTH_NONE, 0)
CBANG_ENUM_BIT(AUTH_ADMIN,  0)
CBANG_ENUM_BIT(AUTH_MOD,    1)

#endif // CBANG_ENUM_EXPAND
