#!/bin/bash
#=============================================================================
# deploy.sh - Déploiement automatisé de 2 VM Debian pour TP MQTTS sur KVM
#
# Remplace le Vagrantfile VirtualBox par une solution KVM + cloud-init
# Crée : broker (192.168.56.20) + client (192.168.56.21)
#
# Usage : sudo ./deploy.sh
#=============================================================================
set -euo pipefail

# --- Configuration -----------------------------------------------------------
BASE_IMG="./debian-12-generic-amd64.qcow2"
VM_DIR="/var/lib/libvirt/images/mqtts-lab"
NETWORK_NAME="mqtts-net"
CLOUD_INIT_DIR="./cloud-init"
SUBNET="192.168.56"
BROKER_IP="${SUBNET}.20"
CLIENT_IP="${SUBNET}.21"
GATEWAY_IP="${SUBNET}.1"
VM_MEMORY=1024
VM_VCPUS=1
VM_DISK_SIZE="10G"
CLIENT_PASSWORD="password123"
SSH_WAIT_TIMEOUT=180  # secondes max d'attente SSH

# --- Couleurs ----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${BLUE}═══ $1 ═══${NC}"; }

# --- Vérifications préalables ------------------------------------------------
section "Vérifications préalables"

if [ "$EUID" -ne 0 ]; then
    error "Ce script doit être lancé en root (sudo ./deploy.sh)"
    exit 1
fi

# Vérifier les dépendances
DEPS=(virsh virt-install cloud-localds qemu-img openssl ssh-keygen)
for cmd in "${DEPS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        error "Commande manquante : $cmd"
        echo "  Installer avec : sudo apt install -y qemu-kvm libvirt-daemon-system virtinst cloud-image-utils"
        exit 1
    fi
done
info "Toutes les dépendances sont présentes"

# Vérifier l'image de base
if [ ! -f "$BASE_IMG" ]; then
    warn "Image Debian cloud absente. Téléchargement..."
    wget -q --show-progress \
        "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2" \
        -O "$BASE_IMG"
    info "Image téléchargée"
fi
info "Image de base : $BASE_IMG"

# Vérifier que les VM n'existent pas déjà
for VM in broker client; do
    if virsh dominfo "$VM" &>/dev/null; then
        warn "La VM '$VM' existe déjà. Lancer ./destroy.sh d'abord."
        exit 1
    fi
done

# --- Préparation -------------------------------------------------------------
section "Préparation des ressources"

mkdir -p "$VM_DIR"

# Générer le hash du mot de passe client
CLIENT_HASH=$(openssl passwd -6 -salt mqttslab "$CLIENT_PASSWORD")
info "Hash du mot de passe client généré"

# Clé SSH de l'utilisateur qui lance le script (via sudo)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

if [ ! -f "${REAL_HOME}/.ssh/id_rsa.pub" ]; then
    warn "Pas de clé SSH trouvée pour $REAL_USER, génération..."
    sudo -u "$REAL_USER" ssh-keygen -t rsa -b 2048 -N "" -f "${REAL_HOME}/.ssh/id_rsa"
fi
HOST_PUBKEY=$(cat "${REAL_HOME}/.ssh/id_rsa.pub")
info "Clé SSH de l'hôte récupérée ($REAL_USER)"

# --- Réseau KVM isolé --------------------------------------------------------
section "Configuration réseau KVM"

if virsh net-info "$NETWORK_NAME" &>/dev/null; then
    info "Réseau $NETWORK_NAME existe déjà"
else
    cat > /tmp/${NETWORK_NAME}.xml <<EOF
<network>
  <name>${NETWORK_NAME}</name>
  <bridge name="virbr-mqtts" stp="on" delay="0"/>
  <ip address="${GATEWAY_IP}" netmask="255.255.255.0">
  </ip>
</network>
EOF
    virsh net-define /tmp/${NETWORK_NAME}.xml
    virsh net-start "$NETWORK_NAME"
    virsh net-autostart "$NETWORK_NAME"
    info "Réseau $NETWORK_NAME créé et démarré"
    rm -f /tmp/${NETWORK_NAME}.xml
fi

