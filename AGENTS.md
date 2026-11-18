# AGENTS.md — Agent Operations & Debugging Guide

Welcome, Agent! This document is designed for AI coding agents and automated systems to quickly understand, build, debug, inspect, and test `XboxStreamRelay`.

---

## 1. Project Overview & Topology

**XboxStreamRelay** is a native macOS application (SwiftUI / AppKit, macOS 13.0+) targeting Apple Silicon & Intel. It relays an Xbox One / Series X|S Twitch broadcast locally via RTMP and forwards it to YouTube Live or a local OBS instance.

```
┌──────────────┐         DNS spoof (dnsmasq)           ┌──────────────────────────────────────────┐
│              │ ───────────────────────────────────► │ macOS Host (XboxStreamRelay)             │
│  Xbox Console│      live.twitch.tv -> <Host IP>      │                                          │
│  Broadcast   │ ───────────────────────────────────► │ 1. RTMP Server: mediamtx (:1935)         │
│              │      RTMP publish stream             │    ├─ Mode A (Direct YouTube):            │
└──────────────┘                                      │    │   ffmpeg -> rtmp://a.rtmp.youtube.com│
                                                      │    └─ Mode B (Local OBS):                 │
                                                      │        Exposes rtmp://localhost:1935/live │
                                                      └──────────────────────────────────────────┘
```

---

## 2. Directory & Source Layout

```
StreamMyGame/
├── AGENTS.md                                         # This guide
├── README.md                                         # User documentation
├── LICENSE                                           # MIT License
├── .gitignore                                        # Ignores temp configs, secrets, derived data
├── XboxStreamRelay.xcodeproj/
│   ├── project.pbxproj                               # DEVELOPMENT_TEAM = "" (clean team ID)
│   └── xcshareddata/xcschemes/XboxStreamRelay.xcscheme
└── XboxStreamRelay/
    ├── Resources/
    │   ├── Info.plist                                # Permissions & macOS bundle config
    │   └── XboxStreamRelay.entitlements              # Network permissions & Keychain access
    └── Sources/
        ├── XboxStreamRelayApp.swift                  # @main entry & AppDelegate lifecycle cleanup
        ├── ContentView.swift                         # Main UI window (500x640), mode & secret binding
        ├── StatusHeaderView.swift                    # Live indicator badge, sleep badge, IP display
        ├── DependencyStatusView.swift                # Status indicators for mediamtx, ffmpeg, dnsmasq
        ├── ConsoleLogView.swift                      # Terminal log viewer with auto-scroll & redaction
        ├── DNSGuideSheet.swift                       # Modal sheet with step-by-step Xbox instructions
        ├── StreamManager.swift                       # Process lifecycle, IOKit power mgmt, YAML generation
        ├── KeychainHelper.swift                      # macOS Security framework Keychain CRUD
        ├── NetworkHelper.swift                       # getifaddrs() IPv4 active interface detector
        └── DependencyChecker.swift                   # Dynamic binary locator (/opt/homebrew & /usr/local)
```

---

## 3. Strict Security Rules (Do Not Violate)

1. **Zero Plaintext Secrets**:
   - YouTube Stream Key is stored **exclusively** in the macOS Keychain (`kSecClassGenericPassword`, service: `com.xboxstreamrelay.app`, account: `youtube_stream_key`).
   - Never store keys in `@AppStorage`, `UserDefaults`, plist files, or git.
2. **Log Redaction**:
   - Any log message passing through `StreamManager.appendLog()` is scrubbed using `sanitized.replacingOccurrences(of: key, with: "••••••••••••")`.
3. **No Hardcoded Network/Personal Identifiers**:
   - No hardcoded MAC addresses, local IPs, or Apple Developer Team IDs (`DEVELOPMENT_TEAM = ""` in pbxproj).
4. **Ephemeral Config Files**:
   - `mediamtx` configs are written to `FileManager.default.temporaryDirectory` with a unique UUID (`mediamtx_<UUID>.yml`) and deleted immediately on relay stop or app termination (`applicationWillTerminate`).

---

## 4. Build & Compilation Verification

### Standard Swiftc Type-Check (Fast sanity test)
```bash
swiftc \
  -sdk $(xcrun --show-sdk-path --sdk macosx) \
  -target arm64-apple-macosx13.0 \
  -parse-as-library \
  XboxStreamRelay/Sources/*.swift \
  -framework SwiftUI -framework Foundation -framework Security -framework IOKit -framework AppKit \
  -typecheck
```

