# SwitchRPC 🎮✨

> A native macOS Discord Rich Presence manager inspired by the Nintendo Switch home menu.

![macOS](https://img.shields.io/badge/macOS-12.0+-blue?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?style=flat-square&logo=swift)
![Release](https://img.shields.io/github/v/release/Jellacious/SwitchRPC?style=flat-square)

---

## 🌟 Features

- **Nintendo Switch UI**: Horizontal tile carousel with live preview, cover artwork, and status badges.
- **Discord Rich Presence (IPC)**: Native Unix socket connection directly with Discord (no browser or heavy NodeJS dependencies required).
- **Multiple Discord Apps**: Switch between custom titles (Nintendo Switch, Plex, Steam, etc.) or add your own Client IDs.
- **Menu Bar Companion**: Minimalist system tray status item with quick actions (`Play`, `Stop`, `Quit`) and background mode.
- **Bilingual Support**: English & French interface with on-the-fly language switching.
- **Automatic GitHub Update Checker**: Check for newer releases directly inside the app settings.

---

## 📥 Installation

1. Download the latest `.dmg` from the **[Releases](https://github.com/Jellacious/SwitchRPC/releases)** page.
2. Open `SwitchRPC-1.0.0.dmg`.
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
swiftc -O main.swift -o SwitchRPC

# (Optional) Build standalone .dmg
./build-dmg.sh
```

---

## 👤 Author

- **Jellacious** ([@Jellacious](https://github.com/Jellacious))
