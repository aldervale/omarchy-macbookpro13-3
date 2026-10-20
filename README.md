# Omarchy on MacBookPro13,3

A guide to the combination of fixes that brought a **2016 15-inch MacBook Pro
with Touch Bar and the Apple T1 chip** into daily use with Omarchy. It connects
existing community projects with our model-specific repair work and shares the
experimental lid-wake workaround.

**The experimental ACPI kernel reduced visible wake from 17–18 seconds to about
1 second in one attended October 14 test, with Touch Bar/Fn working through
T1Bridge PR #47 and the separate unpark hook disabled. Battery retention remains
broken:** saved history reviewed October 19 shows a nearly full battery falling
to 0% across about five hours of closed-lid `s2idle` on October 15.

This is a record of progress on one machine, with reproducible source and
instructions. It is not a complete suspend/resume fix or a general installer
for other MacBook models.

## Results on this machine

| Feature | Observed result | Remaining limitation |
| --- | --- | --- |
| Keyboard and trackpad | Working with in-tree `applespi`; internal-keyboard quirk matches | Occasional focus changes reported; click-to-focus restored, awaiting extended typing check |
| Wi-Fi | Working; 5 GHz association and both bands visible after board NVRAM installation | Internet routing was not separately isolated from Ethernet |
| Speakers | Working after CS8409 community driver installation | Microphone and headphone switching not separately tested |
| T1 firmware at startup | Recovered with `t1-revive`; survives a full shutdown/power-on | Keep a verified backup off this disk |
| Touch Bar after startup | Display lights and controls work with T1Bridge | Startup success does not establish sleep recovery |
| Touch Bar after sleep | Experimental #47 recovered display/Fn without the hook in five observed cycles, including one on the ACPI trial kernel | Long-sleep display recovery and broader reliability remain unvalidated |
| Lid-open wake | About **1 second** in one attended ACPI-kernel cycle; previously 17–18 seconds | Repeat fast-wake tests after fresh boots and on battery remain outstanding |
| USB-C/Thunderbolt controllers after sleep | Driver bindings recovered in recorded undocked cycles | External port functionality and docked sleep are unvalidated |
| Battery retention with lid closed | **Severe depletion across about five hours of confirmed suspend** | Device cause, precise sleep power and wake trigger remain unknown; emergency hibernation did not record completion |
| Camera | Detected by the driver | Capture untested here |
| Touch ID, Bluetooth and ambient light sensor | Not validated here | No fingerprint packages or PAM changes were part of this setup |

