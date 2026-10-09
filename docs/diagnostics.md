# Diagnostics

Run `bash scripts/status.sh` from the repository root. It reads model/version,
sleep policy, T1 USB state, controller bindings, NVMe settings, service state
and battery measurements. It does not read firmware, enumerate network names,
print battery serials, load modules or change settings. A permissions-limited
service check is reported as unavailable rather than interpreted as a failure.

Useful local logs for an attended cycle:

```bash
journalctl -b -u systemd-suspend.service --no-pager
journalctl -b -k --no-pager | rg -i 'suspend|resume|macbook_ec_wake|xhci|thunderbolt|SMU'
journalctl --user -b -u t1-touchbar.service --no-pager
journalctl -b -u t1-touchbar-hw.service --no-pager
```

Confirm actual suspend entry and exit, completed pre/post restoration, EC wake
records when available, and absence of the earlier controller timeouts. The
sleep service's exit status does not prove external ports or the Touch Bar panel
work. Software display state can look healthy while the panel is dark.

Use `systemctl cat systemd-suspend.service` and
`systemd-analyze cat-config systemd/sleep.conf` to inspect hook/policy conflicts.
These are local inspection commands; raw output is not automatically suitable
for a public issue. Review identifying data before sharing excerpts.
