#!/bin/bash
#=============================================================================
# status.sh - Vérification rapide du statut du lab MQTTS
# Usage : sudo ./status.sh
#=============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BROKER_IP="192.168.56.20"
CLIENT_IP="192.168.56.21"

echo -e "${BLUE}══════ Statut du Lab MQTTS ══════${NC}"
echo ""

# Statut des VM
echo -e "${BLUE}VM :${NC}"
for VM in broker client; do
    STATE=$(virsh domstate "$VM" 2>/dev/null || echo "absente")
    if [ "$STATE" = "running" ]; then
        echo -e "  $VM : ${GREEN}$STATE${NC}"
    else
        echo -e "  $VM : ${RED}$STATE${NC}"
    fi
done
echo ""

# Connectivité réseau
echo -e "${BLUE}Réseau :${NC}"
for ENTRY in "broker:$BROKER_IP" "client:$CLIENT_IP"; do
    VM_NAME="${ENTRY%%:*}"
    IP="${ENTRY##*:}"
    if ping -c 1 -W 2 "$IP" &>/dev/null; then
        echo -e "  $VM_NAME ($IP) : ${GREEN}accessible${NC}"
    else
        echo -e "  $VM_NAME ($IP) : ${RED}injoignable${NC}"
    fi
done
echo ""

# Connectivité SSH
echo -e "${BLUE}SSH :${NC}"
for ENTRY in "broker:$BROKER_IP" "client:$CLIENT_IP"; do
    VM_NAME="${ENTRY%%:*}"
    IP="${ENTRY##*:}"
    if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes \
           vagrant@"$IP" true 2>/dev/null; then
        echo -e "  $VM_NAME : ${GREEN}SSH OK${NC}"
    else
        echo -e "  $VM_NAME : ${RED}SSH KO${NC}"
    fi
done
echo ""

# Service Mosquitto sur le broker
echo -e "${BLUE}Services :${NC}"
if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes \
       vagrant@"$BROKER_IP" "systemctl is-active mosquitto" 2>/dev/null | grep -q "active"; then
    echo -e "  Mosquitto (broker) : ${GREEN}actif${NC}"
else
    echo -e "  Mosquitto (broker) : ${RED}inactif${NC}"
fi

# UFW sur le broker
UFW_STATUS=$(ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes \
    vagrant@"$BROKER_IP" "sudo ufw status" 2>/dev/null | head -1)
echo -e "  UFW (broker) : ${YELLOW}${UFW_STATUS:-inconnu}${NC}"
echo ""

# Réseau KVM
echo -e "${BLUE}Réseau KVM :${NC}"
virsh net-list --all 2>/dev/null | grep "mqtts" || echo "  Réseau mqtts-net non trouvé"
echo ""
