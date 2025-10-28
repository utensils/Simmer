//
//  IconAnimator.swift
//  Simmer
//
//  Created on 2025-10-28
//

import AppKit
import Dispatch

/// Schedules repeated callbacks for animation frames.
protocol AnimationScheduler {
    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void)
    func stop()
}

final class DispatchAnimationScheduler: AnimationScheduler {
    private var timer: DispatchSourceTimer?
    private let queue: DispatchQueue

    init(queue: DispatchQueue = .main) {
        self.queue = queue
    }

    func start(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        stop()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler {
            Task { @MainActor in
                handler()
            }
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}

/// Generates menu bar icon animations at 60fps for glow, pulse, and blink styles.
/// Frames are pre-rendered on a background queue per TECH_DESIGN.md guidance to avoid main thread stalls.
@MainActor
final class IconAnimator {
    weak var delegate: IconAnimatorDelegate?

    private(set) var state: IconAnimationState = .idle

    private let frameRate: Double
    private let renderQueue: DispatchQueue
    private let scheduler: AnimationScheduler
    private let iconSize: NSSize
    private let baseIcon: NSImage

    private var frames: [NSImage] = []
    private var currentFrameIndex: Int = 0

    init(
        frameRate: Double = 60.0,
        iconSize: NSSize = NSSize(width: 22, height: 22),
        screenScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0,
        renderQueue: DispatchQueue = DispatchQueue(label: "com.simmer.iconAnimator.render", qos: .userInitiated),
        scheduler: AnimationScheduler = DispatchAnimationScheduler()
    ) {
        self.frameRate = frameRate
        self.iconSize = iconSize
        self.renderQueue = renderQueue
        self.scheduler = scheduler
        self.baseIcon = IconAnimator.makeBaseIcon(size: iconSize, scale: screenScale)
    }

    /// Begins animating the icon for the supplied style and color.
    func startAnimation(style: AnimationStyle, color: CodableColor) {
        scheduler.stop()

        let nsColor = color.toNSColor()
        let frameCount = frameCount(for: style)
        let generatedFrames = renderQueue.sync {
            generateFrames(for: style, color: nsColor, frameCount: frameCount)
        }

        guard !generatedFrames.isEmpty else {
            return
        }

        frames = generatedFrames
        currentFrameIndex = 0
        state = .animating(style: style, color: color)

        delegate?.animationDidStart(style: style, color: color)
        delegate?.updateIcon(frames[currentFrameIndex])

        if frames.count > 1 {
            scheduler.start(interval: 1.0 / frameRate) { [weak self] in
                guard let self else { return }
                self.advanceFrame()
            }
        }
    }

    /// Stops any active animation and returns the icon to the idle state.
    func stopAnimation() {
        scheduler.stop()
        frames = []
        currentFrameIndex = 0
        state = .idle

        delegate?.animationDidEnd()
        delegate?.updateIcon(baseIcon)
    }

    /// Idle icon image useful for resetting UI components.
    var idleIcon: NSImage {
        baseIcon
    }

    private func advanceFrame() {
        guard !frames.isEmpty else {
            return
        }
        currentFrameIndex = (currentFrameIndex + 1) % frames.count
        delegate?.updateIcon(frames[currentFrameIndex])
    }

    private func frameCount(for style: AnimationStyle) -> Int {
        switch style {
        case .glow:
            return max(1, Int(frameRate * 2.0))
        case .pulse:
            return max(1, Int(frameRate * 1.5))
        case .blink:
            return max(1, Int(frameRate * 0.5))
        }
    }

    private func generateFrames(for style: AnimationStyle, color: NSColor, frameCount: Int) -> [NSImage] {
        guard frameCount > 0 else { return [] }

        return (0..<frameCount).compactMap { frameIndex in
            let progress = Double(frameIndex) / Double(frameCount)
            switch style {
            case .glow:
                let opacity = glowOpacity(at: progress)
                return renderFrame(color: color, opacity: opacity, scale: 1.0, includeTint: opacity > 0)
            case .pulse:
                let scale = pulseScale(at: progress)
                let opacity = pulseOpacity(at: progress)
                return renderFrame(color: color, opacity: opacity, scale: scale, includeTint: opacity > 0.01)
            case .blink:
                let visible = blinkVisible(at: progress)
                return renderFrame(color: color, opacity: visible ? 1.0 : 0.0, scale: 1.0, includeTint: visible)
            }
        }
    }

    private func glowOpacity(at progress: Double) -> CGFloat {
        let value = 0.75 + 0.25 * sin(2.0 * .pi * progress)
        return CGFloat(min(max(value, 0.5), 1.0))
    }

    private func pulseScale(at progress: Double) -> CGFloat {
        let value = 1.075 + 0.075 * sin(2.0 * .pi * progress)
        return CGFloat(min(max(value, 1.0), 1.15))
    }

    private func pulseOpacity(at progress: Double) -> CGFloat {
        let value = 0.85 + 0.15 * sin(2.0 * .pi * progress)
        return CGFloat(min(max(value, 0.7), 1.0))
    }

    private func blinkVisible(at progress: Double) -> Bool {
        progress.truncatingRemainder(dividingBy: 1.0) < 0.5
    }

    private func renderFrame(color: NSColor, opacity: CGFloat, scale: CGFloat, includeTint: Bool) -> NSImage {
        let image = NSImage(size: iconSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: iconSize)
        baseIcon.draw(in: rect)

        guard includeTint, opacity > 0 else {
            image.isTemplate = false
            return image
        }

        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()

        if abs(scale - 1.0) > CGFloat.ulpOfOne {
            context?.translateBy(x: rect.midX, y: rect.midY)
            context?.scaleBy(x: scale, y: scale)
            context?.translateBy(x: -rect.midX, y: -rect.midY)
        }

        let inset: CGFloat = 4.0
        let circleRect = rect.insetBy(dx: inset, dy: inset)
        color.withAlphaComponent(opacity).setFill()
        NSBezierPath(ovalIn: circleRect).fill()

        context?.restoreGState()
        image.isTemplate = false
        return image
    }

    private static func makeBaseIcon(size: NSSize, scale: CGFloat) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        NSBezierPath(rect: rect).fill()

        let innerRect = rect.insetBy(dx: 4.0, dy: 4.0)
        let fillColor = NSColor(calibratedWhite: 0.25, alpha: 1.0)
        let strokeColor = NSColor(calibratedWhite: 0.85, alpha: 1.0)

        fillColor.setFill()
        NSBezierPath(ovalIn: innerRect).fill()

        strokeColor.setStroke()
        let borderPath = NSBezierPath(ovalIn: innerRect)
        borderPath.lineWidth = 1.5 / max(scale, 1.0)
        borderPath.stroke()

        image.isTemplate = false
        return image
    }
}
