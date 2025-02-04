#!/bin/bash
set -euo pipefail

OUTPUT_DIR="jumpbox_snapshot_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

# Detect init system
INIT_SYSTEM="unknown"
if [ -d /run/systemd/system ]; then
    INIT_SYSTEM="systemd"
elif [ -x /sbin/openrc-init ]; then
    INIT_SYSTEM="openrc"
elif [ -x /sbin/init ]; then
    INIT_SYSTEM="sysv"
fi

# System Information
{
    echo "=== System Overview ==="
    echo "Hostname: $(hostname)"
    echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime)"
    echo "Init System: $INIT_SYSTEM"
    echo "Architecture: $(uname -m)"
} > "$OUTPUT_DIR/system_info.txt"

# Services and Processes (init-system agnostic)
{
    echo "=== Running Processes ==="
    ps auxf
    
    echo -e "\n=== Listening Services ==="
    netstat -tulpn 2>/dev/null || ss -tulpn
    
    case $INIT_SYSTEM in
        "systemd")
            echo -e "\n=== Systemd Services ==="
            systemctl list-units --type=service --state=running 2>/dev/null || true
            ;;
        "openrc")
            echo -e "\n=== OpenRC Services ==="
            rc-status --all 2>/dev/null || true
            ;;
        "sysv")
            echo -e "\n=== SysV Init Services ==="
            service --status-all 2>/dev/null || true
            ;;
    esac
} > "$OUTPUT_DIR/services.txt"

# Apache Guacamole Specific (updated for non-systemd)
if [ -d /etc/guacamole ]; then
    {
        echo "=== Guacamole Processes ==="
        pgrep -alf tomcat
        pgrep -alf guac
        
        echo -e "\n=== Service Status ==="
        case $INIT_SYSTEM in
            "systemd")
                systemctl status tomcat* guac* mysql* postgresql* 2>/dev/null || true
                ;;
            *)
                for service in tomcat guacd mysql postgresql; do
                    if [ -f "/etc/init.d/$service" ]; then
                        echo "=== $service ==="
                        /etc/init.d/$service status 2>/dev/null || true
                    fi
                done
                ;;
        esac
    } > "$OUTPUT_DIR/guacamole_config.txt"
fi

# Rest of the original script remains unchanged...
# [Keep the network, firewall, user, package, cron, and security sections from previous version]
# [Only modify systemd-specific parts using the same pattern above]

# Create archive
tar czf "${OUTPUT_DIR}.tar.gz" "$OUTPUT_DIR"

echo "Snapshot created: ${OUTPUT_DIR}.tar.gz"
