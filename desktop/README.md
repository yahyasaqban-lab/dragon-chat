# 🐉 Dragon Chat Desktop

Secure communication platform built on Matrix protocol with LiveKit for voice/video.

## Features

- ✅ End-to-end encrypted messaging
- ✅ Voice & video calls (LiveKit)
- ✅ Screen sharing
- ✅ Room management
- ✅ Direct messages
- ✅ Voice channels
- ✅ File sharing
- ✅ System tray integration
- ✅ Cross-platform (Mac, Windows, Linux)
- ✅ Auto-updates

## Quick Start

### Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Run with DevTools
npm start
```

### Build

```bash
# Build for current platform
npm run build

# Build for macOS
npm run build:mac

# Build for Windows
npm run build:win

# Build for Linux
npm run build:linux

# Build for all platforms
npm run build:all
```

### Output

Built apps will be in `dist/` folder:

- **macOS**: `Dragon Chat-1.0.0.dmg`, `Dragon Chat-1.0.0-mac.zip`
- **Windows**: `Dragon Chat Setup 1.0.0.exe`, `Dragon Chat 1.0.0.exe` (portable)
- **Linux**: `Dragon Chat-1.0.0.AppImage`, `.deb`, `.rpm`

## Configuration

Edit `src/renderer.js` to change default servers:

```javascript
const homeserver = 'https://matrix.y7xyz.com';
const livekitUrl = 'wss://livekit.y7xyz.com';
```

## Project Structure

```
dragon-chat-desktop/
├── src/
│   ├── main.js         # Electron main process
│   ├── preload.js      # Preload script (IPC)
│   ├── renderer.js     # UI logic, Matrix SDK
│   ├── index.html      # Main UI
│   └── styles.css      # Styles
├── assets/
│   ├── icon.png        # App icon (512x512)
│   └── tray-icon.png   # Tray icon (32x32)
├── build/
│   ├── icon.icns       # macOS icon
│   ├── icon.ico        # Windows icon
│   └── entitlements.mac.plist
└── package.json
```

## Icons

You need to create these icon files:

- `assets/icon.png` (512x512 PNG)
- `assets/tray-icon.png` (32x32 PNG)
- `build/icon.icns` (macOS, convert from PNG)
- `build/icon.ico` (Windows, convert from PNG)

### Convert Icons

```bash
# macOS - create .icns from PNG
mkdir icon.iconset
sips -z 16 16     icon.png --out icon.iconset/icon_16x16.png
sips -z 32 32     icon.png --out icon.iconset/icon_16x16@2x.png
sips -z 32 32     icon.png --out icon.iconset/icon_32x32.png
sips -z 64 64     icon.png --out icon.iconset/icon_32x32@2x.png
sips -z 128 128   icon.png --out icon.iconset/icon_128x128.png
sips -z 256 256   icon.png --out icon.iconset/icon_128x128@2x.png
sips -z 256 256   icon.png --out icon.iconset/icon_256x256.png
sips -z 512 512   icon.png --out icon.iconset/icon_256x256@2x.png
sips -z 512 512   icon.png --out icon.iconset/icon_512x512.png
sips -z 1024 1024 icon.png --out icon.iconset/icon_512x512@2x.png
iconutil -c icns icon.iconset -o icon.icns

# Windows - use ImageMagick or online converter
convert icon.png -define icon:auto-resize=256,128,64,48,32,16 icon.ico
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd/Ctrl + N | Create room |
| Cmd/Ctrl + J | Join room |
| Cmd/Ctrl + Shift + V | Start voice call |
| Cmd/Ctrl + Shift + C | Start video call |
| Cmd/Ctrl + , | Settings |
| Cmd/Ctrl + Q | Quit |

## Code Signing (Production)

### macOS
```bash
# Sign for distribution
electron-builder --mac --config.mac.identity="Developer ID Application: Your Name"

# Notarize
xcrun notarytool submit "dist/Dragon Chat-1.0.0.dmg" --apple-id "your@email.com" --password "app-specific-password" --team-id "TEAM_ID"
```

### Windows
```bash
# Sign with certificate
electron-builder --win --config.win.certificateFile="cert.pfx" --config.win.certificatePassword="password"
```

## Auto Updates

1. Create GitHub releases with built files
2. App will auto-check for updates on startup
3. Users get notification when update is available

## Dependencies

- **electron**: Desktop framework
- **matrix-js-sdk**: Matrix protocol
- **livekit-client**: Voice/video calls
- **electron-store**: Settings persistence
- **electron-updater**: Auto-updates

## License

MIT

---

Created by Dragon 🐉 for Yahya
