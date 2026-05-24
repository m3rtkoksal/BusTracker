#import <FirebaseCore/FirebaseCore.h>

/// Firebase yalnızca UIApplication hazırken AppDelegate üzerinden yapılandırılır.
/// Erken constructor, Auth notificationManager'ın nil kalmasına yol açabiliyordu.
__attribute__((constructor))
static void BusTrackerConfigureFirebaseEarly(void) {
    (void)[FIRApp class];
}
