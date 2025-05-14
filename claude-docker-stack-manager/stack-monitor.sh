#!/bin/bash

# Docker Monitor
# A tool for monitoring Docker containers and sending alerts
# Author: Claude

# Configuration
EMAIL=""
SLACK_WEBHOOK=""
DISCORD_WEBHOOK=""
CHECK_INTERVAL=300  # Default 5 minutes
MAX_CPU_PERCENT=80
MAX_MEM_PERCENT=80
MAX_DISK_PERCENT=90
LOG_FILE="$HOME/docker/monitor.log"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    # Color based on level
    case "$level" in
        "INFO")
            local color=$GREEN
            ;;
        "WARNING")
            local color=$YELLOW
            ;;
        "ERROR")
            local color=$RED
            ;;
        *)
            local color=$NC
            ;;
    esac

    # Log to file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    # Print to terminal with color
    echo -e "${color}[$timestamp] [$level] $message${NC}"
}

# Send email alert
send_email_alert() {
    local subject="$1"
    local message="$2"

    if [ -z "$EMAIL" ]; then
        log "WARNING" "Email not configured. Skipping email alert."
        return
    fi

    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "$subject" "$EMAIL"
        log "INFO" "Email alert sent to $EMAIL"
    else
        log "ERROR" "mail command not found. Cannot send email alert."
    fi
}

# Send Slack alert
send_slack_alert() {
    local message="$1"

    if [ -z "$SLACK_WEBHOOK" ]; then
        log "WARNING" "Slack webhook not configured. Skipping Slack alert."
        return
    fi

    if command -v curl &> /dev/null; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"$message\"}" \
            "$SLACK_WEBHOOK" > /dev/null
        log "INFO" "Slack alert sent"
    else
        log "ERROR" "curl command not found. Cannot send Slack alert."
    fi
}

# Send Discord alert
send_discord_alert() {
    local message="$1"

    if [ -z "$DISCORD_WEBHOOK" ]; then
        log "WARNING" "Discord webhook not configured. Skipping Discord alert."
        return
    fi

    if command -v curl &> /dev/null; then
        curl -s -X POST -H 'Content-type: application/json' \
            --data "{\"content\":\"$message\"}" \
            "$DISCORD_WEBHOOK" > /dev/null
        log "INFO" "Discord alert sent"
    else
        log "ERROR" "curl command not found. Cannot send Discord alert."
    fi
}

# Send alert via configured methods
send_alert() {
    local subject="$1"
    local message="$2"

    send_email_alert "$subject" "$message"
    send_slack_alert "$message"
    send_discord_alert "$message"
}

# Check if a container has stopped unexpectedly
check_containers() {
    log "INFO" "Checking container status..."

    local containers=$(docker ps -a --format "{{.Names}}|{{.Status}}")
    local down_containers=""

    if [ -z "$containers" ]; then
        log "INFO" "No containers found"
        return
    fi

    while IFS='|' read -r name status; do
        if [[ "$status" == *"Exited"* ]]; then
            log "WARNING" "Container $name is down: $status"
            down_containers="${down_containers}${name} ($status)\n"
        fi
    done <<< "$containers"

    if [ -n "$down_containers" ]; then
        send_alert "Docker Container Alert" "The following containers are down:\n$down_containers"
    else
        log "INFO" "All containers are running"
    fi
}

