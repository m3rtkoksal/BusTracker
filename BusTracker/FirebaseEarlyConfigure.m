#import <FirebaseCore/FirebaseCore.h>

/// Firebase Messaging/Auth, SwiftUI @main'den önce yüklenebilir — mümkün olan en erken configure.
__attribute__((constructor(101)))
static void BusTrackerFirebaseConfigureEarly(void) {
    if ([FIRApp defaultApp] != nil) {
        return;
    }
#if DEBUG
    // Analytics DebugView — Firebase configure'dan ÖNCE olmalı.
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"/google/measurement/debug_mode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
#endif
    NSString *path = [[NSBundle mainBundle] pathForResource:@"GoogleService-Info" ofType:@"plist"];
    if (path.length > 0) {
        FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:path];
        if (options != nil) {
            [FIRApp configureWithOptions:options];
            return;
        }
    }
    [FIRApp configure];
}
