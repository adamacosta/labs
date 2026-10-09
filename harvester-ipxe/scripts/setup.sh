#!/bin/sh

set -eu

SCRIPTS_ROOT="$(dirname "$(realpath "$0")")"

. "$SCRIPTS_ROOT/lib.sh"

usermod -aG docker,libvirt "$(id -nu)"

mkdir -p "$HOME/.config/libvirt"
touch "$HOME/.config/libvirt/libvirtd.conf"
grep -q 'uri_default = "qemu:///system"' "$HOME/.config/libvirt/libvirtd.conf" || \
    echo 'uri_default = "qemu:///system"' >> "$HOME/.config/libvirt/libvirt.conf"
