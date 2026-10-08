import SwiftUI
import WebKit

final class MathMessageWebView: WKWebView, WKNavigationDelegate, WKScriptMessageHandler {
    var onHeight: ((CGFloat) -> Void)?
    private var message = ""
    private var dark = false
    private var ready = false

    init() {
        let configuration = WKWebViewConfiguration()
        super.init(frame: .zero, configuration: configuration)
        setValue(false, forKey: "drawsBackground")
        navigationDelegate = self
        // A weak proxy avoids a WebKit -> handler -> WebKit retain cycle.
        configuration.userContentController.add(WeakHeightHandler(self), name: "height")
        let embedded = Bundle.main.url(forResource: "WaddleOn_WaddleOn", withExtension: "bundle").flatMap(Bundle.init(url:))
        let bundle = embedded ?? Bundle.module
        if let url = bundle.url(forResource: "message", withExtension: "html", subdirectory: "Resources/Math") {
            loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setMessage(_ text: String, dark: Bool = false) {
        guard text != message || self.dark != dark else { return }
        message = text
        self.dark = dark
        render()
    }

    private func render() {
        guard ready else { return }
        // Pass the model output as data, never as HTML or executable JS.
        callAsyncJavaScript("setMessage(text, dark)", arguments: ["text": message, "dark": dark],
                            in: nil, in: .page, completionHandler: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        ready = true
        render()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let height = message.body as? Double, height.isFinite else { return }
        onHeight?(CGFloat(max(24, min(height, 100_000))))
    }
}

private final class WeakHeightHandler: NSObject, WKScriptMessageHandler {
    weak var owner: MathMessageWebView?
    init(_ owner: MathMessageWebView) { self.owner = owner }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.userContentController(userContentController, didReceive: message)
    }
}

struct MathMessageView: View {
    let text: String
    @State private var height: CGFloat = 60
    var body: some View {
        MathMessageRepresentable(text: text, height: $height)
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

private struct MathMessageRepresentable: NSViewRepresentable {
    let text: String
    @Binding var height: CGFloat
    func makeNSView(context: Context) -> MathMessageWebView { MathMessageWebView() }
    func updateNSView(_ view: MathMessageWebView, context: Context) {
        view.onHeight = { value in
            DispatchQueue.main.async { if abs(height - value) > 1 { height = value } }
        }
        view.setMessage(text, dark: true)
    }
}
