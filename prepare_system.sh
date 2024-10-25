###
# v1.0 Script to reload ice driver from given path, enable all 
#network interfaces and list if links are detected.
#
# usage: ./prepare_system [path_to_driver]
# set DEBUG_COMMANDS environment variable to run your own commands.
###
RED='\e[31m'
GREEN='\e[32m'
RESET='\e[0m'
# if MAC address starts with MAC_PREFIX, change it
MAC_PREFIX="00:00:00:00" 
# Starting suffix for new MAC address assignments 
SUFFIX=0x0120 
INTERFACES=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo)
ICE_DRIVER_PATH=$1
SCRIPT_NAME=$(basename "$0")
INSTALL_DESTINATION="/usr/local/bin/$SCRIPT_NAME"
#add commands specific to debug
function run_user_commands {
echo -e "${GREEN}Executing commands from DEBUG_COMMANDS...${RESET}"
eval "$DEBUG_COMMANDS"
}
#install script to /usr/local/bin
function install_script {
cp "$0" "$INSTALL_DESTINATION" 
chmod +x "$INSTALL_DESTINATION" 
echo -e "${GREEN}Script copied to $INSTALL_DESTINATION${RESET}"

}
function stop_useless_services {
systemctl stop firewalld > /dev/null 2>&1
systemctl stop ntp > /dev/null 2>&1
}
function reload_driver {
if [[ -f $ICE_DRIVER_PATH && "$ICE_DRIVER_PATH" == *".ko" ]]; then
    echo -e "${GREEN}Removing old and inserting new ice driver...${RESET}"
    rmmod irdma > /dev/null 2>&1
    rmmod ice > /dev/null 2>&1
    insmod $ICE_DRIVER_PATH
else
  echo -e "${RED}Driver path does not exist, or is incorrect (no ice.ko file), skipping.${RESET}"
fi
}
#Enabling all interfaces in the system#
function enable_all_interfaces {
echo -e "${GREEN}Enabling all network interfaces in the system...${RESET}"
echo -e "Loading interfaces and IPs list...\n"
for interface in $INTERFACES; do
    sudo ip link set "$interface" up
done
}
#printing if physical link is detected  or not using ethtool#
function print_links_info {
for iface in $INTERFACES; do
        echo "Interface: $iface"
        ip addr show $iface | grep -e "inet" -e "link/ether"
        ethtool $iface | grep  "Link detected"
        ethtool -i $iface | grep -e "bus" -e "driver" -e "version" | grep -v "expansion"
        echo "------------------------------------------------------"
done
}
function change_wrong_mac_addresses {
for iface in $(ls /sys/class/net/ | grep -Ev "lo|bootnet|br0|vir"); do
  current_mac=$(cat /sys/class/net/$iface/address)
  if [[ $current_mac == $MAC_PREFIX* ]]; then
    # Convert SUFFIX to a MAC format (convert hex to standard MAC address format)
    new_mac=$(printf "%02x:%02x:%02x:%02x:%02x:%02x" 0 0 0 0 $((SUFFIX >> 8)) $((SUFFIX & 0xff)))
    echo "Changing MAC address of $iface from $current_mac to $new_mac"
      #Increment the suffix for the next MAC address
    SUFFIX=$((SUFFIX + 1))
  fi
done
}
### Main ###
install_script
stop_useless_services
reload_driver
change_wrong_mac_addresses
enable_all_interfaces
run_user_commands
print_links_info