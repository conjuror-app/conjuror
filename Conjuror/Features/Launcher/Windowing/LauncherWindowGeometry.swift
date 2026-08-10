import AppKit

enum LauncherWindowGeometry {
    static func centeredFrame(
        size: NSSize,
        visibleFrame: NSRect
    ) -> NSRect {
        let frame = NSRect(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2 + visibleFrame.height * 0.15,
            width: size.width,
            height: size.height
        )
        return constrainedFrame(frame, to: visibleFrame)
    }

    static func resizedFrame(
        currentFrame: NSRect,
        targetSize: NSSize,
        visibleFrame: NSRect?
    ) -> NSRect {
        let frame = NSRect(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.maxY - targetSize.height,
            width: targetSize.width,
            height: targetSize.height
        )
        guard let visibleFrame else {
            return frame
        }
        return constrainedFrame(frame, to: visibleFrame)
    }

    private static func constrainedFrame(
        _ frame: NSRect,
        to visibleFrame: NSRect
    ) -> NSRect {
        let width = min(frame.width, visibleFrame.width)
        let height = min(frame.height, visibleFrame.height)
        let maximumX = visibleFrame.maxX - width
        let maximumY = visibleFrame.maxY - height

        return NSRect(
            x: min(max(frame.origin.x, visibleFrame.minX), maximumX),
            y: min(max(frame.origin.y, visibleFrame.minY), maximumY),
            width: width,
            height: height
        )
    }
}
