import NotelyCore
import SwiftUI

/// Settings > Integrations: the GitHub account and the lists linked to a
/// repository.
struct IntegrationsPane: View {
    let store: NoteStore
    let account: GitHubAccount
    let sync: SyncController
    @State private var showsAccountSheet = false

    /// Linked lists, newest first, as in the menu.
    private var linkedLists: [Note] {
        store.notes.reversed().filter { $0.isList && $0.githubRepo != nil }
    }

    private var accountStatus: String {
        guard account.isConnected else { return "Not connected" }
        if account.tokenRejected { return "Token no longer works" }
        return account.login.map { "Connected as @\($0)" } ?? "Connected"
    }

    var body: some View {
        Form {
            Section("GitHub") {
                LabeledContent("Account") {
                    HStack(spacing: 12) {
                        Text(accountStatus)
                            .foregroundStyle(.secondary)
                        if account.isConnected && account.tokenRejected {
                            Button("Reconnect…") { showsAccountSheet = true }
                        }
                        if account.isConnected {
                            Button("Disconnect") { account.disconnect() }
                        } else {
                            Button("Setup Account") { showsAccountSheet = true }
                        }
                    }
                }
            }
            Section("Linked lists") {
                if linkedLists.isEmpty {
                    Text("No linked lists")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(linkedLists) { note in
                        // Long titles and repository names truncate; they
                        // must not widen the pane.
                        LabeledContent(listTitle(note.title), value: note.githubRepo ?? "")
                            .lineLimit(1)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showsAccountSheet) {
            AccountSheet(account: account, onConnect: { sync.refreshAll() })
        }
    }
}

/// The "GitHub Account" sheet: takes a personal access token, checks it
/// with GitHub, and saves it in the Keychain only when GitHub accepts it.
/// The typed characters stay hidden.
struct AccountSheet: View {
    let account: GitHubAccount
    var onConnect: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var isChecking = false
    @State private var problem: String?

    private var isBlank: Bool {
        token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GitHub Account")
                .font(.headline)
            SecureField("Personal Access Token", text: $token)
                .textFieldStyle(.roundedBorder)
                .disabled(isChecking)
            Text("Use a classic token with the “repo” scope. It reaches every repository you work in, also ones you don't own. A fine-grained token reaches only the repositories of one owner.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let problem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Connect") { connect() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBlank || isChecking)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func connect() {
        isChecking = true
        problem = nil
        Task { @MainActor in
            let result = await account.connect(token: token)
            isChecking = false
            switch result {
            case .connected:
                onConnect()
                dismiss()
            case .rejected:
                problem = "GitHub didn't accept this token."
            case .offline:
                problem = "GitHub can't be reached. Check the connection and try again."
            case .saveFailed:
                problem = "The token could not be saved in the Keychain."
            case .failed:
                problem = "GitHub had a problem. Try again later."
            }
        }
    }
}
