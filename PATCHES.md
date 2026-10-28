# 7-Zip iOS Patches (`PATCHES.md`)

This document lists all minimal modifications made to the original 7-Zip codebase (located in `third_party/7zip/`) to enable secure in-process execution on iOS and macOS, support real-time UI callbacks, prevent unwanted terminations, and handle password/overwrite queries non-interactively.

---

### 1. `third_party/7zip/CPP/7zip/UI/Console/ConsoleClose.cpp`
* **Purpose**: Prevent process termination and avoid modifying OS signal handlers on iOS.
* **Changes**:
  * Commented out `exit(EXIT_FAILURE)` in `HandlerRoutine` when user break threshold is reached.
  * Guarded `CCtrlHandlerSetter` so that on Apple platforms (`__APPLE__`), default system signal handlers are preserved and not replaced.

### 2. `third_party/7zip/CPP/7zip/UI/Console/PercentPrinter.h` & `PercentPrinter.cpp`
* **Purpose**: Bridge 7-Zip progress reporting to SwiftUI / Objective-C / C callbacks.
* **Changes**:
  * Added global callback hook `g_sz_progress_callback(UInt64 completed, UInt64 total, UInt64 files, const wchar_t* fileName)`.
  * Triggered the callback in `CPercentPrinter::Print()` whenever progress updates occur.

### 3. `third_party/7zip/CPP/7zip/UI/Console/UserInputUtils.h` & `UserInputUtils.cpp`
* **Purpose**: Avoid blocking on `stdin` for password and overwrite prompts on iOS.
* **Changes**:
  * Added `g_sz_get_password_callback` and `g_sz_confirm_overwrite_callback`.
  * In `GetPassword_HRESULT`, if `g_sz_get_password_callback` is registered, request password via callback instead of reading from `g_StdIn`.
  * In `ScanUserYesNoAllQuit`, if `g_sz_confirm_overwrite_callback` is registered, query the callback instead of waiting on terminal input.

### 4. `third_party/7zip/CPP/7zip/UI/Console/ExtractCallbackConsole.cpp`
* **Purpose**: Pass existing and new filenames to overwrite confirmation callback.
* **Changes**:
  * In `CExtractCallbackConsole::AskOverwrite`, if `g_sz_confirm_overwrite_callback` is set, pass `existName` and `newName` to the callback before falling back to default answers.

### 5. `third_party/7zip/C/LzFindMt.c`
* **Purpose**: Prevent calls to `exit(1)` in multithreaded match finder lock checks.
* **Changes**:
  * In the debug macro block `BUFFER_MUST_BE_LOCKED` / `BUFFER_MUST_BE_UNLOCKED`, replaced `exit(1)` with a safe no-op.
