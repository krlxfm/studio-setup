#/bin/sh

# Installs and configures LibreTime to run on a KRLX server with domain stream.krlx.org
# This script intended to be run on a clean install of Ubuntu 18.04

sudo apt update || exit 1    # forces user to be root, and requires internet access, else exits
sudo apt upgrade

# Set up ntp to synchronize times properly
sudo apt install ntp
# Add ntp servers using ed

printf "16a
server ntp.ubuntu.com
server 0.north-america.pool.ntp.org
server 1.north-america.pool.ntp.org
server 2.north-america.pool.ntp.org
server 3.north-america.pool.ntp.org
.
w
q
" | sudo ed /etc/ntp.conf
invoke-rc.d ntp restart

GATEWAY="$(ip route show | awk '/default/{print $3}')"
IP_ADDR="$(ip route show | awk '/\//{print $1}')"

# Overwrite netplan config file to have static IP of server
sudo mkdir -p /etc/netplan
NETPLAN_ED="0a
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd
  ethernets:
    enp3s0:
      addresses: [$IP_ADDR]
      gateway4: $GATEWAY
      nameservers:
        addresses: 1.1.1.1
.
w
q
"
COUNT="$(ls -1 /etc/netplan/*.netcfg.yaml | wc -l)"
case $COUNT in
    0) touch /etc/netplan/01-netcfg.yaml
        printf "$NETPLAN" | sudo ed /etc/netplan/01-netcfg.yaml ;;
    *) NETPLAN_FILE="$(ls -1 /etc/netplan/*-netcfg.yaml | head -1)"
        LINE="$(grep -n "dhcp" "$NETPLAN_FILE" | tr ":" " " | awk '{print $1}')"
        printf $LINE"c\n      addresses: [$IP_ADDR]\n      gateway4: $GATEWAY\n      nameservers:\n        addresses: 1.1.1.1\n.\nw\nq\n" | ed $NETPLAN_FILE ;;
esac

# Enable firewall
sudo apt install ufw
sudo ufw enable
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 8000/tcp
sudo ufw allow 8001/tcp
sudo ufw allow 8002/tcp

git clone https://github.com/LibreTime/libretime.git
cd libretime
./install -fiap
# It will prompt if you would like to run composer as root... it seems that the
# script is written in a way which requires you to continue as root, since you
# needed to call `sudo ./install -fiap`, and thus are root for the duration of
# the script.

# Now, need to configure LibreTime through the browser-based client
echo "Open $IP_ADDR in a web browser (without HTTPS-Everywhere)"
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

