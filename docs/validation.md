# Validation

Software checks establish syntax, buildability and guard behavior. They do not
establish battery retention, panel illumination or reliable physical resume.

## Repository checks

From the root, without administrator privileges:

```bash
for script in install-persistent-sleep.sh persistent-sleep/macbook-suspend \
  platform/macbook-nvme-suspend-fix scripts/status.sh install-touchbar.sh touchbar/resume; do
  bash -n "$script" || break
done
python3 -m unittest discover -s tests -v
```

The tests run the sleep helper against temporary sysfs fixtures and fake
modprobe commands. They cover peripheral refusal, model/controller checks,
first-suspend selection from `deep`, EC-load failure and cleanup after a
failed Thunderbolt unload. They cannot sleep the machine or change live sysfs.

To check the module against your running kernel in an isolated build directory:

```bash
build_dir=$(mktemp -d -t mbp13-3-build.XXXXXX)
cp ec-wake-trial/Makefile ec-wake-trial/macbook_ec_wake_trial.c "$build_dir/"
make -C /usr/lib/modules/"$(uname -r)"/build M="$build_dir" W=1 modules
```

This compiles without installing/loading the module. On October 9, 2026, the
publication checks passed on `7.2.5-3-omarchy`: shell syntax, all 13 isolated helper
tests, a `W=1` module build and local document-link checks. The published helper,
installer and EC source matched the original repair copies byte-for-byte.
The copied installer was not run against the live machine during publication.

The October 9–10 review passed 28 isolated tests covering the existing sleep
helper, Touch Bar report validation and single-write behavior, opened-device
identity checks, resume guards, installer rollback and manifest/state refusal.
Six shell files passed individual `bash -n` checks. The published Touch Bar
sysfs-only preflight passed on this host without opening a device node. These
checks do not replace a fresh hardware test of the new installer/readback check.

The October 20 documentation publication reran all 28 isolated tests and the
six shell syntax checks successfully. Relative document links/anchors and
`git diff --check` also passed. No runtime source changed in this publication.

## Short attended lid test

1. Save work, start from a healthy boot and disconnect all peripherals except
   an optional direct charger. Confirm preflight passes.
2. Record package versions, battery/AC status and whether the Touch Bar display
   is lit. Use `bash scripts/status.sh` for a status snapshot.
3. Close the lid for two minutes. Open it without a keypress and time the
   interval until the screen responds. If there is no response after 30 seconds,
   press Shift once and record it as a manual wake.
4. Check keyboard/trackpad, Wi-Fi, speakers and controller bindings. Record
   Touch Bar **display illumination** and **touch input** separately.
5. Inspect the local logs for actual `s2idle` entry/exit and completed cleanup.
   Repeat on mains and battery, including after a fresh boot.

Historically, with the optional Touch Bar hook, the display and Fn recovered automatically
in four owner-confirmed cycles, including one after a full reboot. Two recent
owner timings were **13 seconds** to visible wake. Without that hook, the
display remained dark despite working touch input. Record the actual behavior
and the installed helper revision; long sleeps and battery retention are still
unvalidated by those four cycles. Subsequent driver and kernel trials are
summarized in [the current status](status.md); severe battery depletion has
since been confirmed.

## Battery retention test

Do this after short cycles work. Start with a 30–60-minute undocked battery
test, attended at both ends, rather than another multi-day closed-lid run.

- Disconnect the charger and record time, charge percentage and available
  `energy_now` or `charge_now` values before closing the lid.
- After opening, record the same values and wake delay immediately.
- Check actual sleep duration and whether there were unexpected wake/resuspend
  events. A failed peripheral guard means the test did not enter this suspend.
- Continue recording while unplugged after wake, because the October 20 test
  showed delayed/abrupt charge-estimate changes. Separate awake time from sleep
  and do not treat an unstable immediate reading as sleep consumption.
- Report a loss rate only if the readings and interval support it. A drop of
  percentage points per hour differs from absolute energy loss; retain units
  with each value. Current short-test data do not establish sleep watts.

The status script prints available battery values without serial numbers. A
controlled discharge with confirmed suspend is needed before attributing drain
to the sleep state itself. Until then, use a full shutdown for long unplugged
periods and transport.

## Sharing a hardware report

Include model/kernel/package versions, whether AC or battery powered the test,
peripherals, actual time asleep, visible wake time, any keypress needed,
Touch Bar display/input results and battery values with units. Add a short
sanitized excerpt only when it supports a finding. Logs can contain hostnames,
network names, MAC addresses, user paths and identifiers; review them before
posting. Keep all Apple firmware, FDR data and restore logs private.
