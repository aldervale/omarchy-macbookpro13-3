#!/usr/bin/env bash
set -euo pipefail
export PATH=/usr/bin:/usr/sbin
[[ $EUID == 0 ]] || { echo 'Administrator privileges required.' >&2; exit 1; }
[[ $(</sys/class/dmi/id/product_name) == MacBookPro13,3 ]] || exit 1
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package=macbook-ec-wake
version=0.1
src=/usr/src/$package-$version
helper=/usr/local/sbin/macbook-suspend
dropin=/etc/systemd/system/systemd-suspend.service.d/60-macbook-thunderbolt-trial.conf
manifest=/var/lib/macbook-repair/persistent-sleep-files.sha256
files=("$src/Makefile" "$src/macbook_ec_wake_trial.c" "$src/dkms.conf" "$helper" "$dropin")

active=$(systemctl show systemd-suspend.service -p ActiveState --value)
[[ $active == inactive && ! -e /run/macbook-suspend/state &&
   ! -e /run/macbook-suspend-trial/state ]] || {
  echo 'Suspend must be inactive with no pending recovery; stopping.' >&2; exit 1;
}

case ${1:-install} in
  install)
    for path in "$src" "$helper" "$dropin" "$manifest" "/var/lib/dkms/$package"; do
      [[ ! -e $path && ! -L $path ]] || {
        echo "Already exists; refusing to overwrite: $path" >&2; exit 1;
      }
    done
    [[ -d /usr/lib/modules/$(uname -r)/build ]] || exit 1
    bash -n "$base/persistent-sleep/macbook-suspend"
    bash "$base/persistent-sleep/macbook-suspend" check
    rollback() {
      local result=$?
      trap - EXIT
      if [[ $result != 0 ]]; then
        echo 'Installation failed; removing only files added by this attempt.' >&2
        [[ ! -e $dropin ]] || unlink "$dropin"
        systemctl daemon-reload || true
        if [[ -d /var/lib/dkms/$package/$version ]]; then
          dkms remove -m "$package" -v "$version" --all || true
        fi
        for path in "${files[@]}" "$manifest"; do
          [[ ! -e $path ]] || unlink "$path"
        done
        [[ ! -d $src ]] || rmdir "$src" || true
      fi
      exit "$result"
    }
    trap rollback EXIT
    install -d -m755 "$src" /var/lib/macbook-repair
    install -m644 "$base/ec-wake-trial/Makefile" "$base/ec-wake-trial/macbook_ec_wake_trial.c" "$src/"
    install -m644 "$base/persistent-sleep/dkms.conf" "$src/dkms.conf"
    dkms add -m "$package" -v "$version"
    dkms build -m "$package" -v "$version" -k "$(uname -r)"
    dkms install -m "$package" -v "$version" -k "$(uname -r)"
    # DKMS install runs depmod; verify module discovery before enabling hooks.
    modinfo -k "$(uname -r)" macbook_ec_wake_trial >/dev/null
    install -Dm755 "$base/persistent-sleep/macbook-suspend" "$helper"
    install -Dm644 "$base/persistent-sleep/60-macbook-thunderbolt-trial.conf" "$dropin"
    systemctl daemon-reload
    systemd-analyze verify systemd-suspend.service
    effective_pre=$(systemctl show systemd-suspend.service -p ExecStartPre --value)
    [[ $effective_pre == *'/usr/local/sbin/macbook-suspend pre'* && $effective_pre != *'/run/macbook-suspend-trial/helper'* ]] || {
      echo 'Unexpected effective suspend hooks; reverting.' >&2; exit 1;
    }
    sha256sum "${files[@]}" > "$manifest"
    trap - EXIT
    echo 'Persistent undocked sleep workaround installed. No reboot or suspend triggered.'
    echo 'DKMS will attempt to rebuild the EC helper on future kernel updates.'
    echo 'External USB/Thunderbolt/display attachments cause this guarded suspend to be refused.'
    echo "Rollback: sudo bash $base/install-persistent-sleep.sh remove; then reboot."
    ;;
  remove)
    [[ -f $manifest && ! -L $manifest ]] || { echo 'Installation manifest is missing; stopping.' >&2; exit 1; }
    current=$(sha256sum "${files[@]}")
    [[ $current == "$(<"$manifest")" ]] || { echo 'Installed files changed; refusing removal.' >&2; exit 1; }
    unlink "$dropin"
    systemctl daemon-reload
    dkms remove -m "$package" -v "$version" --all
    for path in "${files[@]}"; do
      [[ ! -e $path ]] || unlink "$path"
    done
    rmdir "$src"
    unlink "$manifest"
    echo 'Persistent workaround removed. Reboot to remove the current-boot trials and EC mark.'
    ;;
  *) echo "Usage: $0 install|remove" >&2; exit 2 ;;
esac
