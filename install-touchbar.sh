#!/usr/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Fresh install/removal of the optional recovery; never initiates sleep.
set -euo pipefail
export PATH=/usr/bin:/usr/sbin
[[ $EUID == 0 ]] || { echo 'Administrator privileges required.' >&2; exit 1; }
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,3 ]] || exit 1
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target=/usr/local/libexec/macbook-touchbar
dropin=/etc/systemd/system/systemd-suspend.service.d/70-macbook-touchbar-trial.conf
manifest=$target/files.sha256
files=("$target/unpark.py" "$target/resume" "$dropin")

active=$(systemctl show systemd-suspend.service -p ActiveState --value)
[[ $active == inactive && ! -e /run/macbook-suspend/state ]] || {
  echo 'Suspend must be inactive with no pending controller cleanup.' >&2; exit 1;
}
for path in /run/macbook-touchbar-trial /run/systemd/system/systemd-suspend.service.d/70-macbook-touchbar-trial.conf; do
  [[ ! -e $path && ! -L $path ]] || { echo 'Remove the old runtime trial first.' >&2; exit 1; }
done

case ${1:-} in
  install)
    for path in "$target" "$dropin"; do
      [[ ! -e $path && ! -L $path ]] || { echo "Refusing to overwrite $path" >&2; exit 1; }
    done
    commands=$(systemctl show systemd-suspend.service -p ExecStopPost --value)
    [[ $commands == *'/usr/local/sbin/macbook-suspend post'* ]] || {
      echo 'Install the controller cleanup hook first.' >&2; exit 1;
    }
    bash -n "$base/touchbar/resume"
    /usr/bin/python3 -I "$base/touchbar/unpark.py"
    added=()
    rollback() {
      local result=$?
      trap - EXIT
      for path in "${added[@]}"; do [[ ! -e $path ]] || unlink "$path"; done
      rmdir "$target" 2>/dev/null || true
      systemctl daemon-reload || true
      exit "$result"
    }
    trap rollback EXIT
    install -d -m700 "$target"
    added+=("$target/unpark.py")
    install -m600 "$base/touchbar/unpark.py" "$target/unpark.py"
    added+=("$target/resume")
    install -m700 "$base/touchbar/resume" "$target/resume"
    added+=("$dropin")
    install -Dm644 "$base/touchbar/70-macbook-touchbar-trial.conf" "$dropin"
    systemctl daemon-reload
    systemd-analyze verify systemd-suspend.service
    commands=$(systemctl show systemd-suspend.service -p ExecStopPost --value)
    [[ $commands == *'/usr/local/sbin/macbook-suspend post'*"$target/resume"* ]] || {
      echo 'Unexpected recovery order; reverting installation.' >&2; exit 1;
    }
    added+=("$manifest")
    sha256sum "${files[@]}" > "$manifest"
    trap - EXIT
    echo 'Touch Bar recovery installed. Test a lid cycle, then repeat after reboot.'
    ;;
  remove)
    [[ -f $manifest && ! -L $manifest ]] || { echo 'No installation manifest.' >&2; exit 1; }
    current=$(sha256sum "${files[@]}")
    [[ $current == "$(<"$manifest")" ]] || { echo 'Installed files changed; refusing removal.' >&2; exit 1; }
    unlink "$dropin"
    systemctl daemon-reload
    for path in "$target/resume" "$target/unpark.py" "$manifest"; do unlink "$path"; done
    rmdir "$target"
    echo 'Touch Bar recovery removed; controller sleep workaround retained.'
    ;;
  *) echo "Usage: $0 install|remove" >&2; exit 2 ;;
esac
