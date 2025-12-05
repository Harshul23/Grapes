# Grapes 🍇

A lightweight macOS menu bar application that monitors your battery level and provides visual alerts when battery charge reaches customizable thresholds.

## Overview

Grapes is a battery observer app designed for macOS that runs quietly in the menu bar and alerts you when your battery level is too low (needs charging) or too high (should be unplugged). The app features beautiful sliding overlay animations with customizable threshold settings to help you maintain optimal battery health.

## Features

- **Menu Bar Integration**: Runs as a lightweight menu bar app with battery icon indicator
- **Customizable Thresholds**: Set your own low and high battery percentage alerts
  - Default low threshold: 20%
  - Default high threshold: 80%
- **Visual Alerts**: Beautiful full-screen sliding overlay animations that show:
  - Current battery percentage
  - Color-coded indicators (red for low, green for high)
  - Action prompts ("Plug in!" or "Enough!")
- **Smart Notifications**: 
  - Monitors battery every 20 seconds
  - Alerts only once per threshold crossing
  - Auto-dismisses after 3 seconds or click to dismiss instantly
- **Toggle Alerts**: Easily enable or disable alerts from the menu bar
- **Auto-start at Login**: Automatically starts with macOS (macOS Ventura 13.0+)
- **Blur Effect**: Elegant blurred background overlay with smooth animations

## Requirements

- macOS 13.0 (Ventura) or later recommended (for auto-start functionality; earlier versions work but without auto-start)
- Xcode or Swift command-line tools (for building from source)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/Harshul23/Grapes.git
   cd Grapes/battery_observer
   ```

2. **Option A - Build with Swift Compiler (Command Line)**:
   ```bash
   swiftc -o Grapes main.swift AppDelegate.swift -framework Cocoa -framework IOKit -framework QuartzCore -framework ServiceManagement
   ./Grapes
   ```

3. **Option B - Create and Build with Xcode**:
   - Open Xcode and create a new macOS App project
   - Replace the default files with `main.swift` and `AppDelegate.swift` from the `battery_observer` directory
   - Copy the `Assets.xcassets` folder into your Xcode project
   - Build and run (⌘ + R)

4. The app will appear in your menu bar with a battery icon once running

## Usage

### Starting the App

Once launched, Grapes runs in the background and appears as a battery icon in your macOS menu bar.

### Menu Bar Options

Click the battery icon in the menu bar to access:

- **Preferences…**: Open settings to customize battery thresholds
- **Enable/Disable Alerts**: Toggle battery alerts on or off
- **Quit**: Exit the application

### Setting Battery Thresholds

1. Click the battery icon in the menu bar
2. Select "Preferences…" (or press `⌘ + ,`)
3. Adjust the sliders:
   - **High Battery Threshold**: Set between 50% - 100% (when to alert for unplugging)
   - **Low Battery Threshold**: Set between 5% - 50% (when to alert for charging)
4. Values are automatically saved and take effect immediately

### Understanding Alerts

#### Low Battery Alert (Red)
- Triggers when battery drops to or below your low threshold
- Shows red sliding bar animation
- Displays current percentage and "Plug in!" message
- Suggests you should charge your device

#### High Battery Alert (Green)
- Triggers when battery reaches or exceeds your high threshold
- Shows green sliding bar animation
- Displays current percentage and "Enough!" message
- Suggests you should unplug your device

### Dismissing Alerts

Alerts automatically dismiss after 3 seconds, or you can:
- Click anywhere on the overlay to dismiss immediately

## Technical Details

### Architecture

The app is built with native macOS technologies:

- **Cocoa Framework**: For macOS app development
- **IOKit**: For battery status monitoring via `IOPSCopyPowerSourcesInfo()`
- **QuartzCore**: For smooth animations
- **ServiceManagement**: For auto-start at login functionality

### Components

#### `main.swift`
Entry point that initializes the NSApplication and sets up the AppDelegate.

#### `AppDelegate.swift`
Main application logic including:
- Menu bar setup and management
- Battery monitoring timer (checks every 20 seconds)
- Alert threshold management with UserDefaults persistence
- Sliding overlay UI with blur effects
- Preferences window with real-time slider updates

### Battery Monitoring

The app uses IOKit to access battery information:
- Reads current capacity and maximum capacity
- Calculates percentage level
- Compares against user-defined thresholds
- Triggers alerts only on threshold crossings (not continuously)

### Data Persistence

User preferences are stored using `UserDefaults`:
- `lowThreshold`: Low battery alert percentage (default: 20)
- `highThreshold`: High battery alert percentage (default: 80)

## Battery Health Tips

Optimal battery health is often maintained by:
- Keeping charge between 20% and 80% when possible
- Avoiding full discharge cycles
- Not leaving devices plugged in at 100% for extended periods

Grapes helps you maintain these practices with customizable alerts!

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests

## License

Please check the repository for license information.

## Author

Created by [Harshul23](https://github.com/Harshul23)

---

**Note**: This app requires appropriate permissions to monitor battery status. macOS may prompt you to grant necessary permissions on first launch.
