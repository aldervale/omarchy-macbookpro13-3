# Status and upstream plan — October 20, 2026

On this MacBookPro13,3, the experimental ACPICA correction reduced visible wake
from 17–18 seconds to about one second. T1Bridge PR #47 restored the Touch Bar
without our separate userspace unpark hook. **Battery retention remains broken.**
These are results on one machine, not a general release or a complete sleep fix.

## What has been physically tested

- **Touch Bar:** seven directly observed display/Fn recoveries with
  [T1Bridge #47](https://github.com/standardagents/t1bridge/pull/47) at
  `d43d2c52d965ce0ee495e311a6cf982ab6cc9b4f`. Four were on the original kernel,
  including two after a packaged reboot; three were on the ACPI trial kernel.
  The separate unpark hook was disabled. Earlier live-swap attempts included
  aborted suspends on both stock and trial drivers and are not counted as passes.
- **Wake speed:** three attended recoveries across two boots of
  `7.2.5-3-omarchy-acpi-trial`. The first was reported as about one second,
  the second as nearly immediate; the third passed without a numerical timing.
  The latter two included 15 minutes asleep on battery.
- **Kernel evidence:** before the correction, all 200,160 traced ACPI mailbox
  reads at register `0x530` targeted host bridge `00:00.0`, and two Thunderbolt
  bridge callbacks accounted for 17.65 seconds of a 17.86-second noirq resume.
  The corrected kernel has not yet had an equivalent address/timing trace.
- **Retained dependencies:** model-specific EC lid wake, guarded s2idle and
  Thunderbolt unload/reload remain in use. Recovery tests were undocked.
  Controller bindings returned; external port functionality is not validated.
- **Battery:** saved history shows nearly full charge falling to 0% across
  about five hours of confirmed suspend on October 15. A short automatic test
  confirmed successful sleep but showed charge estimates increasing across
  sleep and falling in steps afterward. It does not establish sleep watts.
  The critical-battery suspend-then-hibernate path also lacks a recorded
  completion and bypasses the ordinary MacBook suspend hooks.

The local kernel builds the correction from
[ACPICA #1235](https://github.com/open-acpica/acpica/pull/1235), carried by
[omarchy-pkgs #544](https://github.com/omacom/omarchy-pkgs/pull/544), on the
existing `7.2.5-3` recipe. It is **not** a test of #544's exact newer package
recipes or its BORE variant. Kernel, headers and the installed DKMS modules
built successfully. The original kernel remains available for rollback.

See [findings](findings.md) for dates, measurements and limitations.
Until battery retention is fixed and validated, shut down for long unplugged
periods and transport.

## Atomic contributions

| Area | Destination and present status | Remaining gate |
| --- | --- | --- |
| Keyboard classification / touchpad typing suppression | Two local proposals: the model-scoped libinput quirk in Omarchy and its ownership in the companion settings package | Rebase, complete source/package checks and extended typing validation |
| Lid wake and suspend | Local opt-in Omarchy proposal for EC wake, guarded s2idle and controller cleanup | Full final-branch checks, attended split-installer/removal validation and unresolved power/recovery behavior |
| Touch Bar display recovery | Contribute hardware evidence to existing T1Bridge #47; hold our separate display-hook PR | Broader/long-sleep testing and upstream driver delivery; do not ship duplicate recovery by default |
| Resume latency | Contribute evidence to existing ACPICA #1235 and downstream kernel carry #544 | Maintainer review and validation of the actual downstream recipes; corrected-address trace would strengthen our report |
| Battery retention / critical power | Separate investigation, with evidence in this repository | Identify the cause and validate a fix before choosing its upstream code destination |

These are five work areas, not a promise of five PRs. Keyboard source and
packaging need separate changes; other areas already have upstream proposals.
The existing [Omarchy draft #14894](https://github.com/omacom/omarchy/pull/14894)
preserves the earlier combined proposal and stays a draft. New code submissions
wait for the full applicable test gate. Documentation and hardware reports can
be published while those gates remain open.

The last complete baseline run used Omarchy `77bfaca`, companion packages
`7aa7343` and ISO sources `4f4b3e3`. After environment-specific reruns, three
baseline failures remained: a Grok assertion mismatch, package removal lifecycle
and polkit file ownership. This is a report of those pinned revisions, not a
claim about today's upstream head. Final atomic branches still need their own
complete runs and package checks. Missing CI results and skipped tests are not
passes. [The review](review.md#test-gate-and-current-blockers) records the detail.

## Work order

1. Publish the evidence and limitations here, update the existing Omarchy draft,
   and report the driver/kernel results in their existing upstream discussions.
2. Recheck upstream source/package bases and resolve the atomic test gates;
   finish the keyboard source/package pair first.
3. Investigate battery retention and emergency recovery before expanding the
   suspend contribution's validation. Keep a corrected-address trace separate
   from any power-policy experiment.
4. Submit each code change only after its own required checks and physical
   validation pass. Retire redundant userspace recovery when the driver path
   is sufficiently validated and available.

The security review also repaired local audio DKMS source ownership and hardened
the published installers. Click-to-focus was restored locally; extended typing
validation remains pending. Wi-Fi, audio and conditional T1 firmware recovery
remain documented community prerequisites rather than automatic new installers.
