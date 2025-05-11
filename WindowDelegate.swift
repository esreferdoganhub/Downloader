import Cocoa

class WindowDelegate: NSObject, NSWindowDelegate {
    func windowWillEnterFullScreen(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.toggleFullScreen(nil) // Tam ekranı engelle
        }
    }
    func windowShouldZoom(_ window: NSWindow, toFrame frame: NSRect) -> Bool {
        return false // Zoom (büyütme) engelle
    }
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Yeniden boyutlandırmayı engelle
        return sender.frame.size
    }
    func windowDidBecomeMain(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.styleMask.remove(.resizable)
        }
    }
    func windowDidBecomeKey(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            window.styleMask.remove(.resizable)
        }
    }
}
