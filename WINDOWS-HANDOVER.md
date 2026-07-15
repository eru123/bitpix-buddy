# BitPix Buddy — Windows Host Handover

## Project Goal
Build a cross-platform desktop pixel-pet overlay:
- **Linux**: raw X11/xlib overlay, borderless, always-on-top, draggable, wheel-scalable, transparent background (pending Shape extension).
- **Windows**: native Odin + SDL2 overlay, same behavior, matching daemon/CLI API.

Default pet is a 12×16 RGBA pixel art blob with 4-frame idle animation.

---

## Repo
```
git clone git@github.com:eru123/bitpix-buddy.git
```
Clone into your Windows user profile, e.g. `C:\Users\<you>\bitpix-buddy`.

---

## What’s Already Done (Linux)
- `buddy-packs/default/` — 4-frame idle animation pack (`frame_1.png` … `frame_4.png`, `frames.bin`, `manifest.json`).
- `linux/main.odin` — X11 overlay renderer:
  - Loads frames at runtime from `frames.bin` (avoids Odin compile-time literal limits).
  - Fixed 24fps render loop for smooth dragging response.
  - Idle frame advance: **1fps** (`frame_tick >= 24`).
  - `override_redirect` borderless overlay, draggable, wheel-scalable with proportional bounds.
  - Reads daemon state from `/tmp/bitpix-state.json` (`action=idle|working|error`).
- `daemon/bitpixd.py` — user systemd service on Linux, Unix socket `/tmp/bitpixd.sock`.
- `daemon/bpctl.py` — CLI client (`idle|working|error|deploying|status`).
- `daemon/animator.py` — optional animation helper for future Action Editor integration.

---

## What You Must Do on Windows

### 1. Prereqs
- Install **Odin** dev nightly (use the same version family if possible).
- Install **SDL2** development libs/headers for Odin (`vendor:sdl2`).
- Git + Python 3 (for daemon tests).

### 2. Windows Daemon
Linux uses a systemd user service. On Windows, replace it with:
- A **Windows Service** wrapper around `bitpixd.py`, or
- A **startup tray app / background process** that runs `bitpixd.py`.

State file on Windows: replace `/tmp/bitpix-state.json` with a Windows-friendly path, e.g. `%LOCALAPPDATA%\BitPix\bitpix-state.json`. Update `daemon/bitpixd.py`, `bpctl.py`, and `animator.py` to use this path via an environment variable (`BITPIX_STATE_PATH`) so it stays cross-platform.

Socket: Unix domain sockets do not work on Windows. Change `bitpixd.py` to a **TCP localhost socket** (port `127.0.0.1:9867` by default). Update `bpctl.py` accordingly.

### 3. Update `windows/main.odin`
Current file is a SDL2 stub with colored rectangles. Integrate the real asset:
- Load the same 4-frame pack. Easiest path: **embed a runtime binary blob** like Linux (`frames.bin`), instead of trying to inline giant Odin arrays.
- Implement **sprite rendering** from `frames.bin` with transparent pixels drawn alpha-thresholded.
- Add **state-driven frame cycling**:
  - Idle: cycle all 4 frames at **1fps**.
  - Working: frame 2 only.
  - Error: frame 3 only.
- Keep **24fps render loop** for dragging responsiveness, but throttle frame advance separately.
- Implement **window dragging** (SDL2 `SDL_WINDOWEVENT` / mouse motion) and **wheel scaling** with proportional bounds and aspect-ratio lock.
- Keep **borderless + always-on-top** (`SDL_WINDOW_BORDERLESS | SDL_WINDOW_ALWAYS_ON_TOP`).
- If possible, make the window background transparent with SDL2 (`SDL_SetRenderDrawColor(0,0,0,0)` + alpha-blended texture). True shaped transparency on Windows is optional but nice.

### 4. Cross-Platform Refactor (Important)
Currently Linux and Windows entrypoints are separate files with duplicated logic. Before adding more states, extract shared Odin code into a common package or at least align:
- Frame loading
- State parsing
- DrawSprite / ClearFrame
- Config struct and bounds math

If Odin `-collection` gives you trouble (it did on Linux), just duplicate carefully until it works.

### 5. Build & Run
Build native Windows Odin binary:
```
odin build .\windows\ -out:.\build\windows-pixel-app.exe
```
Run it. You should see the 12×16 pixel pet, cycling 1fps in idle, draggable, resizable with mouse wheel.

### 6. Daemon Wiring
Run the Windows daemon (service or background tray). Use `bpctl.py` to switch states and confirm the renderer updates:
```
python bpctl.py working
python bpctl.py idle
python bpctl.py status
```

---

## Known Linux-Specific Pain Points (Don’t Repeat These)
- **`usleep` FFI**: Odin doesn’t expose `usleep` cleanly in this nightly. We ended up not using it on Linux; if you need sleep on Windows, use `SDL_Delay(ms)` from `vendor:sdl2` or write a tiny C wrapper and link the .obj.
- **Odin `link_name` quoting**: use `@(link_name="...")` or plain `link_name=` syntax from libc-shim style; avoid `#foreign_attr {}` — it errored here.
- **Shared packages**: `-collection` imports were unreliable in our setup; inlining is acceptable short-term.
- **Compile-time array limits**: large nested Odin array literals hit compiler limits. Use runtime blobs (`frames.bin`) instead.

---

## Verification Checklist
- [ ] Repo cloned at `C:\Users\<you>\bitpix-buddy`
- [ ] `windows/main.odin` renders 4-frame sprite from `frames.bin`
- [ ] Idle advances at 1fps, not 24fps
- [ ] Window is draggable
- [ ] Mouse wheel scales with bounds/aspect lock
- [ ] Daemon/CLI works with Windows state path and TCP socket
- [ ] `bpctl.py` state changes reflected in window

---

## Git Workflow
- Commit after each implementation step, ≤150 chars, no AI sig, author `eru123`.
- Push to `origin/master`.

---

## Quick Start Commands (Windows, illustrative)
```powershell
cd $env:USERPROFILE\bitpix-buddy
git clone git@github.com:eru123/bitpix-buddy.git .
cd daemon
python bitpixd.py   # or install as Windows service
python bpctl.py status
cd ..\windows
odin build .\windows\ -out:.\build\windows-pixel-app.exe
.\build\windows-pixel-app.exe
```
