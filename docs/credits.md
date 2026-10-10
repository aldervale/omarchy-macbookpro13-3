# Credits and integration

The three repositories originally used to investigate this machine were:

| Project | Contribution to this setup | How it fits |
| --- | --- | --- |
| [dzanaga/macbookpro-2016-2017-linux](https://github.com/dzanaga/macbookpro-2016-2017-linux) | Model-specific references and BCM43602 board template | Selected components informed our repair; the full installer was not run |
| [nohzafk/omarchy-macbookpro-t1](https://github.com/nohzafk/omarchy-macbookpro-t1) | EFI/T1, Wi-Fi, audio and Touch Bar research | Its main validation is a different model (`14,2`); its legacy Touch Bar path is distinct from ours |
| [niconistal/t1-revive](https://github.com/niconistal/t1-revive) | Recovery from missing T1 boot/firmware data | Used only for the owner's attended recovery; it is not a resume fix |

The installed runtime comes from
[standardagents/t1bridge](https://github.com/standardagents/t1bridge), and audio
from [davidjo/snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro).
The kernel supplies `applespi`, ACPI EC handling, PCI power management and
Thunderbolt support. The experiment uses existing kernel interfaces rather
than replacing their event handlers.

The [same-model reports in discussion #4695](https://github.com/omacom/omarchy/discussions/4695)
informed our experiments; their custom kernel and other configuration differ.
Our own traces and lid tests establish only the results recorded in this repo.

## Integration boundaries

This repository documents one coherent T1Bridge setup. Do not combine its
runtime with installers that load competing legacy `appleibridge` modules,
force a different T1 USB configuration or provide duplicate Touch Bar services.
Inspect the upstream installer and disable conflicting components first.

No donor firmware or compiled upstream drivers are bundled. The Wi-Fi template
and audio/recovery projects are obtained from their original repositories.
The original source hashes and subsequent review changes are recorded in
[source-provenance.md](source-provenance.md).

## Upstream work

The [draft Omarchy PR #14894](https://github.com/omacom/omarchy/pull/14894)
includes an explicitly enabled `MacBookPro13,3` sleep and Touch Bar recovery
option, with model/peripheral guards, cleanup and removal. It also carries the
keyboard quirk, NVMe helper and a guide connecting the Wi-Fi, audio and T1
prerequisites. See [the contribution scope and validation](review.md).
The new integration remains a draft: battery retention, external-port behavior
and the combined installer need further hardware validation. Docked lid policy
remains distinct from the undocked sleep workaround.

The [optional Touch Bar recovery](touchbar.md) now works in our recorded short
s2idle cycles. Driver-level integration remains a separate investigation, with
related reports in [T1Bridge issue #18](https://github.com/standardagents/t1bridge/issues/18).
A report on another model/sleep state is a comparison, not a diagnosis here.
