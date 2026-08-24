# ❄️ Chill

A lightweight, native macOS CLI tool to monitor system thermals and hardware sensors in real time, built in Swift for Apple Silicon and Intel Macs.

```text
   _____ _    _ _____ _      _      
  / ____| |  | |_   _| |    | |     
 | |    | |__| | | | | |    | |     
 | |    |  __  | | | | |    | |     
 | |____| |  | |_| |_| |____| |____ 
  \_____|_|  |_|_____|______|______|

```

## ✨ Features

* **Interactive CLI Dashboard:** Clean terminal UI with ASCII banner and menu-driven navigation.
* **SoC & Silicon Telemetry:** Direct sensor telemetry via macOS `IOHIDEventSystem` (ApplePMU / RTBuddy).
* **Live Monitor Mode:** Continuous terminal dashboard refreshing every 2 seconds.
* **Thermal Stress Test:** Built-in multi-core CPU load tester to observe real-time thermal response.
* **Zero Heavy Dependencies:** Native Swift implementation with minimal memory and CPU footprint.

---

## 🚀 Installation

### Option 1: Quick Install (Direct Binary)

Clone the repository, build the release binary, and move it to your local path:

```bash
git clone https://github.com/Barbafebles/chill.git
cd chill
swift build -c release
sudo cp .build/release/chill /usr/local/bin/

```

### Option 2: Run via Swift Package Manager

```bash
git clone https://github.com/Barbafebles/chill.git
cd chill
swift run chill

```

---

## 📖 Usage

### Interactive Menu

Run `chill` without flags to launch the interactive terminal interface:

```bash
chill

```

### Quick Commands

* **Instant status snapshot:**
```bash
chill --status
# or
chill -s

```


* **Live continuous monitoring:**
```bash
chill --monitor
# or
chill -m

```


* **Display help:**
```bash
chill --help

```



---

## 🛠️ Architecture & Under the Hood

Unlike legacy Intel Macs that relied entirely on structural `AppleSMC` calls, modern Apple Silicon SoCs (M-Series) route power management and thermal sensors through the internal **Core-Level Power Control (CLPC)** and **RTBuddy** coprocessor.

`chill` interfaces directly with macOS private `IOHIDEventSystem` APIs to read:

* **SoC die & PMU thermal points:** Real-time sensor temperatures (CPU, GPU, NAND, PMU).
* **Cooling telemetry:** Active RPM monitoring and dynamic passive cooling state detection.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](https://www.google.com/search?q=LICENSE) file for details.