# Check container resource usage
check_resources() {
    log "INFO" "Checking container resource usage..."

    local containers=$(docker ps --format "{{.Names}}")
    local high_usage=""

    if [ -z "$containers" ]; then
        log "INFO" "No running containers found"
        return
    fi

    for container in $containers; do
        # Get container stats (CPU, memory)
        local stats=$(docker stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemPerc}}" "$container")

        IFS='|' read -r name cpu_perc mem_perc <<< "$stats"

        # Remove % symbol and convert to number
        cpu_perc=${cpu_perc//%/}
        mem_perc=${mem_perc//%/}

        if (( $(echo "$cpu_perc > $MAX_CPU_PERCENT" | bc -l) )); then
            log "WARNING" "High CPU usage for $name: $cpu_perc%"
            high_usage="${high_usage}$name: CPU $cpu_perc% (threshold: $MAX_CPU_PERCENT%)\n"
        fi

        if (( $(echo "$mem_perc > $MAX_MEM_PERCENT" | bc -l) )); then
            log "WARNING" "High memory usage for $name: $mem_perc%"
            high_usage="${high_usage}$name: Memory $mem_perc% (threshold: $MAX_MEM_PERCENT%)\n"
        fi
    done

    if [ -n "$high_usage" ]; then
        send_alert "Docker Resource Alert" "The following containers have high resource usage:\n$high_usage"
    else
        log "INFO" "All containers are within resource limits"
    fi
}

# Check disk space
check_disk_space() {
    log "INFO" "Checking disk space..."

    local docker_dir=$(docker info --format '{{.DockerRootDir}}')
    local disk_usage=$(df -h "$docker_dir" | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "$disk_usage" -gt "$MAX_DISK_PERCENT" ]; then
        log "WARNING" "High disk usage: $disk_usage%"
        send_alert "Docker Disk Space Alert" "Docker directory ($docker_dir) has high disk usage: $disk_usage% (threshold: $MAX_DISK_PERCENT%)"
    else
        log "INFO" "Disk space usage is within limits: $disk_usage%"
    fi
}

# Check Docker daemon status
check_docker_daemon() {
    log "INFO" "Checking Docker daemon status..."

    if ! docker info &> /dev/null; then
        log "ERROR" "Docker daemon is not running"
        send_alert "Docker Daemon Alert" "Docker daemon is not running!"
        return 1
    else
        log "INFO" "Docker daemon is running"
    fi

    return 0
}

# Monitor everything once
full_check() {
    if check_docker_daemon; then
        check_containers
        check_resources
        check_disk_space
    fi
}

# Show configuration
show_config() {
    echo "Docker Monitor Configuration:"
    echo "----------------------------"
    echo "Check interval: $CHECK_INTERVAL seconds"
    echo "Max CPU threshold: $MAX_CPU_PERCENT%"
    echo "Max memory threshold: $MAX_MEM_PERCENT%"
    echo "Max disk usage threshold: $MAX_DISK_PERCENT%"
    echo "Email alerts: $([ -n "$EMAIL" ] && echo "Enabled ($EMAIL)" || echo "Disabled")"
    echo "Slack alerts: $([ -n "$SLACK_WEBHOOK" ] && echo "Enabled" || echo "Disabled")"
    echo "Discord alerts: $([ -n "$DISCORD_WEBHOOK" ] && echo "Enabled" || echo "Disabled")"
    echo "Log file: $LOG_FILE"
}

# Configure settings
configure() {
    echo "Docker Monitor Configuration"
    echo "----------------------------"

    read -p "Email for alerts (leave empty to disable): " email_input
    EMAIL="$email_input"

    read -p "Slack webhook URL (leave empty to disable): " slack_input
    SLACK_WEBHOOK="$slack_input"

    read -p "Discord webhook URL (leave empty to disable): " discord_input
    DISCORD_WEBHOOK="$discord_input"

    read -p "Check interval in seconds [300]: " interval_input
    CHECK_INTERVAL=${interval_input:-300}

    read -p "Max CPU usage percent [80]: " cpu_input
    MAX_CPU_PERCENT=${cpu_input:-80}

    read -p "Max memory usage percent [80]: " mem_input
    MAX_MEM_PERCENT=${mem_input:-80}

    read -p "Max disk usage percent [90]: " disk_input
    MAX_DISK_PERCENT=${disk_input:-90}

    # Save configuration
    cat > "$HOME/.docker_monitor.conf" << EOF
# Docker Monitor Configuration
EMAIL="$EMAIL"
SLACK_WEBHOOK="$SLACK_WEBHOOK"
DISCORD_WEBHOOK="$DISCORD_WEBHOOK"
CHECK_INTERVAL=$CHECK_INTERVAL
MAX_CPU_PERCENT=$MAX_CPU_PERCENT
MAX_MEM_PERCENT=$MAX_MEM_PERCENT
MAX_DISK_PERCENT=$MAX_DISK_PERCENT
EOF

    echo "Configuration saved to $HOME/.docker_monitor.conf"
}

# Load configuration if it exists
if [ -f "$HOME/.docker_monitor.conf" ]; then
    source "$HOME/.docker_monitor.conf"
fi

# Create log file directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Show usage information
show_help() {
    echo "Docker Monitor"
    echo "Usage: docker-monitor [command]"
    echo
    echo "Commands:"
    echo "  check               Run a full check once"
    echo "  start               Start monitoring in the background"
    echo "  stop                Stop monitoring"
    echo "  status              Check if monitoring is running"
    echo "  configure           Configure monitoring settings"
    echo "  config              Show current configuration"
    echo "  help                Show this help message"
    echo
    echo "When started, the monitor will run checks every $CHECK_INTERVAL seconds."
}

# Start the monitoring service
start_monitoring() {
    if [ -f "/tmp/docker-monitor.pid" ]; then
        local pid=$(cat /tmp/docker-monitor.pid)
        if ps -p "$pid" > /dev/null; then
            echo "Docker Monitor is already running (PID: $pid)"
            return
        else
            rm -f "/tmp/docker-monitor.pid"
        fi
    fi

    # Start monitoring in the background
    nohup bash -c "while true; do $0 check; sleep $CHECK_INTERVAL; done" > /dev/null 2>&1 &

    echo $! > /tmp/docker-monitor.pid
    echo "Docker Monitor started with PID: $!"
    echo "Checking every $CHECK_INTERVAL seconds"
}

# Stop the monitoring service
stop_monitoring() {
    if [ -f "/tmp/docker-monitor.pid" ]; then
        local pid=$(cat /tmp/docker-monitor.pid)
        if ps -p "$pid" > /dev/null; then
            kill "$pid"
            echo "Docker Monitor stopped (PID: $pid)"
        else
            echo "Docker Monitor is not running (stale PID file)"
        fi
        rm -f "/tmp/docker-monitor.pid"
    else
        echo "Docker Monitor is not running"
    fi
}

# Check if the monitoring service is running
check_status() {
    if [ -f "/tmp/docker-monitor.pid" ]; then
        local pid=$(cat /tmp/docker-monitor.pid)
        if ps -p "$pid" > /dev/null; then
            echo "Docker Monitor is running (PID: $pid)"
            echo "Checking every $CHECK_INTERVAL seconds"
        else
            echo "Docker Monitor is not running (stale PID file)"
            rm -f "/tmp/docker-monitor.pid"
        fi
    else
        echo "Docker Monitor is not running"
    fi
}

# Main function
main() {
    case "$1" in
        check)
            full_check
            ;;
        start)
            start_monitoring
            ;;
        stop)
            stop_monitoring
            ;;
        status)
            check_status
            ;;
        configure)
            configure
            ;;
        config)
            show_config
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            show_help
            ;;
    esac
}

# Run main function with all arguments
main "$@"