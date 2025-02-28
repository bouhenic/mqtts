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
git clone https://github.com/votrenom/mqtts-security
cd mqtts-security
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

## Structure du TP

Le TP est structuré en plusieurs étapes progressives:

1. **Configuration de l'environnement de test**
   - Déploiement automatisé avec Vagrant
   - Mise en place de deux VMs Ubuntu: broker (192.168.56.20) et client (192.168.56.21)

2. **Création et configuration des certificats**
   - Mise en place d'une autorité de certification (CA)
   - Génération des certificats serveur et client
   - Signatures des certificats

3. **Configuration du broker MQTT**
   - Configuration MQTTS avec certificats
   - Mise en place de l'authentification par mot de passe
   - Configuration de l'authentification par certificat client

4. **Tests de sécurité**
   - Communication MQTT sécurisée
   - Vérification de l'authentification
   - Tests des différentes méthodes de sécurisation

## Détails techniques

### Topologie du réseau
- **Broker MQTT**: 192.168.56.20
- **Client MQTT**: 192.168.56.21
- **Réseau**: 192.168.56.0/24

### Ports utilisés
- **1883**: MQTT standard (non sécurisé)
- **8883**: MQTTS (MQTT sur TLS)

## Contenu du dépôt

- `Vagrantfile` - Configuration pour déployer automatiquement l'environnement de test
- `docs/` - Documentation détaillée et ressources pédagogiques
- `scripts/` - Scripts d'automatisation et de configuration

## Pour aller plus loin

- Implémentation d'une liste de contrôle d'accès (ACL) pour le broker
- Surveillance du trafic MQTT avec des outils comme Wireshark
- Intégration avec des systèmes d'authentification externes (LDAP, OAuth)

## Ressources d'apprentissage

- [Documentation officielle du protocole MQTT](https://mqtt.org/)
- [Guide de sécurité MQTT OWASP](https://owasp.org/www-project-iot-security/)
- [Documentation Mosquitto Broker](https://mosquitto.org/documentation/)

## Contributions

Les contributions sont les bienvenues! N'hésitez pas à soumettre des issues ou des pull requests.

## Licence

Ce projet est sous licence MIT. Voir le fichier `LICENSE` pour plus de détails.

