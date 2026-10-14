import Foundation

/// How a linked list's last sync ended, a full refresh or a push alike.
public enum SyncResult: Equatable {
    case ok
    /// With the reason, as the GitHub menu shows it.
    case failed(String)
}

/// When the sync result shows beside a linked list's refresh button.
public enum SyncStatus {
    /// A result fades this long after it shows.
    public static let fadeAfter: TimeInterval = 60

    /// Whether the result shows at `now`. A check mark shows for
    /// `fadeAfter`. An x shows while `waiting` changes are not on GitHub
    /// (waiting or held), and for `fadeAfter` once none are left.
    public static func visible(result: SyncResult?, at: Date?, now: Date, waiting: Int) -> Bool {
        guard let result, let at else { return false }
        let fresh = now.timeIntervalSince(at) < fadeAfter
        switch result {
        case .ok: return fresh
        case .failed: return waiting > 0 || fresh
        }
    }
}
