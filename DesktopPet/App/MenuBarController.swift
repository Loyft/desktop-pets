import AppKit
import ServiceManagement

final class MenuBarController {
    private let statusItem: NSStatusItem
    private weak var petPanel: PetPanel?
    private var isPaused = false

    init(petPanel: PetPanel) {
        self.petPanel = petPanel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.menuIcon()
            button.image?.isTemplate = true
            button.toolTip = "Desktop Pet"
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let hideItem = NSMenuItem(
            title: "Hide Pet",
            action: #selector(toggleVisibility(_:)),
            keyEquivalent: "h"
        )
        hideItem.target = self
        menu.addItem(hideItem)

        let pauseItem = NSMenuItem(
            title: "Pause",
            action: #selector(togglePause(_:)),
            keyEquivalent: "p"
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(
            title: "Open at Login",
            action: #selector(toggleOpenAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        loginItem.state = Self.isOpenAtLoginEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Desktop Pet",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func toggleVisibility(_ sender: NSMenuItem) {
        guard let petPanel else { return }
        let willHide = petPanel.isPetVisible
        petPanel.setPetHidden(willHide)
        sender.title = willHide ? "Show Pet" : "Hide Pet"
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        isPaused.toggle()
        petPanel?.setPaused(isPaused)
        sender.title = isPaused ? "Resume" : "Pause"
    }

    @objc private func toggleOpenAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                sender.state = .off
            } else {
                try service.register()
                sender.state = .on
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not update Login Item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            sender.state = Self.isOpenAtLoginEnabled ? .on : .off
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private static var isOpenAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private static func menuIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath(ovalIn: rect.insetBy(dx: 3, dy: 4))
            NSColor.black.setFill()
            path.fill()
            // ears
            let left = NSBezierPath()
            left.move(to: NSPoint(x: rect.minX + 4, y: rect.midY + 1))
            left.line(to: NSPoint(x: rect.minX + 6, y: rect.maxY - 2))
            left.line(to: NSPoint(x: rect.minX + 8, y: rect.midY + 2))
            left.fill()
            let right = NSBezierPath()
            right.move(to: NSPoint(x: rect.maxX - 4, y: rect.midY + 1))
            right.line(to: NSPoint(x: rect.maxX - 6, y: rect.maxY - 2))
            right.line(to: NSPoint(x: rect.maxX - 8, y: rect.midY + 2))
            right.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
