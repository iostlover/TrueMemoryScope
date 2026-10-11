# 🔍 TrueMemoryScope

**Unmask Hidden Physical RAM Usage Concealed by Windows Task Manager.**

A lightweight, standalone diagnostic GUI tool for Windows that reveals the **true physical memory consumption (Working Set)** of games and applications. Zero installation, zero external dependencies.

[English README](README.md) | [日本語ドキュメント (Japanese)](README_JA.md)

---

## 🧐 The Problem: Why Does Task Manager Lie?

Have you ever looked at Task Manager and noticed:
> *"My system is using 50 GB out of 64 GB RAM (78%), but when I sum up the processes in Task Manager, they barely add up to 10 GB. Where is all my RAM going?!"*

### The Technical Trap
In Windows Task Manager, the default **Memory** column in the **Processes** tab only shows **Private Working Set** (memory exclusively owned by a process that cannot be shared).

However, modern game engines (such as **Unreal Engine**) and media software load huge asset packages (textures, 3D models, sound files) using **Memory Mapped Files**.
- Windows classifies Memory Mapped Files as **"Shareable"**.
- Because they are shareable, **Task Manager EXCLUDES them from the process list memory column!**
- **Real Example:** A game process may actively hold **34.8 GB** of physical RAM in hardware, yet Task Manager only shows **7.2 GB** in the process list. The remaining **27.6 GB** is completely invisible!

---

## 💡 The Solution: TrueMemoryScope

**TrueMemoryScope** analyzes both **Working Set (actual physical RAM usage)** and **Private Working Set (Task Manager's view)** for every process in real time:

- 🔥 **Real RAM Usage (WS)**: The true physical RAM space occupied by each process on your hardware chips.
- 🚨 **Hidden Memory (Diff)**: Mapped files and shared assets that Task Manager does not show in the process list.
- ⚡ **Filter Hidden Memory**: Quickly filter out processes that hide over 1 GB of memory.
- 🎯 **Kill Process**: Terminate memory-hogging processes with a single click.
- 🚀 **Zero Installation**: Built purely with Windows native PowerShell + WPF. No Python, no .NET runtime installer, no admin rights required.

---

## 🖥️ Preview & Features

- **System-Wide Metric Cards**:
  - **Physical RAM In-Use**: True memory used / total, with dynamic warning colors.
  - **Committed Memory**: Virtual memory quota committed by apps and OS.
  - **Standby & Cache**: Clean cached memory that can be reclaimed instantly.
  - **Kernel Pools**: Nonpaged pool & paged pool (driver memory leaks detection).
- **Interactive Process Grid**:
  - Proper numeric sorting (ascending/descending) on all metric columns.
  - Instant process search & filtering.
  - Process path and PID inspection.

---

## 🚀 How to Run

### English Version
Simply double-click **`Launch_EN.bat`** (or `TrueMemoryScope_EN/Launch_EN.bat`).

### 日本語版 (Japanese Version)
Simply double-click **`Launch_JA.bat`** (or `TrueMemoryScope_JA/Launch_JA.bat`).

---

## 📁 Repository Structure

```text
TrueMemoryScope/
├── Launch_EN.bat             # Root launcher (English)
├── Launch_JA.bat             # Root launcher (Japanese)
├── README.md                 # English documentation
├── README_JA.md              # Japanese documentation
├── LICENSE                   # MIT License
│
├── TrueMemoryScope_EN/       # English standalone package
│   ├── Launch_EN.bat
│   ├── app.ps1
│   └── ui.xaml
│
└── TrueMemoryScope_JA/       # Japanese standalone package
    ├── Launch_JA.bat
    ├── app.ps1
    └── ui.xaml
```

---

## 🛠️ System Requirements

- **OS**: Windows 10 / Windows 11 (64-bit)
- **PowerShell**: 5.1 or later (pre-installed on all modern Windows systems)
- **Dependencies**: None! Works out of the box.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE). Feel free to use, modify, and distribute.
