# ❄️ Chill

A sleek, lightweight, and native macOS CLI hardware and telemetry monitor built entirely in Swift for Apple Silicon and Intel Macs.

```text
  ░█████╗░██╗░░██╗██╗██╗░░░░░██╗░░░░░
  ██╔══██╗██║░░██║██║██║░░░░░██║░░░░░
  ██║░░╚═╝███████║██║██║░░░░░██║░░░░░
  ██║░░██╗██╔══██║██║██║░░░░░██║░░░░░
  ╚█████╔╝██║░░██║██║███████╗███████╗
  ░╚════╝░╚═╝░░╚═╝╚═╝╚══════╝╚══════╝

```

---

## ✨ Features

* **Cyberpunk / Retro ASCII TUI:** Zero-flicker native terminal interface using ANSI alternate screen buffers and raw keyboard mode.
* **CPU & Sparklines:** Real-time multi-core CPU tracking with historical ASCII sparklines (` ▂▃▄▅▆▇█`).
* **Silicon Telemetry & Thermal Headroom:** Direct SoC die temperature readings via private `IOHIDEventSystem` APIs, calculating real-time thermal headroom before throttling.
* **Unified Memory & Network I/O:** Breakdown of App, Wired, and Compressed RAM alongside live network download/upload throughput.
* **Battery Health & Cycles:** Native AppleSmartBattery IOKit telemetry showing battery capacity, health percentage, and total cycle count.
* **Interactive Process Monitor:** Top resource-hogging processes with dynamic colored badges (🟢, 🟠, 🔴) and hot-swappable sorting.
* **Interactive Keyboard Controls:**
* `[Q / X]` Clean exit and terminal restoration.
* `[P]` Toggle process ordering between **% CPU** and **% RAM**.
* `[+ / -]` Dynamically adjust refresh rate in 0.5s steps.
* `[S]` Trigger an instant 3-second multi-threaded CPU stress test.



---

## 🚀 Installation

### Option 1: Global Binary (Recommended)

Clone the repository, compile the release build, and copy it to your local system path:

```bash
git clone https://github.com/Barbafebles/chill.git
cd chill
swift build -c release
sudo cp .build/release/chill /usr/local/bin/

```

Now you can run `chill` directly from any terminal session:

```bash
chill

```

### Option 2: Swift Package Manager (Local Run)

```bash
git clone https://github.com/Barbafebles/chill.git
cd chill
swift run chill

```

---

## ⌨️ Interactive Shortcuts

While running `chill`, press any of the following keys without pressing Enter:

| Key | Action |
| --- | --- |
| **`Q`** / **`X`** | Exit application cleanly |
| **`P`** | Toggle Top Apps sorting (**CPU%** ⟷ **RAM%**) |
| **`+`** / **`-`** | Increase / decrease dashboard refresh interval |
| **`S`** | Run an inline 3-second CPU stress test |

---

## 🛠️ Architecture & Under the Hood

Unlike traditional cross-platform monitors that rely on heavy dependencies or generic POSIX wrappers, **`chill`** interfaces directly with low-level macOS subsystems:

* **`IOHIDEventSystem` & `AppleSMC` Bridge:** Direct access to PMU and RTBuddy sensor arrays.
* **`IOKit` Battery Registry:** Hardware-level inspection of battery health and cycle count.
* **`Mach Kernel APIs` (`host_processor_info` / `host_statistics64`):** Precise CPU load and unified memory telemetry with negligible resource footprint.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://www.google.com/search?q=LICENSE) file for details.
