# talos-homelab

https://docs.siderolabs.com/talos/v1.10/platform-specific-installations/single-board-computers/rpi_generic

## Install homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo >> /home/$USER/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"' >> /home/$USER/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
```

## Install talosctl

```bash
brew tap siderolabs/tap
brew trust siderolabs/tap
brew install siderolabs/tap/talosctl
```

## Install talos

```bash
DEVICE=sda

# Get schematic ID

SCHEMATIC_ID=$(curl -X POST \
  --data-binary @rpi_generic.yaml \
  https://factory.talos.dev/schematics | jq -r '.id')

TALOS_VERSION=1.13.3

curl -LO https://factory.talos.dev/image/${SCHEMATIC_ID}/v${TALOS_VERSION}/metal-arm64.raw.xz
xz -d metal-arm64.raw.xz

sudo dd if=metal-arm64.raw of=/dev/${DEVICE} conv=fsync bs=4M status=progress
```

## Prepare disks for CEPH
```bash
DEVICE=sdb

sudo ceph-volume lvm zap --destroy /dev/${DEVICE}2
sudo sgdisk --zap-all /dev/${DEVICE}
sudo ceph-volume lvm zap --destroy /dev/${DEVICE}
```

## Generate config (rpi4)

```bash
cd config

CLUSTER_NAME=talos-default
DISK_NAME=mmcblk0
CONTROL_PLANE_NODES="k0 k1 k2"
CONTROL_PLANE_IPS="10.0.1.1 10.0.1.2 10.0.1.3"
ENDPOINT=10.0.2.1
WORKER_NODES="k3"
WORKER_NODE_IPS="10.0.1.4"

talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$ENDPOINT:6443 --force
for K in ${CONTROL_PLANE_NODES}; do
    talosctl machineconfig patch controlplane.yaml --patch @${K}-patch.yaml --output ${K}.yaml
done

for K in ${CONTROL_PLANE_NODES}; do
    talosctl apply-config --insecure \
        --nodes ${K}.lan \
        --file ${K}.yaml
done


for K in ${WORKER_NODES}; do
    talosctl machineconfig patch worker.yaml --patch @${K}-patch.yaml --output ${K}.yaml
done

for K in ${WORKER_NODES}; do
    talosctl apply-config --insecure \
        --nodes ${K}.lan \
        --file ${K}.yaml
done


talosctl config endpoint ${CONTROL_PLANE_IPS}

talosctl bootstrap --nodes 10.0.1.3

talosctl kubeconfig --nodes 10.0.2.1
```

## Upgrade

```bash

SCHEMATIC_ID=$(curl -X POST \
  --data-binary @rpi_generic.yaml \
  https://factory.talos.dev/schematics | jq -r '.id')

TALOS_VERSION=1.13.4

NODE=10.0.1.1 # k0
NODE=10.0.1.2 # k1
NODE=10.0.1.3 # k2

talosctl upgrade --nodes ${NODE} \
  --image factory.talos.dev/metal-installer/${SCHEMATIC_ID}:v${TALOS_VERSION}

talosctl dmesg -f --nodes ${NODE}

```

### Check ceph health

```bash
kubectl rook-ceph ceph status
```

### Remove ceph disk

```bash


kubectl rook-ceph ceph osd tree

OSD=0

kubectl rook-ceph ceph osd out ${OSD}

# Wait until all pgs are active+clean
kubectl rook-ceph ceph status

kubectl -n rook-ceph delete deployment rook-ceph-osd-${OSD}

kubectl rook-ceph ceph osd down ${OSD}
kubectl rook-ceph ceph osd purge ${OSD} --yes-i-really-mean-it

kubectl rook-ceph ceph status
```

* Infrastructure -> 10.0.0.0/24
  * Modem        -> 10.0.0.1/20
  * Office WiFi  -> 10.0.0.2/20
  # * Playroom WiFi-> 10.0.0.3/20
  * PoE Switch   -> 10.0.0.4/20

* K8s            -> 10.0.1.0/24
  * k0           -> 10.0.1.1/20
  * k1           -> 10.0.1.2/20
  * k2           -> 10.0.1.3/20
  * k3           -> 10.0.1.4/20

* VIPs           -> 10.0.2.0/24
  * k8s API      -> 10.0.2.1/20
  * Ingress      -> 10.0.2.2/20
  * Prom Push GW -> 10.0.2.3/20
  * Gateway API  -> 10.0.2.4/20
  * ...
  * Openspeedtest-> 10.0.2.253/20
  * PiHole       -> 10.0.2.254/20

* Clients        -> 10.0.3.0/24
  * Inverter     -> 10.0.3.1/20 (cc:f9:57:c5:fd:e9)
  * valetudo     -> 10.0.3.2 (7c:49:eb:98:40:9c)