The visible wake estimates are owner reports. October 13 kernel traces measured
about **17.5 seconds in noirq device resume**, largely two Thunderbolt bridge
callbacks at about 8.6–8.9 seconds each. A later diagnostic counted 200,160
ACPI mailbox reads to host bridge `00:00.0`, supporting the wrong-address
mechanism described in [kernel PR #544](https://github.com/omacom/omarchy-pkgs/pull/544).
A separately named build of the same kernel with that correction passed the
October 14 attended wake test. No new per-bridge timing or corrected-address
trace was captured. Earlier traces measured about 12.67 seconds in that phase.
These measure different intervals from visible wake and should not be added
together. See [the evidence and chronology](docs/findings.md).

The sleep helper **refuses suspend while external USB devices, Thunderbolt
devices or displays are attached**. Disconnect them before a lid test; a direct
charger is permitted. A refused suspend can leave the laptop awake with its lid
closed. Until battery retention is fixed and validated, shut down for long unplugged
periods and transport.

## Start here

1. Read [the setup guide](docs/setup.md) for prerequisites, Wi-Fi, audio, the NVMe
   correction, conditional T1 firmware recovery and T1Bridge.
2. Read [the experimental sleep instructions](docs/sleep.md) before installing
   the optional EC module and suspend hooks. They include removal instructions.
   Then see [Touch Bar recovery](docs/touchbar.md) for the separate display hook.
3. Use [the validation guide](docs/validation.md) to measure wake time, Touch Bar
   behavior and battery loss. Hardware results and software checks are separate.
4. Consult [diagnostics](docs/diagnostics.md) for a small status report and local
   log commands.

The [October review](docs/review.md) records an audio-source ownership repair,
installer hardening, the touchpad review, wake experiments and their remaining
validation, and [draft Omarchy PR #14894](https://github.com/omacom/omarchy/pull/14894).
The existing draft contains the earlier combined proposal. Separate keyboard,
sleep and dependent Touch Bar contributions are now prepared locally, with a
companion keyboard packaging change. New submissions are held until the full
test gate passes; the review records the current upstream test blockers.
The split installers also need attended hardware validation.

Clone this repository:

```bash
git clone https://github.com/aldervale/omarchy-macbookpro13-3.git
cd omarchy-macbookpro13-3
```

Cloning does not install anything. There is no all-in-one setup command.

## Tested versions

Hardware work began September 27–29, 2026. Owner follow-up on October 5 confirmed
general lid wake, persistent Touch Bar display failure and closed-lid battery
depletion. Installed versions were checked again on October 9:

| Component | Version |
| --- | --- |
| Model | `MacBookPro13,3` |
| Omarchy | `4.0.4-1` |
| Kernel and matching headers | `linux-omarchy 7.2.5-3`; running release `7.2.5-3-omarchy` |
| DKMS | `3.4.3-2` |
| T1Bridge and kernel modules | `t1bridge 0.1.12-1`, `t1bridge-dkms 0.1.12-1` |
| Omarchy integration | `t1bridge-omarchy 0.2.2-1` |
| Firmware recovery used | `t1-revive 0.1.3`, commit `c2062f3` |

These are tested versions, not a claim that they are the newest releases or
that the same commands work unchanged on a future kernel.

On October 13, the controlled #47 trial was packaged locally as
`t1bridge-dkms 0.1.12.r47.d43d2c5-1` and installed for reboot validation.
Its four modules rebuilt successfully; the boot image and module selection
were verified. This is a local experimental package, not an official release.
The loaded module identity was verified after a full reboot. Startup and the
two subsequent lid-sleep cycles passed with the separate unpark hook
disabled; visible wake took about 18 seconds. The original signed package and
boot image are retained for rollback.

On October 14, the separately named `7.2.5-3-omarchy-acpi-trial` kernel booted
with the same #47 driver. Startup and one attended lid cycle passed; the owner
reported about one second to illumination with Touch Bar/Fn working. The
original kernel remains installed as a fallback. The October 15 battery
depletion happened on this trial kernel; faster wake does not establish lower
sleep power.

## Projects that made this possible

- [dzanaga/macbookpro-2016-2017-linux](https://github.com/dzanaga/macbookpro-2016-2017-linux):
  model-specific setup references and the BCM43602 board template.
- [nohzafk/omarchy-macbookpro-t1](https://github.com/nohzafk/omarchy-macbookpro-t1):
  T1/EFI, Wi-Fi, audio and legacy Touch Bar research, primarily demonstrated on a
  `MacBookPro14,2`. Its results are distinct from our `13,3` results.
- [niconistal/t1-revive](https://github.com/niconistal/t1-revive): the attended
  Linux firmware recovery used on this machine.
- [standardagents/t1bridge](https://github.com/standardagents/t1bridge): our
  installed T1 runtime, kernel drivers, Touch Bar renderer and Omarchy integration.
- [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro):
  the audio driver we installed through DKMS.
- [Omarchy discussion #4695](https://github.com/omacom/omarchy/discussions/4695):
  same-model reports that informed the EC wake and Thunderbolt experiments.

Our additions are the measured `13,3` results, guarded suspend sequence, EC
wake-capability module, Touch Bar recovery integration, NVMe target correction
and keyboard integration quirk.
See [credits and integration notes](docs/credits.md) and
[source provenance](docs/source-provenance.md).

## Contributing and license

Please include the model, software versions, connected peripherals, wake time,
Touch Bar display **and** input results, and measured battery loss in hardware
reports. See [CONTRIBUTING.md](CONTRIBUTING.md). The next priorities are battery
retention, faster wake and broader validation of Touch Bar recovery.

Repository code and documentation are GPL-2.0-only; see [LICENSE](LICENSE).
Referenced projects retain their own licenses. Apple firmware, device restore
data, host-specific NVRAM and raw private logs are not distributed here.
