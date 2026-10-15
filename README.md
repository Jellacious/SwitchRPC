# SwitchRPC 🎮

> A native macOS Discord Rich Presence manager.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square&logo=swift)
![Release](https://img.shields.io/github/v/release/Jellacious/SwitchRPC?style=flat-square)

---

## 🌟 Features

- **Discord Rich Presence**: Native Unix socket connection directly with Discord.
- **Multiple Discord Apps**: Switch between custom titles or add your own Client IDs.
- **Menu Bar Companion**: Minimalist system tray status item with quick actions (`Play`, `Stop`, `Quit`) and background mode.
- **Auto-start on Login**: Option to start automatically when logging in.

---

## 📥 Installation

1. Download the latest `.dmg` from the **[Releases](https://github.com/Jellacious/SwitchRPC/releases)** page.
2. Open `SwitchRPC-X.X.X.dmg`.
3. Drag & drop **SwitchRPC.app** into your `/Applications` folder.
4. Launch **SwitchRPC** from your Applications or Spotlight.

---

## 🛠️ Building from source

Requirements:
- macOS with Xcode Command Line Tools installed (`xcode-select --install`)

```bash
# Clone the repository
git clone https://github.com/Jellacious/SwitchRPC.git
cd SwitchRPC

# Compile binary
swiftc -O Sources/Models/*.swift Sources/Services/*.swift Sources/Views/*.swift Sources/main.swift -o SwitchRPC

# Or build the DMG installer
./build-dmg.sh

# Run application
./SwitchRPC
```

---

Developed with ❤️ by [Jellacious](https://github.com/jellacious).
Note : AI was used in this project.
