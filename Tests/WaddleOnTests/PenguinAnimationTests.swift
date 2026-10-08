import XCTest
import AppKit
@testable import WaddleOn

final class PenguinAnimationTests: XCTestCase {
    @MainActor func testDirectionDoesNotFlickerAtAnySectorBoundary() {
        let penguin = PenguinView(frame: .zero)
        func vector(_ degrees: Double) -> CGVector {
            let angle = degrees * .pi / 180
            return CGVector(dx: -sin(angle) * 100, dy: -cos(angle) * 100)
        }
        for sector in 0..<8 {
            let center = Double(sector) * 45
            penguin.setWalking(false, toward: .zero)
            penguin.setWalking(true, toward: vector(center))
            XCTAssertEqual(penguin.direction, sector)
            for jitter in [21.0, 24, 22, 23, 21, 25] {
                penguin.setWalking(true, toward: vector(center + jitter))
                XCTAssertEqual(penguin.direction, sector)
            }
            penguin.setWalking(true, toward: vector(center + 33))
            XCTAssertEqual(penguin.direction, (sector + 1) % 8)
            for jitter in [24.0, 21, 23, 22] {
                penguin.setWalking(true, toward: vector(center + jitter))
                XCTAssertEqual(penguin.direction, (sector + 1) % 8)
            }
            penguin.setWalking(true, toward: vector(center + 12))
            XCTAssertEqual(penguin.direction, sector)
        }
    }

    @MainActor func testWalkingAdvancesWithoutWindowTimerAndDoesNotResetEachStep() {
        let penguin = PenguinView(frame: NSRect(x: 0, y: 0, width: 267, height: 252))
        penguin.prepareAnimations()
        penguin.setWalking(true, toward: CGVector(dx: 1, dy: 0))
        let start = ProcessInfo.processInfo.systemUptime
        penguin.advanceAnimation(at: start)
        let first = penguin.walkingFrameIndex
        for step in 1...6 {
            penguin.setWalking(true, toward: CGVector(dx: 1, dy: 0))
            penguin.advanceAnimation(at: start + Double(step) / 60)
        }
        XCTAssertNotEqual(penguin.walkingFrameIndex, first)
        XCTAssertEqual(penguin.walkingFrameIndex, 3)
    }
}
