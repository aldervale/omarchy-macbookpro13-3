# Touch Bar recovery after s2idle

On this MacBookPro13,3, the Touch Bar stayed dark after sleep even though touch
zones and the renderer still worked. A single HID feature report relit it;
Fn then changed the visible icons. Two manual recoveries and four automatic
recoveries were owner-confirmed on October 9, including a sleep cycle after a
full reboot. This does not establish support for other models or deep/S3 sleep.

## What the hook does

The T1Bridge 0.1.12 display driver parks the panel during suspend. Our helper
discovers production T1 USB `05ac:8600`, configuration 2, interface 6; verifies
the reviewed report descriptor and the opened hidraw device; and reads report
3. If mode is 1 (parked), it sends one 15-byte report with mode 2 and transition
value 500. Mode 2 is left alone. Unknown states or identities are refused.
Readback follows a 0.6-second settling pause; it cannot prove illumination.

The wrapper runs after successful suspend and controller cleanup. It has an
8-second timeout and 2-second kill grace; failure is logged without failing
the suspend service. A process timeout cannot guarantee termination of a
kernel operation stuck in uninterruptible sleep. No ACPI method, firmware
recovery, USB reset, rebind or service restart is involved.

The tested write took approximately 12 ms; the complete hook took about
0.74 seconds. The separate 12.7-second kernel noirq phase dominates wake time.

## Install

Requires the [existing undocked sleep workaround](sleep.md), T1Bridge 0.1.12
and Python 3. Read the sources first. From this repository root:

```bash
# Sysfs-only preflight; does not open hidraw or send a report:
python3 -I touchbar/unpark.py
sudo bash install-touchbar.sh install
```

The installer refuses existing targets, active suspend, pending cleanup and
the old runtime trial. It does not upgrade a working installation or initiate
sleep. It installs root-owned files under `/usr/local/libexec/macbook-touchbar`
and the `70-macbook-touchbar-trial.conf` suspend-service drop-in, then checks
ordering and records file hashes. The historical basename is retained to avoid
accidental coexistence with earlier hooks.

Perform an attended lid cycle with empty external ports. Check visible icons,
Fn changes and touch actions separately, then repeat after a full reboot.
Check the service journal for one recovery invocation per successful cycle.

```bash
journalctl -b -u systemd-suspend.service --no-pager
```

Do not repeatedly send commands to an unidentified or unresponsive device.
Review the failure instead. Firmware regeneration is not a resume remedy.

## Remove

```bash
sudo bash install-touchbar.sh remove
```

Removal verifies installed hashes and leaves the EC/Thunderbolt workaround
installed. Remove this hook before removing that controller workaround.
Edited or partial installations require inspection instead of forced deletion.

## Evidence and upstream scope

The installed driver was checked against T1Bridge commit `81cbdf8` (0.1.12).
Its suspend callback writes the park report; the reviewed resume path has no
matching explicit unpark. That is a source observation, not proof of a universal
driver fix. Other models and S3 have reported different results in
[T1Bridge issue 18](https://github.com/standardagents/t1bridge/issues/18).
Our result is specifically **13,3 + s2idle + unpark alone**, without SOCW.

The eventual driver-level fix belongs with T1Bridge. This repository supplies
the bounded workaround and reproducible evidence while that is investigated.
