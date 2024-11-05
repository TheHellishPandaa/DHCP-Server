#!/bin/bash
#:Description: A tool for creating and managing a DHCP server with MAC filtering in an Ubuntu 22.04 system.
#:Usage: First option installs the DHCP-SERVER. The second option configures and sets up parameters, including MAC filtering.
#:Dependencies:
#:      - "ISC-DHCP-SERVER"

install_dhcp_server(){
   sudo apt-get update && sudo apt-get upgrade -y
   sudo apt-get install isc-dhcp-server
   echo -e "Copying the file isc-dhcp-server in /etc/default/isc-dhcp-server.copy..."
   sudo cp /etc/default/isc-dhcp-server /etc/default/isc-dhcp-server.copy
   
   echo -e "Interfaces of the system: "
   ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"
   read -p "Enter the name of the interface for the DHCP server (e.g., ens33, ens34, etc.): " ens

   config_file="/etc/default/isc-dhcp-server"
   if [ -f "$config_file" ]; then
       sudo sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$ens\"/" "$config_file"
   else
       echo "Error: $config_file doesn't exist."
   fi

   sudo systemctl restart isc-dhcp-server
   sudo ip link set "$ens" down
   sudo ip link set "$ens" up
}

configure_dhcp_server(){
   config_file="/etc/dhcp/dhcpd.conf"
   if [ ! -f "$config_file" ]; then
       echo "Error: The $config_file doesn't exist."
       exit 1
   fi
   echo -e "Interfaces of the system: "
   ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"
   read -p "Enter the name of the interface for the DHCP server (e.g., ens33, ens34, etc.): " ens

   config_file="/etc/default/isc-dhcp-server"
   if [ -f "$config_file" ]; then
       sudo sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$ens\"/" "$config_file"
   else
       echo "Error: $config_file doesn't exist."
   fi

   read -p "Enter the network address (e.g., 10.33.200.0): " subnet
   read -p "Enter the network mask (e.g., 255.255.255.0): " netmask
   read -p "Enter the IP address of the router (e.g., 10.33.200.1): " router
   read -p "Enter the DNS ( separated by commas , e.g., 8.8.8.8,1.1.1.1): " dns
   read -p "Enter the start of the IP range (e.g., 10.33.200.5): " range_start
   read -p "Enter the end of the IP range (e.g., 10.33.200.20): " range_end

   config_dhcp="subnet $subnet netmask $netmask {
     option routers $router;
     option subnet-mask $netmask;
     option domain-name-servers $dns;
     range $range_start $range_end;
   }"

   echo "option domain-name \"example.org\";" | sudo tee "$config_file" > /dev/null
   echo "option domain-name-servers ns1.example.org, ns2.example.org;" | sudo tee -a "$config_file" > /dev/null
   echo "default-lease-time 600;" | sudo tee -a "$config_file" > /dev/null
   echo "max-lease-time 7200;" | sudo tee -a "$config_file" > /dev/null
   echo "ddns-update-style none;" | sudo tee -a "$config_file" > /dev/null
   echo -e "\n$config_dhcp" | sudo tee -a "$config_file" > /dev/null

   echo "DHCP configuration updated in $config_file."

   sudo systemctl restart isc-dhcp-server
}

configure_mac_filter(){
   config_file="/etc/dhcp/dhcpd.conf"
   if [ ! -f "$config_file" ]; then
       echo "Error: The $config_file doesn't exist."
       exit 1
   fi

   echo "Configuring MAC filtering..."
   echo -e "\n# MAC Filtering Configuration\n" | sudo tee -a "$config_file" > /dev/null

   while true; do
       read -p "Enter an allowed MAC address (or type 'done' to finish): " mac_address
       if [ "$mac_address" == "done" ]; then
           break
       fi
       read -p "Enter the IP address to assign to $mac_address: " ip_address
       
       # Add a host block for each allowed MAC address
       echo "host allowed_device_$mac_address {
         hardware ethernet $mac_address;
         fixed-address $ip_address;
       }" | sudo tee -a "$config_file" > /dev/null
   done

   echo "MAC filtering rules added to $config_file."

   sudo systemctl restart isc-dhcp-server
}

while true; do
   echo "Select an option:"
   echo "1) Install ISC-DHCP-SERVER"
   echo "2) Configure DHCP server parameters"
   echo "3) Configure MAC filtering"
   echo "4) Exit"

   read -p "Enter your option (1-4): " option

   case $option in
       1)
           install_dhcp_server
           ;;
       2)
           configure_dhcp_server
           ;;
       3)
           configure_mac_filter
           ;;
       4)
           exit 0
           ;;
       *)
           echo "Invalid option, please try again."
           ;;
   esac

   echo -e "\n"
done
