import Foundation

enum L10n {
    private static var L: LanguageManager { LanguageManager.shared }

    // MARK: - Common

    static var ok: String { L.t("Tamam", "OK") }
    static var back: String { L.t("Geri", "Back") }
    static var cancel: String { L.t("Vazgeç", "Cancel") }
    static var confirm: String { L.t("Onayla", "Confirm") }
    static var loading: String { L.t("Yükleniyor...", "Loading...") }
    static var loadingEllipsis: String { L.t("Yükleniyor…", "Loading…") }
    static var error: String { L.t("Hata", "Error") }
    static var success: String { L.t("Başarılı", "Success") }
    static var info: String { L.t("Bilgi", "Info") }
    static var service: String { L.t("Servis", "Shuttle") }
    static var driver: String { L.t("Sürücü", "Driver") }
    static var driverDefaultName: String { L.t("Şoför", "Driver") }

    // MARK: - Language

    static var settingsLanguage: String { L.t("Dil", "Language") }

    // MARK: - Attendance

    static var attendanceComing: String { L.t("Gelecek", "Coming") }
    static var attendanceNotComing: String { L.t("Gelmeyecek", "Not coming") }
    static var attendanceUnknown: String { L.t("Belirtmedi", "No response") }
    static var attendanceComingSelf: String { L.t("Geliyorum", "I'm coming") }
    static var attendanceNotComingSelf: String { L.t("Gelmiyorum", "I'm not coming") }
    static var attendanceUncertain: String { L.t("Belirsiz", "Undecided") }
    static var attendanceBoarded: String { L.t("Bindi", "On board") }
    static var attendanceBoardedSelf: String { L.t("Servise bindim", "On the shuttle") }
    static func passengerBoardedNotification(_ name: String) -> String {
        L.t("\(name) servise bindi", "\(name) boarded the shuttle")
    }

    // MARK: - Roles

    static var roleDriver: String { L.t("Sürücü", "Driver") }
    static var rolePassenger: String { L.t("Yolcu", "Passenger") }

    // MARK: - Tabs

    static var tabPassengers: String { L.t("Yolcular", "Passengers") }
    static var tabMap: String { L.t("Harita", "Map") }
    static var tabSettings: String { L.t("Ayarlar", "Settings") }
    static var tabService: String { L.t("Servis", "Shuttle") }

    // MARK: - Status badges

    static var active: String { L.t("AKTİF", "ACTIVE") }
    static var live: String { L.t("CANLI", "LIVE") }

    // MARK: - Driver home

    static var serviceNameLabel: String { L.t("SERVİS ADI", "SHUTTLE NAME") }
    static var serviceCodeLabel: String { L.t("SERVİS KODU", "SHUTTLE CODE") }
    static var waitingForPassengers: String { L.t("YOLCU BEKLENİYOR", "WAITING FOR PASSENGERS") }
    static var waitingForPassengersHint: String {
        L.t(
            "Yolcular yukarıdaki servis kodunu kullanarak katıldığında burada görünecek.",
            "Passengers will appear here when they join using the shuttle code above."
        )
    }
    static var passengerList: String { L.t("YOLCU LİSTESİ", "PASSENGER LIST") }
    static var statComing: String { L.t("GELECEK", "COMING") }
    static var statNotComing: String { L.t("GELMEYECEK", "NOT COMING") }
    static var statUnknown: String { L.t("BELİRTMEDİ", "NO RESPONSE") }
    static var preparing: String { L.t("Hazırlanıyor", "Preparing") }
    static var share: String { L.t("Paylaş", "Share") }
    static var copy: String { L.t("Kopyala", "Copy") }
    static var stopShuttle: String { L.t("SERVİSİ DURDUR", "STOP SHUTTLE") }
    static var startShuttle: String { L.t("SERVİSİ BAŞLAT", "START SHUTTLE") }
    static var sharingLocation: String { L.t("Konum paylaşılıyor", "Sharing location") }
    static var selectDurationOnStart: String { L.t("Başlatınca süre seçilir", "Duration is selected when starting") }
    static func tripEndTime(_ time: String) -> String { L.t("Bitiş: \(time)", "Ends: \(time)") }
    static var locationPermissionDenied: String {
        L.t("Konum izni kapalı. Ayarlar'dan izin verin.", "Location permission is off. Enable it in Settings.")
    }
    static var backgroundLocationWarning: String {
        L.t(
            "Arka planda konum paylaşımı için \"Her zaman\" iznini açın.",
            "Enable \"Always\" location permission for background sharing."
        )
    }
    static var enableAlwaysLocation: String { L.t("Her zaman iznini aç", "Enable always location") }

    // MARK: - Passenger home

