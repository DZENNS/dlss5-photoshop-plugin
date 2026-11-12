#include "Localization.h"
#include <cassert>
int main(){@autoreleasepool{
for(NSString*s in @[@"ru",@"ru_RU",@"ru-RU",@"RU_ru"]){SetDLSSLocale(s);assert(dlssRussian);assert([tr(@"да",@"yes") isEqualToString:@"да"]);}
for(NSString*s in @[@"en_US",@"de_DE",@"fr_FR",@"ja_JP",@"russian",@""]){SetDLSSLocale(s);assert(!dlssRussian);}
SetDLSSLocale(nil);assert(!dlssRussian);puts("PASS: Russian host locale only; all others and unavailable locale use English");}}
