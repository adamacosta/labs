# harvester-ipxe

Skeleton files and scripts to run a virtual switch with gateway services for network booting the Harvester installer onto three KVM guests to create a simulated HA cluster.

## Requirements

This *should* run on any Linux but has been tested on Arch Linux and openSUSE Leap 16.1. Required software is:
- `curl`
- `docker`
- `git`
- `sshpass`
- `virsh`
- `virt-install`

`git` is only needed to clone this repo and `sshpass` for automating scripted password auth when connecting to the virtual nodes. It is not needed if you add pubkeys or do not wish to ssh to the node. The `run.sh` script will fail its automated setup once the cluster is running, but all that means if you will need to choose an administrator password and accept the license agreement manually.

## Usage

To check system requirements:

```sh
./scripts/check.sh
```

To configure `docker` and `libvirt`:

```sh
./scripts/setup.sh
```

To start a single-node cluster:

```sh
./scripts/run.sh
```

To start a three-node cluster:

```sh
./scripts/run.sh --ha
```

To stop a cluster:

```sh
./scripts/stop.sh
```

To stop a cluster, all network services, and delete the virtual bridge:

```sh
./scripts/stop.sh --all
```

## Known Issues

This will not work if `firewalld` is running. The network services bind to privileged host ports 53, 67, 69, 80, 123, and 443.

QEMU guests display strange behavior when the same virtual disk content is written to the same host filesystem repeatedly, even though both the machine provisioner and installer make some attempt to wipe old file content before installing. Checksum errors on either tarball extraction or container image loading will fail in seemingly random places. This is why the stop script completely destroys the storage pool and deletes the parent directory inode to try and avoid this.