    static var waitingForDriverLocation: String { L.t("Sürücü konumu bekleniyor", "Waiting for driver location") }
    static var shuttleNotStarted: String { L.t("Servis henüz başlamadı", "Shuttle has not started yet") }
    static var waitingForLocation: String { L.t("Konum bekleniyor", "Waiting for location") }
    static var shuttleInactive: String { L.t("Servis pasif", "Shuttle inactive") }
    static var attendanceTodayQuestion: String { L.t("BUGÜN GELECEK MİSİNİZ?", "ARE YOU COMING TODAY?") }
    static func attendanceQuestionForDate(_ dateLabel: String) -> String {
        L.t("\(dateLabel) GELECEK MİSİNİZ?", "ARE YOU COMING ON \(dateLabel)?")
    }
    static func yourChoice(_ choice: String) -> String { L.t("Seçiminiz: \(choice)", "Your choice: \(choice)") }
    static var attendanceHint: String {
        L.t(
            "Seçiminiz sürücüye kaydedilir. Servis bitince yeniden seçmeniz gerekir.",
            "Your choice is saved for the driver. You must choose again after the shuttle ends."
        )
    }
    static var attendanceHolidayHint: String {
        L.t(
            "Seçiminiz yalnızca bugün için geçerli. Mod açıkken diğer günler varsayılan gelmiyorum.",
            "Your choice is for today only. While this mode is on, other days default to not coming."
        )
    }
    static var pickupPoint: String { L.t("BİNİŞ NOKTASI", "PICKUP POINT") }
    static func savedAt(_ time: String) -> String { L.t("Kayıtlı: \(time)", "Saved: \(time)") }
    static var noPickupSaved: String { L.t("Henüz biniş noktası kaydetmediniz.", "You haven't saved a pickup point yet.") }
    static var comingBlockedWithoutPickup: String {
        L.t(
            "Kayıtlı biniş noktanız olmadığı için seçim yapamazsınız.",
            "You can't make a selection because you haven't saved a pickup point."
        )
    }
    static var setOnMap: String { L.t("HARİTADA BELİRLE", "SET ON MAP") }
    static var editOnMap: String { L.t("HARİTADA DÜZENLE", "EDIT ON MAP") }
    static var tapMapToSelectPickup: String {
        L.t("Haritaya dokunarak biniş noktanızı seçin.", "Tap the map to select your pickup point.")
    }
    static var savePickupPoint: String { L.t("BİNİŞ NOKTAMI KAYDET", "SAVE MY PICKUP POINT") }
    static var change: String { L.t("DEĞİŞTİR", "CHANGE") }
    static var pickupPinLabel: String { L.t("Biniş", "Pickup") }

    // MARK: - Settings

    static var settingsServiceCode: String { L.t("Servis Kodu", "Shuttle Code") }
    static var settingsYourName: String { L.t("Adınız", "Your Name") }
    static var settingsShuttle: String { L.t("Servis", "Shuttle") }
    static var holidayModeTitle: String { L.t("Tatil Modu", "Holiday Mode") }
    static var holidayModeOff: String { L.t("Kapalı", "Off") }
    static var holidayModeBadgeActive: String { L.t("AKTİF", "ON") }
    static func holidayModeUntil(_ date: String) -> String { L.t("\(date) tarihine kadar", "Until \(date)") }
    static var holidayModeCardDetailOff: String {
        L.t(
            "Seyrek kullanıyorsanız açın: her gün işaretlemeden varsayılan gelmiyorum; servise bineceğiniz günlerde Geliyorum seçin.",
            "For occasional use: default is not coming without daily taps; mark Coming only on shuttle days."
        )
    }
    static func holidayModeCardDetailActive(_ date: String) -> String {
        L.t(
            "\(date) tarihine kadar seçmediğiniz her gün gelmiyorum; bineceğiniz gün Geliyorum yeterli.",
            "Until \(date), unselected days are not coming; on shuttle days, tap Coming."
        )
    }
    static var holidayModeCalendarHint: String {
        L.t(
            "Modun biteceği son günü seçin (ör. 3 ay). Bu sürede her gün Gelmiyorum işaretlemeniz gerekmez; servise bineceğiniz gün uygulamadan Geliyorum seçin, sürücü anında görür.",
            "Pick when this mode ends (e.g. 3 months). Unselected days count as not coming; on days you ride, choose Coming and the driver sees it right away."
        )
    }
    static var holidayModeEndDateLabel: String { L.t("Bitiş tarihi", "End date") }
    static var holidayModeSave: String { L.t("Kaydet", "Save") }
    static var holidayModeEndEarly: String { L.t("Tatili bitir", "End holiday now") }
    static var holidayModeSaved: String {
        L.t("Tatil modu kaydedildi.", "Holiday mode saved.")
    }
    static var holidayModeEnded: String { L.t("Tatil modu kapatıldı.", "Holiday mode turned off.") }
    static var sparseModeSuggestionTitle: String {
        L.t("Servisi az kullanıyor musunuz?", "Rarely use the shuttle?")
    }
    static func sparseModeSuggestionBody(comingDays: Int) -> String {
        L.t(
            "Son 1 ayda servise yalnızca \(comingDays) kez \"Geliyorum\" seçtiniz. Tatil Modu ile her gün \"Gelmiyorum\" demek zorunda kalmazsınız; geleceğiniz günlerde sadece \"Geliyorum\" yeterli.",
            "In the last month you chose \"I'm coming\" only \(comingDays) times. With Holiday Mode you don't need to tap \"Not coming\" every day — on days you ride, just tap \"I'm coming\"."
        )
    }
    static var sparseModeSheetTitle: String { L.t("Servisi az kullanıyorsunuz", "You rarely use the shuttle") }
    static func sparseModeSheetMessage(comingDays: Int) -> String {
        L.t(
            "Son 1 ayda yalnızca \(comingDays) kez \"Geliyorum\" seçtiniz. İsterseniz Tatil Modu açarak genel durumunuzu gelmiyorum yapabilirsiniz; servise bineceğiniz günlerde sadece \"Geliyorum\" seçmeniz yeterli.",
            "In the last month you chose \"I'm coming\" only \(comingDays) times. You can turn on Holiday Mode so your default is not coming — on days you ride, just choose \"I'm coming\"."
        )
    }
    static var sparseModeSheetOk: String { L.t("Tamam", "OK") }
    static var signOut: String { L.t("Çıkış Yap", "Sign Out") }
    static var deleteAccount: String { L.t("Hesabı Sil", "Delete Account") }
    static var inviteLinkShare: String { L.t("DAVET LİNKİ PAYLAŞ", "SHARE INVITE LINK") }

