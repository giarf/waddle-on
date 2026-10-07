import Foundation
import Combine

struct ChatMessage: Identifiable {
    let id: UUID
    let role: String
    var content: String

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }
}

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft = ""
    @Published var isSending = false
    @Published var error: String?
    @Published var isHistoryExpanded = false {
        didSet {
            if oldValue != isHistoryExpanded {
                onHistoryExpanded?(isHistoryExpanded)
            }
        }
    }

    var onSend: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onHistoryExpanded: ((Bool) -> Void)?

    var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func send() {
        guard canSend, let onSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        draft = ""
        error = nil
        onSend(text)
    }
}
