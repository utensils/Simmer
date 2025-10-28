//
//  IconAnimatorTests.swift
//  SimmerTests
//
//  Created on 2025-10-28
//

import AppKit
import XCTest
@testable import Simmer

@MainActor
final class IconAnimatorTests: XCTestCase {
    private var scheduler: MockAnimationScheduler!
    private var delegate: MockAnimatorDelegate!
    private var animator: IconAnimator!
    private var baselineCounts: [ColorChannel: Int] = [:]

    override func setUp() {
        super.setUp()
        scheduler = MockAnimationScheduler()
        delegate = MockAnimatorDelegate()
        animator = IconAnimator(scheduler: scheduler)
        animator.delegate = delegate

        baselineCounts[.red] = tintedPixelCount(in: animator.idleIcon, channel: .red) ?? 0
        baselineCounts[.green] = tintedPixelCount(in: animator.idleIcon, channel: .green) ?? 0
        baselineCounts[.blue] = tintedPixelCount(in: animator.idleIcon, channel: .blue) ?? 0
    }

    override func tearDown() {
        animator = nil
        delegate = nil
        scheduler = nil
        baselineCounts = [:]
        super.tearDown()
    }

    func testStartAnimationNotifiesDelegateAndSchedulesFrames_glow() {
        animator.startAnimation(style: .glow, color: CodableColor(red: 1, green: 0, blue: 0))

        XCTAssertEqual(delegate.started.count, 1)
        XCTAssertEqual(delegate.started.first?.style, .glow)
        XCTAssertEqual(scheduler.interval, 1.0 / 60.0, accuracy: 0.0001)
        XCTAssertGreaterThan(delegate.images.count, 0)

        scheduler.fire(times: 10)
        advanceMainRunLoop(times: 10)

        XCTAssertEqual(delegate.images.count, 11, "Initial frame plus 10 updates expected")
        XCTAssertTrue(delegate.images.allSatisfy { $0.size == NSSize(width: 22, height: 22) })

        let reds = delegate.images.compactMap { centerComponentValue(of: $0, channel: .red) }
        guard let minRed = reds.min(), let maxRed = reds.max() else {
            return XCTFail("Failed to extract center color values")
        }
        XCTAssertGreaterThan(maxRed - minRed, 0.05, "Glow should noticeably change red intensity over time")
        XCTAssertGreaterThan(minRed, 0.2)
        XCTAssertLessThanOrEqual(maxRed, 1.0)
    }

    func testPulseAnimationScalesTintedAreaOverTime() {
        animator.startAnimation(style: .pulse, color: CodableColor(red: 0, green: 1, blue: 0))

        scheduler.fire(times: 30)
        advanceMainRunLoop(times: 30)

        let deltas = delegate.images.compactMap { tintedPixelCount(in: $0, channel: .green) }
            .map { $0 - baselineCounts[.green, default: 0] }
        guard let minPixels = deltas.min(), let maxPixels = deltas.max() else {
            return XCTFail("No pixel data captured")
        }

        XCTAssertGreaterThan(maxPixels - minPixels, 40, "Pulse should noticeably change tinted area across frames")
    }

    func testBlinkAnimationAlternatesVisibility() {
        animator.startAnimation(style: .blink, color: CodableColor(red: 0, green: 0, blue: 1))

        scheduler.fire(times: 40)
        advanceMainRunLoop(times: 40)

        let blues = delegate.images.compactMap { centerComponentValue(of: $0, channel: .blue) }
        guard let minBlue = blues.min(), let maxBlue = blues.max() else {
            return XCTFail("Failed to extract blue component values")
        }
        let baselineBlue = centerComponentValue(of: animator.idleIcon, channel: .blue) ?? 0.25
        XCTAssertLessThanOrEqual(minBlue, baselineBlue + 0.05, "Blink should include frames near baseline intensity")
        XCTAssertGreaterThan(maxBlue, baselineBlue + 0.4, "Blink should include frames with strong tinted intensity")
    }

    func testStopAnimationResetsStateAndIcon() {
        animator.startAnimation(style: .glow, color: CodableColor(red: 1, green: 0, blue: 0))
        scheduler.fire(times: 5)
        advanceMainRunLoop(times: 5)

        animator.stopAnimation()

        XCTAssertEqual(delegate.endedCount, 1)
        XCTAssertEqual(animator.state, .idle)
        guard let finalImage = delegate.images.last,
              let idleData = animator.idleIcon.tiffRepresentation,
              let finalData = finalImage.tiffRepresentation else {
            return XCTFail("Missing image data for comparison")
        }
        XCTAssertEqual(finalData, idleData)
    }

    // MARK: - Helpers

    private func centerComponentValue(of image: NSImage, channel: ColorChannel) -> CGFloat? {
        guard let bitmap = bitmap(from: image),
              let color = bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?
                .usingColorSpace(.deviceRGB) else { return nil }
        switch channel {
        case .red:
            return color.redComponent
        case .green:
            return color.greenComponent
        case .blue:
            return color.blueComponent
        }
    }

    private func tintedPixelCount(in image: NSImage, channel: ColorChannel) -> Int? {
        guard let bitmap = bitmap(from: image) else { return nil }
        var count = 0
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let value: CGFloat
                switch channel {
                case .red:
                    value = color.redComponent
                case .green:
                    value = color.greenComponent
                case .blue:
                    value = color.blueComponent
                }
                if value > 0.35 {
                    count += 1
                }
            }
        }
        return count
    }

    private func bitmap(from image: NSImage) -> NSBitmapImageRep? {
        guard let data = image.tiffRepresentation else { return nil }
        return NSBitmapImageRep(data: data)
    }

    private func advanceMainRunLoop(times: Int) {
        for _ in 0..<max(1, times) {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.002))
        }
    }
}

private enum ColorChannel {
    case red
    case green
    case blue
}

// MARK: - Test Doubles

private final class MockAnimationScheduler: AnimationScheduler {
    private var handler: (@MainActor () -> Void)?
    private(set) var isRunning = false
    private(set) var recordedInterval: TimeInterval = 0

    var interval: TimeInterval {
        recordedInterval
    }

    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        recordedInterval = interval
        isRunning = true
        self.handler = handler
    }

    func stop() {
        isRunning = false
        handler = nil
        recordedInterval = 0
    }

    func fire(times: Int = 1) {
        guard let handler, isRunning else { return }
        for _ in 0..<times {
            Task { @MainActor in
                handler()
            }
        }
    }
}

private final class MockAnimatorDelegate: IconAnimatorDelegate {
    struct StartEvent {
        let style: AnimationStyle
        let color: CodableColor
    }

    private(set) var started: [StartEvent] = []
    private(set) var images: [NSImage] = []
    private(set) var endedCount = 0

    func animationDidStart(style: AnimationStyle, color: CodableColor) {
        started.append(StartEvent(style: style, color: color))
    }

    func animationDidEnd() {
        endedCount += 1
    }

    func updateIcon(_ image: NSImage) {
        images.append(image)
    }
}
