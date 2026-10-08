import AppKit
import XCTest
@testable import WaddleOn

final class DesktopActionTests: XCTestCase {
    func testTrajectoryReachesCapturedTargetAcrossNegativeScreenCoordinates() {
        let start = NSPoint(x: 420, y: 80)
        let target = NSPoint(x: -1200, y: -200)
        let trajectory = SnowballTrajectory(start: start, target: target)
        XCTAssertEqual(trajectory.position(progress: 0), start)
        XCTAssertEqual(trajectory.position(progress: 1), target)
        XCTAssertEqual(trajectory.position(progress: 2), target)
        let midpoint = trajectory.position(progress: 0.5)
        XCTAssertEqual(midpoint.x, (start.x + target.x) / 2)
        XCTAssertGreaterThan(midpoint.y, (start.y + target.y) / 2, "Arc must rise above the straight path")
        XCTAssertLessThanOrEqual(trajectory.duration, 1.2)
    }

    func testZeroDistanceTrajectoryRemainsFinite() {
        let trajectory = SnowballTrajectory(start: .zero, target: .zero)
        XCTAssertEqual(trajectory.duration, 0.35)
        XCTAssertTrue(trajectory.position(progress: 0.5).y.isFinite)
        XCTAssertEqual(trajectory.position(progress: 1), .zero)
    }

    func testIntervalClampsAndJitterStayWithinConfiguredBounds() {
        XCTAssertEqual(SnowballTrajectory.clampedInterval(-1), 5)
        XCTAssertEqual(SnowballTrajectory.clampedInterval(900), 300)
        XCTAssertEqual(SnowballTrajectory.clampedInterval(.nan), 20)
        for interval in [5.0, 20, 300] {
            for _ in 0..<100 {
                let delay = SnowballTrajectory.randomDelay(interval: interval)
                XCTAssertGreaterThanOrEqual(delay, interval * 0.75)
                XCTAssertLessThanOrEqual(delay, interval * 1.25)
            }
        }
    }

    func testShortcutIgnoresAutorepeatUntilRelease() {
        var latch = HotKeyPressLatch()
        XCTAssertTrue(latch.receive(pressed: true))
        for _ in 0..<10 { XCTAssertFalse(latch.receive(pressed: true)) }
        XCTAssertFalse(latch.receive(pressed: false))
        XCTAssertFalse(latch.receive(pressed: false))
        XCTAssertTrue(latch.receive(pressed: true))
    }

    @MainActor func testNativeProjectileIsNoninteractiveAndCleansUpAfterImpact() {
        _ = NSApplication.shared
        let projectile = SnowballProjectile(start: .zero, target: NSPoint(x: 100, y: 100), launchedAt: 10)
        XCTAssertTrue(projectile.panel.ignoresMouseEvents)
        XCTAssertFalse(projectile.panel.isOpaque)
        XCTAssertFalse(projectile.panel.canBecomeKey)
        XCTAssertFalse(projectile.panel.canBecomeMain)
        XCTAssertTrue(projectile.advance(now: 10.1))
        XCTAssertTrue(projectile.advance(now: 10.4), "Small impact should still be visible")
        XCTAssertFalse(projectile.advance(now: 12))
        XCTAssertFalse(projectile.panel.isVisible)
    }
}
