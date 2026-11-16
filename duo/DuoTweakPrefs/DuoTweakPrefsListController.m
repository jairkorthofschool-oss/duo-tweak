#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>

@interface DuoTweakPrefsListController : PSListController
@end

@implementation DuoTweakPrefsListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

@end
