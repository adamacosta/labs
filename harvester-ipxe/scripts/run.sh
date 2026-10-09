#!/bin/sh

ARG=${1:-""}

set -eu

SCRIPTS_ROOT="$(dirname "$(realpath "$0")")"

. "$SCRIPTS_ROOT/lib.sh"

install_domain() {
    virt-install \
        --autostart \
        --boot "uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no" \
        --console "type=pty,target.type=serial" \
        --cpu host-passthrough \
        --disk "pool=harvester,bus=virtio,size=180,sparse=no" \
        --disk "pool=harvester,bus=virtio,size=50,sparse=no" \
        --graphics "vnc,listen=0.0.0.0,password=${VNC_PASSWORD},port=590${1}" \
        --memory 32768 \
        --name "hvst-$1" \
        --network "bridge=virbr1,mac=52:54:00:00:00:${1}1,model=virtio" \
        --network "bridge=virbr1,mac=52:54:00:00:00:${1}2,model=virtio" \
        --noautoconsole \
        --osinfo opensuse16.0 \
        --pxe \
        --quiet \
        --vcpus 8 \
        --wait &
}

start_network() {
    # already active
    if virsh net-list | grep -q 'harvester'; then
        if docker compose ls | grep -q 'gateway'; then
            return
        else
            docker compose --file "$(pwd)/files/compose.yaml" up --detach
        fi
        return
    fi
    # defined but inactive
    if virsh net-list --all | grep -q 'harvester'; then
        virsh net-start --network harvester
    # not defined
    else
        virsh net-define "$(pwd)/files/harvester-net.xml"
        virsh net-start --network harvester
    fi
    docker compose --file "$(pwd)/files/compose.yaml" up --detach
}

start_pool() {
    # already active
    virsh pool-list | grep -q 'harvester' && return
    # defined but inactive
    if virsh pool-list --all | grep -q 'harvester'; then
        virsh pool-start --pool harvester
    # not defined
    else
        virsh pool-define "$(pwd)/files/harvester-pool.xml"
        virsh pool-build --pool harvester
        virsh pool-start --pool harvester
    fi
}

start_network
start_pool

VNC_PASSWORD="$(tr -cd '[:alnum:]' </dev/random | head -c 8)"

if [ "$ARG" = "--ha" ]; then
    for id in 1 2 3; do
        install_domain "$id"
    done
else
    install_domain "1"
fi

echo "VNC password = $VNC_PASSWORD"

timeout 30m bash -c '
result=$(curl -ks https://192.168.200.10/ping)
until [ "$result" = "pong" ]; do 
  sleep 30s
  echo "Waiting on mgmt VIP to become available..."
  result=$(curl -ks https://192.168.200.10/ping)
done'

sshpass -p "rancher" \
    ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    rancher@192.168.200.11 \
    'echo "rancher" | sudo -S cat /etc/rancher/rke2/rke2.yaml' 2>/dev/null |
    sed 's/127\.0\.0\.1/192.168.200.10/' \
    >"$(pwd)/harvester.yaml"

chmod 0600 "$(pwd)/harvester.yaml"
export KUBECONFIG="$(pwd)/harvester.yaml"

kubectl rollout status deployment/rancher --namespace cattle-system

USER=$(kubectl get user --output yaml |
    yq '.items[] | select(.username=="admin").metadata.name')
HARVESTER_PASSWORD="harvesterpassword"

# Password "admin" for the admin UI user is hard-coded in the installer
kubectl create -f -<<EOF
apiVersion: ext.cattle.io/v1
kind: PasswordChangeRequest
metadata:
  generateName: passwordchange-
spec:
  userID: $USER
  currentPassword: admin
  newPassword: $HARVESTER_PASSWORD
EOF

kubectl patch user "$USER" \
    --namespace cattle-system \
    -p '{"mustChangePassword":false}' \
    --type merge
TIMESTAMP=$(printf "%sZ" "$(date --utc +%Y-%m-%dT%H:%M:%S.%N | head -c -7)")
kubectl patch settings.management.cattle.io eula-agreed \
    -p "{\"value\":\"$TIMESTAMP\"}" \
    --type merge
kubectl patch settings.management.cattle.io first-login \
    -p '{"value":"false"}' \
    --type merge

# Turn on extension developer features reveals the embedded Rancher and Longhorn UIs
TOKEN=$(curl -k "https://192.168.200.10/v1-public/login" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data-raw "{\"username\":\"admin\",\"password\":\"$HARVESTER_PASSWORD\",\"responseType\":\"token\",\"type\":\"localProvider\"}" \
    -s |
    jq -r '.token')
PREFS=$(curl -k "https://192.168.200.10/v1/userpreferences/$USER" \
    -H "Authorization: Bearer $TOKEN" \
    -s |
    jq -r 'del(.links) | .data."plugin-developer"="true" | tostring')
curl -k "https://192.168.200.10/v1/userpreferences/$USER" \
    -X PUT \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    --data-raw "$PREFS"
