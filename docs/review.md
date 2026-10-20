# Review: October 9–13, 2026

This review covers the published repair code and instructions, the local
installation scripts, installed hooks and permissions, keyboard settings,
and selected upstream driver/source paths. It is not a security certification
of the Linux kernel, Apple firmware or all dependencies in T1Bridge/audio.

## Security and simpler implementation

- **Repaired audio DKMS source ownership.** Our original `cp -a` preserved the
  regular account's ownership under `/usr/local/src/snd_hda_macbookpro`.
  `/usr/src/snd_hda_macbookpro-0.1` points there; its DKMS `PRE_BUILD` runs a
  script from that tree as root. An unprivileged process with access to that
  account could alter a later privileged rebuild. The 40 non-Git source files
  matched the original checkout. The durable tree is now root-owned; a full
  metadata check found no non-root-owned or group/other-writable entries.
  This is a permissions repair, not evidence of prior exploitation. The setup
  guide now avoids preserving ownership and includes remediation.
- **Installer checks now fail closed.** A failed systemd query or any state
  other than `inactive` stops installation/removal. Sleep removal compares
  hashes for the known target files instead of accepting whichever paths a
  manifest lists. Tests exercise these refusal cases without administrator
  privileges or live sysfs changes.
- **Touch Bar installation is smaller.** The public installer is 72 lines,
  versus 116 in the private persistent installer. It removes migration of
  the retired runtime trial; existing targets and trials are refused. The
  device-identity guards, one-write recovery, timeout and cleanup order remain.
  Tests add code to the repository, but the shipped installer is smaller.
- **Recovery checks its result.** The published HID helper now reports failure
  if readback still says parked, without retrying. The installed, physically
  validated helper is retained; this new negative-path check is mock-tested.
- **No private hardware data is included.** Firmware, FDR/restore data, board
  NVRAM with a host MAC, raw ACPI tables and raw journals remain outside this
  repository. The ignore rules also exclude common credential/build artifacts.
  Review staged files before every publication; ignore rules are not a secret
  scanner or an access-control mechanism.
  The private repair working directory is now mode `0700`, so other local
  accounts cannot traverse its diagnostics and recovery working files.

The systemd hooks and EC module remain privileged hardware workarounds. Their
model checks constrain compatibility; USB IDs and descriptor hashes are not
cryptographic authentication of hardware. Local installers run reviewed source
as root once, then install root-owned runtime files. Do not run a checkout that
another user can alter. Existing package signing requirements were retained;
this work adds no PAM rules or passwordless administrator permissions.

## Touchpad and keyboard focus

The installed Apple SPI keyboard rule matches `AttrKeyboardIntegration=internal`.
The touchpad retains its Apple palm-size and touch-size quirks. Live Hyprland
had typing suppression enabled but `follow_mouse = 1`; our older repair record
had set it to `0`. That drift directly permits ordinary pointer motion to
change keyboard focus. We restored `0`, kept natural scrolling and typing
suppression, reloaded Hyprland and confirmed no configuration errors.

