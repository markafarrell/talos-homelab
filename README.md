# talos-homelab

https://docs.siderolabs.com/talos/v1.10/platform-specific-installations/single-board-computers/rpi_generic

## Install talosctl

```bash
curl -sL 'https://www.talos.dev/install' | bash
```

## Install talos

```bash
DEVICE=sda

# Get schematic ID

SCHEMATIC_ID=$(curl -X POST \
  --data-binary @rpi_generic.yaml \
  https://factory.talos.dev/schematics | jq -r '.id')

TALOS_VERSION=1.11.5

curl -LO https://factory.talos.dev/image/${SCHEMATIC_ID}/v${TALOS_VERSION}/metal-arm64.raw.xz
xz -d metal-arm64.raw.xz

sudo dd if=metal-arm64.raw of=/dev/${DEVICE} conv=fsync bs=4M status=progress
```

## Prepare disks for CEPH
```bash
DEVICE=sda

sudo sgdisk --zap-all /dev/${DEVICE}
```

## Generate config

```bash
cd config

CLUSTER_NAME=talos-default
DISK_NAME=mmcblk0
CONTROL_PLANE_NODES="k0 k1 k2"
CONTROL_PLANE_IPS="10.0.1.1 10.0.1.2 10.0.1.3"
ENDPOINT=10.0.2.1

talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$ENDPOINT:6443
for K in ${CONTROL_PLANE_NODES}; do
    talosctl machineconfig patch controlplane.yaml --patch @${K}-patch.yaml --output ${K}.yaml
done

for K in ${CONTROL_PLANE_NODES}; do
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

TALOS_VERSION=1.11.5

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