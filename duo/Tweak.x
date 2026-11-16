#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define PREF_DOMAIN CFSTR("nl.jair.duotweak")

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

static UIWindow *KeyWindow(void) {
	UIApplication *app = [UIApplication sharedApplication];
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
+ (void)trigger;
@end

@implementation DuoEffectRunner

static CADisplayLink *gLink = nil;
static UIView *gContainer = nil;

+ (void)cancel {
	[gLink invalidate];
	gLink = nil;
	[gContainer removeFromSuperview];
	gContainer = nil;
}

+ (void)poll:(CADisplayLink *)link {
	if (!gContainer) return;
	UIWindow *w = gContainer.window;
	if (!w) return;
	CATransform3D t = w.layer.transform;
	CGFloat angle = atan2(t.m21, t.m11);
	gContainer.transform = CGAffineTransformMakeRotation(-angle);
}

+ (void)trigger {
	if (!EffectActive()) return;

	UIWindow *window = KeyWindow();
	if (!window) return;

	[self cancel];

	UIView *snap = [window snapshotViewAfterScreenUpdates:NO];
	if (!snap) return;

	CGFloat bw = window.bounds.size.width;
	CGFloat bh = window.bounds.size.height;

	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, bw, bh)];
	container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	container.userInteractionEnabled = NO;

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

	UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
		blur.effect = effect;
	} completion:nil];

	if (cfgShrink) {
		[UIView animateWithDuration:0.28 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
			wrap.frame = CGRectMake(bw * 0.05, bh * 0.05, bw * 0.9, bh * 0.9);
			wrap.layer.cornerRadius = 40;
			wrap.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, bw * 0.9, bh * 0.9) cornerRadius:40].CGPath;
		} completion:nil];
	}

	gLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(poll:)];
	[gLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.65 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (gContainer != container) return;
		[UIView animateWithDuration:0.3 animations:^{
			container.alpha = 0.0;
		} completion:^(BOOL finished) {
			if (gContainer == container) {
				[self cancel];
			}
		}];
	});
}

@end

%ctor {
	@autoreleasepool {
		ReloadPrefs();

		[[NSNotificationCenter defaultCenter] addObserverForName:@"UIApplicationDidChangeStatusBarOrientationNotification" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
			[DuoEffectRunner trigger];
		}];

		__block UIInterfaceOrientation last = [[UIApplication sharedApplication] statusBarOrientation];
		[[NSNotificationCenter defaultCenter] addObserverForName:@"UIDeviceOrientationDidChangeNotification" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
			UIInterfaceOrientation cur = [[UIApplication sharedApplication] statusBarOrientation];
			if (cur != last && cur != UIInterfaceOrientationUnknown) {
				last = cur;
				[DuoEffectRunner trigger];
			}
		}];
	}
}
