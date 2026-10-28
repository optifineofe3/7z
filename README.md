# 7-Zip for iOS (LiveContainer & Sideload)

An authentic, high-performance port of the official **7-Zip** engine for iOS (iOS 15.0+, arm64), featuring a native SwiftUI interface designed around an ultra-clean **Black Minimalist** aesthetic.

Built specifically for sideloading without jailbreak (via **LiveContainer**, **AltStore**, **SideStore**, or **TrollStore**) and without requiring a paid Apple Developer Account.

---

## ✨ Features & Desktop Parity

### 📦 1. Add to Archive ("Создание архива")
Full desktop parity with the classic 7-Zip dialog:
* **Formats**: `7z`, `zip`, `tar`, `gzip`, `bzip2`, `xz`, `wim`.
* **Compression Levels**: Store (0), Fastest (1), Fast (3), Normal (5), Maximum (7), Ultra (9).
* **Methods**: LZMA2, LZMA, PPMd, BZip2, Deflate, Deflate64, Copy.
* **Granular Options**:
  * Dictionary size: 64 KB up to 1536 MB (1.5 GB).
  * Word size: 32, 64, 128, 273.
  * Solid block size: Non-solid, 64 MB ... 4 GB, Solid.
  * CPU Thread count: 1 up to device active processor cores.
* **Jetsam Memory Guard**:
  * Real-time calculation of compression and decompression memory requirements.
  * Reads safe budget via `os_proc_available_memory()`.
  * Warns if selected dictionary/threads exceed available memory with a one-tap **Auto-reduce** button.
* **Volume Splitting**: Custom size or presets (10M, 100M, 650M CD, 700M CD, 1000M 1GB, 4092M FAT32, 4480M DVD).
* **Update & Path Modes**: Add & replace, Update & add, Freshen, Synchronize; Relative, Full, and Absolute paths.
* **Security & Encryption**: AES-256 encryption, password confirmation, Show Password toggle, and Header / File Names encryption (`-mhe=on`).
* **Presets**: Built-in presets (*Fast*, *Normal*, *Maximum*, *Maximum + Encryption*) and custom presets.
* **Developer Mode**: View exact generated 7-Zip CLI command line string.

### 🔍 2. Archive Viewing & Extraction
* **Hierarchy Browser**: Navigate folders and files with search, sorting (Name, Size, Packed, Date), and multi-selection.
* **Archive Information**: Format, solid status, method, headers size, physical size, files/folders counts (`l -slt`).
* **Extraction Modes**: Extract all or selected items, preserve directory structure or flat extraction, overwrite policy (Ask, Overwrite, Skip, Auto-rename).
* **Multi-volume Support**: Open `.7z.001`, `.part1.rar`, etc. seamlessly.
* **Quick Look & Share**: Extract single files to temporary storage for instant preview (`QLPreviewController`) or sharing via standard iOS Share Sheet.

### ⚡ 3. Tools & Performance
* **Integrity Test (`t`)**: Test archive health without writing to disk.
* **Checksum & Hashes (`h`)**: Calculate CRC32, CRC64, SHA-1, SHA-256, SHA-512, BLAKE2sp, and XXH64 with one-tap copy to clipboard.
* **Hardware Benchmark (`b`)**: CPU compression and decompression benchmark measuring MIPS ratings.

### 📱 4. iOS Integration
* **File Sharing & In-Place Open**: `UIFileSharingEnabled = YES`, `LSSupportsOpeningDocumentsInPlace = YES`.
* **System Associations**: "Open in 7-Zip" from Files, Safari, Telegram, Mail, and AirDrop.
* **Background Tasks**: Long operations run in background via `UIApplication.beginBackgroundTask` with idle timer kept alive and local notifications on completion.
* **Task Manager**: Operation queue with real-time speed, ETA, progress percentage, cancel/retry, and full scrolling logs.

---

## 🎨 Design

Strict **Black Minimalism**:
* **Background**: Pure Black `#000000`
* **Cards & Groups**: Dark `#0B0B0B`–`#121212` with subtle borders (`#1F1F1F`)
* **Text**: Primary `#F2F2F2`, Secondary `#8E8E93`
* **Accent**: Crisp White `#FFFFFF` (Black text on white controls)
* **Destructive**: Red `#FF453A`
* Haptic feedback on key actions (`UIImpactFeedbackGenerator`).

---

## 🏗️ Repository Structure

```
├── .github/workflows/build.yml   # Automated CI: smoke test + iOS build + IPA release
├── App/                          # SwiftUI iOS Application
│   ├── 7ZipApp.swift             # App entrypoint
│   ├── Models/                   # Data models (ArchiveItem, CompressionSettings, Tasks, Settings)
│   ├── Services/                 # SevenZipBridge, TaskManager, BookmarkManager, MemoryBudget
│   ├── Theme/                    # Strict dark minimalist theme & haptics
│   └── Views/                    # UI views (Archives, Browser, Create, Extract, Tasks, Tools, Settings)
├── Core/                         # C/C++ In-Process 7-Zip Wrapper
│   ├── sz_wrapper.h              # C interface (sz_run, sz_cancel, callbacks, memory)
│   ├── sz_wrapper.cpp            # Wrapper implementation & exception handling
│   ├── 7ZipCore.xcconfig         # Build flags & compiler definitions
│   ├── 7Zip-Bridging-Header.h    # Swift bridging header
│   └── CMakeLists.txt            # CMake build for macOS host smoke testing
├── Resources/                    # Assets, Info.plist, Entitlements, Localizations (RU/EN)
├── Tests/                        # Smoke test (7z LZMA2 roundtrip, zip AES roundtrip)
├── third_party/7zip/             # Pristine official 7-Zip sources
├── PATCHES.md                    # Minimal patches documented
└── project.yml                   # XcodeGen project specification
```

---

## 🛠️ Building & CI

### Automated GitHub Actions Workflow
Every push and tag triggers `.github/workflows/build.yml`:
1. **Smoke Test**: Builds the core test binary on macOS host and verifies roundtrip archive creation and extraction for:
   * 7z (LZMA2, `-mx=7`, `-md=64m`, `-mhe=on`, password)
   * ZIP (AES-256, password)
2. **Project Generation**: Uses `xcodegen generate` to create `7Zip.xcodeproj`.
3. **Build**: Compiles the unsigned iOS app with `xcodebuild` targeting `generic/platform=iOS` (`arm64`).
4. **IPA Packaging**: Packages `Payload/7Zip.app`, embeds entitlements via `ldid -S`, and creates `7Zip.ipa`.
5. **Release**: Attaches `7Zip.ipa` as a release asset for tags (`v*`).

### Building Locally on macOS
```bash
# 1. Install prerequisites
brew install xcodegen ldid cmake ninja

# 2. Run host smoke test
cmake -B build_host -S Core -DCMAKE_BUILD_TYPE=Release
cmake --build build_host
./build_host/smoke_test

# 3. Generate Xcode project
xcodegen generate

# 4. Open in Xcode or build via CLI
open 7Zip.xcodeproj
```

---

## 📄 License
* Original 7-Zip source code: GNU LGPL v2.1+ by Igor Pavlov.
* unRAR code: Eugene Roshal (see unRAR license restrictions).