The owner reports mostly good touchpad behavior with occasional focus changes.
The new click-to-focus setting needs a normal typing check. If focus still
jumps, distinguish an accidental click from pointer motion; do not keep
adjusting unrelated sensitivity values. Libinput deliberately leaves physical
buttons active during typing, and modifier keys such as Ctrl/Alt/Shift/Fn do
not trigger its typing timeout. See [libinput's documented behavior](https://wayland.freedesktop.org/libinput/doc/latest/palm-detection.html#disable-while-typing)
and [Hyprland's focus settings](https://wiki.hypr.land/Configuring/Basics/Variables/#input).

Libinput 1.31.3 source also confirms the classification mechanism: its
[keyboard tagging](https://gitlab.freedesktop.org/libinput/libinput/-/blob/1.31.3/src/evdev.c)
uses the integration quirk, and [touchpad pairing](https://gitlab.freedesktop.org/libinput/libinput/-/blob/1.31.3/src/evdev-mt-touchpad.c)
requires that internal-keyboard tag for an internal touchpad. This supports
fixing the vendor-zero rule rather than adding a background input-monitoring
daemon.

## Wake performance: localized, not yet improved

October 13 update: repeated stock and #47 trials now show approximately
17.5 seconds in noirq resume, chiefly two bridge callbacks taking about
8.6–8.8 seconds each. The owner consistently measured 17–18 seconds to the
screen. The earlier measurements below remain historical results; the system
has not become faster. [Kernel packaging PR #544](https://github.com/omacom/omarchy-pkgs/pull/544)
is a candidate to investigate separately, not a validated fix on this 13,3.

Two recent traces measured about 6.24 seconds in each of two Alpine Ridge
`8086:1578` upstream bridges' `pci_pm_resume_noirq` callbacks. With callbacks
serialized, total noirq resume was 12.684 and 12.690 seconds. The owner timed
visible wake at about 13 seconds in both cycles. The Touch Bar hook ran later
and took about 0.74 seconds; these intervals use different boundaries.

Source review narrowed the next investigation to bridge power restoration
versus PCI configuration restoration. Private ACPI inspection found polling
and retry paths in both bridges' `_PS0` routines. That is a candidate explanation,
not a timing measurement of a particular firmware method. The matching Linux
[PCI PM callbacks](https://github.com/gregkh/linux/blob/v7.2.5/drivers/pci/pci-driver.c)
call power restoration and configuration restoration; a function trace during
an attended wake can distinguish them. Do not shorten generic kernel timeouts
or call ACPI reset methods based solely on the six-second number.

A second controlled experiment can change only callback concurrency: retain
the peripheral guards, EC module, s2idle, Thunderbolt unload/reload and Touch
Bar hook, but set `pm_async=1` after preparation for one cycle. Independent
bridge delays might overlap; firmware serialization may prevent that, and
earlier controller failures could return. A runtime-only trial is staged
privately, **not installed or physically validated**. Measure the same
boundaries and remove it immediately if devices fail or wake gets worse.
No improved wake-time or power-use result is claimed.

Disabling bridge D3cold or removing/rescanning PCI devices changes power or
device behavior more substantially. Those are not part of this revision.
The existing NVMe setting is correctly applied to the SSD rather than the GPU,
but its necessity on this Samsung-equipped 15-inch model is unproven. A future
controlled removal test may allow retiring it. Keep that separate from wake
concurrency so the result can be interpreted.

## Community comments and upstream work

The suggestion was to turn reproducible fixes into pull requests against
Omarchy so other users receive them. Publishing this guide records the work;
it does not put the changes in Omarchy. The audio comment points to the same
community driver we used. The agent-provider suggestion is about tools used
to investigate, not a hardware requirement. The t1-revive remark acknowledges
that firmware recovery worked here; it does not imply everyone needs recovery.

As checked for this review, related upstream work already exists:

| Work | Existing upstream discussion/PR | Relevance |
| --- | --- | --- |
| NVMe targeting | [#11624](https://github.com/omacom/omarchy/pull/11624), [#12687](https://github.com/omacom/omarchy/pull/12687) | Both open; narrow Apple-controller applicability is being reviewed, so our dynamic targeting is not proof that every NVMe needs this setting |
| Thunderbolt resume | [#11570](https://github.com/omacom/omarchy/pull/11570), [#9899](https://github.com/omacom/omarchy/pull/9899) | Open; primarily S3 work with different device-removal strategies, not validation of our s2idle combination |
| BCM43602 5 GHz board file | [#7671](https://github.com/omacom/omarchy/pull/7671) | Open; availability of a PR does not mean the fix ships |
| T1 display resume | [T1Bridge #18](https://github.com/standardagents/t1bridge/issues/18) | Appropriate home for driver-level park/unpark evidence; models and sleep states have differing results |

Our existing [draft Omarchy PR #14894](https://github.com/omacom/omarchy/pull/14894) contains the earlier combined proposal. It remains a draft at `4c02255`. The next revision is being prepared as atomic contributions, with no new submissions or pushes until the test gate passes:

| Contribution | Scope and dependency |
| --- | --- |
| Keyboard classification | A model/device-scoped libinput quirk in Omarchy; a companion settings-package change owns the database file. The proposed hardware installer and migration were removed. |
| Lid wake and suspend | Optional EC wake module, guarded s2idle/Thunderbolt sequence, DKMS installation and removal; independent of the keyboard change. |
| Touch Bar after sleep | Hold the separate display-hook contribution: #47 has four observed recoveries without it, including two after a packaged reboot. Prefer the driver fix if broader validation and upstream delivery succeed. |
| NVMe target correction | Coordinate with existing PR #11624 instead of opening a duplicate. The setting's necessity on this Samsung-equipped model remains unproven. |
| Wi-Fi, audio, T1 recovery and personal focus policy | Keep the complete setup and evidence in this repository. Firmware recovery and third-party driver installation are not automated by these contributions. |

The hardware fixes have separate review boundaries. Keyboard classification needs source and packaging changes in two repositories; together with sleep, these are three planned PRs. The fourth, for the display hook, remains on hold while the driver fix is evaluated. The static quirk matches only the observed model, SPI keyboard and vendor ID; shipping it through the settings package does not enable it on other hardware. It preserves administrator local overrides and avoids creating an unowned file under `/usr`. The source proposal shrank from 88 added lines to 37, including its tests.

The sleep and Touch Bar installers own separate manifests and ordered drop-ins. The Touch Bar installer refuses a missing sleep dependency; sleep removal refuses an installed display hook. Fixtures exercise both actual installers together, including the correct removal order. A failed DKMS removal leaves the sleep installation intact so removal can be retried. The copied recovery payload retains GPL-2.0-only, with its own license and provenance. Neither sleep nor Touch Bar recovery is automatically enabled.

### Test gate and current blockers

The atomic branches are based on Omarchy `77bfaca`. Keyboard matching and libinput parser validation pass. The sleep contribution passes 28 fixture tests; the Touch Bar contribution passes 20, including installation/removal of both components. The Omarchy CLI checks pass on the prepared hardware branches. The companion packaging fixture exercises both settings recipes on x86_64 and aarch64 with older sources and sources containing the new quirk; it passes. These tests use temporary files and mocks, not host suspend or device writes.

A full run against **unchanged upstream** completed all 370 shell test files and the CLI suite. The CLI suite passed; ten shell files failed and 31 contained skipped checks. Seven of those failures subsequently passed unchanged in an appropriate clean environment: the original failures involved read-only fixture mounts, missing companion ISO sources, namespace ownership or system time-service access. Headless skips remain unexecuted coverage, not passes.

Three source/packaging failures remain on that unchanged baseline:

- `default-agent-test.sh` expects `mise unuse -g`, while the existing Grok migration calls `mise unuse -y -g`. A separate local assertion correction passes its focused test; it is not mixed into the hardware branches.
- `passwordless-grant-lifecycle-test.sh` requires removal hooks missing from the current companion settings packages. [omarchy-pkgs PR #257](https://github.com/omacom/omarchy-pkgs/pull/257) proposes the related lifecycle work but is not merged into the tested package base.
- `unowned-system-paths-test.sh` identifies USB/Thunderbolt polkit files that the current package recipes do not own. The earlier keyboard draft added another unowned path; the new package-owned design removes that regression. The four baseline polkit reports remain.

These results use `omarchy-pkgs` at `7aa7343` and `omarchy-iso` at `4f4b3e3`. No tests or ownership checks were disabled to obtain a passing result. The full suite is **not green**, and complete full-suite runs on each final atomic branch remain a submission gate after resolving the baseline issues. Packaging builds and their required CI checks also remain gates; the existing draft has no reported CI checks, which does not establish passing tests.

The underlying hardware sequence has the recorded physical results; the new split installation still needs an attended installation/removal test. The original display hook is retained on disk and disabled for the #47 comparison. The local #47 package passed startup and two sleep/recovery cycles after a full reboot, followed by one successful cycle on the ACPI trial kernel; this is separate from the Omarchy installer tests. That latest attended cycle took about one second to illumination, per the owner. Repeated fast-wake testing, extended typing and port functionality after wake remain outstanding; operation remains undocked-only.

Saved history reviewed October 19 shows severe battery depletion across about five hours of confirmed closed-lid suspend on October 15. The emergency suspend-then-hibernate path bypasses the installed MacBook hooks and has no recorded completion. Battery retention and compatible critical-power handling are unresolved hardware gates. No improved battery result is claimed.

A subsequent read-only mailbox trace counted 200,160 ACPI PCI reads at offset
`0x530`, all targeting host bridge `00:00.0`. This supports the address-derivation
fault described in #544. The trace was removed and its logging settings restored.
A separate kernel carrying the correction subsequently passed the first attended
fast-wake test; no corrected-address trace has yet been captured. See
[the updated results and limits](findings.md).
