#!/bin/bash
set -euo pipefail

# Configuration
OUTPUT_DIR="jumpbox_snapshot_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# System Information
{
    echo "=== System Overview ==="
    hostnamectl
    echo -e "\nKernel Version: $(uname -r)"
    echo "Uptime: $(uptime)"
    echo "Date/Time: $(date)"
} > "$OUTPUT_DIR/system_info.txt"

# Network Configuration
{
    echo "=== Network Configuration ==="
    ip -4 addr show
    ip -6 addr show
    ip route show
    ip -6 route show
    cat /etc/resolv.conf
    ss -tulpn
} > "$OUTPUT_DIR/network_info.txt"

# Firewall State
{
    echo "=== Firewall Rules ==="
    iptables-save
    ip6tables-save
    if command -v ufw >/dev/null; then ufw status verbose; fi
    if command -v firewalld >/dev/null; then firewall-cmd --list-all-zones; fi
} > "$OUTPUT_DIR/firewall_state.txt"

# User/Service Configuration
{
    echo "=== User Accounts ==="
    getent passwd
    echo -e "\n=== Sudoers ==="
    getent group sudo
    grep -r '^[^#]' /etc/sudoers.d/ 2>/dev/null || true
    echo -e "\n=== SSH Keys ==="
    find /home /root -name authorized_keys -exec sh -c 'echo "=== {} ==="; cat {}' \; 2>/dev/null
} > "$OUTPUT_DIR/user_config.txt"

# Services and Processes
{
    echo "=== Active Services ==="
    systemctl list-units --type=service --state=running
    echo -e "\n=== Process List ==="
    ps auxf
} > "$OUTPUT_DIR/services.txt"

# Package Information
{
    echo "=== Installed Packages ==="
    if command -v dpkg >/dev/null; then
        dpkg -l
    elif command -v rpm >/dev/null; then
        rpm -qa
    fi
} > "$OUTPUT_DIR/packages.txt"

# Cron Jobs
{
    echo "=== System Crontabs ==="
    ls -l /etc/cron.*/*
    echo -e "\n=== User Crontabs ==="
    for user in /var/spool/cron/crontabs/*; do
        echo "=== $user ==="
        cat "$user"
    done
} > "$OUTPUT_DIR/cron_jobs.txt"

# Apache Guacamole Specific
if [ -d /etc/guacamole ]; then
    {
        echo "=== Guacamole Configuration ==="
        cat /etc/guacamole/*.xml /etc/guacamole/*.conf 2>/dev/null
        echo -e "\n=== Database Connection ==="
        grep -ri 'jdbc:' /etc/guacamole/
        echo -e "\n=== User Mappings ==="
        find /etc/guacamole/ -name 'user-mapping.xml' -exec cat {} \;
        echo -e "\n=== Service Status ==="
        systemctl status tomcat* guac* mysql* postgresql* 2>/dev/null
    } > "$OUTPUT_DIR/guacamole_config.txt"
fi

# Security Relevant Information
{
    echo "=== SSH Configuration ==="
    cat /etc/ssh/sshd_config
    echo -e "\n=== Fail2Ban Status ==="
    if command -v fail2ban-client >/dev/null; then
        fail2ban-client status
    fi
    echo -e "\n=== Listening Ports ==="
    lsof -i -P -n
} > "$OUTPUT_DIR/security_info.txt"

# Log Collection
LOG_SNAPSHOT="$OUTPUT_DIR/logs"
mkdir -p "$LOG_SNAPSHOT"
cp -r /var/log/{syslog*,auth.log*,guacamole*,apache2/*,nginx/*,tomcat*} "$LOG_SNAPSHOT" 2>/dev/null || true

# Create archive
tar czf "${OUTPUT_DIR}.tar.gz" "$OUTPUT_DIR"

echo "Snapshot created: ${OUTPUT_DIR}.tar.gz"
echo "To inspect contents: tar tzf ${OUTPUT_DIR}.tar.gz"
