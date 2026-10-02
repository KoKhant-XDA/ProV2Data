GhostLock - Universal Temp Root (v1.2)
=======================================
CVE-2026-43499 futex PI UAF exploit for Xiaomi/Redmi/POCO devices.

Architecture: ONE universal binary + kernel profile files.
Per-device fallback binaries included for devices without profiles.

Quick Start:
  1. Connect phone via USB, enable USB debugging
  2. Run Ghostlock.bat
  3. Done. Root is temporary (lost on reboot).

Contents:
  Ghostlock.bat              Main one-click script (Windows)
  bin/
    ghostlock                Universal exploit binary (arm64, v1.2)
    ghostlock-extract.exe    Offset extractor CLI (Windows x64, v1.2)
    ksu-manager.apk          KernelSU Manager app (v1.2)
    ghostlock_14r            Fallback: Xiaomi 14R (quark)
    ghostlock_pad7pro        Fallback: Pad 7 Pro (g614238d0d630)
    ghostlock_pad7pro_g7b9e94e37cfa  Fallback: Pad 7 Pro (g7b9e94e37cfa)
    gl_sky_exploit            Sky exploit (Redmi Note 12R)
    libksud.so                KSU daemon library (Sky flow)
    ksu_loader.sh             KSU loader script (Sky flow)
    run_ksu_full.sh           Full root script (Sky flow)
  profiles/
    54 kernel profile .bin files

Device Support Matrix:
  Xiaomi 14 (houji)             SM8650  profile    NEW
  Mi 14 Pro / Civi 4 Pro        SM8650  profile
  Mi 14 Ultra / K80             SM8650  profile
  K80 Pro / K80 Ultra            SM8650  profile
  Mi 15 Pro (6.6)               SM8650  profile
  Xiaomi Pad 7 Pro (g965475777129) SM8650  profile
  Xiaomi Pad 7 Pro (g7b9e94e37cfa) SM8650  fallback binary
  Xiaomi Pad 7 Pro (g614238d0d630) SM8650  fallback binary
  Xiaomi 14R (quark)            SM8650  fallback binary
  Redmi 15R Spring              SM6375  profile
  Redmi Note 12R (sky)          SM6877  special exploit
  8G2 devices                   SM8550  profile
  Many 6.6/6.12 kernels         profiles
  5.15 kernel devices           profiles

How it works:
  1. Script detects your kernel version (uname -r)
  2. Looks for matching .bin profile in profiles/
  3. If found: pushes universal ghostlock + profile, runs with --load-prebuilt-profile
  4. If not found: checks for device-specific fallback binary
  5. If no fallback either: error with instructions to generate profile

Old + new plain package:
  legacy/bin/       Original plain generic, Mi 14 Ultra, ksud and support files
  legacy/devices/   Original 14R, 8G2, K80, Pad 7 Pro, Sky and Spring payloads
  legacy/offsets/   Original K80 and Turbo 3 offset data

GS.bat and PiSuite always try an exact new kernel profile first. They use a
known legacy payload only for an exact supported model/kernel match. Unknown
kernels are blocked instead of receiving a generic incompatible payload.

Adding a new kernel:
  ghostlock-extract.exe boot.img --format conf --out profile.conf
  (Import into the app, or convert to .bin and place in profiles/)

Source repos:
  https://github.com/YuKongA/ghostlock-app/
  https://github.com/JoinChang/ghostlock-oneplus
  https://github.com/x-spy/CVE-2026-43499-popsicle
  https://github.com/NebuSec/CyberMeowfia
  https://github.com/Linuxoid-cn/CVE-2026-43499-Poc-Analysis
  https://github.com/byemaxx/ghostlock-anchor
