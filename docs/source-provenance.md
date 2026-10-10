# Source provenance

The initial publication at commit `636250c` copied these nine files byte-for-byte
from the tested local repair work on 2026-10-09. The hashes below describe that
initial publication, not later revisions. Paths in the middle column are
relative to the private repair directory; that directory is not published.

| Repository file | Repair source | SHA-256 |
| --- | --- | --- |
| `install-persistent-sleep.sh` | `install-persistent-sleep.sh` | `cb060bb1a7f37460e91752c59ea5a0f289ecf4b90cf8d8a185c708bb573c65e2` |
| `ec-wake-trial/macbook_ec_wake_trial.c` | `ec-wake-trial/macbook_ec_wake_trial.c` | `0b936b84c806a02e04e12329aa72b9ef84b4d85fec2fb8c443897848ca379a10` |
| `ec-wake-trial/Makefile` | `ec-wake-trial/Makefile` | `9f8088a5a96fd3a6fe054cf271c5f4c5c64a47ef215f778dec03b98faf25293c` |
| `persistent-sleep/macbook-suspend` | `persistent-sleep/macbook-suspend` | `6445aac3e2f91ad5d48a75d65be954229eadb9974e16ea422a6c156e5c0414a2` |
| `persistent-sleep/dkms.conf` | `persistent-sleep/dkms.conf` | `8def30f39cadd259866b8ceabd8f94f30d6923dcf9b9df36f5596717cac510ca` |
| `persistent-sleep/60-macbook-thunderbolt-trial.conf` | `persistent-sleep/60-macbook-thunderbolt-trial.conf` | `89c9f1d929453bbeca1c7dd6a8f08fb300e43ef58b438b9d5049bae0ae759ae8` |
| `platform/macbook-nvme-suspend-fix` | `staged/macbook-nvme-suspend-fix` | `033bb3ef4a908a99f1d4fc05d3814af1ec2b002c5589b842a1a9201b06dc7a11` |
| `platform/nvme-override.conf` | `staged/nvme-override.conf` | `043c963ef846a972e9e05341820ddb523dc60b8dba0d6f5d822670c82bb01900` |
| `platform/apple-spi-keyboard.quirks` | `staged/apple-spi-keyboard.quirks` | `8d7a0ff6c43bae663e5c0068f6b112953fdcb90a8a8d0ca6540f2bca1eac0d7d` |

The module already declares `GPL-2.0-only`. Repository-authored scripts and
documentation are distributed under GPL-2.0-only; see the root LICENSE.

The s2idle configuration, diagnostic script and isolated tests were prepared for
this public repository. Validation of those files is recorded in
[validation.md](validation.md). Firmware, NVRAM containing a host MAC address,
packages, raw journals and T1 restore data are not included.

## October 9–10 review changes

`install-persistent-sleep.sh` now requires a successful inactive-state query
and compares the removal manifest against the expected file list. Its hash
therefore differs from the original above; the installed sleep helper and EC
module are unchanged.

`touchbar/unpark.py` derives from the physically tested private
`unpark-touchbar-once.py`. Device discovery, descriptor checks, ioctl values,
single-write payload and timing are unchanged. Besides public wording, the
published version adds a failure result if readback still reports parked.
That additional negative-path check is tested with mocks, not a new physical
recovery run. The installed host still uses the previously validated copy.

`touchbar/resume` and its drop-in are copied from the validated persistent
hook. `install-touchbar.sh` is a smaller fresh-install/removal implementation;
it omits migration of the retired runtime trial and refuses that state instead.
Installer fixtures do not constitute a live deployment test.

## Omarchy integration draft

[Omarchy PR #14894](https://github.com/omacom/omarchy/pull/14894) now includes
the sleep and Touch Bar recovery payload, the keyboard quirk, NVMe helper and
full setup guide. Integration commit
[`4c02255`](https://github.com/aldervale/omarchy/commit/4c02255)
copies the payload from this repository at `ff11b52`, retaining GPL-2.0-only
and a directory-local license.

The EC module, DKMS configuration, s2idle policy and HID helper are unchanged.
The Makefile drops a trailing blank line; shell shebangs follow Omarchy's
convention. Runtime helpers use a new root-owned directory. One 119-line
installer replaces the two separate installers (159 lines combined), installs
an ordered controller/display drop-in and includes the sleep policy in removal.
It refuses existing installations instead of migrating the working host.

The expanded draft passes 34 isolated tests, the keyboard install/migration
checks, Omarchy's CLI suite and syntax/unit checks. Its EC module builds with
`W=1` against `7.2.5-3-omarchy`. The new combined installation has not had a
physical hardware test, and the original working host hooks were not replaced.