# --- Fonction de création de VM ----------------------------------------------
create_vm() {
    local NAME="$1"
    local IP="$2"
    local USERDATA_TEMPLATE="$3"

    section "Création de la VM : $NAME ($IP)"

    # Copier et redimensionner le disque
    info "Copie et redimensionnement du disque..."
    cp "$BASE_IMG" "${VM_DIR}/${NAME}.qcow2"
    qemu-img resize "${VM_DIR}/${NAME}.qcow2" "$VM_DISK_SIZE" >/dev/null

    # Injecter les variables dans le cloud-init user-data
    info "Préparation du cloud-init..."
    sed -e "s|CHANGEME_CLE_PUBLIQUE_HOTE|${HOST_PUBKEY}|g" \
        -e "s|CHANGEME_CLIENT_HASH|${CLIENT_HASH}|g" \
        "${CLOUD_INIT_DIR}/${USERDATA_TEMPLATE}" > "/tmp/${NAME}-user-data.yml"

    # Générer le network-config (Netplan format v2)
    cat > "/tmp/${NAME}-network-config.yml" <<EOF
version: 2
ethernets:
  enp1s0:
    dhcp4: true
  enp2s0:
    addresses:
      - ${IP}/24
EOF

    # Créer l'ISO seed cloud-init
    cloud-localds -v \
        --network-config="/tmp/${NAME}-network-config.yml" \
        "${VM_DIR}/${NAME}-cidata.iso" \
        "/tmp/${NAME}-user-data.yml" 2>/dev/null

    info "ISO cloud-init créé"

    # Créer la VM
    info "Lancement de la VM..."
    virt-install \
        --name "$NAME" \
        --memory "$VM_MEMORY" \
        --vcpus "$VM_VCPUS" \
        --disk "path=${VM_DIR}/${NAME}.qcow2,format=qcow2,bus=virtio" \
        --disk "path=${VM_DIR}/${NAME}-cidata.iso,device=cdrom" \
        --network network=default,model=virtio \
        --network network=${NETWORK_NAME},model=virtio \
        --os-variant debian12 \
        --graphics none \
        --console pty,target_type=serial \
        --noautoconsole \
        --import \
        --quiet

    info "VM $NAME déployée ✓"

    # Nettoyage fichiers temporaires
    rm -f "/tmp/${NAME}-user-data.yml" "/tmp/${NAME}-network-config.yml"
}

# --- Déploiement des VM ------------------------------------------------------
create_vm "broker" "$BROKER_IP" "broker-user-data.yml"
create_vm "client" "$CLIENT_IP" "client-user-data.yml"

# --- Attente du boot et cloud-init -------------------------------------------
section "Attente du démarrage des VM"

wait_for_ssh() {
    local HOST="$1"
    local NAME="$2"
    local ELAPSED=0
    local INTERVAL=5

    while [ $ELAPSED -lt $SSH_WAIT_TIMEOUT ]; do
        if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
               -o BatchMode=yes vagrant@"$HOST" true 2>/dev/null; then
            info "$NAME accessible via SSH ($HOST) après ${ELAPSED}s"
            return 0
        fi
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
        echo -ne "\r  Attente de $NAME... ${ELAPSED}s / ${SSH_WAIT_TIMEOUT}s"
    done
    echo ""
    error "Timeout : $NAME n'est pas accessible après ${SSH_WAIT_TIMEOUT}s"
    return 1
}

# Attente initiale pour le boot
info "Attente du boot initial (30s)..."
sleep 30

# Vérifier la connectivité SSH
wait_for_ssh "$BROKER_IP" "broker"
wait_for_ssh "$CLIENT_IP" "client"

# --- Échange de clés SSH broker → client ------------------------------------
section "Échange de clés SSH"

info "Copie de la clé publique du broker vers le client..."
BROKER_PUBKEY=$(ssh -o StrictHostKeyChecking=no vagrant@"$BROKER_IP" \
    "cat /home/vagrant/.ssh/id_rsa.pub" 2>/dev/null)

if [ -n "$BROKER_PUBKEY" ]; then
    ssh -o StrictHostKeyChecking=no vagrant@"$CLIENT_IP" \
        "echo '$BROKER_PUBKEY' | sudo tee -a /home/client/.ssh/authorized_keys >/dev/null && \
         sudo chown client:client /home/client/.ssh/authorized_keys" 2>/dev/null
    info "Clé du broker ajoutée aux authorized_keys du client ✓"
else
    warn "Impossible de récupérer la clé du broker (cloud-init peut-être pas terminé)"
    warn "Vous pouvez le faire manuellement plus tard"
fi

# --- Ajout des entrées /etc/hosts sur chaque VM -----------------------------
section "Configuration des noms d'hôtes"

for VM_IP in "$BROKER_IP" "$CLIENT_IP"; do
    ssh -o StrictHostKeyChecking=no vagrant@"$VM_IP" \
        "echo '${BROKER_IP} broker broker.local' | sudo tee -a /etc/hosts >/dev/null && \
         echo '${CLIENT_IP} client client.local' | sudo tee -a /etc/hosts >/dev/null" 2>/dev/null
done
info "Entrées /etc/hosts configurées sur les deux VM"

# --- Résumé ------------------------------------------------------------------
section "Déploiement terminé !"

echo ""
echo -e "  ${GREEN}broker${NC}  : ssh vagrant@${BROKER_IP}"
echo -e "  ${GREEN}client${NC}  : ssh vagrant@${CLIENT_IP}"
echo ""
echo -e "  Console VM : ${YELLOW}virsh console broker${NC} / ${YELLOW}virsh console client${NC}"
echo -e "  Statut     : ${YELLOW}virsh list --all${NC}"
echo ""
echo -e "  User client : client / ${CLIENT_PASSWORD}"
echo ""
echo -e "  Détruire le lab : ${RED}sudo ./destroy.sh${NC}"
echo ""
