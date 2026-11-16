#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface DuoTweakPrefsListController : PSListController
@end

@implementation DuoTweakPrefsListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

		NSString *diag = [self diagnoseText];
		PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Diagnose (automatisch)"];
		[group setProperty:diag forKey:@"footerText"];

		NSMutableArray *specs = [_specifiers mutableCopy];
		[specs addObject:group];
		_specifiers = specs;
	}

	return _specifiers;
}

- (NSString *)diagnoseText {
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableString *m = [NSMutableString string];

	NSString *dir1 = @"/var/jb/Library/MobileSubstrate/DynamicLibraries";
	NSString *dir2 = @"/var/jb/usr/lib/TweakInject";
	NSString *dir = [fm fileExistsAtPath:dir1] ? dir1 : dir2;

	[m appendFormat:@"Map: %@\n", dir];

	BOOL isDir = NO;
	if (![fm fileExistsAtPath:dir isDirectory:&isDir] || !isDir) {
		[m appendString:@"Map bestaat NIET!"];
	} else {
		NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];
		[m appendFormat:@"Bestanden: %lu\n", (unsigned long)files.count];
		[m appendFormat:@"DuoTweak.dylib aanwezig: %@\n", [fm fileExistsAtPath:[dir stringByAppendingPathComponent:@"DuoTweak.dylib"]] ? @"JA" : @"NEE"];
		NSString *ownContent = [self readText:[dir stringByAppendingPathComponent:@"DuoTweak.plist"]];
		[m appendFormat:@"Onze filter: %@\n", ownContent ?: @"(geen/leesfout)"];

		NSString *otherName = nil;
		NSString *otherContent = nil;
		for (NSString *f in files) {
			if ([f hasSuffix:@".plist"] && ![f isEqualToString:@"DuoTweak.plist"]) {
				NSString *c = [self readText:[dir stringByAppendingPathComponent:f]];
				if (c.length > 0) { otherName = f; otherContent = c; break; }
			}
		}
		if (otherName) {
			[m appendFormat:@"Andere tweak %@:\n%@", otherName, otherContent];
		} else {
			[m appendFormat:@"Geen andere tweak-plist gevonden"];
		}
	}

	return m;
}

- (NSString *)readText:(NSString *)path {
	NSData *data = [NSData dataWithContentsOfFile:path];
	if (!data) return nil;
	NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!s) s = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	NSString *t = [s stringByReplacingOccurrencesOfString:@"\n" withString:@" | "];
	if (t.length > 300) t = [t substringToIndex:300];
	return t;
}

@end