    // MARK: - Sign out / delete dialogs

    static var signOutConfirmMessage: String {
        L.t("Çıkış yapmak istediğinize emin misiniz?", "Are you sure you want to sign out?")
    }
    static var deleteAccountConfirmMessage: String {
        L.t(
            "Hesabınızı ve tüm verilerinizi kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
            "Are you sure you want to permanently delete your account and all data? This cannot be undone."
        )
    }
    static var deleteAccountConfirmMessagePassenger: String {
        L.t(
            "Hesabınızı ve tüm verilerinizi (profil, biniş noktaları, katılım kayıtları vb.) kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
            "Are you sure you want to permanently delete your account and all data (profile, pickup points, attendance records, etc.)? This cannot be undone."
        )
    }
    static var deleteAccountPermanently: String { L.t("Hesabı Kalıcı Olarak Sil", "Delete Account Permanently") }
    static var accountDeletedSuccess: String { L.t("Hesabınız başarıyla silindi.", "Your account was deleted successfully.") }
    static var accountDeleteFailed: String {
        L.t("Hesap silinirken bir hata oluştu. Lütfen tekrar deneyin.", "Something went wrong while deleting your account. Please try again.")
    }

    // MARK: - Driver trip

    static var shuttleStopped: String { L.t("Servis durduruldu.", "Shuttle stopped.") }
    static var alwaysLocationRequiredToStart: String {
        L.t(
            "Servisi başlatmak için \"Her zaman\" konum izni zorunludur. Ayarlar'dan izin verin.",
            "\"Always\" location permission is required to start the shuttle. Enable it in Settings."
        )
    }
    static func shuttleStartedAutoStop(_ hoursLabel: String) -> String {
        L.t("Servis başlatıldı. \(hoursLabel) sonra otomatik duracak.", "Shuttle started. It will stop automatically after \(hoursLabel).")
    }
    static func hoursLabel(_ hours: Double) -> String {
        if hours == floor(hours) {
            return L.t("\(Int(hours)) saat", "\(Int(hours)) hours")
        }
        return L.t("\(hours) saat", "\(hours) hours")
    }
    static var serviceCodeNotFound: String { L.t("Servis kodu bulunamadı.", "Shuttle code not found.") }
    static var serviceCodeCopied: String { L.t("Servis kodu kopyalandı.", "Shuttle code copied.") }

    // MARK: - Passenger actions

    static func choiceSaved(_ choice: String) -> String {
        L.t("Seçiminiz kaydedildi: \(choice)", "Your choice was saved: \(choice)")
    }
    static var markPickupOnMap: String { L.t("Haritada sabah biniş noktanızı işaretleyin.", "Mark your morning pickup point on the map.") }
    static var shuttleInfoNotFound: String { L.t("Servis bilgisi bulunamadı.", "Shuttle information not found.") }
    static var updateFailed: String { L.t("Güncellenemedi.", "Could not update.") }
    static var saveFailed: String { L.t("Kaydedilemedi.", "Could not save.") }
    static var signOutFailed: String { L.t("Çıkış yapılamadı.", "Could not sign out.") }
    static var googleVerificationFailed: String {
        L.t("Google doğrulaması tamamlanamadı.", "Google verification could not be completed.")
    }
    static var shuttleStartFailed: String { L.t("Servis başlatılamadı.", "Could not start the shuttle.") }
    static var pickupSavedComing: String {
        L.t("Biniş noktanız kaydedildi. Durumunuz: Geliyorum.", "Pickup point saved. Your status: I'm coming.")
    }

    // MARK: - Login / registration

