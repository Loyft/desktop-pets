import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var petPanel: PetPanel!
    private var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        petPanel = PetPanel()
        petPanel.orderFrontRegardless()

        menuBar = MenuBarController(petPanel: petPanel)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParamsChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        petPanel?.orderOut(nil)
    }

    @objc private func screenParamsChanged() {
        petPanel?.refreshScreenGeometry()
    }
}
