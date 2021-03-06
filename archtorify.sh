#!/usr/bin/env bash

# archtorify.sh
#
# Arch Linux - Transparent proxy through Tor
#
# Copyright (C) 2015-2019 Brainfuck

# GNU GENERAL PUBLIC LICENSE
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# ===================================================================
# General settings
# ===================================================================

# Program information
readonly prog_name="archtorify"
readonly version="1.17.1"
readonly signature="Copyright (C) 2015-2019 Brainfuck"
readonly bug_report="Please report bug to <https://github.com/brainfucksec/archtorify/issues>."


# Colors for terminal output
export red=$'\e[0;91m'
export green=$'\e[0;92m'
export blue=$'\e[0;94m'
export white=$'\e[0;97m'
export bold_white=$'\e[1;97m'
export cyan=$'\e[0;96m'
export endc=$'\e[0m'


# ===================================================================
# Set program's directories and files
# ===================================================================

# Configuration files: /usr/share/archtorify/data
# Backup files: /opt/archtorify/backups
readonly config_dir="/usr/share/archtorify/data"
readonly backup_dir="/opt/archtorify/backups"

# End settings
# ===================================================================


# ===================================================================
# Show program banner
# ===================================================================
banner() {
printf "${bold_white}
=========================================

 _____         _   _           _ ___
|  _  |___ ___| |_| |_ ___ ___|_|  _|_ _
|     |  _|  _|   |  _| . |  _| |  _| | |
|__|__|_| |___|_|_|_| |___|_| |_|_| |_  |
                                    |___|

=========================================

=[ Arch Linux
=[ Transparent proxy through Tor${endc}\\n"

printf "${white}
Version: $version
$signature
=========================================${endc}\\n\\n"
}


# ===================================================================
# Check if the program run as a root
# ===================================================================
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        printf "\\n${red}%s${endc}\\n" \
               "[ failed ] Please run this program as a root!" 2>&1
        exit 1
    fi
}


# ===================================================================
# Display program version
# ===================================================================
print_version() {
    printf "%s\\n" "$prog_name $version"
    exit 0
}


# ===================================================================
# Disable firewall ufw
# ===================================================================

# See: https://wiki.archlinux.org/index.php/Uncomplicated_Firewall
#
# If ufw is installed and/or active, disable it, if isn't installed,
# do nothing, don't display nothing to user, just jump to next function
disable_ufw() {
    if hash ufw 2>/dev/null; then
        if ufw status | grep -q active$; then
            printf "${blue}%s${endc} ${green}%s${endc}\\n" \
                   "::" "Disabling firewall ufw, please wait..."
            ufw disable
        else
            ufw status | grep -q inactive$;
            printf "${blue}%s${endc} ${green}%s${endc}\\n" \
                   "::" "Firewall ufw is inactive, continue..."
        fi
    fi
}


# ===================================================================
# Enable ufw
# ===================================================================

# Often, if ufw isn't installed, again, do nothing
# and jump to the next function
enable_ufw() {
    if hash ufw 2>/dev/null; then
        if ufw status | grep -q inactive$; then
            printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" \
                   "::" "Enabling firewall ufw, please wait..."
            ufw enable
        fi
    fi
}


# ===================================================================
# Setup program files
# ===================================================================

# Function for replace default system files with program files
replace_file() {
    local source_file="$1"
    local dest_file="$2"

    # Backup original file in the backup directory
    if ! cp -vf "$1" "$backup_dir/$2.backup" 2>/dev/null; then
        printf "\\n${red}%s${endc}\\n" \
            "[ failed ] can't copy original '$1' file in the backup directory."

        printf "%s\\n" "$bug_report"
        exit 1
    fi

    # Copy new file from archtorify configuration directory
    if ! cp -vf "$config_dir/$2" "$1" 2>/dev/null; then
        printf "\\n${red}%s${endc}\\n" "[ failed ] can't set '$1'"
        printf "%s\\n" "$bug_report"
        exit 1
    fi
}


# ===================================================================
# Check default settings
# ===================================================================

# Check:
# -> required dependencies (only tor)
# -> program folders
# -> tor systemd service file
# -> tor `torrc` configuration file
check_defaults() {
    # Check: dependencies
    # ===================
    if ! hash tor 2>/dev/null; then
        printf "\\n${red}%s${endc}\\n" \
               "[ failed ] tor isn't installed, exit"
        exit 1
    fi

    # Check: program's defaults directories
    # =====================================
    if [ ! -d "$backup_dir" ]; then
        printf "\\n${red}%s${endc}\\n" \
               "[ failed ] directory '$backup_dir' not exist, run makefile first!"
        exit 1
    fi

    if [ ! -d "$config_dir" ]; then
        printf "\\n${red}%s${endc}\\n" \
               "[ failed ] directory '$config_dir' not exist, run makefile first!"
        exit 1
    fi

    # Check file: `/usr/lib/systemd/system/tor.service`
    # =================================================
    #
    # reference file: `/usr/share/archtorify/data/tor.service`
    #
    # grep required strings from existing file
    grep -q -x '\[Service\]' /usr/lib/systemd/system/tor.service
    local string1=$?

    grep -q -x 'User=root' /usr/lib/systemd/system/tor.service
    local string2=$?

    grep -q -x 'Group=root' /usr/lib/systemd/system/tor.service
    local string3=$?

    grep -q -x 'Type=simple' /usr/lib/systemd/system/tor.service
    local string4=$?

    # if required strings does not exists replace original
    # `tor.service` file
    if [[ "$string1" -ne 0 ]] ||
       [[ "$string2" -ne 0 ]] ||
       [[ "$string3" -ne 0 ]] ||
       [[ "$string4" -ne 0 ]]; then

        printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" \
               "::" "Setting file: /usr/lib/systemd/system/tor.service"

        replace_file /usr/lib/systemd/system/tor.service tor.service
    fi

    # Check: permissions of directory: `/var/lib/tor`
    # ===============================================
    #
    # required permissions: -rwx------  tor tor
    # octal value: 700
    if [[ "$(stat -c '%U' /var/lib/tor)" != "tor" ]] &&
        [[ "$(stat -c '%a' /var/lib/tor)" != "700" ]]; then

        printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" \
               "::" "Setting permissions of directory: /var/lib/tor"

        # Exec commands if needed:
        # set owner `tor`
        chown -R tor:tor /var/lib/tor

        # chmod 700
        chmod -R 700 /var/lib/tor

        # reload systemd daemons
        systemctl --system daemon-reload

        printf "%s\\n" "... Done"
    fi

    # Check file: `/etc/tor/torrc`
    # ============================
    #
    # reference file: `/usr/share/archtorify/data/torrc`
    #
    # grep required strings from existing file
    grep -q -x 'User tor' /etc/tor/torrc
    local string1=$?

    grep -q -x 'SocksPort 9050' /etc/tor/torrc
    local string2=$?

    grep -q -x 'DNSPort 53' /etc/tor/torrc
    local string3=$?

    grep -q -x 'TransPort 9040' /etc/tor/torrc
    local string4=$?

    # if required strings does not exists replace original
    # `/etc/tor/torrc` file
    if [[ "$string1" -ne 0 ]] ||
       [[ "$string2" -ne 0 ]] ||
       [[ "$string3" -ne 0 ]] ||
       [[ "$string4" -ne 0 ]]; then

        printf "\\n${blue}%s${endc} ${green}%s${endc}\n" "::" \
               "Setting file: /etc/tor/torrc"

        replace_file /etc/tor/torrc torrc
    fi
}


# ===================================================================
# Check public IP
# ===================================================================
check_ip() {
    printf "${cyan}%s${endc} ${green}%s${endc}\\n" \
           "==>" "Checking your public IP, please wait..."

    if external_ip="$(curl -s -m 10 http://ipinfo.io)" ||
        external_ip="$(curl -s -m 10 http://ip-api.com)"; then

        printf "${blue}%s${endc} ${green}%s${endc}\\n" "::" "IP Address Details:"
        printf "${white}%s${endc}\\n" "$external_ip" | tr -d '"{}' | sed 's/  //g'
    else
        printf "${red}%s${endc}\\n\\n" "[ failed ] curl: HTTP request error"

        printf "%s\\n" "try another Tor circuit with '$prog_name --restart'"
        printf "%s\\n" "$bug_report"
        exit 1
    fi
}


# ===================================================================
# Check status of program and services
# ===================================================================

# Check:
# -> tor.service
# -> tor settings
# -> public IP
check_status () {
    check_root

    # Check status of tor.service
    # ===========================
    printf "${cyan}%s${endc} ${green}%s${endc}\\n" \
           "==>" "Check current status of Tor service"

    if systemctl is-active tor.service >/dev/null 2>&1; then
        printf "${cyan}%s${endc} ${green}%s${endc}\\n\\n" \
               "[ ok ]" "Tor service is active"
    else
        printf "${red}%s${endc}\\n" "[-] Tor service is not running! exit"
        exit 1
    fi

    # Check tor network settings
    # ==========================
    #
    # make http request with curl at: https://check.torproject.org/
    # and grep the necessary strings from the html page to test connection
    # with tor
    printf "${cyan}%s${endc} ${green}%s${endc}\\n" \
           "==>" "Check Tor network settings"

    local hostport="localhost:9050"
    local url="https://check.torproject.org/"

    # curl: `-L` and `tac` for avoid error: (23) Failed writing body
    # https://github.com/kubernetes/helm/issues/2802
    # https://stackoverflow.com/questions/16703647/why-curl-return-and-error-23-failed-writing-body
    if curl -s -m 10 --socks5 "$hostport" --socks5-hostname "$hostport" -L "$url" \
        | cat | tac | grep -q 'Congratulations'; then
        printf "${cyan}%s${endc} ${green}%s${endc}\\n\\n" \
               "[ ok ]" "Your system is configured to use Tor"
    else
        printf "${red}%s${endc}\\n\\n" "[!] Your system is not using Tor"

        printf "%s\\n" "try another Tor circuit with '$prog_name --restart'"
        printf "%s\\n" "$bug_report"
        exit 1
    fi

    # Check current public IP
    check_ip
}

# ===================================================================
# Start transparent proxy
# ===================================================================
main() {
    banner
    check_root
    sleep 1
    check_defaults

    # Stop tor.service
    # ================
    if systemctl is-active tor.service >/dev/null 2>&1; then
        systemctl stop tor.service
    fi

    printf "\\n${cyan}%s${endc} ${green}%s${endc}\\n" \
           "==>" "Starting Transparent Proxy"

    # Disable firewall ufw
    sleep 2
    disable_ufw

    # DNS settings: `/etc/resolv.conf`:
    # =================================
    #
    # Configure system's DNS resolver to use Tor's DNSPort
    # on the loopback interface, i.e. write nameserver 127.0.0.1
    # to `etc/resolv.conf` file
    printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" \
           "::" "Configure system's DNS resolver to use Tor's DNSPort"

    # backup current resolv.conf
    if ! cp -vf /etc/resolv.conf "$backup_dir/resolv.conf.backup" 2>/dev/null; then
        printf "${red}%s${endc}\\n" \
               "[ failed ] can't copy resolv.conf to the backup directory"

        printf "%s\\n" "$bug_report"
        exit 1
    fi

    # write new nameserver
    printf "%s\\n" "nameserver 127.0.0.1" > /etc/resolv.conf
    sleep 1

    # Disable IPv6 with sysctl
    # ========================
    printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" "::" "Disable IPv6 with sysctl"
    sysctl -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1


    # Start tor.service for new configuration
    # =======================================
    printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" "::" "Start Tor service"

    if systemctl start tor.service iptables 2>/dev/null; then
        printf "${cyan}%s${endc} ${green}%s${endc}\\n" \
            "[ ok ]" "Tor service started"
    else
        printf "${red}%s${endc}\\n" "[ failed ] systemd error, exit!"
        exit 1
    fi

    # iptables settings
    # =================
    #
    # Save current iptables rules
    printf "\\n${blue}%s${endc} ${green}%s${endc}" "::" "Backup iptables... "
    iptables-save > "$backup_dir/iptables.backup"
    printf "%s\\n" "Done"

    # Flush current iptables rules
    printf "${blue}%s${endc} ${green}%s${endc}" "::" "Flush current iptables... "
    iptables -F
    iptables -t nat -F
    printf "%s\\n" "Done"

    # Set new iptables rules
    # ======================
    #
    # write new iptables rules on file: `/etc/iptables/iptables.rules`
    #
    # reference file: `/usr/share/archtorify/data/iptables.rules`
    printf "${blue}%s${endc} ${green}%s${endc}\\n" "::" "Set new iptables rules... "

    if ! cp -vf "$config_dir/iptables.rules" /etc/iptables/iptables.rules 2>/dev/null; then
        printf "\\n${red}%s${endc}\\n" \
               "[ failed ] can't set '/etc/iptables/iptables.rules'"

        printf "%s\\n" "$bug_report"
        exit 1
    else
        printf "\\n"
    fi

    # check program status
    check_status

    printf "${cyan}%s${endc} ${green}%s${endc}\\n" \
           "[ ok ]" "Transparent Proxy activated, your system is under Tor"
}


# ===================================================================
# Stop transparent proxy
# ===================================================================

# Stop connection with Tor Network and return to clearnet navigation
stop() {
    check_root

    printf "${cyan}%s${endc} ${green}%s${endc}\\n" \
           "==>" "Stopping Transparent Proxy"
    sleep 2

    # Resets default settings
    # =======================
    #
    # Flush current iptables rules
    printf "${blue}%s${endc} ${green}%s${endc}" "::" "Flush iptables rules... "
    iptables -F
    iptables -t nat -F
    printf "%s\\n" "Done"

    # Restore iptables
    printf "${blue}%s${endc} ${green}%s${endc}" \
           "::" "Restore the default iptables rules... "

    iptables-restore < "$backup_dir/iptables.backup"
    printf "%s\\n" "Done"

    # Stop tor.service
    printf "${blue}%s${endc} ${green}%s${endc}" "::" "Stop Tor service... "
    systemctl stop tor.service
    printf "%s\\n" "Done"

    # Restore `/etc/resolv.conf`
    # =========================
    printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" \
           "::" "Restore '/etc/resolv.conf' file with default DNS"

    # delete current `/etc/resolv.conf` file
    rm -v /etc/resolv.conf

    # restore file with `resolvconf` program if exists
    # otherwise copy the original file from backup directory
    if hash resolvconf 2>/dev/null; then
        resolvconf -u
    else
        cp -vf "$backup_dir/resolv.conf.backup" /etc/resolv.conf
    fi
    sleep 1

    # Re-enable IPv6
    # ==============
    printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" "::" "Enable IPv6"
    sysctl -w net.ipv6.conf.all.disable_ipv6=0
    sysctl -w net.ipv6.conf.default.disable_ipv6=0

    # Restore default `/etc/tor/torrc`
    # ================================
    printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" \
           "::" "Restore '/etc/tor/torrc' file with default tor settings"

    cp -vf "$backup_dir/torrc.backup" /etc/tor/torrc

    # Restore default `/usr/lib/systemd/system/tor.service`
    # =====================================================
    printf "\\n${blue}%s${endc} ${green}%s${endc}\\n" \
           "::" "Restore default '/usr/lib/systemd/system/tor.service' file"

    cp -vf "$backup_dir/tor.service.backup" /usr/lib/systemd/system/tor.service

    # Enable firewall ufw
    enable_ufw

    # End program
    # ===========
    printf "\\n${cyan}%s${endc} ${green}%s${endc}\\n" \
           "[-]" "Transparent Proxy stopped"
}


# ===================================================================
# Restart tor.service and change public IP (i.e. new Tor exit node)
# ===================================================================
restart() {
    check_root

    printf "${cyan}%s${endc} ${green}%s${endc}\\n" \
            "==>" "Restart Tor service and change IP"

    systemctl restart tor.service iptables
    sleep 3

    printf "${cyan}%s${endc} ${green}%s${endc}\\n\\n" \
           "[ ok ]" "Tor Exit Node changed"

    # Check current public ip
    check_ip
    exit 0
}


# ===================================================================
# Show help menù
# ===================================================================
usage() {
    printf "${white}%s${endc}\\n" "$prog_name $version"
    printf "${white}%s${endc}\\n" "Arch Linux - Transparent proxy through Tor"
    printf "${white}%s${endc}\\n\\n" "$signature"

    printf "${green}%s${endc}\\n\\n" "Usage:"

    printf "${white}%s${endc} ${red}%s${endc} ${white}%s${endc} ${red}%s${endc}\\n" \
           "┌─╼" "$USER" "╺─╸" "$(hostname)"
    printf "${white}%s${endc} ${green}%s${endc}\\n\\n" "└───╼" "$prog_name [option]"

    printf "${green}%s${endc}\\n\\n" "Options:"

    printf "${white}%s${endc}\\n" \
           "-h, --help      show this help message and exit"

    printf "${white}%s${endc}\\n" \
           "-t, --tor       start transparent proxy through tor"

    printf "${white}%s${endc}\\n" \
           "-c, --clearnet  reset iptables and return to clearnet navigation"

    printf "${white}%s${endc}\\n" \
           "-s, --status    check status of program and services"

    printf "${white}%s${endc}\\n" \
           "-i, --ipinfo    show public IP"

    printf "${white}%s${endc}\\n" \
           "-r, --restart   restart tor service and change Tor exit node"

    printf "${white}%s${endc}\\n" \
           "-v, --version   display program version and exit"
    exit 0
}


# ===================================================================
# Parse command line options
# ===================================================================
if [[ "$#" -eq 0 ]]; then
    printf "%s\\n" "$prog_name: Argument required"
    printf "%s\\n" "Try '$prog_name --help' for more information."
    exit 1
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        -t | --tor)
            main
            shift
            ;;
        -c | --clearnet)
            stop
            ;;
        -r | --restart)
            restart
            ;;
        -s | --status)
            check_status
            ;;
        -i | --ipinfo)
            check_ip
            ;;
        -v | --version)
            print_version
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        -- | -* | *)
            printf "%s\\n" "$prog_name: Invalid option '$1'"
            printf "%s\\n" "Try '$prog_name --help' for more information."
            exit 1
            ;;
    esac
    shift
done
