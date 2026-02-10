 TP MQTTS - Lab KVM automatisé

Déploiement automatisé de 2 VM Debian 12 (Bookworm) pour un TP sur MQTT/MQTTS,
en remplacement du Vagrantfile VirtualBox original.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 Hôte Ubuntu (KVM)                │
│                                                  │
│   ┌──────────────┐       ┌──────────────┐       │
│   │   broker      │       │   client      │       │
│   │  Debian 12    │       │  Debian 12    │       │
│   │               │       │               │       │
│   │  mosquitto    │       │  mosquitto-   │       │
│   │  ufw          │       │  clients      │       │
│   │  openssl      │       │  openssl      │       │
│   │               │       │               │       │
│   │ .56.20        │       │ .56.21        │       │
│   └──────┬───────┘       └──────┬───────┘       │
│          │    Réseau mqtts-net   │                │
│          └───────192.168.56.0/24─┘                │
└─────────────────────────────────────────────────┘
```

## Prérequis

### Paquets requis (Ubuntu)

```bash
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
    virtinst cloud-image-utils qemu-utils bridge-utils
sudo usermod -aG libvirt $USER
# Se reconnecter pour prendre en compte le groupe
```

### Image Debian Cloud

Le script la télécharge automatiquement si absente, ou manuellement :

```bash
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
```

Placer l'image à la racine du projet (à côté de `deploy.sh`).

## Utilisation

### Déployer le lab

```bash
chmod +x deploy.sh destroy.sh status.sh
sudo ./deploy.sh
```

Le script :
1. Vérifie les dépendances
2. Télécharge l'image Debian si nécessaire
3. Crée un réseau KVM isolé (`192.168.56.0/24`)
4. Déploie 2 VM via cloud-init
5. Attend que SSH soit accessible
6. Échange les clés SSH entre broker et client
7. Configure `/etc/hosts` sur les deux VM

### Accéder aux VM

```bash
ssh vagrant@192.168.56.20   # broker
ssh vagrant@192.168.56.21   # client

# Ou via la console série :
sudo virsh console broker
sudo virsh console client
# (Ctrl+] pour quitter la console)
```

### Vérifier le statut

```bash
sudo ./status.sh
```

### Détruire le lab

```bash
sudo ./destroy.sh
```

## Identifiants

| Utilisateur | Mot de passe   | Rôle                    |
|-------------|----------------|-------------------------|
| vagrant     | (clé SSH)      | Admin sudo              |
| client      | password123    | Utilisateur TP          |

## Ports ouverts (broker)

| Port     | Service          |
|----------|------------------|
| 22/tcp   | SSH              |
| 1883/tcp | MQTT (sans TLS)  |
| 8883/tcp | MQTTS (avec TLS) |

## Personnalisation

### Modifier les IP

Éditer les variables en haut de `deploy.sh` :

```bash
SUBNET="192.168.56"
BROKER_IP="${SUBNET}.20"
CLIENT_IP="${SUBNET}.21"
```

### Modifier les ressources VM

```bash
VM_MEMORY=1024   # RAM en Mo
VM_VCPUS=1       # Nombre de vCPU
VM_DISK_SIZE="10G"
```

### Ajouter des paquets

Éditer les fichiers `cloud-init/*-user-data.yml`, section `packages:`.

## Mapping Vagrant → KVM

| Vagrant / VirtualBox              | KVM / cloud-init                           |
|-----------------------------------|--------------------------------------------|
| `config.vm.box "ubuntu/focal64"`  | Image qcow2 Debian 12 cloud               |
| `vm.network "private_network"`    | `virsh net-define` réseau isolé            |
| `vb.memory` / `vb.cpus`          | `--memory` / `--vcpus` (virt-install)      |
| `vm.provision "shell"`            | `runcmd` + `packages` (cloud-init)         |
| Dossier partagé `/vagrant/`       | Échange via SSH post-déploiement           |
| `vagrant up`                      | `sudo ./deploy.sh`                         |
| `vagrant destroy`                 | `sudo ./destroy.sh`                        |
| `vagrant ssh broker`              | `ssh vagrant@192.168.56.20`                |

## Dépannage

**VM ne démarre pas :**
```bash
virsh list --all           # État des VM
virsh start broker         # Démarrer manuellement
journalctl -u libvirtd     # Logs libvirt
```

**Cloud-init n'a pas terminé :**
```bash
ssh vagrant@192.168.56.20
sudo cloud-init status --wait
sudo cat /var/log/cloud-init-output.log
```

**Réseau non accessible :**
```bash
virsh net-list --all
virsh net-start mqtts-net
ip addr show virbr-mqtts
```

