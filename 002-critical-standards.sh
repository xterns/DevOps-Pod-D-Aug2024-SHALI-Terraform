
#!/bin/bash

# Error handler function
error_handler() {
  echo "Error occurred in script at line: $1. Exiting."
  exit 1
}

# Trap the ERR signal to catch errors and call the error_handler function
trap 'error_handler $LINENO' ERR

set -e

log_file="/var/log/critical_standards_setup.log"

# Logging function
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a $log_file
}

# Function to ensure dpkg is configured properly and chrony is installed
 prepare_system() {
  log "Running dpkg configure..."
  sudo dpkg --configure -a

  log "Installing chrony..."
  sudo apt-get install chrony -y
}

# Function to enforce password expiry policy
enforce_password_expiry() {
    log "Enforcing password expiry policy..."

    if [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y libpam-pwquality
        echo "PASS_MAX_DAYS 90" >> /etc/login.defs
        echo "PASS_MIN_DAYS 10" >> /etc/login.defs
        echo "PASS_WARN_AGE 7" >> /etc/login.defs
        for user in $(awk -F: '{if ($3 >= 1000) print $1}' /etc/passwd); do
            chage --maxdays 90 --mindays 10 --warndays 7 $user
        done
    elif [ -f /etc/redhat-release ]; then
        yum install -y libpwquality
        echo "PASS_MAX_DAYS 90" >> /etc/login.defs
        echo "PASS_MIN_DAYS 10" >> /etc/login.defs
        echo "PASS_WARN_AGE 7" >> /etc/login.defs
        for user in $(awk -F: '{if ($3 >= 1000) print $1}' /etc/passwd); do
            chage --maxdays 90 --mindays 10 --warndays 7 $user
        done
    else
        log "Failed to enforce password expiry policy. Exiting..."
        exit 1
    fi

    log "Password expiry policy enforced."
}

# Function to disable USB ports
disable_usb_ports() {
    log "Disabling USB ports..."

    echo "blacklist usb-storage" > /etc/modprobe.d/disable-usb-storage.conf

    if [ -f /etc/debian_version ]; then
        update-initramfs -u
    elif [ -f /etc/redhat-release ]; then
        dracut -f
    else
        log "Failed to disable USB ports. Exiting..."
        exit 1
    fi

    log "USB ports disabled."
}

# Function to configure time synchronization
configure_time_sync() {
    log "Configuring time synchronization..."
    if [ -f /etc/debian_version ]; then
        apt-get update && apt-get install -y chrony
        systemctl enable chrony && systemctl restart chrony
    elif [ -f /etc/redhat-release ]; then
        yum install -y chrony
        systemctl enable chronyd && systemctl restart chronyd
    else
        log "Unsupported OS. Exiting..."
        exit 1
    fi

    if chronyc tracking; then
        log "Time synchronization validated successfully."
    else
        log "Time synchronization validation failed."
        exit 1
    fi

    log "Time synchronization configured."
}

# Function to secure kernel parameters
secure_kernel_params() {
    log "Securing kernel parameters..."
    sysctl_conf='/etc/sysctl.conf'
    commands=(
        "net.ipv4.ip_forward=0"
        "net.ipv4.conf.all.send_redirects=0"
        "net.ipv4.conf.all.accept_source_route=0"
        "net.ipv4.conf.all.accept_redirects=0"
        "net.ipv4.conf.all.secure_redirects=0"
        "net.ipv4.conf.all.log_martians=1"
        "kernel.randomize_va_space=2"
    )
    for command in "${commands[@]}"; do
        if ! grep -q "^$command" "$sysctl_conf"; then
            echo "$command" >> "$sysctl_conf"
        fi
    done

    sysctl -p
    log "Kernel parameters secured."
}

# Function to configure secure DNS
#configure_secure_dns() {
#    AWS_DNS_SERVER="169.254.169.253"
#    log "Configuring secure DNS..."
#
#    if [ -f /etc/debian_version ]; then
#        echo "nameserver $AWS_DNS_SERVER" | tee /etc/resolv.conf
#        echo "supersede domain-name-servers $AWS_DNS_SERVER" | tee -a /etc/dhcp/dhclient.conf
#        systemctl restart systemd-networkd
#    elif [ -f /etc/redhat-release ]; then
#        echo "nameserver $AWS_DNS_SERVER" | tee /etc/resolv.conf
#        echo "supersede domain-name-servers $AWS_DNS_SERVER" | tee -a /etc/dhcp/dhclient.conf
#        systemctl restart NetworkManager
#    fi
#    chmod 644 /etc/resolv.conf
#    nslookup amazon.com
#    exit_code=$?
#    return $exit_code
#}

# Function to remove unnecessary packages
remove_unnecessary_packages() {
    DEBIAN_CRITICAL_SERVICES=("sshd" "systemd-networkd" "chrony" "git" "cron" "systemd-journald" "firewalld")
    REDHAT_CRITICAL_SERVICES=("sshd" "NetworkManager" "selinux" "cron" "systemd-journald" "firewalld" "ssh")
    log "Removing unnecessary packages..."

    if [[ -f /etc/debian_version ]]; then
        CRITICAL_SERVICES="$DEBIAN_CRITICAL_SERVICES"
        apt-get remove -y telnet ftp
        apt-get autoremove -y
    elif [[ -f /etc/redhat-release ]]; then
        CRITICAL_SERVICES="$REDHAT_CRITICAL_SERVICES"
        yum remove -y telnet ftp
    else
        log "Unsupported system type. Exiting..."
        exit 1
    fi

    for service in "${CRITICAL_SERVICES[@]}"; do
        systemctl status "$service"
        if [ $? -ne 0 ]; then
            log "Critical service $service is not running properly. Exiting..."
            exit 1
        fi
    done

    log "Unnecessary packages removed successfully."
}

# Function to enable and configure SELinux/AppArmor
enable_security_framework() {
    if [ -f /etc/debian_version ]; then
        log "Configuring AppArmor on Debian-based system..."
        apt-get update && apt-get install -y apparmor apparmor-utils
        systemctl enable apparmor && systemctl start apparmor
        apparmor_status
    elif [ -f /etc/redhat-release ]; then
        log "Configuring SELinux on RedHat-based system..."
        yum install -y policycoreutils selinux-policy-targeted
        setenforce 1
        sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
        getenforce
    else
        log "Unsupported OS. Exiting..."
        exit 1
    fi
    log "Security framework configured."
}

# Function to disable unnecessary network protocols
disable_unnecessary_network_protocols() {
    log "Disabling unnecessary network protocols..."

    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    sysctl -p
    if [ $? -ne 0 ]; then
        log "Failed to disable unnecessary network protocols."
        exit 1
    fi
    log "Unnecessary network protocols disabled successfully."
}

# Function to monitor user activity
monitor_user_activity() {
    log "Setting up user activity monitoring..."

    if [ -f /etc/debian_version ]; then
        apt-get install -y auditd
    elif [ -f /etc/redhat-release ]; then
        yum install -y audit
    fi

    systemctl enable auditd && systemctl start auditd
    auditctl -e 1
    log "User activity monitoring enabled successfully."
}

# Main execution sequence
#prepare_system
enforce_password_expiry
disable_usb_ports
configure_time_sync
secure_kernel_params
#configure_secure_dns
remove_unnecessary_packages
enable_security_framework
disable_unnecessary_network_protocols
monitor_user_activity

log "002-critical-standards.sh completed successfully."
