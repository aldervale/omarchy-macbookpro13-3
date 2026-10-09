# Experimental undocked sleep workaround

**Expect roughly 10–15 seconds to wake. The Touch Bar lights at startup but
its display stays dark after resume, while touch input still responds. Battery
retention is unresolved.** This is an optional partial workaround for
`MacBookPro13,3`, tested on `7.2.5-3-omarchy`.

## What it does

Before suspend, the helper checks the model, two bound Alpine Ridge NHI/xHCI
controller pairs and absence of external peripherals. It requires EC wake
policy and lid wake permission to be enabled. It then:

1. Loads our EC wake-capability module with `apply=1`.
2. Selects `s2idle` and saves `pm_async`.
3. Temporarily sets synchronous device callbacks (`pm_async=0`).
4. Unloads the `thunderbolt` module.
5. Lets systemd perform suspend.
6. Restores `pm_async` and reloads Thunderbolt with `host_reset=0` after wake,
   or after a failed preparation step.

The EC module checks Apple/model identity and ECDT GPE `0x07`. Under the kernel's
system sleep lock it checks whether the GPE is wake-capable, preserving the
existing wake-mask bit. Only a missing capability (`AE_TYPE`) calls
`acpi_ec_mark_gpe_for_wake()`; a follow-up check verifies the result.
An already wake-capable EC is left as-is. Unloading the module alone does not
undo the capability mark; reboot clears it.

`s2idle` and `deep` are different sleep states; see the
[Linux sleep-state documentation](https://docs.kernel.org/admin-guide/pm/sleep-states.html).
Choosing `s2idle` does not establish acceptable power draw.

## Constraints

- **Undocked only.** External USB, Thunderbolt devices and displays cause
  preflight to fail and that suspend to be aborted. A direct charger is allowed.
  Do not close the lid expecting sleep with a dock attached.
- Driver binding recovery is observed; functional external ports after resume
  still need a hardware test.
- Installation on other models is refused. Future kernels need a successful
  module build and new hardware validation.
- A competing suspend hook, alternate sleep policy or custom lid handling needs
  review before installing. Suspend refusal can leave a closed laptop awake.
- A reboot/shutdown is currently the confirmed way to return to the working
  startup state. Service restarts did not establish Touch Bar illumination recovery.

## Install on a clean setup

Read `install-persistent-sleep.sh` and the helper first. The installer is the
same source used on our machine, without an automatic reinstall/upgrade mode.
It refuses to overwrite existing target files. If you already have this
workaround installed, keep it and compare versions instead of reinstalling.

Verify matching headers, DKMS, enabled lid wake and EC policy:

```bash
ls -ld /usr/lib/modules/"$(uname -r)"/build
command -v dkms
cat /sys/bus/platform/devices/PNP0C0D:00/power/wakeup
cat /sys/module/acpi/parameters/ec_no_wakeup
systemctl cat systemd-suspend.service
systemd-analyze cat-config systemd/sleep.conf
bash persistent-sleep/macbook-suspend check
```

Expected lid wake is `enabled`, EC policy is `N`, and preflight passes with
ports empty. A `[deep]` selection in `/sys/power/mem_sleep` after boot is not
itself a failure: the pre-hook selects `s2idle` before sleep. Both `s2idle` and
`deep` must remain available as appropriate to the kernel/hardware.

Our original installer retained a separately installed systemd sleep-policy
file. This repository includes it explicitly. If
`/etc/systemd/sleep.conf.d/60-macbook-s2idle.conf` already exists, inspect it;
keep an identical/equivalent setting and do not overwrite a conflicting policy.
On a clean setup where that path does not exist:

```bash
sudo test ! -e /etc/systemd/sleep.conf.d/60-macbook-s2idle.conf && \
  sudo install -Dm644 persistent-sleep/60-macbook-s2idle.conf \
    /etc/systemd/sleep.conf.d/60-macbook-s2idle.conf
sudo bash install-persistent-sleep.sh install
```

If the policy file existed, skip that first command and run the installer only
after reviewing the policy. If installation fails after adding the policy,
remove only the policy file you just added or restore your previous setting.

The installer builds/installs DKMS package `macbook-ec-wake/0.1`, adds
`/usr/local/sbin/macbook-suspend` and the systemd service drop-in, reloads
systemd, verifies the effective hooks and writes a hash manifest. The drop-in's
`60-macbook-thunderbolt-trial.conf` name is retained so it overrides our old
same-named runtime trial rather than running both sets of hooks.

It does not initiate sleep or reboot. DKMS requests future kernel rebuilds;
that is not a guarantee of future compatibility.

## Verify on hardware

Save work, disconnect peripherals, and start with one attended two-minute lid
cycle. Open the lid without touching a key. Measure time until the screen is
usable, then check Wi-Fi, keyboard/trackpad, speakers, controller bindings and
Touch Bar display/input separately. If no response after 30 seconds, press
Shift once and record that manual intervention.

Read the actual suspend entry/exit and hook records. Do not interpret a
successful service exit or an active T1 renderer as proof that everything
recovered. Follow [validation.md](validation.md) before longer battery tests.

## Remove

From the repository root:

```bash
sudo bash install-persistent-sleep.sh remove
```

The manifest check refuses removal if tracked installed files were edited.
Reboot after removal to clear the EC wake mark and loaded module state. Removal
leaves the separate `60-macbook-s2idle.conf` policy in place, matching our
original rollback. To fully revert a clean installation, also remove that file
**only if you added it from this repository**, or restore the policy you backed
up. Removing the policy returns to the preexisting sleep policy; our original
deep-resume failure can then recur.

The helper removal does not remove audio, Wi-Fi, NVMe, keyboard or T1Bridge
changes. During a boot containing our older `/run` trial, removal can expose
that runtime drop-in until reboot.
