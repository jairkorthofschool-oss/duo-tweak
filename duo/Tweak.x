#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

#define PREF_DOMAIN CFSTR("nl.jair.duotweak")
#define TILT_ON_DEG 12.0
#define TILT_OFF_DEG 4.0

static BOOL cfgEnabled = YES;
static BOOL cfgAllApps = NO;
static BOOL cfgShrink = YES;
static BOOL cfgDebug = YES;

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
	cfgDebug   = ReadBool(CFSTR("debug"), YES);
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
			if (w.isKeyWindow || w.isFirstResponder || w.frame.size.width > 100) consider(w);
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
static UIWindow *gOverlay = nil;
static UIView *gContainer = nil;
static BOOL gSession = NO;

+ (void)boot {
	NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
	UIApplication *app = SharedApp();
	if (!app) return;

	ReloadPrefs();
	NSLog(@"[DuoTweak] ctor in %@ enabled=%d allapps=%d debug=%d", bid ?: @"(nil)", cfgEnabled, cfgAllApps, cfgDebug);

	[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
		[DuoEffectRunner endSession];
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

+ (UIWindow *)prepareOverlay {
	UIWindow *w = gOverlay;
	if (!w) {
		UIWindow *src = BestWindow();
		CGRect f = (src && src.frame.size.width > 100) ? src.frame : [UIScreen mainScreen].bounds;
		w = [[UIWindow alloc] initWithFrame:f];
		if (!w) return nil;
		if (src.windowScene) {
			w.windowScene = src.windowScene;
		}
		w.windowLevel = 99999.0;
		w.userInteractionEnabled = NO;
		w.backgroundColor = [UIColor clearColor];
		w.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		w.hidden = NO;
		gOverlay = w;
	} else {
		w.hidden = NO;
	}
	return w;
}

+ (void)flash:(UIColor *)color inWindow:(UIWindow *)w {
	if (!cfgDebug || !w) return;
	UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(0, 40, w.bounds.size.width, 14)];
	bar.backgroundColor = color;
	bar.alpha = 0.95;
	bar.layer.cornerRadius = 7;
	[w addSubview:bar];
	[UIView animateWithDuration:0.8 delay:1.2 options:0 animations:^{
		bar.alpha = 0.0;
	} completion:^(BOOL finished) {
		[bar removeFromSuperview];
	}];
}

+ (void)handleMotion:(CMDeviceMotion *)motion {
	CMAcceleration g = motion.gravity;
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

	UIWindow *overlay = [self prepareOverlay];
	if (!overlay) return;

	[self flash:[UIColor colorWithRed:0.0 green:0.4 blue:1.0 alpha:1.0] inWindow:overlay];

	UIWindow *src = BestWindow();
	UIView *snap = src ? [src snapshotViewAfterScreenUpdates:NO] : nil;

	CGFloat bw = overlay.bounds.size.width;
	CGFloat bh = overlay.bounds.size.height;

	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bw, bh)];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	container.userInteractionEnabled = NO;
	container.transform = CGAffineTransformMakeRotation(angle);

	UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:nil];
	blur.frame = CGRectMake(0, 0, bw, bh);
	blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	blur.userInteractionEnabled = NO;
	[container addSubview:blur];

	if (snap) {
		UIView *wrap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bw, bh)];
		wrap.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		wrap.userInteractionEnabled = NO;
		wrap.layer.cornerRadius = 46;
		wrap.layer.shadowColor = [UIColor blackColor].CGColor;
		wrap.layer.shadowOpacity = 0.45;
		wrap.layer.shadowRadius = 30;
		wrap.layer.shadowOffset = CGSizeMake(0, 6);
		wrap.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, bw, bh) cornerRadius:46].CGPath;

		UIView *floatSnap = [src snapshotViewAfterScreenUpdates:NO];
		floatSnap.frame = wrap.bounds;
		floatSnap.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		floatSnap.layer.cornerRadius = 46;
		floatSnap.layer.masksToBounds = YES;
		floatSnap.userInteractionEnabled = NO;
		[wrap addSubview:floatSnap];

		[container addSubview:wrap];

		CGFloat s = cfgShrink ? 0.72 : 1.0;
		CGFloat tw = bw * s;
		CGFloat th = bh * s;
		[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
			wrap.frame = CGRectMake((bw - tw) / 2.0, (bh - th) / 2.0, tw, th);
			wrap.layer.cornerRadius = 34;
			wrap.layer.shadowOpacity = 0.55;
			wrap.layer.shadowRadius = 40;
			wrap.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, tw, th) cornerRadius:34].CGPath;
		} completion:nil];
	}

	[overlay addSubview:container];
	gContainer = container;
	gSession = YES;

	[UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		blur.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
	} completion:nil];

	[self flash:[UIColor colorWithRed:0.1 green:0.85 blue:0.3 alpha:1.0] inWindow:overlay];
}

+ (void)endSession {
	if (!gSession) return;
	gSession = NO;
	UIView *container = gContainer;
	gContainer = nil;
	if (container) {
		[UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
			container.alpha = 0.0;
		} completion:^(BOOL finished) {
			[container removeFromSuperview];
		}];
	}
	if (gOverlay) {
		gOverlay.hidden = YES;
	}
}

@end

%ctor {
	@autoreleasepool {
		[DuoEffectRunner boot];
	}
}
