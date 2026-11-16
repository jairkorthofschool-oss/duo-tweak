#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <QuartzCore/QuartzCore.h>

#define PREF_DOMAIN CFSTR("nl.jair.duotweak")
#define TILT_ON_DEG 8.0
#define TILT_OFF_DEG 4.0

static BOOL cfgEnabled = YES;
static BOOL cfgAllApps = NO;
static BOOL gTilted = NO;

static BOOL ReadBool(CFStringRef key, BOOL fallback) {
	CFTypeRef v = CFPreferencesCopyAppValue(key, PREF_DOMAIN);
	if (!v) return fallback;
	BOOL r = [(__bridge id)v boolValue];
	CFRelease(v);
	return r;
}

static void ReloadPrefs(void) {
	CFPreferencesAppSynchronize(PREF_DOMAIN);
	cfgEnabled = ReadBool(CFSTR("enabled"), YES);
	cfgAllApps = ReadBool(CFSTR("allapps"), NO);
}

static BOOL IsSpringBoard(void) {
	return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

static BOOL EffectActive(void) {
	if (!cfgEnabled) return NO;
	return cfgAllApps || IsSpringBoard();
}

static UIApplication *SharedApp(void) {
	@try {
		return [UIApplication sharedApplication];
	} @catch (NSException *e) {
		return nil;
	}
}

static UIWindow *BestWindow(void) {
	UIApplication *app = SharedApp();
	if (!app) return nil;

	__block UIWindow *best = nil;
	__block CGFloat bestArea = 0;

	void (^consider)(UIWindow *) = ^(UIWindow *w) {
		if (!w || w.hidden) return;
		CGFloat area = w.frame.size.width * w.frame.size.height;
		if (area > bestArea) { bestArea = area; best = w; }
	};

	for (UIScene *scene in app.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) continue;
		for (UIWindow *w in ((UIWindowScene *)scene).windows) {
			if (w.isKeyWindow || w.frame.size.width > 100) consider(w);
		}
	}

	if (!best) {
		for (UIWindow *w in app.windows) consider(w);
	}

	return best;
}

@interface DuoEffectRunner : NSObject
+ (void)boot;
@end

@implementation DuoEffectRunner

static CMMotionManager *gMotion = nil;

+ (void)boot {
	NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
	UIApplication *app = SharedApp();
	if (!app) return;

	ReloadPrefs();
	NSLog(@"[DuoTweak] ctor in %@ enabled=%d allapps=%d", bid ?: @"(nil)", cfgEnabled, cfgAllApps);

	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[DuoEffectRunner resetTransform];
	}];

	CMMotionManager *motion = [[CMMotionManager alloc] init];
	motion.deviceMotionUpdateInterval = 1.0 / 60.0;
	[motion startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *m, NSError *err) {
		if (err) {
			NSLog(@"[DuoTweak] motion fout: %@", err);
			return;
		}
		[DuoEffectRunner handleMotion:m];
	}];
	gMotion = motion;
	NSLog(@"[DuoTweak] motion updates gestart");
}

+ (void)resetTransform {
	UIWindow *w = BestWindow();
	if (!w) return;
	if (CATransform3DIsIdentity(w.layer.transform)) return;
	[CATransaction begin];
	[CATransaction setAnimationDuration:0.2];
	w.layer.transform = CATransform3DIdentity;
	[CATransaction commit];
}

+ (void)handleMotion:(CMDeviceMotion *)motion {
	CMAcceleration g = motion.gravity;

	CGFloat theta = atan2(-g.z, -g.y);
	CGFloat deg = fabs(theta) * 180.0 / M_PI;

	if (!EffectActive()) {
		if (gTilted) { gTilted = NO; [self resetTransform]; }
		return;
	}

	if (deg < TILT_OFF_DEG) {
		if (gTilted) {
			gTilted = NO;
			[self resetTransform];
		}
		return;
	}

	if (!gTilted && deg < TILT_ON_DEG) return;
	gTilted = YES;

	UIWindow *w = BestWindow();
	if (!w) return;

	CGFloat bh = w.bounds.size.height;

	CATransform3D t = CATransform3DIdentity;
	t = CATransform3DTranslate(t, 0, bh / 2.0, 0);
	t.m34 = -1.0 / 700.0;
	t = CATransform3DRotate(t, -theta, 1.0, 0.0, 0.0);
	t = CATransform3DTranslate(t, 0, -bh / 2.0, 0);

	w.layer.transform = t;
}

@end

%ctor {
	@autoreleasepool {
		[DuoEffectRunner boot];
	}
}
