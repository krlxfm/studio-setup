#/bin/sh

# Installs and configures LibreTime to run on a KRLX server with domain stream.krlx.org
# This script intended to be run on a clean install of Debian
# (Ubuntu is messier -- see netplan)

DOMAIN="stream.krlx.org"    # Ensure that stream.krlx.org points to this server's IP
DNS="1.1.1.1"   # Cloudflare

sudo apt update || exit 1    # forces user to be a sudoer, and requires internet access, else exits
sudo apt upgrade

# Go to home directory
cd

# Establish new hostname
sudo hostname "$DOMAIN"                     # transient hostname
echo "$DOMAIN" > "hostname"
sudo cp "hostname" "/etc/hostname"          # static hostname

# Install some important packages
sudo apt install git htop ufw

# Enable firewall
sudo apt install ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 8001/tcp
sudo ufw allow 8002/tcp
sudo ufw enable

git clone https://github.com/LibreTime/libretime.git
cd libretime
sudo ./install -fiap
# It will prompt if you would like to run composer as root... it seems that the
# script is written in a way which requires you to continue as root, since you
# needed to call `sudo ./install -fiap`, and thus are root for the duration of
# the script.

# Now, need to configure LibreTime through the browser-based client
echo "Open $DOMAIN in a web browser (without HTTPS-Everywhere)"
echo "to finish configuring LibreTime.  Recommended to change passwords."
echo "Once finished with configuration, press <Enter>."
read DONE

# Enable systemd services for LibreTime and supplemental programs
sudo systemctl enable libretime-liquidsoap || sudo systemctl enable libretime-liquidsoap.service
sudo systemctl enable libretime-playout || sudo systemctl enable libretime-playout.service
sudo systemctl enable libretime-celery || sudo systemctl enable libretime-celery.service
sudo systemctl enable libretime-analyzer || sudo systemctl enable libretime-analyzer.service
sudo systemctl enable apache2 || sudo systemctl enable apache2.service
sudo systemctl enable rabbitmq-server || sudo systemctl enable rabbitmq-server.service

# Add 22-data user to audio group so LibreTime can "output analog audio directly
# from its server to a mixing console or transmitter"
sudo adduser www-data audio

# Set up HTTPS using certbot
# WARNING: This may break things, so leaving it commented out
#sudo apt install certbot python3-certbot-apache
#sudo certbot --apache   # get and install certificate
