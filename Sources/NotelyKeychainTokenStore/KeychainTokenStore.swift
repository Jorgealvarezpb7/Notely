import Foundation
import NotelyCore
import Security

/// Keeps the GitHub token in the login Keychain, as one generic password,
/// never in the notes data or the app's preferences. The token is read
/// from the Keychain once per launch and then kept in memory: each read of
/// an item the running build is not yet allowed to read asks the user for
/// their password, and one launch reads the token several times. A class,
/// so the account and the client share one cache.
public final class KeychainTokenStore: TokenStore {
    private static let service = "com.notely.github"
    private static let account = "token"

    /// `nil` until the first read; then the token, or `.some(nil)` when
    /// none is saved.
    private var cached: String??
    /// Requests read the token from background tasks; held across the
    /// Keychain call, so reads at the same time ask only once.
    private let lock = NSLock()

    public init() {}

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: Self.service,
         kSecAttrAccount as String: Self.account]
    }

    public func read() -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        // Only a found or missing token is kept; a read the user refused
        // asks again next time.
        if status == errSecItemNotFound {
            cached = .some(nil)
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        let token = String(data: data, encoding: .utf8)
        cached = .some(token)
        return token
    }

    /// Replaces a saved token, or adds one when none is saved.
    public func save(_ token: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let data = Data(token.utf8)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        let saved: Bool
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            saved = SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        } else {
            saved = status == errSecSuccess
        }
        // Read again from the Keychain next time when the save failed.
        cached = saved ? .some(token) : nil
        return saved
    }

    public func delete() {
        lock.lock()
        defer { lock.unlock() }
        SecItemDelete(query as CFDictionary)
        cached = .some(nil)
    }
}