### Full Xcodebuild Verification
```bash
xcodebuild \
  -project XboxStreamRelay.xcodeproj \
  -scheme XboxStreamRelay \
  -destination 'platform=macOS,arch=arm64' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

---

## 5. Testing & Debugging Procedures

### A. Testing Binary Discovery
Binaries installed via Homebrew live at:
- Apple Silicon: `/opt/homebrew/bin/mediamtx`, `/opt/homebrew/bin/ffmpeg`, `/opt/homebrew/sbin/dnsmasq`
- Intel: `/usr/local/bin/mediamtx`, `/usr/local/bin/ffmpeg`, `/usr/local/sbin/dnsmasq`

Run:
```bash
which mediamtx ffmpeg dnsmasq
```
Verify `DependencyChecker.shared.checkDependencies()` resolves all 3 paths.

### B. Validating MediaMTX Configuration
To verify the YAML configuration syntax expected by `mediamtx` (version 1.21.x+):
- **Local OBS Mode**:
  ```yaml
  api: no
  metrics: no
  rtsp: no
  hls: no
  webrtc: no
  srt: no
  rtmp: yes
  rtmpAddress: :1935
  paths:
    all:
  ```
- **Direct YouTube Mode**:
  ```yaml
  api: no
  metrics: no
  rtsp: no
  hls: no
  webrtc: no
  srt: no
  rtmp: yes
  rtmpAddress: :1935
  paths:
    all:
      runOnAvailable: /opt/homebrew/bin/ffmpeg -i rtmp://localhost:1935/$MTX_PATH -c copy -f flv rtmp://a.rtmp.youtube.com/live2/<STREAM_KEY>
      runOnAvailableRestart: yes
  ```
*(Note: `runOnAvailable` replaces the deprecated `runOnReady` in newer MediaMTX releases).*

### C. End-to-End Simulation (Simulating Xbox Streaming)
You can simulate the Xbox without a physical console using `ffmpeg`:

1. Start `mediamtx` manually or start the relay inside `XboxStreamRelay.app` (OBS Local mode).
2. Publish a synthetic test stream to simulate Xbox Twitch broadcast:
   ```bash
   ffmpeg -re -f lavfi -i testsrc=size=1280x720:rate=30 -f lavfi -i sine=frequency=1000:sample_rate=44100 \
     -c:v libx264 -pix_fmt yuv420p -c:a aac -f flv rtmp://localhost:1935/app/xbox_feed
   ```
3. Test receiving the stream:
   - In OBS Studio: Add **Media Source**, uncheck "Local File", set input to `rtmp://localhost:1935/app/xbox_feed` (or `rtmp://localhost:1935/live`).
   - Or test ingest playback via ffplay / mpv:
     ```bash
     ffplay rtmp://localhost:1935/app/xbox_feed
     ```
4. Confirm UI transitions:
   - When stream publishes, status badge transitions to `Live → Local OBS Relay` or `Live → YouTube Live`.
   - When stream stops, status returns to `Listening on :1935`.

### D. Testing Sleep Prevention
Verify IOKit power assertion during active relay:
```bash
pmset -g assertions | grep "NoIdleSleepAssertion"
```
Look for:
`NoIdleSleepAssertion ... named: "XboxStreamRelay is actively streaming game capture"`

### E. Checking for Orphan Processes or Leaked Configs
After clicking **Stop Relay** or quitting the app:
```bash
# 1. Ensure no mediamtx process is lingering
pgrep -fl mediamtx

# 2. Check no temp config was left in $TMPDIR
ls -la $TMPDIR/mediamtx_*.yml 2>/dev/null
```
Both commands should return zero matches.

---

## 6. Common Pitfalls & Solutions

- **Port 1935 in use**: If another process or previous zombie `mediamtx` is using port 1935, run `lsof -i :1935` and kill it.
- **`dnsmasq` port 53 conflict**: macOS runs mDNSResponder on port 53. If running dnsmasq, run it with `sudo brew services start dnsmasq` with proper listen directives or bound to your specific local interface IP.
- **Keychain Access Prompt**: In development builds without production code signing, macOS may display a system dialog requesting Keychain access. This is expected behavior for unsigned developer debug builds.