    static var loginTitle: String { L.t("Giriş", "Sign In") }
    static var signingIn: String { L.t("Giriş yapılıyor...", "Signing in...") }
    static var signInAction: String { L.t("Giriş Yap", "Sign In") }
    static var signInWithAppleHint: String { L.t("Apple hesabınızla giriş yapın.", "Sign in with your Apple account.") }
    static var signInWithApple: String { L.t("Apple ile Giriş Yap", "Sign in with Apple") }
    static var noAccount: String { L.t("Hesabın yok mu?", "Don't have an account?") }
    static var createAccount: String { L.t("Hesap oluştur", "Create account") }
    static var createAccountTitle: String { L.t("Hesap Oluştur", "Create Account") }
    static var profileIncomplete: String {
        L.t("Profil bilgileri eksik. Lütfen tekrar deneyin.", "Profile information is incomplete. Please try again.")
    }
    static var profileNotFound: String {
        L.t(
            "Bu Apple hesabıyla kayıtlı profil bulunamadı. Hesabınız silinmiş olabilir; yeni hesap oluşturabilirsiniz.",
            "No profile found for this Apple account. Your account may have been deleted; you can create a new one."
        )
    }
    static var roleSelectionTitle: String { L.t("Hesap Oluştur", "Create Account") }
    static var roleSelectionSubtitle: String { L.t("Sürücü müsünüz, yolcu mu?", "Are you a driver or a passenger?") }
    static var iAmDriver: String { L.t("Sürücüyüm", "I'm a driver") }
    static var iAmDriverSubtitle: String {
        L.t(
            "Servisi oluştururum, sabah \"Servisi Başlat\" derim ve konumumu paylaşırım.",
            "I create the shuttle, tap \"Start Shuttle\" in the morning, and share my location."
        )
    }
    static var iAmPassenger: String { L.t("Yolcuyum", "I'm a passenger") }
    static var iAmPassengerSubtitle: String {
        L.t(
            "Servise katılırım, haritadan takip ederim ve geleceğimi bildiririm.",
            "I join the shuttle, track on the map, and let the driver know if I'm coming."
        )
    }
    static var alreadyHaveAccount: String { L.t("Zaten hesabım var —", "Already have an account —") }
    static var signInWithAppleLink: String { L.t("Apple ile giriş yap", "sign in with Apple") }
    static var driverRegistration: String { L.t("Sürücü Kaydı", "Driver Registration") }
    static var passengerRegistration: String { L.t("Yolcu Kaydı", "Passenger Registration") }
    static var driverRegistrationSubtitle: String {
        L.t("Servisinizi oluşturun, yolcularınız sizi takip etsin.", "Create your shuttle and let passengers track you.")
    }
    static var passengerRegistrationSubtitle: String {
        L.t("Servis kodunuzla katılın, haritadan takip edin.", "Join with your shuttle code and track on the map.")
    }
    static var serviceNameField: String { L.t("Servis adı", "Shuttle name") }
    static var serviceCodeField: String { L.t("Servis kodu", "Shuttle code") }
    static var serviceNameExample: String { L.t("Örn. Kadıköy Servisi", "e.g. Kadikoy Shuttle") }
    static var serviceCodeExample: String { L.t("Sürücünün verdiği 6 haneli kod", "6-digit code from your driver") }
    static var nameExampleDriver: String { L.t("Örn. Ahmet", "e.g. Alex") }
    static var nameExamplePassenger: String { L.t("Örn. Ayşe", "e.g. Emma") }
    static var driverLocationFooter: String {
        L.t("Konum paylaşımı yalnızca sürücü hesabında açıktır.", "Location sharing is only enabled for driver accounts.")
    }
    static var passengerLocationFooter: String {
        L.t("Yolcu hesabında konum paylaşımı yoktur.", "Passenger accounts do not share location.")
    }
    static var enterNameToRegister: String { L.t("Kayıt için adınızı girin.", "Enter your name to register.") }
    static var enterServiceCode: String { L.t("Servis kodu girmedin.", "Enter a shuttle code.") }
    static var serviceCodeMinLength: String { L.t("Servis kodu en az 4 karakter olmalı.", "Shuttle code must be at least 4 characters.") }
    static var enterServiceName: String { L.t("Servis adı girmedin.", "Enter a shuttle name.") }
    static var driverAccountCreated: String { L.t("Servis hesabınız oluşturuldu.", "Your shuttle account was created.") }
    static var joinedShuttle: String { L.t("Servise katıldınız.", "You joined the shuttle.") }
    static var yourNameField: String { L.t("Adınız", "Your name") }
    static var appleRegistrationNote: String {
        L.t("Kayıt için Apple hesabınız kullanılır; telefon numarası istenmez.", "Your Apple account is used for registration; no phone number is required.")
    }
    static var registerWithApple: String { L.t("Apple ile Kayıt Ol", "Register with Apple") }
    static var selectAndContinue: String { L.t("SEÇ VE DEVAM ET", "SELECT AND CONTINUE") }
    static var backToRoleSelection: String { L.t("ROL SEÇİMİNE DÖN", "BACK TO ROLE SELECTION") }
    static var continueWithApple: String { L.t("Apple ile Devam Et", "Continue with Apple") }

    // MARK: - Notifications

