import Foundation

enum DriverSubscriptionShare {
    static func normalizedServiceCode(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func renewalURL(serviceCode: String) -> URL {
        DriverSubscriptionConfig.renewalPageURL(serviceCode: normalizedServiceCode(serviceCode))
    }

    static func renewalURLString(serviceCode: String) -> String {
        renewalURL(serviceCode: serviceCode).absoluteString
    }

    static func shareMessage(serviceCode: String) -> String {
        L10n.subscriptionRenewalShareMessage(renewalURLString(serviceCode: serviceCode))
    }

#if os(iOS) || os(visionOS)
    static func share(serviceCode: String) {
        SharePresenter.present(items: [shareMessage(serviceCode: serviceCode), renewalURL(serviceCode: serviceCode)])
    }

    @discardableResult
    static func copyLink(serviceCode: String) -> Bool {
        CopyServiceCode.copyPlainText(renewalURLString(serviceCode: serviceCode))
    }
#endif
}
