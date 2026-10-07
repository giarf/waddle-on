import AppKit
import SwiftUI

@main
enum WaddleOnApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let desktop = DesktopController()
    private let chat = ChatViewModel()
    private let store = SettingsStore()
    private let client = OpenAIClient()
    private var request: Task<Void, Never>?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installEditingMenu()
        chat.onSend = { [weak self] text in self?.send(text) }
        chat.onCancel = { [weak self] in self?.cancel() }
        chat.onOpenSettings = { [weak self] in self?.openSettings() }
        chat.onHistoryExpanded = { [weak self] expanded in self?.desktop.setChatExpanded(expanded) }
        desktop.onOpenSettings = { [weak self] in self?.openSettings() }
        desktop.onQuit = { NSApp.terminate(nil) }
        desktop.setChatContent(NSHostingView(rootView: ChatBarView(model: chat)))
        desktop.start()
        desktop.showBubble("¡Hola! Soy tu compañero de escritorio. Mantén ⌥ Option y haz clic para que camine hasta allí.")
    }

    func applicationWillTerminate(_ notification: Notification) {
        request?.cancel()
        desktop.stop()
    }

    private func installEditingMenu() {
        // AppKit routes these shortcuts through the focused field's responder
        // chain, including SwiftUI SecureField's native field editor.
        let mainMenu = NSMenu()
        let editItem = NSMenuItem(title: "Edición", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edición")
        let commands: [(String, Selector, String)] = [
            ("Deshacer", Selector(("undo:")), "z"),
            ("Rehacer", Selector(("redo:")), "Z"),
            ("Cortar", #selector(NSText.cut(_:)), "x"),
            ("Copiar", #selector(NSText.copy(_:)), "c"),
            ("Pegar", #selector(NSText.paste(_:)), "v"),
            ("Seleccionar todo", #selector(NSText.selectAll(_:)), "a")
        ]
        for (title, action, key) in commands {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key.lowercased())
            item.keyEquivalentModifierMask = key == "Z" ? [.command, .shift] : [.command]
            editMenu.addItem(item)
        }
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    private func send(_ text: String) {
        guard request == nil else { return }
        let configuration = store.loadConfiguration()
        let key: String
        do { key = try store.loadAPIKey() }
        catch { chat.error = error.localizedDescription; openSettings(); return }
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            chat.error = "Configura el modelo de IA para empezar."
            openSettings()
            return
        }
        chat.messages.append(ChatMessage(role: "user", content: text))
        chat.isSending = true
        chat.error = nil
        let messages = chat.messages.map { AIMessage(role: $0.role, content: $0.content) }
        request = Task { [weak self] in
            guard let self else { return }
            defer { self.chat.isSending = false; self.request = nil }
            do {
                let response = try await self.client.complete(messages: messages, configuration: configuration, apiKey: key)
                try Task.checkCancellation()
                self.chat.messages.append(ChatMessage(role: "assistant", content: response))
                self.desktop.showBubble(response)
            } catch {
                if !Task.isCancelled { self.chat.error = error.localizedDescription }
            }
        }
    }

    private func cancel() { request?.cancel() }

    private func openSettings() {
        if let settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }
        presentSettings()
    }

    private func presentSettings() {
        let configuration = store.loadConfiguration()
        let model = SettingsViewModel(
            baseURL: configuration.baseURL,
            model: configuration.model,
            apiKey: (try? store.loadAPIKey()) ?? "",
            systemPrompt: configuration.systemPrompt
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 550),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "Configurar Waddle On"
        window.isReleasedWhenClosed = false
        window.level = .floating
        model.onSave = { [weak self, weak window, weak model] in
            guard let self, let model else { return }
            do {
                try self.store.saveAPIKey(model.apiKey)
                self.store.saveConfiguration(AIConfiguration(
                    baseURL: model.baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                    model: model.model.trimmingCharacters(in: .whitespacesAndNewlines),
                    systemPrompt: model.systemPrompt
                ))
                self.chat.error = nil
                window?.close()
                self.settingsWindow = nil
            } catch { model.error = error.localizedDescription }
        }
        model.onCancel = { [weak self, weak window] in
            window?.close()
            self?.settingsWindow = nil
        }
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
