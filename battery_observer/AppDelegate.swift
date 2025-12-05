import Cocoa
import IOKit.ps
import QuartzCore
import ServiceManagement

enum AlertKind {
    case low
    case high
}

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - State

    var statusItem: NSStatusItem!
    var alertsEnabled = true

    var timer: Timer?
    var lastAlert: AlertKind?
    var overlayWindow: NSWindow?

    // MARK: - State
        
        // ... (keep statusItem, alertsEnabled, etc.) ...

        // UI References for live updates
        var highValueLabel: NSTextField?
        var lowValueLabel: NSTextField?

        // Load from UserDefaults (or default to 20/80 if not set)
        var lowThreshold: Int {
            get {
                let val = UserDefaults.standard.integer(forKey: "lowThreshold")
                return val == 0 ? 20 : val // Default to 20 if 0 (not set)
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "lowThreshold")
            }
        }

        var highThreshold: Int {
            get {
                let val = UserDefaults.standard.integer(forKey: "highThreshold")
                return val == 0 ? 80 : val // Default to 80
            }
            set {
                UserDefaults.standard.set(newValue, forKey: "highThreshold")
            }
        }

    var preferencesWindow: NSWindow?

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Auto-start at login (Ventura+)
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        }

        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        startBatteryMonitor()
    }

    // MARK: - Menu bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: nil)
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        menu.addItem(
            withTitle: "Preferences…",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )

        menu.addItem(.separator())

        menu.addItem(
            withTitle: alertsEnabled ? "Disable Alerts" : "Enable Alerts",
            action: #selector(toggleAlerts),
            keyEquivalent: ""
        )

        menu.addItem(.separator())

        menu.addItem(
            withTitle: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        statusItem.menu = menu
    }

    @objc func toggleAlerts() {
        alertsEnabled.toggle()
        setupMenuBar()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Battery monitoring

    func startBatteryMonitor() {
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            self.checkBattery()
        }
    }

    func checkBattery() {
        guard alertsEnabled else { return }

        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
            let ps = list.first,
            let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
            let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
            let max = desc[kIOPSMaxCapacityKey as String] as? Int
        else { return }

        let level = Int(Double(current) / Double(max) * 100)

        // low alert
        if level <= lowThreshold && lastAlert != .low {
            showSlideOverlay(level: level, kind: .low)
            lastAlert = .low
        }

        // high alert
        if level >= highThreshold && lastAlert != .high {
            showSlideOverlay(level: level, kind: .high)
            lastAlert = .high
        }
    }

    // MARK: - Sliding overlay UI (safe version)

    func ensureOverlayWindow() -> (NSWindow, NSView)? {
        if overlayWindow == nil {
            guard let screen = NSScreen.main?.frame else { return nil }

            let window = NSWindow(
                contentRect: screen,
                styleMask: [.titled, .fullSizeContentView], // can become key safely
                backing: .buffered,
                defer: false
            )

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true

            window.isMovable = false
            window.isReleasedWhenClosed = false
            window.level = .statusBar + 100
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = false

            let contentView = NSView(frame: screen)
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentView = contentView

            overlayWindow = window
        }

        guard let window = overlayWindow,
              let contentView = window.contentView
        else { return nil }

        // Clear previous overlay views
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.alphaValue = 1

        return (window, contentView)
    }

    func showSlideOverlay(level: Int, kind: AlertKind) {
        guard let (window, contentView) = ensureOverlayWindow(),
              let screen = NSScreen.main?.frame
        else { return }

        window.makeKeyAndOrderFront(nil)

        let fullWidth = screen.width
        let fullHeight = screen.height
        
        // --- BLUR BACKGROUND (SAFE VERSION)
        let blurView = NSVisualEffectView(frame: contentView.bounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.material = .hudWindow    // cleaner / softer blur
       // or .hudWindow, .menu, .sidebar — adjust as you like
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        contentView.addSubview(blurView)

        // --- DARK DIMMER ON TOP OF BLUR
        let dimView = NSView(frame: contentView.bounds)
        dimView.autoresizingMask = [.width, .height]
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.20).cgColor
        contentView.addSubview(dimView)

       
        // Bar geometry: 90% height, centered vertically
        let barHeight = fullHeight * 0.9
        let barY = (fullHeight - barHeight) / 2

        let startFrame = NSRect(x: 0,
                                y: barY,
                                width: 0,
                                height: barHeight)

        let slideBar = NSView(frame: startFrame)
        slideBar.wantsLayer = true

        let isLow = (kind == .low)
        let barColor = (isLow ? NSColor.systemRed : NSColor.systemGreen)
            .withAlphaComponent(0.9)

        slideBar.layer?.backgroundColor = barColor.cgColor
        slideBar.layer?.cornerRadius = 40
        dimView.addSubview(slideBar)

        // Battery percentage text
        let percentLabel = NSTextField(labelWithString: "\(level)%")
        percentLabel.textColor = .white
        percentLabel.font = NSFont.systemFont(ofSize: 110, weight: .heavy)
        percentLabel.alignment = .center
        percentLabel.frame = NSRect(
            x: 0,
            y: barY + barHeight * 0.55,
            width: fullWidth,
            height: 120
        )
        dimView.addSubview(percentLabel)

        // Action text
        let actionText = isLow ? "Plug in!" : "Enough!"
        let actionLabel = NSTextField(labelWithString: actionText)
        actionLabel.textColor = .white
        actionLabel.font = NSFont.systemFont(ofSize: 80, weight: .bold)
        actionLabel.alignment = .center
        actionLabel.isSelectable = false
        actionLabel.isEditable = false
        actionLabel.isBezeled = false
        actionLabel.drawsBackground = false
        actionLabel.frame = NSRect(
            x: 0,
            y: barY + barHeight * 0.25,
            width: fullWidth,
            height: 100
        )

        // Click text to dismiss
        let click = NSClickGestureRecognizer(target: self,
                                             action: #selector(dismissOverlayInstantly(_:)))
        actionLabel.addGestureRecognizer(click)
        dimView.addSubview(actionLabel)

        // Slide animation
        let targetWidth = fullWidth * CGFloat(level) / 100

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)

            let targetFrame = NSRect(x: 0,
                                     y: barY,
                                     width: targetWidth,
                                     height: barHeight)

            slideBar.animator().frame = targetFrame
        }

        // Auto-dismiss after 3s
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.fadeOutOverlay()
        }
    }

    @objc func dismissOverlayInstantly(_ sender: Any?) {
        fadeOutOverlay()
    }

    func fadeOutOverlay() {
        guard let window = overlayWindow,
              let content = window.contentView
        else { return }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            content.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)       // hide
            content.alphaValue = 1     // reset for next time
        })
    }


    // MARK: - Preferences

        @objc func openPreferences() {
            if preferencesWindow == nil {
                createPreferencesWindow()
            }
            
            // Sync labels with current values every time we open
            highValueLabel?.stringValue = "\(highThreshold)%"
            lowValueLabel?.stringValue = "\(lowThreshold)%"
            
            preferencesWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        func createPreferencesWindow() {
            let screen = NSScreen.main?.visibleFrame ?? .zero
            let size = NSSize(width: 420, height: 260)

            let rect = NSRect(
                x: screen.midX - size.width / 2,
                y: screen.midY - size.height / 2,
                width: size.width,
                height: size.height
            )

            let window = NSWindow(
                contentRect: rect,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            window.title = "Preferences"
            window.isReleasedWhenClosed = false // Keep window in memory to prevent crash

            // Helper to create labels
            func makeLabel(text: String, frame: NSRect, isBold: Bool = false) -> NSTextField {
                let lbl = NSTextField(labelWithString: text)
                lbl.frame = frame
                if isBold { lbl.font = NSFont.boldSystemFont(ofSize: 13) }
                return lbl
            }

            let contentView = NSView(frame: NSRect(origin: .zero, size: size))
            window.contentView = contentView

            // --- High Threshold UI ---
            contentView.addSubview(makeLabel(text: "High Battery Threshold", frame: NSRect(x: 20, y: 170, width: 200, height: 24)))
            
            // Dynamic Label (e.g., "80%")
            let hValLabel = makeLabel(text: "\(highThreshold)%", frame: NSRect(x: 350, y: 170, width: 50, height: 24), isBold: true)
            hValLabel.alignment = .right
            contentView.addSubview(hValLabel)
            self.highValueLabel = hValLabel

            let highSlider = NSSlider(value: Double(highThreshold), minValue: 50, maxValue: 100, target: self, action: #selector(highSliderChanged(_:)))
            highSlider.frame = NSRect(x: 20, y: 145, width: 380, height: 24)
            contentView.addSubview(highSlider)

            // --- Low Threshold UI ---
            contentView.addSubview(makeLabel(text: "Low Battery Threshold", frame: NSRect(x: 20, y: 90, width: 200, height: 24)))

            // Dynamic Label (e.g., "20%")
            let lValLabel = makeLabel(text: "\(lowThreshold)%", frame: NSRect(x: 350, y: 90, width: 50, height: 24), isBold: true)
            lValLabel.alignment = .right
            contentView.addSubview(lValLabel)
            self.lowValueLabel = lValLabel

            let lowSlider = NSSlider(value: Double(lowThreshold), minValue: 5, maxValue: 50, target: self, action: #selector(lowSliderChanged(_:)))
            lowSlider.frame = NSRect(x: 20, y: 65, width: 380, height: 24)
            contentView.addSubview(lowSlider)

            preferencesWindow = window
            window.makeKeyAndOrderFront(nil)
        }

        @objc func highSliderChanged(_ sender: NSSlider) {
            let value = Int(sender.doubleValue)
            highThreshold = value // This triggers the 'set' to save to UserDefaults
            highValueLabel?.stringValue = "\(value)%"
        }

        @objc func lowSliderChanged(_ sender: NSSlider) {
            let value = Int(sender.doubleValue)
            lowThreshold = value // This triggers the 'set' to save to UserDefaults
            lowValueLabel?.stringValue = "\(value)%"
        }

}