    static var notifications: String { L.t("BİLDİRİMLER", "NOTIFICATIONS") }
    static var notificationsOn: String { L.t("Açık", "On") }
    static var notificationsTapToEnable: String {
        L.t("Bildirim izni için dokunun veya toggle'ı açın", "Tap here or turn on the toggle to enable notifications")
    }
    static var notificationsOffOpenSettings: String {
        L.t("Kapalı — iPhone ayarlarından açın", "Off — enable in iPhone Settings")
    }
    static var notificationsNotRequested: String { L.t("Henüz izin istenmedi", "Permission not requested yet") }
    static var notificationsOffSystemSettings: String { L.t("Kapalı — sistem ayarlarından açın", "Off — enable in system settings") }
    static var notificationsOnTemporary: String { L.t("Açık (geçici)", "On (temporary)") }
    static var notificationsUnknown: String { L.t("Bilinmiyor", "Unknown") }
    static var notificationsDisabledTitle: String { L.t("Bildirimler kapalı", "Notifications are off") }
    static var notificationsDisabledMessage: String {
        L.t(
            "Servis başladığında ve sürücü yaklaştığında haberdar olmak için bildirimleri açın.",
            "Enable notifications to know when the shuttle starts and when the driver is nearby."
        )
    }
    static var driverNotificationPermissionBody: String {
        L.t(
            "Yolcular katıldığında ve servis başladığında haberdar olmak için bildirimleri açın.",
            "Enable notifications to know when passengers board and when the shuttle starts."
        )
    }
    static var passengerNotificationPermissionBody: String {
        L.t(
            "Bildirimleri açmadan konum ve kayıt adımlarına devam edemezsiniz.",
            "You must enable notifications before continuing with location and saving."
        )
    }
    static var notificationPermissionBodySettings: String {
        L.t(
            "Ayarlar açıldıysa aşağıdaki adımları uygulayın, sonra bu ekrana dönün.",
            "If Settings opened, follow the steps below, then return to this screen."
        )
    }
    static var notificationSettingsStep1: String {
        L.t("\"Ayarlara git\"e basın.", "Tap \"Go to Settings\".")
    }
    static var notificationSettingsStep2: String {
        L.t("Bildirimler → BusTracker'ı açın.", "Notifications → enable BusTracker.")
    }
    static var notificationSettingsStep3: String {
        L.t("Uygulamaya dönün.", "Return to the app.")
    }
    static var motionPermissionTitle: String { L.t("Hareket izni gerekli", "Motion permission required") }
    static var motionPermissionDisabledMessage: String {
        L.t(
            "Servise bindiğinizi anlamak için hareket izni gerekir. Ayarlardan açın.",
            "Motion permission is required to detect boarding. Enable it in Settings."
        )
    }
    static var driverMotionPermissionBody: String {
        L.t(
            "Yolcuların servise bindiğini anlamak için hareket izni gerekir.",
            "Motion permission is required to detect when passengers board the shuttle."
        )
    }
    static var passengerMotionPermissionBody: String {
        L.t(
            "Servise bindiğinizi otomatik anlamak için hareket izni gerekir.",
            "Motion permission is required to detect when you board the shuttle automatically."
        )
    }
    static var motionPermissionBodySettings: String {
        L.t(
            "Ayarlar açıldıysa aşağıdaki adımları uygulayın, sonra bu ekrana dönün.",
            "If Settings opened, follow the steps below, then return to this screen."
        )
    }
    static var motionSettingsStep1: String {
        L.t("\"Ayarlara git\"e basın.", "Tap \"Go to Settings\".")
    }
    static var motionSettingsStep2: String {
        L.t("Hareket ve Fitness → BusTracker'ı açın.", "Motion & Fitness → enable BusTracker.")
    }
    static var motionSettingsStep3: String {
        L.t("Uygulamaya dönün.", "Return to the app.")
    }
    static var driverLocationPermissionDenied: String {
        L.t(
            "Konum izni kapalı. Servis başlatmak ve konum paylaşmak için izin gerekli.",
            "Location permission is off. Permission is required to start the shuttle and share your location."
        )
    }
    static var openSettings: String { L.t("Ayarları Aç", "Open Settings") }
    static var later: String { L.t("Sonra", "Later") }

    // MARK: - Driver map

    static var nextStop: String { L.t("SONRAKİ DURAK", "NEXT STOP") }
    static var morningPickup: String { L.t("Sabah biniş", "Morning pickup") }
    static var noStop: String { L.t("Durak yok", "No stop") }
    static var waitingForPassengerPickup: String { L.t("Yolcu biniş noktası bekleniyor.", "Waiting for passenger pickup point.") }
    static var capacity: String { L.t("KAPASİTE", "CAPACITY") }
    static var stops: String { L.t("DURAKLAR", "STOPS") }
    static func unspecifiedCount(_ count: Int) -> String { L.t("\(count) belirtmedi", "\(count) no response") }
    static var shuttleWaiting: String { L.t("Servis bekliyor", "Shuttle waiting") }

    // MARK: - Trip duration sheet

    static var tripDuration: String { L.t("Servis Süresi", "Shuttle Duration") }
    static var tripDurationBodyCanStart: String {
        L.t(
            "Sefer boyunca konumunuz yolculara paylaşılır. Paylaşım süre sonunda otomatik durur.",
            "Your location is shared with passengers during the trip. Sharing stops automatically when time is up."
        )
    }
    static var tripDurationBodyNeedsPermission: String {
        L.t(
            "\"Her zaman\" konum izni olmadan servis başlatılamaz. Önce İZİN VER adımlarını tamamlayın.",
            "The shuttle cannot start without \"Always\" location permission. Complete the GRANT PERMISSION steps first."
        )
    }

    // MARK: - Always location guide

