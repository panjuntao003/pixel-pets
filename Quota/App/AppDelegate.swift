import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let coordinator = QuotaCoordinator()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        coordinator.start()
        coordinator.stateStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
        coordinator.settingsStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
        updateMenuBarIcon()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
    }

    private func updateMenuBarIcon() {
        let status = coordinator.stateStore.overallStatus(among: coordinator.enabledProviders)
        let renderer = ImageRenderer(content: MenuBarDotView(status: status))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let size = NSSize(width: 18, height: 18)
        guard let cgImage = renderer.cgImage else {
            statusItem?.button?.image = NSImage(
                systemSymbolName: "circle.fill",
                accessibilityDescription: "Quota"
            )
            return
        }
        let image = NSImage(cgImage: cgImage, size: size)
        image.isTemplate = false
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = MenuBarDotView(status: status).tooltip
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 420)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                stateStore: coordinator.stateStore,
                onRefresh: { [weak self] in
                    self?.coordinator.refresh()
                }
            )
            .environmentObject(coordinator.settingsStore)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
