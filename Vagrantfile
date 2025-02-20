Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.define "broker" do |broker|
    broker.vm.hostname = "broker"
    broker.vm.network "private_network", ip: "192.168.56.20"
    
    broker.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    
    broker.vm.provision "shell", inline: <<-SHELL
      # Création de l'utilisateur client
      id -u client &>/dev/null || useradd -m -s /bin/bash client
      echo "client:password123" | chpasswd
      
      # Génération de la clé SSH pour l'utilisateur vagrant
      sudo -u vagrant mkdir -p /home/vagrant/.ssh
      sudo -u vagrant ssh-keygen -t rsa -N "" -f /home/vagrant/.ssh/id_rsa || true
      
      sudo apt-get update

       # Installer Wireshark, Firefox et Ettercap
      sudo apt-get install -y openssl mosquitto-clients mosquitto
      # Configuration du pare-feu UFW
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw allow 22/tcp   # SSH
      sudo ufw allow 1883/tcp  # MQTT sans TLS
      sudo ufw allow 8883/tcp  # MQTT avec TLS
      echo "y" | sudo ufw enable  # Force l'activation sans confirmation

      # Vérification du statut
      sudo ufw status verbose
      
      # Copie de la clé publique
      cp /home/vagrant/.ssh/id_rsa.pub /vagrant/broker_key.pub
    SHELL
  end

  config.vm.define "client" do |client|
    client.vm.hostname = "client"
    client.vm.network "private_network", ip: "192.168.56.21"
    
    client.vm.provider "virtualbox" do |vb|
      vb.memory = "1024"
      vb.cpus = 1
    end
    
    client.vm.provision "shell", inline: <<-SHELL
      # Création de l'utilisateur client
      id -u client &>/dev/null || useradd -m -s /bin/bash client
      echo "client:password123" | chpasswd
      
      # Configuration du répertoire .ssh pour l'utilisateur client
      mkdir -p /home/client/.ssh
      chmod 700 /home/client/.ssh
      touch /home/client/.ssh/authorized_keys
      chmod 600 /home/client/.ssh/authorized_keys
      
      # Ajout de la clé publique du broker aux clés autorisées
      if [ -f /vagrant/broker_key.pub ]; then
        cat /vagrant/broker_key.pub >> /home/client/.ssh/authorized_keys
      fi
      
      sudo apt-get update

       # Installer Wireshark, Firefox et Ettercap
      sudo apt-get install -y openssl mosquitto-clients xauth x11-apps

      # Ajouter la variable DISPLAY dans le fichier .bashrc pour qu'elle soit disponible à chaque session
      echo "export DISPLAY=localhost:10.0" >> /home/vagrant/.bashrc

      # Correction des propriétés
      chown -R client:client /home/client/.ssh
      
      # Configuration explicite de sshd
      cat > /etc/ssh/sshd_config.d/custom.conf << EOL
PasswordAuthentication yes
PubkeyAuthentication yes
PermitRootLogin no
EOL
      
      # Redémarrage du service SSH
      systemctl restart sshd
    SHELL
  end
end
