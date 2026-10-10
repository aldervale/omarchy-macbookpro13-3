# Review: October 9–10, 2026

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

Our [draft Omarchy PR #14894](https://github.com/omacom/omarchy/pull/14894)
covers the complete MacBookPro13,3 setup, including code for the sleep and
Touch Bar workarounds. Its scope is:

| Component | Proposed Omarchy contribution |
| --- | --- |
| Keyboard typing suppression | Model/device-scoped libinput quirk, hardware install leaf and migration |
| Lid wake and suspend | EC wake module, guarded s2idle/Thunderbolt sequence, DKMS installation and removal |
| Touch Bar after sleep | Validated one-write unpark sequence after successful controller cleanup |
| Optional setup | `omarchy setup macbookpro13-3 check\|install\|remove`, with confirmation, a sleep inhibitor and one ordered systemd drop-in |
| NVMe target correction | Included sysfs-based helper and explicit installation/rollback instructions; necessity of the setting remains unproven |
| Wi-Fi, audio and T1 startup/recovery | Integrated guide with source versions, third-party prerequisites, ownership repair and firmware recovery boundaries |

The combined installer replaces the separate sleep and Touch Bar installers
for the proposed Omarchy integration. It also owns the s2idle policy, refuses
existing or competing installations and checks effective recovery order and
sleep settings. The copied recovery payload retains GPL-2.0-only, with its own
license and provenance. The keyboard quirk is eligible for normal installation;
the experimental sleep sequence requires an explicit opt-in and is never
enabled by the migration.

The draft does not automatically run third-party Wi-Fi, audio or firmware
installers. These remain documented setup dependencies. Personal focus policy
stays in user configuration; the keyboard quirk does not fix every accidental
physical click.

The stock libinput database returned no keyboard-integration quirk in an
explicit `--data-dir /usr/share/libinput` query; the candidate returned
`AttrKeyboardIntegration=internal`. Both queries excluded local overrides.
The focused keyboard installation/migration fixture and quirk parser checks
pass. The expanded draft also passes 34 recovery, installer, CLI-dispatch and
NVMe-targeting tests, the Omarchy CLI suite, Bash syntax and systemd directive
verification. Tests use isolated files and mocks; they do not suspend the host.

The earlier complete Omarchy test run passed its CLI suite but reported 19 failures
among 370 shell test files, plus headless skips. Missing companion package
sources and sandbox/UI restrictions affected that run; one socket-related
failure passed outside the sandbox. The draft does not claim a green full suite.

The underlying sequence has the recorded physical results; the new combined
installer still needs an attended hardware installation test. The installed
working hooks on the owner's machine were not replaced by this contribution.
The draft remains open for that validation, extended typing and battery tests,
and maintainer review. About 13-second wake and undocked-only operation remain
explicit limitations; no faster wake or improved battery result is claimed.
