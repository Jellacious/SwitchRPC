import Foundation
import SwiftUI
import AppKit

// MARK: - App Delegate & Standard Edit Menu Setup
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    static weak var shared: AppDelegate?
    var window: NSWindow!
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.regular)
        if let icon = Bundle.main.image(forResource: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
        setupMainMenu()
        updateMenuBarVisibility()
        
        createAndShowWindow()
    }
    
    func updateMenuBarVisibility() {
        let enabled = AppState.shared.store.settings.enableMenuBar
        if enabled {
            if statusItem == nil {
                setupStatusBar()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
        }
    }
    
    func createAndShowWindow() {
        if window == nil {
            let contentView = ContentView()
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 415),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.isReleasedWhenClosed = false
            win.center()
            win.title = "SwitchRPC"
            win.contentView = NSHostingView(rootView: contentView)
            win.delegate = self
            self.window = win
        }
        
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        if AppState.shared.store.settings.enableMenuBar {
            // Dès qu'on ferme la fenêtre avec Menu Bar activée : reste discret dans la barre des menus
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.accessory)
            }
        } else {
            // Si la Menu Bar est désactivée : fermer la fenêtre quitte totalement l'application !
            AppState.shared.stop()
            NSApp.terminate(nil)
        }
    }
    
    func setupStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "SwitchRPC")
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = AppState.shared
        
        // Statut actuel
        if let current = state.currentGame, let app = state.store.getApp(for: current.appId) {
            let activeItem = NSMenuItem(title: "🟢 \(app.name) : \(current.name)", action: nil, keyEquivalent: "")
            activeItem.isEnabled = false
            menu.addItem(activeItem)
            
            let stopItem = NSMenuItem(title: L10n.tr("Stop Discord Presence", "Arrêter la présence Discord"), action: #selector(menuStopActivity), keyEquivalent: "s")
            stopItem.target = self
            menu.addItem(stopItem)
        } else {
            let idleItem = NSMenuItem(title: L10n.tr("⚪ Idle (No game active)", "⚪ Inactif (Aucun jeu lancé)"), action: nil, keyEquivalent: "")
            idleItem.isEnabled = false
            menu.addItem(idleItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Sous-menu Lancer un jeu
        let gamesMenu = NSMenu()
        for game in state.store.games {
            let isCurrent = state.currentGame?.id == game.id
            let title = (isCurrent ? "✓ " : "") + game.name
            let item = NSMenuItem(title: title, action: #selector(menuSelectGame(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = game
            gamesMenu.addItem(item)
        }
        
        let playSubmenuItem = NSMenuItem(title: L10n.tr("Switch Game...", "Changer de jeu..."), action: nil, keyEquivalent: "")
        playSubmenuItem.submenu = gamesMenu
        menu.addItem(playSubmenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let showWindowItem = NSMenuItem(title: L10n.tr("Open Switch Window", "Ouvrir la fenêtre Switch"), action: #selector(menuShowWindow), keyEquivalent: "o")
        showWindowItem.target = self
        menu.addItem(showWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: L10n.tr("Quit SwitchRPC", "Quitter SwitchRPC"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }
    
    @objc func menuStopActivity() {
        AppState.shared.stop()
    }
    
    @objc func menuSelectGame(_ sender: NSMenuItem) {
        if let game = sender.representedObject as? SavedGame {
            AppState.shared.selectGame(game)
        }
    }
    
    @objc func menuShowWindow() {
        createAndShowWindow()
    }
    
    func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // Menu Application
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L10n.tr("Quit SwitchRPC", "Quitter SwitchRPC"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        
        // Menu Fichier (avec Commande + W pour fermer la fenêtre)
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: L10n.tr("File", "Fichier"))
        let closeItem = NSMenuItem(title: L10n.tr("Close Window", "Fermer la fenêtre"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(closeItem)
        fileMenuItem.submenu = fileMenu
        
        // Menu Édition (Cmd+X, Cmd+C, Cmd+V, Cmd+A)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: L10n.tr("Edit", "Édition"))
        editMenu.addItem(withTitle: L10n.tr("Cut", "Couper"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.tr("Copy", "Copier"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.tr("Paste", "Coller"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.tr("Select All", "Tout sélectionner"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        
        NSApp.mainMenu = mainMenu
    }
    
    // Déclenché quand on relance l'app depuis le Finder, Spotlight, Alfred ou le Dock
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        createAndShowWindow()
        return true
    }
    
    func application(_ application: NSApplication, openFiles filenames: [String]) {
        createAndShowWindow()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        DiscordIPC.shared.disconnect()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Reste actif en Menu Bar même si la fenêtre principale est fermée !
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