    static var locationPermissionTitle: String { L.t("Servis için konum izni", "Location permission for shuttle") }
    static var locationPermissionBodySettings: String {
        L.t(
            "Ayarlar açıldıysa aşağıdaki adımları uygulayın, sonra bu ekrana dönün.",
            "If Settings opened, follow the steps below, then return to this screen."
        )
    }
    static var locationPermissionBodyInitial: String {
        L.t(
            "Haritada görünmek için konum izni gerekir.",
            "Location permission is required to appear on the map."
        )
    }
    static var driverLocationPermissionBody: String {
        L.t(
            "Servis için \"Her Zaman\" konum izni gerekir. Sistem iki soru sorarsa önce izin verin, sonra Her Zaman'ı seçin.",
            "\"Always\" location is required for the shuttle. If iOS asks twice, allow access then choose Always."
        )
    }
    static var driverLocationWhenInUseUpgradeBody: String {
        L.t(
            "Şu an yalnızca \"Uygulama Kullanılırken\" izni var. Servis için Ayarlardan \"Her Zaman\"a yükseltmeniz gerekir.",
            "You only have \"While Using the App\" access. Upgrade to \"Always\" in Settings to start the shuttle."
        )
    }
    static var driverLocationForegroundTitle: String {
        L.t("Konum izni gerekli", "Location permission required")
    }
    static var driverLocationForegroundBody: String {
        L.t(
            "Servisi başlatmak için önce konum izni vermeniz gerekir.",
            "Location permission is required before you can start the shuttle."
        )
    }
    static var passengerLocationForegroundBody: String {
        L.t(
            "Biniş noktası kaydetmek, geliyorum/gelmiyorum seçmek ve sürücünün sizi haritada görebilmesi için konum izni gerekir.",
            "Location permission is required to save your pickup, set attendance, and appear on the map for the driver."
        )
    }
    static var locationForegroundSettingsStep1: String {
        L.t("\"Ayarlara git\"e basın.", "Tap \"Go to Settings\".")
    }
    static var locationForegroundSettingsStep2: String {
        L.t("Konum → \"Uygulama Kullanılırken\" veya \"Her Zaman\" seçin.", "Location → select \"While Using\" or \"Always\".")
    }
    static var locationForegroundSettingsStep3: String {
        L.t("Uygulamaya dönün.", "Return to the app.")
    }
    static var locationPermissionBodyNeedsSettings: String {
        L.t(
            "Sistem izin penceresi açılmadı. Ayarlardan konumu \"Her Zaman\" yapın:",
            "The permission dialog did not appear. Set location to \"Always\" in Settings:"
        )
    }
    static var locationStep1: String {
        L.t("Açılan pencerede Konum veya İzinler'e dokunun.", "In the dialog, tap Location or Permissions.")
    }
    static var locationStep2: String {
        L.t("\"Her Zaman\" seçeneğini işaretleyin.", "Select \"Always\".")
    }
    static var locationStep3: String {
        L.t("Geri gelip Servisi başlat'a tekrar basın.", "Come back and tap Start Shuttle again.")
    }
    static var locationSettingsStep1: String {
        L.t("\"Ayarlara git\"e basın.", "Tap \"Go to Settings\".")
    }
    static var locationSettingsStep2: String {
        L.t("Konum → \"Her Zaman\" seçin.", "Location → select \"Always\".")
    }
    static var locationSettingsStep3: String {
        L.t("Uygulamaya dönün.", "Return to the app.")
    }
    static var grantPermission: String { L.t("İZİN VER", "GRANT PERMISSION") }
    static var ifWindowDidNotOpen: String { L.t("Pencere açılmadıysa", "If the dialog didn't open") }
    static var goToSettings: String { L.t("Ayarlara git", "Go to Settings") }
    static var locationPermissionChecking: String {
        L.t("Konum izni kontrol ediliyor…", "Checking location permission…")
    }

    // MARK: - Trip attendance sheet

    static var shuttleStarted: String { L.t("Servis başladı", "Shuttle started") }
    static func driverStartedTrip(_ driverName: String) -> String {
        L.t("\(driverName) servisi yola çıktı. Bugün gelecek misiniz?", "\(driverName)'s shuttle is on the way. Are you coming today?")
    }
    static var choiceSentToDriver: String {
        L.t("Seçiminiz sürücüye anında iletilir.", "Your choice is sent to the driver instantly.")
    }

    // MARK: - Weather

    static var clothingAdvice: String { L.t("GİYİM ÖNERİSİ", "CLOTHING TIP") }
    static var weatherLoading: String { L.t("Biniş noktana göre öneri hazırlanıyor…", "Preparing a tip for your pickup point…") }
    static var weatherUnavailable: String { L.t("Öneri şu an alınamadı.", "Tip unavailable right now.") }
    static var weatherNeedsPickup: String {
        L.t(
            "Biniş noktanızı kaydettikten sonra giyim önerisi görünür.",
            "Save your pickup point to see a clothing tip."
        )
    }
    static var pickupPlaceFallback: String { L.t("Biniş noktan", "your pickup point") }
    static func weatherContext(_ placeName: String, _ temperature: Int) -> String {
        L.t("Bugün \(placeName) · \(temperature)°", "Today \(placeName) · \(temperature)°")
    }
    static var adviceRain: String { L.t("Yağmur var — şemsiyeni kap.", "Rain expected — grab an umbrella.") }
    static var adviceColdHat: String { L.t("Hava soğuk — bere takmadan çıkma.", "It's cold — don't leave without a hat.") }
    static var adviceVeryHot: String { L.t("Hava cehennem gibi — şapka tak, su al.", "Very hot — wear a hat and bring water.") }
    static var adviceHot: String { L.t("Hava sıcak — şapka tak, su al.", "It's hot — wear a hat and bring water.") }
    static var adviceCool: String { L.t("Hava serin — ince mont veya hırka al.", "It's cool — bring a light jacket.") }
    static var adviceCold: String { L.t("Hava soğuk — kalın giyin.", "It's cold — dress warmly.") }

