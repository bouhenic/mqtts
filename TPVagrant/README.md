# Sécurisation d'une connexion MQTT

Ce dépôt contient les ressources et instructions pour mettre en place un environnement de test sécurisé pour les communications MQTT, protocole largement utilisé dans l'Internet des Objets (IoT).

## Objectifs

- **Objectif principal:** Sécuriser une connexion MQTT entre un client et un serveur (broker)
- **Apprentissage:** Découvrir les mécanismes de sécurité MQTT et les bonnes pratiques pour les déploiements IoT

## Méthodes de sécurisation implémentées

- Chiffrement SSL/TLS avec MQTTS (port 8883)
- Authentification par mot de passe
- Authentification par certificat client

## Prérequis

- VirtualBox
- Vagrant
- Une machine avec au moins 4GB de RAM disponible

## Démarrage rapide

1. Clonez ce dépôt:
```bash
git clone https://github.com/bouhenic/mqtts
cd mqtts
```

2. Lancez les machines virtuelles:
```bash
vagrant up
```

3. Connectez-vous aux machines virtuelles:
```bash
# Dans un premier terminal (broker)
vagrant ssh broker

# Dans un second terminal (client)
vagrant ssh client -- -X
```

# Configuration du Broker MQTT

## Création des certificats serveur

### 1. Créer une Autorité de Certification (CA)
Sur la VM **broker**, exécutez la commande suivante pour créer une CA auto-signée valable environ 5 ans :

```bash
openssl req -new -x509 -days 1826 -extensions v3_ca -keyout ca.key -out ca.crt
```

### 2. Générer la clé privée du serveur
```bash
openssl genrsa -out server.key 2048
```

### 3. Créer une demande de signature de certificat (CSR) pour le serveur
```bash
openssl req -out server.csr -key server.key -new
```

### 4. Signer la CSR pour générer le certificat serveur
```bash
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 360
```

---

## Configuration de Mosquitto

### 1. Modifier le fichier de configuration
Ajoutez les lignes suivantes à la fin de `/etc/mosquitto/mosquitto.conf` :

```conf
listener 8883
cafile /home/vagrant/ca.crt
certfile /home/vagrant/server.crt
keyfile /home/vagrant/server.key
```

### 2. Redémarrer le service Mosquitto
```bash
sudo systemctl restart mosquitto
```

### 3. Vérifier le statut du service
```bash
sudo systemctl status mosquitto
```

---

## Recopie du certificat CA sur le Client

1. Sur la VM **broker**, afficher le contenu du certificat CA :
   ```bash
   cat /home/vagrant/ca.crt
   ```
2. Copier ce contenu et le coller dans un fichier `ca.crt` sur la VM **client**.

---

## Test du MQTTS

### 1. Abonnement et publication

#### Abonnement (depuis le broker)
```bash
mosquitto_sub -h 192.168.56.20 -p 8883 --cafile /home/vagrant/ca.crt -t your/topic
```

#### Publication (depuis le client)
```bash
mosquitto_pub -h 192.168.56.20 -p 8883 --cafile /home/vagrant/ca.crt -t your/topic -m "Hello world"
```

---

## Authentification par mot de passe

### 1. Configuration

#### Modifier le fichier de configuration
Ajoutez les lignes suivantes dans `/etc/mosquitto/mosquitto.conf` :
```conf
allow_anonymous false
password_file /mosquitto_passwd
```

#### Créer les utilisateurs
Par exemple, pour `userclient` et `userbroker` :
```bash
sudo mosquitto_passwd -c /mosquitto_passwd userclient
sudo mosquitto_passwd /mosquitto_passwd userbroker
```

#### Redémarrer Mosquitto
```bash
sudo systemctl restart mosquitto
```

#### Vérifier le contenu du fichier des mots de passe
```bash
cat /mosquitto_passwd
```

### 2. Test d'authentification par mot de passe

#### Abonnement depuis le broker
```bash
mosquitto_sub -h 192.168.56.20 -p 8883 --cafile /home/vagrant/ca.crt -u userbroker -P <mot_de_passe> -t your/topic
```

#### Publication depuis le client
```bash
mosquitto_pub -h 192.168.56.20 -p 8883 --cafile /home/vagrant/ca.crt -u userclient -P <mot_de_passe> -t your/topic -m "Hello world"
```

---

## Authentification par certificat (Client)

### 1. Création des certificats client

#### Générer la clé privée du client
Sur la VM **client** :
```bash
openssl genrsa -out client.key 2048
```

#### Créer une demande de signature de certificat (CSR) pour le client
```bash
openssl req -out client.csr -key client.key -new
```

#### Copier le fichier `ca.key` depuis la VM broker sur la VM client

#### Signer la CSR pour générer le certificat client
```bash
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 360
```

### 2. Configuration du Broker pour l'authentification client

#### Ajouter la ligne suivante dans `/etc/mosquitto/mosquitto.conf`
```conf
require_certificate true
```

#### Redémarrer Mosquitto
```bash
sudo systemctl restart mosquitto
```

### 3. Test de l'authentification par certificat et mot de passe

#### Abonnement (depuis le broker)
```bash
mosquitto_sub -h 192.168.56.20 -p 8883 --cafile /home/vagrant/ca.crt --cert /home/vagrant/server.crt --key /home/vagrant/server.key -u userbroker -P <mot_de_passe> -t your/topic
```

#### Publication (depuis le client)
```bash
mosquitto_pub -h 192.168.56.20 -p 8883 --cafile /home/vagrant/ca.crt --cert /home/vagrant/client.crt --key /home/vagrant/client.key -u userclient -P <mot_de_passe> -t your/topic -m "Hello world"
```

## Pour aller plus loin

- Implémentation d'une liste de contrôle d'accès (ACL) pour le broker
- Surveillance du trafic MQTT avec des outils comme Wireshark
- Intégration avec des systèmes d'authentification externes (LDAP, OAuth)

## Ressources d'apprentissage

- [Documentation officielle du protocole MQTT](https://mqtt.org/)
- [Guide de sécurité MQTT OWASP](https://owasp.org/www-project-iot-security/)
- [Documentation Mosquitto Broker](https://mosquitto.org/documentation/)

