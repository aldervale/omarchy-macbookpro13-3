#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Read-only report without raw logs, firmware, serials or network identifiers.
set -uo pipefail
export PATH=/usr/bin:/usr/sbin

read_value() {
  local label=$1 path=$2 value
  if [[ -r $path ]] && value=$(cat -- "$path" 2>/dev/null); then
    printf '%s: %s\n' "$label" "$value"
  else
    printf '%s: unavailable\n' "$label"
  fi
}

printf 'UTC: %s\n' "$(date -u +%FT%TZ)"
read_value Model /sys/class/dmi/id/product_name
printf 'Kernel: %s\n' "$(uname -r)"
for package in omarchy linux-omarchy linux-omarchy-headers dkms t1bridge t1bridge-dkms t1bridge-omarchy; do
  pacman -Q "$package" 2>/dev/null || printf '%s: not installed/unavailable\n' "$package"
done
read_value mem_sleep /sys/power/mem_sleep
read_value pm_async /sys/power/pm_async
read_value thunderbolt.host_reset /sys/module/thunderbolt/parameters/host_reset
read_value acpi.ec_no_wakeup /sys/module/acpi/parameters/ec_no_wakeup
read_value lid.wakeup /sys/bus/platform/devices/PNP0C0D:00/power/wakeup

for device in /sys/bus/usb/devices/*; do
  [[ -r $device/idVendor && -r $device/idProduct ]] || continue
  vendor=$(<"$device/idVendor")
  product=$(<"$device/idProduct")
  [[ $vendor == 05ac && ( $product == 8600 || $product == 1281 ) ]] || continue
  printf 'T1 USB: %s:%s\n' "$vendor" "$product"
  read_value T1.configuration "$device/bConfigurationValue"
done
for device in /sys/bus/pci/devices/*; do
  [[ -r $device/vendor && -r $device/device ]] || continue
  [[ $(<"$device/vendor") == 0x8086 ]] || continue
  case $(<"$device/device") in
    0x15d2|0x15d4)
      driver=$(readlink -f "$device/driver" 2>/dev/null || true)
      [[ -L $device/driver ]] || driver=unbound
      printf 'Controller %s %s: %s\n' "${device##*/}" "$(<"$device/device")" "${driver##*/}"
      ;;
  esac
done
for device in /sys/class/nvme/nvme*/device; do
  [[ -d $device ]] || continue
  read_value NVMe.d3cold_allowed "$device/d3cold_allowed"
done
for device in /sys/class/drm/card*-*; do
  case ${device##*/} in
    *-USB-*)
      read_value "${device##*/}.status" "$device/status"
      read_value "${device##*/}.enabled" "$device/enabled"
      ;;
  esac
done
for service in t1-touchbar-hw.service systemd-suspend.service; do
  value=$(systemctl show "$service" -p ActiveState --value 2>/dev/null) || value=unavailable
  printf '%s: %s\n' "$service" "${value:-unavailable}"
done
value=$(systemctl --user show t1-touchbar.service -p ActiveState --value 2>/dev/null) || value=unavailable
printf 'user t1-touchbar.service: %s\n' "${value:-unavailable}"
for supply in /sys/class/power_supply/*; do
  [[ -r $supply/type ]] || continue
  if [[ $(<"$supply/type") == Battery ]]; then
    for field in status capacity energy_now energy_full charge_now charge_full power_now current_now voltage_now; do
      [[ -r $supply/$field ]] || continue
      read_value "${supply##*/}.$field" "$supply/$field"
    done
  elif [[ -r $supply/online ]]; then
    read_value "${supply##*/}.online" "$supply/online"
  fi
done
printf 'Battery units: capacity=percent; energy=µWh; charge=µAh; power=µW; current=µA; voltage=µV.\n'
printf 'Observe Touch Bar illumination and touch input separately; software state does not prove the panel is lit.\n'
