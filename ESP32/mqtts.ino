#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include "config.h"  // Fichier séparé contenant les informations sensibles

WiFiClientSecure wifiClient;
PubSubClient client(wifiClient);

void connectToWiFi() {
  Serial.println("Connexion au WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnecté au WiFi");
}

void connectToMQTT() {
  while (!client.connected()) {
    Serial.println("Connexion au broker MQTT...");
    if (client.connect("ESP32Client", MQTT_USER, MQTT_PASSWORD)) {
      Serial.println("Connecté au broker MQTT");
      client.subscribe("test/fecamp");
    } else {
      Serial.print("Échec de connexion, rc=");
      Serial.println(client.state());
      delay(5000);
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Message reçu sur le sujet : ");
  Serial.println(topic);
  Serial.print("Message : ");
  for (unsigned int i = 0; i < length; i++) {
    Serial.print((char)payload[i]);
  }
  Serial.println();
}

void setup() {
  Serial.begin(115200);
  connectToWiFi();
  wifiClient.setCACert(CA_CERT); // Configure le certificat pour la sécurité
  client.setServer(MQTT_SERVER, MQTT_PORT); 
  client.setCallback(callback);
  connectToMQTT();
}

void loop() {
  if (!client.connected()) {
    connectToMQTT();
  }
  client.loop();
}
