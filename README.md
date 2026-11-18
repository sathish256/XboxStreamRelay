# XboxStreamRelay

A native macOS application that relays your Xbox One / Series X|S RTMP broadcast stream — either directly to YouTube Live or to a local OBS Studio instance for recording or processing.

Built with **Swift + SwiftUI**, targeting **macOS 13.0+** (Apple Silicon and Intel).

---

## ✨ Features

| Feature | Detail |
|---|---|
| **Direct to YouTube Mode** | Xbox → Mac (mediamtx) → YouTube via ffmpeg, fully automated |
| **OBS Local Relay Mode** | Xbox → Mac (mediamtx) → OBS Studio Media Source |
| **Keychain-secured stream key** | YouTube Stream Key stored in macOS Keychain — never on disk |
| **Auto sleep prevention** | IOKit assertion prevents idle sleep while relay is active |
| **DNS Setup Guide** | Built-in step-by-step Xbox DNS redirect walkthrough |
| **Dynamic IP detection** | Detects your Mac's local IPv4 at runtime; no hardcoded addresses |
| **Redacted console log** | Stream key is never printed or logged anywhere |
| **Clean process management** | mediamtx is properly terminated on stop and app quit |

---

## Prerequisites

Install dependencies via [Homebrew](https://brew.sh):

```bash
brew install mediamtx ffmpeg dnsmasq
```

| Tool | Purpose | Required |
|---|---|---|
| `mediamtx` | RTMP relay server | **Yes** |
| `ffmpeg` | Re-stream to YouTube (Direct mode) | Yes (Direct mode) |
| `dnsmasq` | DNS redirect so Xbox connects to this Mac | Optional (manual alternative possible) |

> XboxStreamRelay automatically detects both Apple Silicon (`/opt/homebrew/bin`) and Intel (`/usr/local/bin`) Homebrew paths.

---

## Building in Xcode

1. Clone this repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/XboxStreamRelay.git
   cd XboxStreamRelay
   ```

2. Open the project:
   ```bash
   open XboxStreamRelay.xcodeproj
   ```

3. In Xcode, select your **Team** under *Signing & Capabilities* → your Apple ID or personal team is sufficient for local development.

4. Set the destination to **My Mac** and press **⌘R** to run.

> No hardcoded Team IDs or personal identifiers exist in the project. `DEVELOPMENT_TEAM = ""` is intentional — Xcode will prompt you to set your own.

---

## Xbox DNS Setup (Step-by-Step)

The app includes a built-in **Xbox DNS Setup Guide** (click the `?` button), but here's the quick summary:

### 1 — Configure dnsmasq

Add to `/opt/homebrew/etc/dnsmasq.conf` (Apple Silicon) or `/usr/local/etc/dnsmasq.conf` (Intel):

```
address=/live.twitch.tv/<YOUR_MAC_LOCAL_IP>
address=/ingest.global-contribute.live-video.net/<YOUR_MAC_LOCAL_IP>
```

Your local IP is shown in the app header with a one-click copy button.

Restart dnsmasq:
```bash
sudo brew services restart dnsmasq
```

### 2 — Enable Sharing on Mac

Open **System Settings → General → Sharing → Internet Sharing** and share your internet connection. This Mac's IP becomes the DNS resolver.

### 3 — Set Xbox DNS

**Settings → General → Network Settings → Advanced Settings → DNS Settings → Manual**

Set **Primary DNS** to your Mac's local IP (shown and copyable in the app).

### 4 — Stream

1. Open XboxStreamRelay and press **Start Relay**
2. On your Xbox, start broadcasting to **Twitch** (the DNS redirect intercepts it)
3. In **Direct to YouTube** mode: your stream is re-broadcast live to YouTube
4. In **OBS Local** mode: connect OBS with *Media Source* → `rtmp://localhost:1935/live`

---

## Security Notes

- **YouTube Stream Key** is stored exclusively in the **macOS Keychain** via the Security framework. It is never written to `UserDefaults`, `AppStorage`, disk files, or logs.
- `mediamtx` configuration files are generated dynamically in `FileManager.default.temporaryDirectory` with a unique UUID filename and **deleted automatically** when the relay stops or the app quits.
- The console log **redacts** any occurrence of the stream key with `••••••••••••`, including in mediamtx subprocess output piped through the app.
- No IP addresses, MAC addresses, Apple Developer Team IDs, or personal identifiers are hardcoded anywhere in this repository.
- `DEVELOPMENT_TEAM` is left blank in the project file — you set your own during Xcode signing.

---

## Project Structure

```
XboxStreamRelay/
├── XboxStreamRelay.xcodeproj/
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/XboxStreamRelay.xcscheme
├── XboxStreamRelay/
│   ├── Sources/
│   │   ├── XboxStreamRelayApp.swift      # @main entry point + AppDelegate
│   │   ├── ContentView.swift             # Main SwiftUI window (500×640)
│   │   ├── StreamManager.swift           # Process, IOKit sleep, relay lifecycle
│   │   ├── KeychainHelper.swift          # Keychain CRUD for stream key
│   │   ├── NetworkHelper.swift           # Local IPv4 detection + dnsmasq rules
│   │   ├── DependencyChecker.swift       # Homebrew binary detection
│   │   ├── StatusHeaderView.swift        # Status indicator + IP display
│   │   ├── DependencyStatusView.swift    # Dependency check UI
│   │   ├── ConsoleLogView.swift          # Auto-scrolling redacted log
│   │   └── DNSGuideSheet.swift           # Built-in Xbox DNS walkthrough sheet
│   └── Resources/
│       ├── Info.plist
│       └── XboxStreamRelay.entitlements
├── .gitignore
├── LICENSE
└── README.md
```

---

## Architecture

```
Xbox (Twitch broadcast)
        │
        │  RTMP (intercepted via dnsmasq DNS redirect)
        ▼
┌─────────────────────────────────┐
│          This Mac               │
│                                 │
│  mediamtx (RTMP server :1935)  │
│        │                        │
│        ├─ Direct YouTube mode ──► ffmpeg ──► rtmp://a.rtmp.youtube.com/live2/<KEY>
│        │                        │
│        └─ OBS Local mode ───────► OBS Studio (Media Source rtmp://localhost:1935/live)
└─────────────────────────────────┘
```

---

## Contributing

Pull requests welcome. Please ensure:
- No secrets, Team IDs, or personal identifiers are introduced
- All stream key handling continues to go through `KeychainHelper`
- Temp config files remain ephemeral (UUID-named, in `temporaryDirectory`, auto-deleted)

---

## License

[MIT](LICENSE) — Copyright © [Year] [Your Name]