    // MARK: - My services

    static var myShuttles: String { L.t("SERVİSLERİM", "MY SHUTTLES") }
    static var systemActive: String { L.t("SİSTEM AKTİF", "SYSTEM ACTIVE") }
    static func startedAt(_ time: String) -> String { L.t("Başlangıç: \(time)", "Started: \(time)") }
    static var driverStartedShuttle: String { L.t("Sürücü servisi başlattı", "Driver started the shuttle") }
    static var savedRoutes: String { L.t("KAYITLI ROTALAR", "SAVED ROUTES") }
    static var switchRoute: String { L.t("GEÇİŞ YAP", "SWITCH") }
    static var noOtherRoute: String { L.t("Başka rota yok", "No other route") }
    static var addShuttleHint: String {
        L.t("Yeni bir servis ekleyerek rotalarını genişletebilirsin.", "Add another shuttle to expand your routes.")
    }
    static var addNewShuttle: String { L.t("YENİ SERVİS EKLE", "ADD NEW SHUTTLE") }
    static func shuttleAdded(_ name: String) -> String { L.t("\(name) eklendi ve aktif yapıldı.", "\(name) was added and set as active.") }
    static func shuttleFallbackName(_ prefix: String) -> String { L.t("Servis \(prefix)", "Shuttle \(prefix)") }

    // MARK: - Add service

    static var addShuttleTitle: String { L.t("Yeni servis ekle", "Add new shuttle") }
    static var addShuttleBody: String {
        L.t(
            "Sürücünün verdiği servis kodunu girin. Ekledikten sonra bu servis aktif olur.",
            "Enter the shuttle code from your driver. This shuttle becomes active after you add it."
        )
    }
    static var sixDigitCode: String { L.t("6 haneli kod", "6-digit code") }
    static var joinShuttle: String { L.t("SERVİSE KATIL", "JOIN SHUTTLE") }

    // MARK: - Passenger list

    static var noPassengersYet: String { L.t("Henüz yolcu yok", "No passengers yet") }
    static var passengersJoinWithCode: String {
        L.t("Yolcular servis kodunu girerek katılabilir.", "Passengers can join by entering the shuttle code.")
    }

    // MARK: - App root

    static var connectionError: String { L.t("Bağlantı Hatası", "Connection Error") }
    static var tryAgain: String { L.t("Tekrar Dene", "Try Again") }
    static var firebaseChecklistTitle: String { L.t("Firebase Console kontrol listesi:", "Firebase Console checklist:") }
    static var firebaseCheck1: String { L.t("1. Firestore Database oluşturulmuş olmalı", "1. Firestore Database must be created") }
    static var firebaseCheck2: String { L.t("2. Authentication → Apple etkin olmalı", "2. Authentication → Apple must be enabled") }
    static var firebaseCheck3: String { L.t("3. Push Notifications (APNs) yapılandırılmalı", "3. Push Notifications (APNs) must be configured") }

    // MARK: - Invite

    static var shuttleInvite: String { L.t("Servis daveti", "Shuttle invite") }
    static var alreadyMemberOfShuttle: String { L.t("Bu servise zaten kayıtlısınız.", "You are already registered for this shuttle.") }

    // MARK: - Store errors

    static var signInRequired: String { L.t("Giriş yapmanız gerekiyor.", "You need to sign in.") }
    static var shuttleCodeNotFound: String { L.t("Bu servis kodu bulunamadı.", "This shuttle code was not found.") }
    static var alreadyInShuttle: String { L.t("Zaten bir servise kayıtlısınız.", "You are already registered for a shuttle.") }
    static var serviceNameEmpty: String { L.t("Servis adı boş olamaz.", "Shuttle name cannot be empty.") }
    static var nameEmpty: String { L.t("Adınız boş olamaz.", "Your name cannot be empty.") }
    static var passengersOnlyCanAddShuttle: String {
        L.t("Yalnızca yolcu hesabı servis ekleyebilir.", "Only passenger accounts can add a shuttle.")
    }
    static var alreadyRegisteredForShuttle: String { L.t("Bu servise zaten kayıtlısınız.", "You are already registered for this shuttle.") }
    static var selectTripDuration: String { L.t("Servis süresi seçin.", "Select shuttle duration.") }
    static var alwaysLocationRequiredInSettings: String {
        L.t(
            "Servisi başlatmak için Ayarlar'dan \"Her zaman\" konum iznini açmanız gerekir.",
            "Enable \"Always\" location permission in Settings to start the shuttle."
        )
    }
    static var appleUserIDNotFound: String { L.t("Apple hesap kimliği bulunamadı.", "Apple account ID not found.") }

    // MARK: - Auth errors

