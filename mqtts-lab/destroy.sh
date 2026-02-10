#!/bin/bash
#=============================================================================
# destroy.sh - Suppression complète du lab MQTTS KVM
# Usage : sudo ./destroy.sh
#=============================================================================
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

VM_DIR="/var/lib/libvirt/images/mqtts-lab"
NETWORK_NAME="mqtts-net"

echo -e "${RED}══════════════════════════════════════════${NC}"
echo -e "${RED}  Destruction du lab MQTTS              ${NC}"
echo -e "${RED}══════════════════════════════════════════${NC}"
echo ""

# Confirmation
read -p "Confirmer la suppression de toutes les VM et du réseau ? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    exit 0
fi

# Arrêt et suppression des VM
for VM in broker client; do
    if virsh dominfo "$VM" &>/dev/null; then
        virsh destroy "$VM" 2>/dev/null || true
        virsh undefine "$VM" --remove-all-storage 2>/dev/null || true
        info "VM $VM supprimée"
    else
        warn "VM $VM non trouvée (déjà supprimée ?)"
    fi
done

# Suppression des fichiers restants
if [ -d "$VM_DIR" ]; then
    rm -rf "$VM_DIR"
    info "Répertoire $VM_DIR supprimé"
fi

# Suppression du réseau
if virsh net-info "$NETWORK_NAME" &>/dev/null; then
    virsh net-destroy "$NETWORK_NAME" 2>/dev/null || true
    virsh net-undefine "$NETWORK_NAME" 2>/dev/null || true
    info "Réseau $NETWORK_NAME supprimé"
else
    warn "Réseau $NETWORK_NAME non trouvé"
fi

# Nettoyage known_hosts
for IP in 192.168.56.20 192.168.56.21; do
    ssh-keygen -R "$IP" 2>/dev/null || true
done
info "Entrées SSH known_hosts nettoyées"

echo ""
info "Nettoyage terminé !"
