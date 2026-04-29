import AppKit
import Combine
import SwiftUI

@main
struct PixelPetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(onRegisterHooks: appDelegate.coordinator.registerDetectedHooks)
                .environmentObject(appDelegate.coordinator.settingsStore)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let coordinator = AppCoordinator()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var hookPermissionWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        bindHookPermissionPrompt()
        coordinator.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "PixelPets")
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                viewModel: coordinator.viewModel,
                onRefresh: coordinator.refresh,
                onConfigureHooks: coordinator.registerDetectedHooks
            )
            .environmentObject(coordinator.settingsStore)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func bindHookPermissionPrompt() {
        coordinator.$shouldShowHookPermission
            .combineLatest(coordinator.$hookPermissionOptions)
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldShow, _ in
                guard let self else { return }
                if shouldShow {
                    self.showHookPermissionWindow()
                } else {
                    self.closeHookPermissionWindow()
                }
            }
            .store(in: &cancellables)
    }

    private func showHookPermissionWindow() {
        if let hookPermissionWindow {
            hookPermissionWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = HookPermissionView(
            options: Binding(
                get: { self.coordinator.hookPermissionOptions },
                set: { self.coordinator.hookPermissionOptions = $0 }
            ),
            onConfirm: { [weak self] in
                self?.coordinator.confirmHookPermissionSelection()
            },
            onSkip: { [weak self] in
                self?.coordinator.skipHookPermissionPrompt()
            }
        )

        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "PixelPets Hooks"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        hookPermissionWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeHookPermissionWindow() {
        hookPermissionWindow?.close()
        hookPermissionWindow = nil
    }
}
