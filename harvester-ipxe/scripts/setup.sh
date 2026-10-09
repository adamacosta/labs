#!/bin/sh

set -eu

SCRIPTS_ROOT="$(dirname "$(realpath "$0")")"

. "$SCRIPTS_ROOT/lib.sh"

sudo usermod -aG docker,libvirt "$(id -nu)"

mkdir -p "$HOME/.config/libvirt"
touch "$HOME/.config/libvirt/libvirt.conf"
grep -q 'uri_default = "qemu:///system"' "$HOME/.config/libvirt/libvirt.conf" || \
    echo 'uri_default = "qemu:///system"' >> "$HOME/.config/libvirt/libvirt.conf"

systemctl is-enabled -q docker || sudo ystemctl enable --now docker
systemctl is-enabled -q libvirtd || sudo systemctl enable --now libvirtd
systemctl is-active -q firewalld && sudo systemctl stop firewalld

command -v getenforce >/dev/null && \
    sudo getenforce | grep -q 'Enforcing' && \
    sudo chcon -R -t container_file_t "$(pwd)/files"
