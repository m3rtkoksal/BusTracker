#if os(iOS) || os(visionOS)
import UIKit
import UniformTypeIdentifiers

enum CopyServiceCode {
    /// Panoya yazar. UIPasteboard.main thread'de UI'ı kilitleyebildiği için yazma arka planda yapılır.
    @discardableResult
    static func copy(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !text.isEmpty else { return false }

        DispatchQueue.global(qos: .userInitiated).async {
            UIPasteboard.general.setItems(
                [[UTType.plainText.identifier: text]],
                options: [.localOnly: true]
            )
        }
        return true
    }
}
#endif
