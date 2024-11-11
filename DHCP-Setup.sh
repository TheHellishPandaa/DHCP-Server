#!/bin/bash
# version 1.1
# Author: Jaime Galvez (TheHellishPandaa)
#&COPY;2024 
#GNU/GPL Licence
#Date: November-2024
#:Description: A tool for creating and managing a DHCP server with MAC filtering in an Ubuntu 20.04 system or later
#:Usage: First option installs the DHCP-SERVER. The second option configures and sets up parameters, including MAC filtering.
#:Dependencies:
#:      - "ISC-DHCP-SERVER"



clear

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

echo -e "System Interfaces: "
ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"

# Function to install the DHCP server
install_dhcp_server() {
  # Ask the user to input the network interface name
  read -p "Enter the network interface for the DHCP server (e.g., ens19): " interface_name
  
  apt update && apt install -y isc-dhcp-server
  if [ $? -ne 0 ]; then
    echo "Error installing the DHCP server."
    exit 1
  fi

  # Configure the network interface
  echo "INTERFACESv4=\"$interface_name\"" > /etc/default/isc-dhcp-server

  # Configure the dhcpd.conf file with basic settings
  configure_dhcp

  # Restart and enable the DHCP service
  systemctl restart isc-dhcp-server
  systemctl enable isc-dhcp-server

  echo "DHCP server configured on interface $interface_name with network 10.33.206.0/24."
}

# Function to configure the dhcpd.conf file
configure_dhcp() {
  # Backup the configuration file
  cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.bak
  
  read -p "Enter the subnet (e.g., 10.33.206.0): " subnet
  read -p "Enter the subnet mask (e.g., 255.255.255.0): " subnet_mask
  read -p "Enter the starting IP range (e.g., 10.33.206.100): " range_start
  read -p "Enter the ending IP range (e.g., 10.33.206.200): " range_end
  read -p "Enter the router IP (e.g., 10.33.206.1): " router_ip
  read -p "Enter the DNS servers separated by commas (e.g., 8.8.8.8, 8.8.4.4): " dns_servers
  read -p "Enter the domain name (e.g., network.local): " domain_name

  # Write the configuration to dhcpd.conf
  cat <<EOL > /etc/dhcp/dhcpd.conf
# DHCP server configuration
subnet $subnet netmask $subnet_mask {
    range $range_start $range_end;
    option routers $router_ip;
    option subnet-mask $subnet_mask;
    option domain-name-servers $dns_servers;
    option domain-name "$domain_name";
}
EOL
}

# Function to assign a static IP to a device by its MAC address
assign_static_ip() {
  read -p "Enter the MAC address of the device (e.g., 00:1A:2B:3C:4D:5E): " mac_address
  read -p "Enter the specific IP for this device (e.g., 10.33.206.101): " static_ip

  # Add the static IP assignment to dhcpd.conf
  echo "
# Static IP assignment for device with MAC $mac_address
host fixed_device {
    hardware ethernet $mac_address;
    fixed-address $static_ip;
}" >> /etc/dhcp/dhcpd.conf

  # Apply changes without unnecessary restart
  echo "Static IP $static_ip assigned to device with MAC $mac_address."
}

# Function to block a specific IP
block_ip() {
  read -p "Enter the IP to block (e.g., 10.33.206.105): " blocked_ip

  # Add the IP block without duplicating subnet configuration
  echo "
# Block IP $blocked_ip
host blocked_device {
    hardware ethernet $blocked_ip;
    deny booting;
}" >> /etc/dhcp/dhcpd.conf

  echo "IP $blocked_ip has been blocked."
}

# Function to edit IP ranges, DNS, and subnet mask
edit_dhcp_config() {
  echo "Editing DHCP configuration..."
  configure_dhcp
  echo "DHCP configuration updated."
}

# Main menu
while true; do
  clear
  echo "Select an option:"
  echo "1) Install DHCP server"
  echo "2) Assign specific IP to a device (by MAC address)"
  echo "3) Block a specific IP"
  echo "4) Edit IP ranges, DNS, and subnet mask"
  echo "5) Exit"
  read -p "Option: " option

  case $option in
    1)
      install_dhcp_server
      ;;
    2)
      assign_static_ip
      ;;
    3)
      block_ip
      ;;
    4)
      edit_dhcp_config
      ;;
    5)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid option, please try again."
      ;;
  esac

  echo "Applying changes..."
  systemctl restart isc-dhcp-server
  read -p "Press Enter to continue..."
done


