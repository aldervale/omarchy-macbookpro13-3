# Setup route used on this MacBookPro13,3

This describes our September 2026 repair, using the versions in the root
[README](../README.md). Read upstream instructions before changing another
machine. Preserve its partitions and existing Apple EFI data; copying another
Mac's firmware or calibration data is not a recovery method.

## 1. Identify the model and kernel

```bash
cat /sys/class/dmi/id/product_name
uname -r
pacman -Q omarchy linux-omarchy linux-omarchy-headers dkms
ls -ld /usr/lib/modules/"$(uname -r)"/build
lsusb -d 05ac:
```

This repository's sleep code is restricted to `MacBookPro13,3`, the 2016
15-inch T1 model. `MacBookPro13,3` does not mean a 13-inch display. T2 and the
2017 models need their own validation.

Install build tools and **headers matching the kernel you actually boot**.
For our Omarchy kernel the header package was `linux-omarchy-headers`; installing
only `linux-headers` would cover a different kernel. The usual prerequisites are
`base-devel`, `dkms`, `git`, `usbutils`, `wget`, and the matching headers.
Use Omarchy's supported package/update flow if its databases need updating;
do not perform a standalone `pacman -Sy` partial upgrade.

Before removing `macbook12-spi-driver-dkms`, confirm the keyboard is using the
in-tree `applespi` and the out-of-tree package is obsolete/unbuilt on your system.
We removed version `0+git.315`; the keyboard kept working. Check:

```bash
modinfo -n applespi
dkms status
```

## 2. Repair Wi-Fi board configuration

