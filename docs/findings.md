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

## What remains to prove

| Question | Current evidence | Required next measurement |
| --- | --- | --- |
| Does lid opening reliably wake it? | Several recorded successes and owner follow-up | Repeated cycles after fresh boots, on mains and battery |
| How fast is visible wake? | Owner estimates about 10–15 seconds | Consistent lid-open-to-usable-screen timing |
| Why is wake still slow? | About 12.67 seconds in bridge/noirq recovery | Trace the bridge callbacks and validate a targeted change |
| Why does the Touch Bar display remain dark? | Startup illumination, dark after sleep, touch input survives | Confirmed display updates and before/after tracing |
| Is closed-lid power use acceptable? | Battery depletion over multiple days | Undocked charge/energy snapshots plus proven suspend/wake intervals |
| Do external ports work after wake? | Controllers remain bound | Functional USB-C, display and Thunderbolt tests |
| Does it work while docked? | Current helper deliberately refuses that suspend | A separate docked policy and hardware tests |

Related upstream work includes
[Omarchy discussion #4695](https://github.com/omacom/omarchy/discussions/4695)
and [T1Bridge issue #18](https://github.com/standardagents/t1bridge/issues/18).
Similar symptoms on a `14,2` using S3 do not establish the same cause on our
`13,3` using `s2idle`. These are references to compare, not proof of a fix here.
