#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

#define PREF_DOMAIN CFSTR("nl.jair.duotweak")
#define TILT_ON_DEG 22.0
#define TILT_OFF_DEG 10.0

static BOOL cfgEnabled = YES;
static BOOL cfgAllApps = NO;
static BOOL cfgShrink = YES;

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
	cfgShrink  = ReadBool(CFSTR("shrink"), YES);
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

static UIWindow *KeyWindow(void) {
	UIApplication *app = SharedApp();
	if (!app) return nil;

	UIWindow *win = nil;

	for (UIScene *scene in app.connectedScenes) {
		if (scene.activationState != UISceneActivationStateForegroundActive) continue;
		if (![scene isKindOfClass:[UIWindowScene class]]) continue;
		for (UIWindow *w in ((UIWindowScene *)scene).windows) {
			if (w.isKeyWindow) win = w;
		}
	}

	if (!win) {
		for (UIWindow *w in app.windows) {
			if (w.isKeyWindow) { win = w; break; }
		}
	}

	if (!win) {
		for (UIScene *scene in app.connectedScenes) {
			if (![scene isKindOfClass:[UIWindowScene class]]) continue;
			NSArray *ws = ((UIWindowScene *)scene).windows;
			if (ws.count > 0) win = ws.firstObject;
		}
	}

	return win;
}

@interface DuoEffectRunner : NSObject
+ (void)boot;
@end

@implementation DuoEffectRunner

static CMMotionManager *gMotion = nil;
static UIView *gContainer = nil;
static BOOL gSession = NO;

+ (void)boot {
	UIApplication *app = SharedApp();
	if (!app) return;

	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[DuoEffectRunner endSession];
	}];

	CMMotionManager *motion = [[CMMotionManager alloc] init];
	motion.deviceMotionUpdateInterval = 1.0 / 60.0;
	[motion startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion *m, NSError *err) {
		if (!err) {
			[DuoEffectRunner handleMotion:m];
		}
	}];
	gMotion = motion;
}

+ (void)handleMotion:(CMDeviceMotion *)motion {
	CGVector g = motion.gravity;
	CGFloat angle = atan2(g.x, -g.y);
	CGFloat deg = fabs(angle) * 180.0 / M_PI;

	if (gSession) {
		if (deg < TILT_OFF_DEG || !EffectActive()) {
			[self endSession];
			return;
		}
		if (!gContainer || !gContainer.window) {
			gSession = NO;
			[gContainer removeFromSuperview];
			gContainer = nil;
			if (deg < TILT_ON_DEG) return;
		} else {
			gContainer.transform = CGAffineTransformMakeRotation(angle);
			return;
		}
	}

	if (!EffectActive()) return;
	if (deg > TILT_ON_DEG) {
		[self beginSessionWithAngle:angle];
	}
}

+ (void)beginSessionWithAngle:(CGFloat)angle {
	ReloadPrefs();
	if (!EffectActive()) return;

	UIWindow *window = KeyWindow();
	if (!window) return;

	UIView *snap = [window snapshotViewAfterScreenUpdates:NO];
	if (!snap) return;

	CGFloat bw = window.bounds.size.width;
	CGFloat bh = window.bounds.size.height;

	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bw, bh)];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	container.userInteractionEnabled = NO;
	container.transform = CGAffineTransformMakeRotation(angle);

	UIView *bg = [window snapshotViewAfterScreenUpdates:NO];
	bg.frame = CGRectMake(0, 0, bw, bh);
	bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	bg.userInteractionEnabled = NO;
	[container addSubview:bg];

	UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
	blur.frame = CGRectMake(0, 0, bw, bh);
	blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	blur.userInteractionEnabled = NO;
	[container addSubview:blur];

	UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bw, bh)];
	wrap.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	wrap.userInteractionEnabled = NO;
	wrap.layer.cornerRadius = 46;
	wrap.layer.shadowColor = [UIColor blackColor].CGColor;
	wrap.layer.shadowOpacity = 0.45;
	wrap.layer.shadowRadius = 30;
	wrap.layer.shadowOffset = CGSizeMake(0, 6);
	wrap.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, bw, bh) cornerRadius:46].CGPath;

	UIView *floatSnap = [window snapshotViewAfterScreenUpdates:NO];
	floatSnap.frame = wrap.bounds;
	floatSnap.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	floatSnap.layer.cornerRadius = 46;
	floatSnap.layer.masksToBounds = YES;
	floatSnap.userInteractionEnabled = NO;
	[wrap addSubview:floatSnap];

	[container addSubview:wrap];
	[window addSubview:container];
	gContainer = container;
	gSession = YES;

	[UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
	} completion:nil];

	CGFloat s = cfgShrink ? 0.9 : 1.0;
	CGFloat tw = bw * s;
	CGFloat th = bh * s;
	[UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		wrap.frame = CGRectMake((bw - tw) / 2.0, (bh - th) / 2.0, tw, th);
		wrap.layer.cornerRadius = 40;
		wrap.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, tw, th) cornerRadius:40].CGPath;
	} completion:nil];
}

+ (void)endSession {
	if (!gSession) return;
	gSession = NO;
	UIView *container = gContainer;
	gContainer = nil;
	if (!container) return;
	[UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
		container.alpha = 0.0;
	} completion:^(BOOL finished) {
		[container removeFromSuperview];
	}];
}

@end

%ctor {
	@autoreleasepool {
		[DuoEffectRunner boot];
	}
}
