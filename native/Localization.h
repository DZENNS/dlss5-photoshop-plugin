#pragma once
#import <Cocoa/Cocoa.h>
inline bool dlssRussian=false;
inline void SetDLSSLocale(NSString*locale){NSString*language=[[locale lowercaseString]componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"_-\0"]].firstObject;dlssRussian=[language isEqualToString:@"ru"];}
inline NSString*tr(NSString*ru,NSString*en){return dlssRussian?ru:en;}
