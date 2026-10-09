#!/bin/sh

ARG=${1-""}

set -eu

SCRIPTS_ROOT="$(dirname "$(realpath "$0")")"

. "$SCRIPTS_ROOT/lib.sh"

destroy_domain() {
    if virsh list | grep -q "$1"; then
        virsh destroy "$1"
    fi
    if virsh list --all | grep -q "$1"; then
        virsh undefine "$1" --nvram --remove-all-storage
    fi
}

destroy_domains() {
    for id in 1 2 3; do
        destroy_domain "hvst-$id"
    done
}

destroy_net() {
    if docker compose ls | grep -q 'gateway'; then
        docker compose --project-name gateway down
    fi
    if virsh net-list | grep -q 'harvester'; then
        virsh net-destroy harvester
    fi
    if virsh net-list --all | grep -q 'harvester'; then
        virsh net-undefine harvester
    fi
}

destroy_pool() {
    if virsh pool-list | grep -q 'harvester'; then
        virsh pool-destroy harvester
    fi
    if virsh pool-list --all | grep -q 'harvester'; then
        virsh pool-undefine harvester
    fi
    if [ -d /var/lib/libvirt/images/harvester/ ]; then
	sudo rm -rf /var/lib/libvirt/images/harvester/
    fi
}

destroy_domains
destroy_pool

if [ "$ARG" = "--net" ] || [ "$ARG" = "--all" ]; then
    destroy_net
fi
