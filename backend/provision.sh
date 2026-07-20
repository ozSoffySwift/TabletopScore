#!/bin/sh
# Provision the TabletopScore backend on Oracle Cloud Always Free (Phase 1).
# Requires: oci CLI configured (`oci setup config`). Idempotent-ish: looks up
# existing resources by display-name before creating.
#
# Usage:
#   sh backend/provision.sh                # uses tenancy root compartment
#   COMPARTMENT_OCID=ocid1... sh backend/provision.sh
#
# Always Free ARM capacity errors are COMMON. This script retries every
# availability domain once; if all are out of capacity, rerun later
# (odd hours / start of month work best).
set -eu

NAME=tabletopscore
SSH_KEY="$(dirname "$0")/keys/tabletopscore_ed25519.pub"
# Override if your Always Free ARM quota is split with another instance,
# e.g. SHAPE_CONFIG='{"ocpus": 1, "memoryInGBs": 6}'
if [ -z "${SHAPE_CONFIG:-}" ]; then
    SHAPE_CONFIG='{"ocpus": 2, "memoryInGBs": 12}'
fi
COMPARTMENT_OCID="${COMPARTMENT_OCID:-$(oci iam compartment list --query 'data[0]."compartment-id"' --raw-output 2>/dev/null || true)}"
if [ -z "$COMPARTMENT_OCID" ]; then
    # fall back to tenancy root from the config file
    COMPARTMENT_OCID=$(grep '^tenancy' ~/.oci/config | head -1 | cut -d= -f2 | tr -d ' ')
fi
echo "compartment: $COMPARTMENT_OCID"

# --- VCN -------------------------------------------------------------------
VCN_ID=$(oci network vcn list -c "$COMPARTMENT_OCID" --display-name "$NAME-vcn" \
    --query 'data[0].id' --raw-output 2>/dev/null || true)
if [ -z "$VCN_ID" ] || [ "$VCN_ID" = "null" ]; then
    echo "creating VCN…"
    VCN_ID=$(oci network vcn create -c "$COMPARTMENT_OCID" --display-name "$NAME-vcn" \
        --cidr-blocks '["10.0.0.0/16"]' --wait-for-state AVAILABLE \
        --query 'data.id' --raw-output)
fi
echo "vcn: $VCN_ID"

# --- Internet gateway + default route --------------------------------------
IG_ID=$(oci network internet-gateway list -c "$COMPARTMENT_OCID" --vcn-id "$VCN_ID" \
    --query 'data[0].id' --raw-output 2>/dev/null || true)
if [ -z "$IG_ID" ] || [ "$IG_ID" = "null" ]; then
    IG_ID=$(oci network internet-gateway create -c "$COMPARTMENT_OCID" --vcn-id "$VCN_ID" \
        --display-name "$NAME-ig" --is-enabled true --wait-for-state AVAILABLE \
        --query 'data.id' --raw-output)
fi
RT_ID=$(oci network vcn get --vcn-id "$VCN_ID" --query 'data."default-route-table-id"' --raw-output)
oci network route-table update --rt-id "$RT_ID" --force \
    --route-rules "[{\"destination\":\"0.0.0.0/0\",\"networkEntityId\":\"$IG_ID\"}]" >/dev/null
echo "internet gateway: $IG_ID"

# --- Security list: 22, 80, 443 only ---------------------------------------
SL_ID=$(oci network vcn get --vcn-id "$VCN_ID" --query 'data."default-security-list-id"' --raw-output)
oci network security-list update --security-list-id "$SL_ID" --force \
    --egress-security-rules '[{"destination":"0.0.0.0/0","protocol":"all","isStateless":false}]' \
    --ingress-security-rules '[
      {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":22,"max":22}}},
      {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":80,"max":80}}},
      {"source":"0.0.0.0/0","protocol":"6","isStateless":false,"tcpOptions":{"destinationPortRange":{"min":443,"max":443}}}
    ]' >/dev/null
echo "security list restricted to 22/80/443"

# --- Public subnet ----------------------------------------------------------
SUBNET_ID=$(oci network subnet list -c "$COMPARTMENT_OCID" --vcn-id "$VCN_ID" \
    --display-name "$NAME-subnet" --query 'data[0].id' --raw-output 2>/dev/null || true)
if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" = "null" ]; then
    SUBNET_ID=$(oci network subnet create -c "$COMPARTMENT_OCID" --vcn-id "$VCN_ID" \
        --display-name "$NAME-subnet" --cidr-block "10.0.0.0/24" \
        --wait-for-state AVAILABLE --query 'data.id' --raw-output)
fi
echo "subnet: $SUBNET_ID"

# --- Ubuntu 24.04 arm64 image ----------------------------------------------
IMAGE_ID=$(oci compute image list -c "$COMPARTMENT_OCID" \
    --operating-system "Canonical Ubuntu" --operating-system-version "24.04" \
    --shape "VM.Standard.A1.Flex" --sort-by TIMECREATED --sort-order DESC \
    --query 'data[0].id' --raw-output)
echo "image: $IMAGE_ID"

# --- Instance: try each availability domain (ARM capacity roulette) ---------
EXISTING=$(oci compute instance list -c "$COMPARTMENT_OCID" --display-name "$NAME" \
    --lifecycle-state RUNNING --query 'data[0].id' --raw-output 2>/dev/null || true)
if [ -n "$EXISTING" ] && [ "$EXISTING" != "null" ]; then
    INSTANCE_ID="$EXISTING"
    echo "instance already running: $INSTANCE_ID"
else
    INSTANCE_ID=""
    for AD in $(oci iam availability-domain list -c "$COMPARTMENT_OCID" --query 'data[].name' --raw-output | tr -d '[]", ' | tr '\n' ' '); do
        [ -z "$AD" ] && continue
        echo "trying availability domain $AD…"
        if INSTANCE_ID=$(oci compute instance launch -c "$COMPARTMENT_OCID" \
            --availability-domain "$AD" --display-name "$NAME" \
            --shape "VM.Standard.A1.Flex" \
            --shape-config "$SHAPE_CONFIG" \
            --image-id "$IMAGE_ID" --subnet-id "$SUBNET_ID" \
            --assign-public-ip true \
            --ssh-authorized-keys-file "$SSH_KEY" \
            --wait-for-state RUNNING \
            --query 'data.id' --raw-output 2>/tmp/oci_launch_err); then
            echo "launched in $AD"
            break
        else
            grep -qi "capacity" /tmp/oci_launch_err \
                && echo "  out of capacity in $AD" \
                || { echo "  launch failed:"; cat /tmp/oci_launch_err; }
            INSTANCE_ID=""
        fi
    done
    if [ -z "$INSTANCE_ID" ]; then
        echo ""
        echo "OUT OF CAPACITY in every availability domain. This is normal for"
        echo "Always Free ARM. Rerun this script later (early morning / month"
        echo "start have the best odds). Everything created so far is reused."
        exit 2
    fi
fi

PUBLIC_IP=$(oci compute instance list-vnics --instance-id "$INSTANCE_ID" \
    --query 'data[0]."public-ip"' --raw-output)
echo ""
echo "instance: $INSTANCE_ID"
echo "public IP: $PUBLIC_IP"
echo ""
echo "Next: point your domain/DuckDNS at $PUBLIC_IP, then run:"
echo "  DOMAIN=<your-domain> sh backend/deploy.sh $PUBLIC_IP"
