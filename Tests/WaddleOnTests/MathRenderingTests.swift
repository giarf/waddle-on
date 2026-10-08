import XCTest
import WebKit
@testable import WaddleOn

final class MathRenderingTests: XCTestCase {
    @MainActor func testBundledRendererTypesetsIntegralAndKeepsHTMLInert() async throws {
        let view = MathMessageWebView()
        view.frame = NSRect(x: 0, y: 0, width: 320, height: 250)
        view.setMessage(#"\[\int \sen(x)\cos(x)\,dx=\frac{\sen^2(x)}{2}+C\] <img src=x onerror=alert(1)>"#)
        var rendered = false
        for _ in 0..<100 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if let count = try? await view.evaluateJavaScript("document.querySelectorAll('.katex').length") as? Int, count > 0 {
                rendered = true
                break
            }
        }
        XCTAssertTrue(rendered, "Bundled KaTeX should render math offline")
        let images = try await view.evaluateJavaScript("document.querySelectorAll('img').length") as? Int
        XCTAssertEqual(images, 0)
        let errors = try await view.evaluateJavaScript("document.querySelectorAll('.katex-error').length") as? Int
        XCTAssertEqual(errors, 0)
        _ = try await view.evaluateJavaScript(
            #"setMessage('Entonces:\n\n\\[\\int \\cos(x)\\sin(x)\\,dx = \\frac{\\sin^2(x)}{2}+C\\]\n\nListo.', false)"#)
        let compact = try await view.evaluateJavaScript("""
            (() => {
                const display = document.querySelector('.katex-display');
                let block = display;
                while (block.parentNode.id !== 'message' && block.parentNode.childNodes.length === 1) block = block.parentNode;
                return block.previousSibling.textContent === 'Entonces:' &&
                    block.nextSibling.textContent === 'Listo.' &&
                    getComputedStyle(display.querySelector('.katex')).whiteSpace === 'nowrap';
            })()
            """) as? Bool
        XCTAssertEqual(compact, true, "Display math should not retain redundant blank lines or wrap glyphs")
    }
}
