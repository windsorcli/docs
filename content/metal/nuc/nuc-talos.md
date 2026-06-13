---
title: Boot Talos on an Intel NUC
description: Prepare USB boot media and boot an Intel NUC into Talos maintenance mode before cluster configuration.
---

This page walks you through booting an Intel NUC into Talos **maintenance mode** from USB. You need a workstation (macOS, Linux, or Windows), a USB drive of at least 8 GB, and Ethernet on the NUC. The walkthrough ends before machine configuration, etcd bootstrap, or kubeconfig.

## Prerequisites

- Intel NUC (x86_64) on **UEFI**
- USB drive, 8 GB or larger
- Workstation: **macOS or Linux** with `curl`, `xz`, and `sudo`; or **Windows** with PowerShell and [Rufus](https://rufus.ie/) (optional [WSL](https://learn.microsoft.com/en-us/windows/wsl/) to use the Linux steps)
- Ethernet on the NUC (recommended)
- Wired USB keyboard for firmware setup (Bluetooth keyboards often miss the F2 prompt)
- [`talosctl`](https://www.talos.dev/latest/introduction/installation/) on the workstation if you want to verify the node after boot

## Anatomy

| Piece | Role |
|-------|------|
| [Talos Image Factory](https://factory.talos.dev) | Builds a **schematic** and emits versioned boot images |
| USB stick | Holds the boot image; Talos runs in maintenance mode from it |
| Maintenance mode | Talos runs from RAM until you apply machine config and install to disk |
| Secure Boot | UEFI setting that must match your boot media (off for standard `.raw`, on for Talos Secure Boot ISO) |
| Node IP | Shown on the console or in your router DHCP client list; used with `talosctl` |

## Choose a boot path

Pick one path now. Step 1 configures Secure Boot for that path; later steps use different boot media.

| Path | Boot media | UEFI Secure Boot |
|------|------------|------------------|
| **A — Standard USB** | Image Factory **metal-amd64** `.raw` | **Disabled** |
| **B — Secure Boot** | Talos **Secure Boot ISO** (not the standard `.raw`) | **Enabled** in **Setup Mode** |

**Path A** is the usual way to reach maintenance mode. **Path B** is for Trusted Boot with signed UKI images and `installer-secureboot`; do not use the Path A `.raw` image on Path B.

## Walkthrough

### 1. Configure UEFI and Secure Boot

Configure the NUC on the bench **before** you download or write the USB stick. Secure Boot must match the path you chose above.

#### Enter BIOS setup

Power off the NUC. Connect a **wired** keyboard and monitor (HDMI or DisplayPort; USB-only monitors may not show the F2 prompt).

1. Press the power button.
2. Tap **F2** repeatedly as soon as the NUC logo appears until the firmware setup screen opens.
3. If F2 does not work, disable [Fast Boot](https://www.asus.com/support/FAQ/1052726/) from the power-button menu (hold power ~3 seconds, release, press **F3**), then retry F2. See [Can't access BIOS with F2](https://www.asus.com/support/FAQ/1052511/) for other causes.

Firmware hotkeys on most Intel NUC models:

| Key | Action |
|-----|--------|
| **F2** | Enter BIOS / UEFI setup |
| **F10** | One-time boot menu (pick USB) |
| **F7** | Boot menu on some ASUS NUC models (BIOS update USB) |
| **F10** (in setup) | Save changes and exit |
| **F9** (in setup) | Load optimized defaults |

Official references: [Intel NUC BIOS glossary (PDF)](https://www.intel.com/content/dam/support/us/en/documents/mini-pcs/BIOSGlossary_NUC.pdf), [Intel Express BIOS update instructions (PDF)](https://www.intel.com/content/dam/support/us/en/documents/mini-pcs/AptioV-BIOS-Update-NUC.pdf).

Open the **Secure Boot** page in setup. Menu paths differ by firmware generation (**Boot → Secure Boot** on Aptio V, **Advanced → Boot → Secure Boot** on Visual BIOS).

![Illustrative Aptio V Secure Boot screen — menu layout varies by BIOS version](assets/nuc-aptio-secure-boot.png)

![Illustrative Visual BIOS Secure Boot screen — menu layout varies by BIOS version](assets/nuc-visual-secure-boot.png)

#### Path A: Disable Secure Boot

For the standard **metal-amd64** `.raw` image, set **Secure Boot** to **Disabled**. The factory `.raw` is not signed for Secure Boot.

**Aptio V BIOS** (common on ASUS NUC8 and later):

1. **Boot** → **Secure Boot** → **Secure Boot** → **Disabled**
2. Confirm **UEFI Boot** is enabled
3. **Boot** → **Boot Configuration** or **Boot Priority** — ensure USB boot is allowed
4. Press **F10**, confirm **Yes** to save (you can adjust boot order in the next subsection before exiting)

**Visual BIOS** (older Intel-branded NUC):

1. **Advanced** → **Boot** → **Secure Boot** → **Disabled**
2. **Advanced** → **Boot** → **Boot Configuration** — enable USB in boot devices
3. Press **F10** to save

ASUS publishes firmware screenshots: [Disable Secure Boot on NUCs](https://www.asus.com/us/support/faq/1052728/).

#### Path B: Enable Secure Boot (Setup Mode)

For the Talos **Secure Boot ISO**, set **Secure Boot** to **Enabled** and put the firmware in **Setup Mode** so Talos can enroll the [Sidero Labs signing key](https://factory.talos.dev/secureboot/signing-cert.pem) on first boot.

1. Set **Secure Boot** to **Enabled**.
2. Check **Secure Boot Mode** on screen:
   - **Setup Mode** or **Platform Key: Not Installed** — ready for key enrollment
   - **Standard Mode** with keys already installed — on the Secure Boot page, enable **Clear Secure Boot Data**, save with **F10**, reboot into setup once, then disable **Clear Secure Boot Data** and leave **Secure Boot** enabled
3. Ensure **UEFI Boot** is enabled and USB boot is allowed (same boot menus as Path A).
4. Press **F10** to save.

At first ISO boot, if enrollment does not start automatically, press **Esc** for the boot menu and choose **Enroll Secure Boot keys: auto** (wording varies). Full ISO, install, and verification steps are in the [Talos Secure Boot guide](https://www.talos.dev/latest/talos-guides/install/bare-metal-platforms/secureboot/).

#### Set USB as the boot device

For both paths:

1. On Aptio V: **Boot** → **Boot Priority** or **Boot Configuration** — move **USB** above internal NVMe/SSD, or use the one-time boot menu.
2. On Visual BIOS: **Advanced** → **Boot** → **Boot Configuration** — enable the USB device.
3. Save with **F10** if you have not already.

Or skip permanent boot-order changes: at power-on, press **F10** (or **F7** on some models) and select **UEFI: &lt;your USB brand&gt;**.

### 2. Build the image at the factory

Open [Talos Image Factory](https://factory.talos.dev), choose extensions for your NUC, and note the **schematic ID** and Talos **version** (for example `v1.11.6`).

**Path A** — profile **metal-amd64**.

**Path B** — build or select the **Secure Boot ISO** for your schematic (see the [Talos Secure Boot guide](https://www.talos.dev/latest/talos-guides/install/bare-metal-platforms/secureboot/)); do not use profile **metal-amd64** for the USB stick.

Export variables on the workstation.

On **macOS or Linux** (Path A):

```bash
export SCHEMATIC="<schematic-id>"
export VERSION="<version>"
export ARCH="metal-amd64"
```

On **Windows** (PowerShell, Path A):

```powershell
$SCHEMATIC = "<schematic-id>"
$VERSION = "<version>"
$ARCH = "metal-amd64"
```

### 3. Download and decompress

**Path A** — download the **metal-amd64** compressed raw image. You should end with `metal-amd64.raw` in the current directory.

On **macOS or Linux**:

```bash
curl -fL -o "${ARCH}.raw.xz" \
  "https://factory.talos.dev/image/${SCHEMATIC}/${VERSION}/${ARCH}.raw.xz"
xz -d "${ARCH}.raw.xz"
```

On **Windows** (PowerShell). `curl.exe` is built in; decompress with `tar` on Windows 11 or recent Windows 10, or with [7-Zip](https://www.7-zip.org/) if `tar` does not handle `.xz` on your build:

```powershell
curl.exe -fL -o "$ARCH.raw.xz" `
  "https://factory.talos.dev/image/$SCHEMATIC/$VERSION/$ARCH.raw.xz"
tar -xf "$ARCH.raw.xz"
```

If `tar` reports an error, extract with 7-Zip instead.

**Path B** — download the **Secure Boot ISO** from Image Factory per the [Talos Secure Boot guide](https://www.talos.dev/latest/talos-guides/install/bare-metal-platforms/secureboot/). Do not download the Path A `.raw.xz` file.

### 4. Identify the USB disk

Confirm the device twice before writing. The next step erases that disk.

On **macOS**:

```bash
diskutil list
```

Pick the whole-disk device (for example `/dev/disk4`, not `disk4s1`). For `dd`, use the matching **raw** device (for example `/dev/rdisk4`).

On **Linux**:

```bash
lsblk
```

Pick the removable whole disk (for example `/dev/sdb`), not a partition.

On **Windows**, open **PowerShell as Administrator**:

```powershell
Get-Disk | Where-Object BusType -eq USB | Format-Table Number, FriendlyName, Size
```

Match **Number** to the USB drive size, not your system disk. With **WSL**, if the USB drive appears in `lsblk`, you can use the Linux `dd` steps instead of Rufus.

### 5. Write the image to USB

**Path A** — write `metal-amd64.raw` to the USB stick.

On **macOS** (replace `4` with your disk number):

```bash
diskutil unmountDisk /dev/disk4
sudo dd if="${ARCH}.raw" of=/dev/rdisk4 bs=4m conv=sync
diskutil eject /dev/disk4
```

On **Linux** (replace `sdX` with your device):

```bash
sudo umount /dev/sdX* 2>/dev/null || true
sudo dd if="${ARCH}.raw" of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

The `of=` argument must be the USB disk, not your system drive.

On **Windows**, use [Rufus](https://rufus.ie/):

1. Select the USB **Device**.
2. Click **SELECT** and choose `metal-amd64.raw`.
3. If prompted, choose **DD Image**.
4. Click **START**, confirm the erase warning, then eject safely when finished.

**Path B** — write the **Secure Boot ISO** with Rufus (Windows) or `dd` of the ISO to the disk per the [Talos Secure Boot guide](https://www.talos.dev/latest/talos-guides/install/bare-metal-platforms/secureboot/). Do not write the Path A `.raw` file.

### 6. Boot the NUC

Insert the USB stick, connect Ethernet, and power on.

**Path A** — with Secure Boot **disabled**, Talos should enter maintenance mode. Note the node IP from the console or router DHCP list.

**Path B** — with Secure Boot **enabled** in Setup Mode, the ISO enrolls keys and boots Talos in Secure Boot mode. Follow the [Talos Secure Boot guide](https://www.talos.dev/latest/talos-guides/install/bare-metal-platforms/secureboot/) through maintenance mode and install.

### 7. Verify with talosctl

**Path A** — from the workstation:

```bash
talosctl version --nodes <node-ip>
```

**Path B** — confirm Secure Boot is active:

```bash
talosctl -n <node-ip> get securitystate --insecure
```

Expect `SECUREBOOT` to read `true`. See the [Talos Secure Boot guide](https://www.talos.dev/latest/talos-guides/install/bare-metal-platforms/secureboot/) for install and cluster steps.

## Troubleshooting

### NUC does not boot from USB

**Symptom:** Firmware skips USB or returns to the previous boot device.

**Cause:** USB boot disabled, wrong boot order, or Secure Boot rejecting the stick.

**Fix:** Confirm your [path](#choose-a-boot-path) and [step 1](#1-configure-uefi-and-secure-boot) settings match (Path A: Secure Boot off; Path B: on, with the Secure Boot ISO). Re-flash the stick if the write did not complete.

### Secure Boot blocks the USB stick

**Symptom:** Boot halts with a security violation, "Unauthorized" message, or immediate return to firmware.

**Cause:** Path A **metal-amd64** `.raw` booted while Secure Boot is **Enabled**.

**Fix:** Enter setup with **F2**, follow [Path A: Disable Secure Boot](#path-a-disable-secure-boot), save with **F10**, and boot again. If you need Secure Boot, use [Path B](#path-b-enable-secure-boot-setup-mode) and the Secure Boot ISO.

### Cannot enter BIOS with F2

**Symptom:** The NUC boots straight to an OS or blank screen; F2 has no effect.

**Cause:** Fast Boot, wireless keyboard, or USB monitor without early POST output.

**Fix:** [Disable Fast Boot](https://www.asus.com/support/FAQ/1052726/), use a wired keyboard on a rear USB port, and connect HDMI or DisplayPort. See [ASUS: Can't access BIOS with F2](https://www.asus.com/support/FAQ/1052511/).

### Wrong disk selected for `dd`

**Symptom:** Workstation OS fails to boot or data is missing after the write step.

**Cause:** `of=` pointed at an internal disk instead of the USB device.

**Fix:** Re-image the affected disk from backup if you have one. On the next attempt, run `diskutil list` or `lsblk` again and verify the disk size matches the USB drive before running `dd`.

### `talosctl` cannot reach the node

**Symptom:** `talosctl version` times out or reports connection errors.

**Cause:** Wrong IP, no route to the NUC, or Talos still booting.

**Fix:** Confirm the IP on the NUC console or DHCP list. Ping the address from the workstation. Wait for boot to finish and retry.

## Where to next

- [Talos Linux documentation](https://www.talos.dev/latest/) — configuration, upgrades, and operations
- [Talos Secure Boot guide](https://www.talos.dev/latest/talos-guides/install/bare-metal-platforms/secureboot/) — Path B: ISO, key enrollment, and `installer-secureboot`
- [Talos Image Factory](https://factory.talos.dev) — change schematic, version, or extensions
- [Bare-metal install guide](https://www.talos.dev/latest/talos-guides/install/bare-metal/) — install Talos to disk and form a cluster after maintenance mode
- [ASUS: Disable Secure Boot on NUCs](https://www.asus.com/us/support/faq/1052728/) — manufacturer steps with firmware screenshots
- [Intel NUC BIOS glossary (PDF)](https://www.intel.com/content/dam/support/us/en/documents/mini-pcs/BIOSGlossary_NUC.pdf) — Secure Boot option reference
