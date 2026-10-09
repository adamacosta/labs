#!/bin/sh

set -eu

SCRIPTS_ROOT="$(dirname "$(realpath "$0")")"

. "$SCRIPTS_ROOT/lib.sh"

check_commands() {
    command -v curl >/dev/null || fatal "curl not found"
    command -v docker >/dev/null || command -v podman || fatal "docker or podman not found"
    command -v virsh >/dev/null || fatal "virsh not found"
    command -v virt-install >/dev/null || fatal "virt-install not found"
}

check_cpu_virt() {
    lscpu | grep -oPq 'Virtualization: +(AMD-V|VT-x)' && return
    fatal "Requires AMD-V or Intel VT-x hardware virtualization extensions"
}

check_files() {
    set -- "$(pwd)/files/harvester-net.xml" \
           "$(pwd)/files/harvester-pool.xml" \
           "$(pwd)/files/compose.yaml" \
           "$(pwd)/files/dnsmasq.conf" \
           "$(pwd)/files/nginx.conf"
    for f in "$@"; do
        if [ ! -f "$f" ]; then
            fatal "$f not found"
        fi
    done
}

check_groups() {
    groups | grep -Eq 'libvirt.+docker|docker.+libvirt' || \
    fatal "User needs to be in docker and libvirt groups"
}

check_commands
check_cpu_virt
check_files