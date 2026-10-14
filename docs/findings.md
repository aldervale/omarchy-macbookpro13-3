# Findings and limits of the evidence

This chronology summarizes our local repair notes and the owner's observations.
It contains no raw journals, machine identifiers, restore transcripts or
firmware. Times are approximate where the owner reported them.

## Update: Touch Bar recovery confirmed, October 9

The earlier dark-after-resume limitation below is superseded for the tested
configuration. One report-3 unpark restored illumination and Fn in two manual
tests. The automatic hook then recovered the display in four owner-confirmed
lid cycles, including one after a full reboot. The last two owner-timed wakes
were about 13 seconds each. See [the implementation and scope](touchbar.md).

Corresponding kernel traces measured 12,684.043 and 12,690.102 ms in noirq
resume. The two upstream bridge callbacks took 6,242.186 + 6,242.833 ms and
6,246.280 + 6,244.691 ms respectively. The complete Touch Bar hook took 0.738
and 0.739 seconds; its writes took 11.9 and 12.1 ms. Different timing boundaries
mean these numbers should not be added to the owner's estimates.

No SOCW call, USB reset, driver replacement or firmware regeneration was used
to recover the panel. Longer sleeps, battery retention and external port
function remain unvalidated. The [October review](review.md) records subsequent
security, focus and upstream work separately from physical sleep validation.

## Startup hardware, September 27

The initial Omarchy installation had missing T1 firmware, weak/unconfigured
Wi-Fi, missing speaker support, an obsolete unbuilt SPI driver package and an
NVMe workaround pointed at the discrete GPU. We installed a model-specific
BCM43602 board configuration and the community audio driver, corrected the
NVMe target, removed the obsolete package and built `t1-revive 0.1.3`.

The owner performed attended regeneration, then we installed signed T1Bridge
packages. A full shutdown/power-on loaded the T1 as `05ac:8600` and configuration
2. The owner confirmed speakers, Wi-Fi and a lit, working Touch Bar. That
established startup behavior, not sleep recovery.

## Sleep experiments, September 28

Deep/S3 resume failed with Radeon SMU firmware errors and inaccessible Alpine
Ridge controllers. The initial `s2idle` test recovered graphics but both USB-C
xHCI controllers logged `not ready 65535ms after resume; giving up` and lost
their driver bindings. The Touch Bar was dark.

Temporarily unloading Thunderbolt and using synchronous callbacks prevented
those recorded controller failures. Automatic lid wake was still missing in
one test: the owner opened the lid, waited a minute and then used Shift.

Tracing measured **12,673.906 ms in noirq resume**, including bridge callbacks
of **6,236.185 ms** and **6,238.227 ms**. The later device-resume phase took
**504.606 ms**. These kernel phase measurements do not cover the same start/end
points as the owner's visible wake estimates.

Lid wake permission was enabled and EC wake policy was `N`, but the EC GPE's
wake-mask capability check returned `AE_TYPE`. Our model-gated EC module called
the kernel's EC helper; the follow-up returned `AE_OK`.

With that helper, the owner confirmed automatic wake from opening the lid,
without Shift, in about **10 seconds**. The logs recorded an EC wake and no
repeat of the prior xHCI, inaccessible-PCI or Radeon failures. A further trace
measured **12,672.744 ms in noirq resume**, again largely the two bridges.

The combination was installed persistently through DKMS and systemd. This did
not resolve Touch Bar display recovery.

## After reboot, September 29

The first fresh-boot lid cycle woke automatically in about **15 seconds**, per
the owner. The persistent pre/post hooks ran and both controller pairs remained
bound without the earlier readiness/graphics failures.

The owner explicitly confirmed the Touch Bar was lit after reboot, then went
dark after sleep. Touch input still appeared to work. T1 configuration 2, DRM
`connected`/`enabled`/`On`, and active services persisted despite visible darkness.
DRM card numbers changed across boots; hard-coded card indices are inappropriate.

Restarting the renderer did not illuminate the display. A hardware-service
restart also did not establish a working recovery. A later short reply trace
captured no responses, but a confirmed display update was not established within
the capture window. That trace is inconclusive and identifies no failing component.

## Owner follow-up, October 5

The owner reported that lid closing/opening works in general. The Touch Bar
display **never reappears after waking**, although the button zones still work.
They also reported the laptop ran flat while closed over a couple of days.

That battery report is an observed limitation. The available evidence does not
distinguish a missed suspend, an unexpected wake, or continuous excessive
`s2idle` draw. Existing October 5 review noted a September 30 log ending at
suspend followed by a new boot with no recorded resume; that does not by itself
identify the cause of the depletion.

