TP SÉCURITÉ DU MQTT

Création de 2 conteneurs Docker :
- Un conteneur mosquitto broker.
- Un conteneur mosquitto client.

Créer un répertoire :
mkdir mqtts
cd mqtts
Instanciation des conteneurs et ressources associées définies dans le fichier docker-compose.yaml
Saisir : docker-compose up -d

Exécuter d'un processus à l'intérieur du conteneur broker :
docker exec -it mosquitto_broker /bin/bash

Modifier la configuration de mosquitto pour fonctionner sur le port 8883 avec des certificats :
nano /etc/mosquitto/mosquitto.conf

Ajouter en fin de fichier la configuration suivante:
listener 8883
cafile /ca.crt
certfile /server.crt
keyfile /server.key

Créer un certificat CA (qui signe le certificat serveur) :
openssl req -new -x509 -days 1826 -extensions v3_ca -keyout ca.key -out ca.crt

Générer un certificat serveur et une clé :
Créer une clé serveur :
openssl genrsa -out server.key 2048

Créer une demande de signature de certificat (CSR) :
openssl req -out server.csr -key server.key -new

Signer le CSR avec le certificat CA pour obtenir le certificat serveur :
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 360

Relancer le service mosquitto :
service mosquitto restart

Copier le fichier ca.crt sur le client mosquitto (en 2 étapes) :
Copier tout d'abord ca.crt du broker sur la machine host :
docker cp mosquitto_broker:/ca.crt .

Copier le fichier ca.crt depuis le machine host vers le broker mosquitto :
docker cp ca.crt mosquitto_client:/

