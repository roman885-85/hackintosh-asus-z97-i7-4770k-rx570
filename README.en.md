# Hackintosh: ASUS Z97 · Core i7-4770K · Radeon RX 570 · OpenCore 1.0.8

[🇺🇦 Українська](README.md) · 🇬🇧 English

A working OpenCore **EFI** folder for a Haswell desktop with an AMD Polaris graphics card.
SMBIOS is **MacPro7,1**, so both **macOS Sequoia 15** and **macOS Tahoe 26** run.

> [!IMPORTANT]
> The serial numbers in `EFI/OC/config.plist` are placeholders (`W00000000001`).
> Generate your own before use — see [Before the first boot](#before-the-first-boot).

## Tested

| macOS | Build | Result |
|---|---|---|
| Sequoia 15.8.1 | 24H32 | ✅ all hardware listed below |
| Tahoe 26.7.1 | 25G241 | ✅ all hardware; onboard audio via VoodooHDA ([below](#macos-26-tahoe-what-changed)) |

## Hardware

| Component | Model | Status |
|---|---|---|
| Motherboard | ASUS, Intel Z97 chipset (LPC 8086:8CC4, LGA1150) | — |
| CPU | Intel Core i7-4770K (Haswell, 4 cores / 8 threads) | ✅ XCPM, `plugin-type` via SSDT-PLUG |
| RAM | 2 × 8 GB DDR3-1600 (TeamGroup UD3) | ✅ |
| GPU | ASUS Radeon RX 570, 4 GB (Polaris, 1002:67DF) | ✅ Metal, hardware video decoding (Tahoe), three displays: a 1920×1200 projector and two 1920×1080 monitors |
| iGPU | Intel HD 4600 | not used |
| NVMe | Patriot P300 256 GB (PCIe x2, 5 GT/s) | ✅ NVMeFix, TRIM |
| SATA | Hitachi HTS545050A7E380 500 GB | ✅ |
| Ethernet | Realtek RTL8111G, 1 Gbit/s | ✅ RealtekRTL8111 3.0.0 (EEE disabled) |
| Onboard audio | Realtek ALC887 | ✅ macOS ≤ 15 — AppleALC, layout-id 52; macOS 26 — VoodooHDA |
| HDMI/DP audio | RX 570 | ✅ |
| USB | Intel 9-series XHCI (8086:8CB1) + ASMedia ASM1042 | ✅ USBMap port map: 12 XHC ports + 2 ASMedia |
| Wi-Fi / Bluetooth | none | — |
| Sleep | not configured (`sleep 0`) | ⚠️ not tested |

## What's inside

- **OpenCore 1.0.8** (RELEASE, acidanthera), OpenCanopy graphical picker.
- **SMBIOS:** `MacPro7,1` — the only Tahoe-supported model for Haswell with a discrete GPU only.
- **SecureBootModel:** `Disabled`; Software Update works with `revpatch=sbvmm` (RestrictEvents).

| Kext | Version | Purpose |
|---|---|---|
| Lilu | 1.7.2 | patching framework |
| VirtualSMC + SMCProcessor + SMCSuperIO | 1.3.8 | SMC emulation, CPU and fan sensors |
| WhateverGreen | 1.7.1 | GPU fixes |
| AppleALC | 1.9.8 | onboard audio (macOS 15 and older only, `MaxKernel 24.99.99`) |
| RestrictEvents | 1.1.6 | `revpatch=sbvmm,memtab,pci`: OS updates, no MacPro7,1 memory/PCI warnings |
| NVMeFix | 1.1.3 | NVMe power management |
| RealtekRTL8111 | 3.0.0 | Ethernet; `enableEEE` disabled in `Info.plist` |
| USBMap | — | custom USB port map (old and new key format) |

| ACPI | Purpose |
|---|---|
| SSDT-EC | fake embedded controller for macOS |
| SSDT-PLUG | `plugin-type` — CPU power management (XCPM) |
| SSDT-SBUS | SMBus |
| SSDT-USBX | USB power properties for the newer Mac model |

UEFI drivers: `OpenRuntime`, `OpenCanopy`, `ResetNvramEntry`, `HfsPlus`.

Key settings: `DisableIoMapper`, `AppleXcpmCfgLock` (in case CFG Lock can't be disabled in BIOS),
`csr-active-config` = `030A0000`, `boot-args` = `debug=0x100 keepsyms=1`.

## Before the first boot

1. **Serial numbers.** Get [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS), generate a `MacPro7,1` set and put it into
   `PlatformInfo → Generic`: `SystemSerialNumber`, `MLB`, `SystemUUID`.
   Set `ROM` to your Ethernet MAC address (6 bytes, no colons).
   The serial should be **invalid** on Apple's coverage site, otherwise iCloud may misbehave.
2. **BIOS** (general Haswell recommendations from the Dortania guide):
   - disable: Fast Boot, Secure Boot (OS type "Other OS"), CSM (if your GPU has UEFI GOP), VT-d — optional (`DisableIoMapper` is already set);
   - enable: XHCI Hand-off, EHCI Hand-off, SATA mode AHCI;
   - primary display: PCIe.
3. **Test first.** Boot from a USB stick first: copy `EFI` to the root of a FAT32 stick and pick it in the boot menu (F8).
   If everything works, copy `EFI` to the EFI partition of the system disk.

## macOS 26 Tahoe: what changed

**1. New USB map keys.** macOS 26 reads ports by `usb-port-number` and `usb-port-type`
(instead of `port` and `UsbConnector`). With an old map the USB controllers start with no ports and power down —
keyboard and mouse die, and a USB installer fails with **"Still waiting for root device"**.
The `USBMap.kext` here carries both key sets and works on Sequoia and Tahoe alike.

**2. No AppleHDA.** Apple removed the onboard audio driver, so AppleALC does nothing on Tahoe
(it is limited with `MaxKernel 24.99.99`). Onboard audio comes back with **VoodooHDA 3.6.8** from `PostInstall`:

```bash
sudo cp -R PostInstall/VoodooHDA.kext /Library/Extensions/
sudo chown -R root:wheel /Library/Extensions/VoodooHDA.kext
sudo chmod -R 755 /Library/Extensions/VoodooHDA.kext
sudo kmutil load -p /Library/Extensions/VoodooHDA.kext
```

Then System Settings → Privacy & Security → "Allow", and restart. USB audio interfaces and HDMI audio keep working.

> [!WARNING]
> Do not use the bootloader-injected **VoodooHDA_BL 3.7.0-alpha**: it embeds its own copy of IOAudioFamily,
> the system one then fails to load — and USB audio (AppleUSBAudio) and HDMI audio (AppleGFXHDA) disappear. Verified.

Two changes in VoodooHDA's `Info.plist`: `IONameMatch` = `HDEF` (the audio controller's name on this board),
and the separate AMD HDMI audio personality removed so HDMI stays with the system driver.

**3. SMBIOS.** Tahoe does not support `iMacPro1,1`; `MacPro7,1` is used here.

## Installer package

`tools/macos-package/build.sh` builds `dist/Z97-Haswell-Drivers-DATE.pkg`, which after a clean macOS install:
- on macOS 26+ installs VoodooHDA and triggers the approval prompt;
- installs OpenCore to the EFI partition of the system disk **only if it is not there yet**
  (an identical one is left alone; a different one is not replaced — the package copy goes next to it as `EFI_from_pkg`).

Log: `/var/log/z97-drivers-install.log`. Approving the extension and restarting is always up to the user.

## Known quirks

- On this machine the EFI partition historically has the "Microsoft Basic Data" type — booting is fine,
  but macOS mounts such a partition automatically. The type can only be changed from Recovery or another OS.
- The network drop-outs and 10/100 Mbit/s links we saw were caused by a **cable**, not the driver.

## Changelog

- **2026-10-12** — USB map with macOS 26 keys; removed the unnecessary XHCI-unsupported (8CB1 is supported natively);
  `layout-id` stored as data; AppleALC limited to macOS 15; VoodooHDA for Tahoe.
- **2026-10-11** — OpenCore 1.0.3 → 1.0.8, all kexts updated, `iMacPro1,1` → `MacPro7,1`;
  fixed the USB map that was never applied (stray `ExecutablePath` on a codeless kext); RealtekRTL8111 3.0.0.

## Credits & licenses

- [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg), Lilu, WhateverGreen, AppleALC, VirtualSMC, NVMeFix, RestrictEvents — acidanthera, BSD-3-Clause.
- [RealtekRTL8111](https://github.com/Mieze/RTL8111_driver_for_OS_X) — Laura Müller.
- [VoodooHDA](https://github.com/CloverHackyColor/VoodooHDA) — CloverHackyColor, GPL-2.0 (only `Info.plist` modified).
- `HfsPlus.efi` and picker resources — [acidanthera/OcBinaryData](https://github.com/acidanthera/OcBinaryData).
- [Dortania guide](https://dortania.github.io/OpenCore-Install-Guide/).

This repository's own files (docs, scripts, `config.plist`, `USBMap.kext`) — [MIT](LICENSE).
Use at your own risk; Apple's license allows macOS on Apple hardware only.