We used the board template from
[dzanaga's Wi-Fi assets](https://github.com/dzanaga/macbookpro-2016-2017-linux/tree/main/assets/wifi),
from commit `a5147f9c00738addbbbde85302a211954709e52b`.
Only the model-specific file was installed:

```text
/usr/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro13,3.txt
```

Keep your actual radio country code. Ours was `CA`. The adapter exposed a
generic Broadcom permanent address and a randomized current address, so we
generated a unique locally administered address rather than claiming either
was the original Apple address. Obtain the real factory address from your own
saved macOS data if available; do not copy another person's address.

To reproduce our fallback, clone the upstream repository at that commit and
render its `assets/wifi/brcmfmac43602-pcie.template.txt` locally. This example
retains our country setting; change it to your actual country before running:

```bash
git clone https://github.com/dzanaga/macbookpro-2016-2017-linux.git
git -C macbookpro-2016-2017-linux checkout a5147f9c00738addbbbde85302a211954709e52b
python3 - <<'PY'
from pathlib import Path
import secrets
country = 'CA'  # Set your actual regulatory country.
octets = bytearray(secrets.token_bytes(6))
octets[0] = (octets[0] | 2) & 0xfe
mac = ':'.join(f'{b:02x}' for b in octets)
source = Path('macbookpro-2016-2017-linux/assets/wifi/brcmfmac43602-pcie.template.txt')
text = source.read_text().replace('{{WIFI_MACADDR}}', mac).replace('{{WIFI_COUNTRY}}', country)
assert '{{' not in text
Path('wifi-nvram.local.txt').write_text(text)
print('Rendered wifi-nvram.local.txt; keep the same generated address on later installs.')
PY
```

Back up an existing firmware file before replacing it. Review the rendered
file, then install it and rebuild the Omarchy boot image:

```bash
sudo install -Dm644 wifi-nvram.local.txt \
  '/usr/lib/firmware/brcm/brcmfmac43602-pcie.Apple Inc.-MacBookPro13,3.txt'
sudo limine-mkinitcpio
```

Reboot when ready. We verified 5 GHz association after reboot; Ethernet was
also connected, so that did not prove the internet route used Wi-Fi. Interface
names vary: use `nmcli device` and `iw dev` before checking your link.
Do not commit the rendered file. Rollback restores your backed-up firmware
file, or removes this addition if no file existed, then rebuilds the boot image
and reboots.

## 3. Install the audio driver

We used [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro)
at commit `89b22ff90b86468b186706861dd18663562defa7`. Read its driver instructions
and limitations before installing. Our durable source location was
`/usr/local/src/snd_hda_macbookpro`, so DKMS did not depend on a temporary checkout.

```bash
git clone https://github.com/davidjo/snd_hda_macbookpro.git
git -C snd_hda_macbookpro checkout 89b22ff90b86468b186706861dd18663562defa7
sudo install -d /usr/local/src/snd_hda_macbookpro
sudo cp -a --no-preserve=ownership snd_hda_macbookpro/. /usr/local/src/snd_hda_macbookpro/
cd /usr/local/src/snd_hda_macbookpro
sudo ./install.cirrus.driver.sh -i
```

Use a new source location if that directory already contains a different
installation; resolve the existing DKMS driver first. Check `dkms status`,
rebuild the Omarchy boot image after the kernel-module changes, and reboot.
Test speakers through PipeWire at low volume. Speaker playback was confirmed;
microphone and headphone switching were not separately tested here. Use the
upstream removal instructions for the installed revision when reverting.

The durable source tree must be root-owned and not writable by ordinary users:
DKMS executes its build scripts as root on later kernel updates. Earlier
versions of this guide used `cp -a`, which preserved the checkout's user
ownership. If you followed that version, inspect the tree and the DKMS source
link, then repair the ownership:

```bash
readlink -f /usr/src/snd_hda_macbookpro-0.1
sudo chown -hR root:root /usr/local/src/snd_hda_macbookpro
sudo chmod -R go-w /usr/local/src/snd_hda_macbookpro
```

These commands assume that exact dedicated source directory. They do not
reinstall or reload the running audio driver.

## 4. Correct the NVMe suspend service target if needed

On this machine the packaged service targeted PCI `01:00.0`, which was the GPU;
the NVMe SSD was at `02:00.0`. The included helper discovers NVMe controllers
through sysfs instead of hard-coding a PCI address.

Inspect the existing unit and settings first:

```bash
systemctl cat omarchy-nvme-suspend-fix.service
for path in /sys/class/nvme/nvme*/device/d3cold_allowed; do
  printf '%s: ' "$path"
  cat "$path"
done
```

If the existing service already sets the correct controller to `0`, skip this
correction. Otherwise, from this repository's root, back up any existing helper
or override and install:

```bash
sudo install -Dm755 platform/macbook-nvme-suspend-fix /usr/local/sbin/macbook-nvme-suspend-fix
sudo install -Dm644 platform/nvme-override.conf \
  /etc/systemd/system/omarchy-nvme-suspend-fix.service.d/override.conf
sudo systemctl daemon-reload
sudo systemctl enable omarchy-nvme-suspend-fix.service
sudo systemctl restart omarchy-nvme-suspend-fix.service
```

Verify the NVMe `d3cold_allowed` reads `0` and remains so after reboot.
This addresses one controller setting; it does not prove suspend works.
Rollback restores any prior files (or removes just these additions), reloads
systemd, and reboots. Never substitute a GPU PCI address for the SSD.

## 5. Recover T1 firmware only when it is actually missing

Our T1 was in USB recovery mode (`05ac:1281`). We built `t1-revive 0.1.3` from
commit `c2062f3a09b2d278649d3ec48bbb7d15c8b55bcf`, ran its preflight, and the owner
performed the attended recovery. Read
[t1-revive's recovery cautions and build instructions](https://github.com/niconistal/t1-revive)
and [hardware validation](https://github.com/niconistal/t1-revive/blob/main/docs/hardware-validation.md)
first. Recovery writes device-specific data and boot files; it requires mains
power, an open lid, attendance and access to Apple's services.

The exact command the owner successfully used, from that project's checkout,
was:

```bash
sudo systemd-inhibit --what=sleep:idle --why="T1 firmware recovery" \
  ./bin/t1-revive --confirm-each regenerate
```

In that version `--confirm-each` is a **global option placed before**
`regenerate`. Preflight included installing `acpi_call-dkms` and verifying the
matching kernel headers. A successful recovery was followed by T1Bridge
installation and a full shutdown/power-on. Initial boot enumeration was then
`05ac:8600`; speakers, Wi-Fi and the Touch Bar worked.

If your T1 already boots as `05ac:8600`, a dark display after sleep alone is not
evidence of missing firmware. Do not use regeneration as a routine resume fix.
Make a verified, encrypted off-disk backup of this Mac's recovered Apple EFI
data using the upstream backup instructions. Never put it in this repository.

## 6. Use T1Bridge for the runtime stack

We installed the official signed `t1bridge`, `t1bridge-dkms`, and
`t1bridge-omarchy` packages. Follow the
[official package instructions](https://github.com/standardagents/t1bridge#install-official-packages)
for repository configuration and signing-key verification, using the matching
Omarchy kernel headers. Our Touch Bar setup did not install fingerprint
packages or change PAM.

The minimal service activation we used was:

```bash
sudo systemd-sysusers /usr/lib/sysusers.d/t1bridge.conf
sudo systemd-tmpfiles --create /usr/lib/tmpfiles.d/t1bridge.conf
sudo usermod -aG t1bridge "$(id -un)"
sudo systemctl daemon-reload
sudo systemctl enable t1-touchbar-hw.service
```

Reboot and log into the local graphical session to pick up the group membership
and packaged early T1 configuration selector, then run:

```bash
systemctl --user daemon-reload
systemctl --user enable --now t1-touchbar.service
```

Confirm actual illumination by eye. A connected DRM connector, an active
renderer or T1 USB configuration 2 does not prove the panel is lit.
Refer to [the upstream manual setup](https://github.com/standardagents/t1bridge/blob/main/docs/setup.md)
for current installation/removal details. Avoid combining its modules with a
legacy `appleibridge` stack or competing configuration-selector services.

## 7. Optional sleep and keyboard work

Only after startup hardware works, read [sleep.md](sleep.md) to decide whether
the experimental undocked workaround suits your use. It still has slow wake
and unresolved battery retention. The separate [Touch Bar hook](touchbar.md)
recovers the display in our recorded short cycles, including after a reboot.

The optional `platform/apple-spi-keyboard.quirks` marks the SPI keyboard as
internal because ours reported vendor `0000` and missed libinput's stock Apple
rule. That may improve disabling the touchpad while typing. Merge this stanza
into `/etc/libinput/local-overrides.quirks` rather than replacing other quirks,
validate it with `libinput quirks validate`, and test after a new graphical
login. We verified rule matching; the owner reports much better behavior with
occasional focus changes. `input.follow_mouse = 1` had been re-enabled locally;
we restored `0` on October 9 so pointer motion cannot ordinarily steal keyboard
focus. Natural scrolling and `disable_while_typing = true` remain enabled.
This is a personal focus preference, separate from the device classification
fix. Extended typing validation is still needed. See [the review](review.md).

We did not add `pcie_ports=compat`, change GPU selection, install a replacement
kernel or apply a T2-specific display recipe. This guide describes the working
combination we tested; features reported on other models need separate evidence.