    static var networkError: String {
        L.t("Ağ hatası. İnternet bağlantınızı kontrol edin.", "Network error. Check your internet connection.")
    }
    static var tooManyRequests: String {
        L.t("Çok fazla deneme yapıldı. Lütfen birkaç dakika sonra tekrar deneyin.", "Too many attempts. Please try again in a few minutes.")
    }
    static var accountDisabled: String { L.t("Bu hesap devre dışı bırakılmış.", "This account has been disabled.") }
    static var appleSignInNotEnabled: String {
        L.t("Apple ile giriş Firebase Console'da etkin değil.", "Sign in with Apple is not enabled in Firebase Console.")
    }
    static var appleCredentialInvalid: String {
        L.t("Apple giriş bilgisi geçersiz. Tekrar deneyin.", "Apple sign-in credentials are invalid. Try again.")
    }
    static var appleSignInCancelled: String { L.t("Apple ile giriş iptal edildi.", "Sign in with Apple was cancelled.") }
    static var notSignedIn: String { L.t("Oturum açık değil.", "Not signed in.") }
    static var userProfileNotFound: String { L.t("Kullanıcı profili bulunamadı.", "User profile not found.") }
    static var firebaseNotReady: String { L.t("Firebase henüz hazır değil. Lütfen tekrar deneyin.", "Firebase is not ready yet. Please try again.") }
    static var appleUserIDUnavailable: String { L.t("Apple hesap kimliği alınamadı.", "Could not retrieve Apple account ID.") }
    static var appleCredentialUnavailable: String { L.t("Apple giriş bilgisi alınamadı.", "Could not retrieve Apple sign-in credentials.") }
    static var appleAuthFailed: String { L.t("Apple kimlik doğrulaması tamamlanamadı.", "Apple authentication could not be completed.") }
    static var firebaseNotReadyShort: String { L.t("Firebase hazır değil.", "Firebase is not ready.") }
    static var signInWithPhone: String { L.t("Telefon ile giriş yapın.", "Sign in with your phone.") }

    static var appleSignInIOSOnly: String {
        L.t("Apple ile giriş yalnızca iOS'ta desteklenir.", "Sign in with Apple is only supported on iOS.")
    }
    static var reauthRequiredToDelete: String {
        L.t(
            "Hesap silmek için güvenlik nedeniyle önce çıkış yapıp tekrar Apple ile giriş yapmanız gerekebilir.",
            "For security, you may need to sign out and sign in again with Apple before deleting your account."
        )
    }

    // MARK: - Smler

    static var invalidServiceCode: String { L.t("Geçerli bir servis kodu yok.", "No valid shuttle code.") }
    static var smlerAPIKeyMissingInfo: String {
        L.t(
            "Smler API anahtarı tanımlı değil. Xcode → Info.plist → SmlerAPIKey alanına dashboard'daki API key'i yapıştırın.",
            "Smler API key is not configured. Paste the dashboard API key into Info.plist → SmlerAPIKey in Xcode."
        )
    }
    static var smlerAPIKeyMissing: String { L.t("Smler API anahtarı eksik.", "Smler API key is missing.") }
    static var smlerAPIInvalid: String { L.t("Smler API adresi geçersiz.", "Smler API URL is invalid.") }
    static var smlerNoResponse: String { L.t("Smler yanıt vermedi.", "Smler did not respond.") }
    static func smlerLinkFailed(_ statusCode: Int, _ detail: String) -> String {
        L.t("Smler link oluşturulamadı (\(statusCode)): \(detail)", "Could not create Smler link (\(statusCode)): \(detail)")
    }
    static var smlerShortLinkMissing: String {
        L.t(
            "Smler kısa link adresi alınamadı. Console'daki response body'ye bakın.",
            "Could not get Smler short link URL. Check the response body in the console."
        )
    }
    static func connectionErrorDetail(_ message: String) -> String {
        L.t("Bağlantı hatası: \(message)", "Connection error: \(message)")
    }
    static var apiURLNotFound: String { L.t("API adresi bulunamadı.", "API URL not found.") }
    static var checkXcodeConsole: String {
        L.t("Ayrıntı için Xcode console [Smler] satırlarına bakın.", "See Xcode console [Smler] lines for details.")
    }
    static var smlerShareTitle: String { L.t("Shuttle Live servis daveti", "Shuttle Live shuttle invite") }
    static func smlerShareBody(_ code: String, _ url: String) -> String {
        L.t(
            "Servis kodu: \(code)\n\(url)",
            "Shuttle code: \(code)\n\(url)"
        )
    }
    static var smlerOGTitle: String { L.t("Shuttle Live — Servis daveti", "Shuttle Live — Shuttle invite") }
    static var smlerOGDescription: String {
        L.t(
            "Resmi Shuttle Live uygulaması. Servis kodunuzla güvenle katılın. App Store'dan indirin.",
            "Official Shuttle Live app. Join safely with your shuttle code. Download on the App Store."
        )
    }

    // MARK: - Firebase bootstrap

    static var googleServicePlistMissing: String {
        L.t(
            "GoogleService-Info.plist bulunamadı. Dosyanın BusTracker hedefinde Copy Bundle Resources içinde olduğundan emin olun.",
            "GoogleService-Info.plist not found. Make sure it is in Copy Bundle Resources for the BusTracker target."
        )
    }
    static func firebaseConnectionFailed(_ message: String) -> String {
        L.t("Firebase bağlantısı kurulamadı: \(message)", "Could not connect to Firebase: \(message)")
    }
}
