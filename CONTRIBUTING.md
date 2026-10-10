# Contributing

Hardware reports are welcome, especially for battery retention, repeatability
of Touch Bar recovery and wake timing on `MacBookPro13,3`. Follow
[the validation guide](docs/validation.md) and include:

- Model, kernel and relevant package versions.
- AC/battery power, attached devices and exact steps.
- Actual time asleep and lid-open-to-usable-screen time; any keypress needed.
- Touch Bar illumination at startup and after resume, plus touch response.
- Battery values before/after with units and confirmed suspend/wake intervals.

Do not upload EFI images, firmware, FDR data, fingerprints, restore transcripts,
credentials or unreviewed journals. A concise redacted excerpt is usually more
useful than a full system dump.

Run the software checks in [validation.md](docs/validation.md) for source changes.
Preserve the hardware and peripheral guards and cleanup after preparation
failure. Explain which machine and kernel received a physical test; a simulated
test or successful build is not evidence of physical sleep recovery.

Contributions use GPL-2.0-only, matching the repository license. Update the
evidence and limitations when results change. If modifying one of the original
repair files, update the provenance record so it no longer claims an unchanged
copy.
