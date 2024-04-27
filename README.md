# TP SÉCURITÉ DU MQTT
## CRÉATION DE 2 CONTENEURS DOCKER :
![Texte alternatif](mqtt.drawio.svg)

- Un conteneur mosquitto broker.
- Un conteneur mosquitto client.

1. Cloner le répertoire :
```bash
git clone https://github.com/bouhenic/mqtts
cd mqtts
```
2. Instanciation des conteneurs et ressources associées définies dans le fichier docker-compose.yaml
```bash
docker-compose up -d
```
3. On vérifie les conteneurs créés :
```bash
docker ps
```
![Texte alternatif](scr1.png)

4. Exécuter un processus à l'intérieur du conteneur broker :
```bash
docker exec -it mosquitto_broker /bin/sh
```
4. Changement de droit et de propriétaire du fichier passwd :
```bash
chmod 0700 /etc/mosquitto/passwd
chown mosquitto:mosquitto /etc/mosquitto/passwd
```
5. Modifier la configuration de mosquitto pour fonctionner sur le port 8883 avec des certificats :
```bash
nano /etc/mosquitto/mosquitto.conf
```
5. Lancer le service mosquitto :
```bash
mosquitto -c /etc/mosquitto/mosquitto.conf
```
5. Lancer un second terminal dans le conteneur :
```bash
docker exec -it mosquitto_broker /bin/sh
```
6. Ajouter en fin de fichier la configuration suivante:
```bash
listener 8883
cafile /ca.crt
certfile /server.crt
keyfile /server.key
```
## GÉNÉRATION DES CERTIFICATS DU CA ET DU SERVEUR :

7. Créer un certificat CA (qui signe le certificat serveur) :
```bash
openssl req -new -x509 -days 1826 -extensions v3_ca -keyout ca.key -out ca.crt
```
8. Générer une clé privée et une demande de Signature de Certificat:
- Créer une clé privée serveur :
```bash
openssl genrsa -out server.key 2048
```
- Créer une demande de signature de certificat (CSR) :
```bash
openssl req -out server.csr -key server.key -new
```

9. Signer la Demande de Signature de Certificat (CSR) et générer un certificat SSL/TLS signé:
```bash
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 360
```
- in server.csr : Spécifie le fichier d'entrée contenant la CSR. server.csr est le fichier qui contient la demande de certificat générée par ou pour le serveur, qui souhaite obtenir un certificat signé.
- CA ca.crt : Indique le certificat de l'Autorité de Certification (CA) utilisé pour signer la CSR. ca.crt contient le certificat public de la CA.
- CAkey ca.key : Spécifie la clé privée de l'Autorité de Certification (ca.key) qui correspond au certificat public spécifié par -CA. Cette clé privée est utilisée pour signer effectivement la CSR et générer le certificat signé.
- out server.crt : Définit le nom du fichier de sortie pour le certificat signé. Dans cet exemple, le certificat signé est sauvegardé dans server.crt.
10. Relancer le service mosquitto :
```bash
mosquitto -c /etc/mosquitto/mosquitto.conf
```

11. Copier le fichier ca.crt (représente le certificat de l'Autorité de Certification) sur le client mosquitto (en 2 étapes) :
- Copier tout d'abord ca.crt du broker sur la machine host :
```bash
docker cp mosquitto_broker:/ca.crt .
```

- Copier le fichier ca.crt depuis le machine host vers le broker mosquitto :
```bash
docker cp ca.crt mosquitto_client:/
```

12. Depuis le broker on s'abonne à un topic :
```bash
mosquitto_sub -h 172.27.0.2 -p 8883 --cafile /ca.crt -t your/topic
```

13. On se connecte sur le client :
```bash
docker exec -it mosquitto_client /bin/bash
```
![Texte alternatif](ssl-4.svg)

14. Depuis le client mosquitto, on publie :
```bash
mosquitto_pub -h 172.27.0.2 -p 8883 --cafile /ca.crt -t your/topic -m "Hello world"
```