## Touch Bar recovery and controlled driver trial, October 9–13

Two manual unparks and four automatic recoveries were confirmed on October 9,
including a sleep cycle after a full reboot. The display was parked while its
touch input still worked; one bounded HID awake report restored visible icons
and Fn behavior. See [the optional recovery hook](touchbar.md).

On October 13 we tested [T1Bridge PR #47](https://github.com/standardagents/t1bridge/pull/47)
at `d43d2c52d965ce0ee495e311a6cf982ab6cc9b4f`, based on installed 0.1.12,
with the userspace display hook disabled and the existing controller workaround
retained. Initial attempts aborted with internal xHCI EBUSY; a stock-driver
comparison in that same boot also aborted. These were not successful sleeps
or faster resumes, and their cause remains unresolved. A failed suspend also
exposed a limitation of our hook: it skips recovery when the suspend service
fails, which can leave the panel parked after an abort.

After a fresh boot, three stock cycles passed, including one after unloading
and reloading the unchanged stock display driver. The subsequent #47 trial
produced two directly observed successful sleep/display recovery cycles without
the userspace unpark hook: approximately 28 seconds and 120 seconds asleep,
with working Touch Bar/Fn afterward. One further suspend succeeded in the logs
without a separate visual report. Kernel counters and systemd results confirm
actual sleep, rather than screen blanking after an aborted attempt.

Visible wake remained 17–18 seconds. In the observed two-minute #47 test,
the two Alpine Ridge bridge callbacks consumed 8.705 and 8.582 seconds of a
17.491-second noirq-resume phase; ordinary device resume took 0.526 seconds.
Stock controls had comparable timings. This locates the dominant delay in
bridge recovery but does not identify the precise firmware operation responsible.
[Kernel packaging PR #544](https://github.com/omacom/omarchy-pkgs/pull/544)
is a candidate for a separate investigation; its correction has not been
tested on this machine. No faster-wake or battery improvement is claimed.

The tested #47 source passed all components of its quality target across staged
runs, including 980 Rust tests, native/sanitizer checks, dependency policy,
kernel builds and isolated packaging verification. Three opt-in
firmware/hardware tests were not run. A local package built from that exact
source, `t1bridge-dkms 0.1.12.r47.d43d2c5-1`, is now installed.
Its extracted sources rebuilt successfully, and installation
verified the disk modules and boot image while preserving the kernel and boot
arguments. The unpark override now persists across reboot.

A full reboot then loaded the expected #47 module, with visible Touch Bar and
working Fn at startup. The first lid cycle after that reboot also passed:
automatic wake in approximately 18 seconds, visible icons and working Fn.
Kernel counters advanced from zero to one successful suspend with zero failures;
systemd reported success and ran only controller cleanup, with no userspace
unpark. This is the third directly observed #47 sleep/display recovery pass.
Detailed per-device timing was disabled after reboot, so this cycle adds a
visible-wake estimate, not a new bridge timing measurement. These results
validate this local package's startup and one post-reboot recovery; they do
not validate long sleeps, other models or the separate Omarchy installers.

## What remains to prove

| Question | Current evidence | Required next measurement |
| --- | --- | --- |
| Does lid opening reliably wake it? | Several recorded successes and owner follow-up | Repeated cycles after fresh boots, on mains and battery |
| How fast is visible wake? | Latest owner estimates 17–18 seconds; earlier 10–15 seconds | Consistent timing across power conditions and fresh boots |
| Why is wake still slow? | Latest noirq phase about 17.5 seconds, mainly two bridges | Trace the bridge callbacks and validate a targeted change |
| Can the display hook be retired? | Three observed #47 recoveries with it disabled, including after a packaged reboot | Broader repeated/long-sleep validation and upstream driver delivery |
| Is closed-lid power use acceptable? | Battery depletion over multiple days | Undocked charge/energy snapshots plus proven suspend/wake intervals |
| Do external ports work after wake? | Controllers remain bound | Functional USB-C, display and Thunderbolt tests |
| Does it work while docked? | Current helper deliberately refuses that suspend | A separate docked policy and hardware tests |

Related upstream work includes
[Omarchy discussion #4695](https://github.com/omacom/omarchy/discussions/4695)
and [T1Bridge issue #18](https://github.com/standardagents/t1bridge/issues/18).
Similar symptoms on a `14,2` using S3 do not establish the same cause on our
`13,3` using `s2idle`. These are references to compare, not proof of a fix here.
