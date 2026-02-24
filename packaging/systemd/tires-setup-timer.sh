#!/bin/bash
# Tires timer setup script
# Reads RunInterval from /etc/tires/storage.json and configures systemd timer

set -e

CONFIG_FILE="${1:-/etc/tires/storage.json}"
OVERRIDE_DIR="/etc/systemd/system/tires.timer.d"
OVERRIDE_FILE="$OVERRIDE_DIR/override.conf"

echo "🔧 Configuring Tires timer..."

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Extract RunInterval from JSON (simple grep-based extraction)
RUN_INTERVAL=$(grep -o '"RunInterval"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)"/\1/')

if [ -z "$RUN_INTERVAL" ]; then
    echo "⚠️  RunInterval not found in config, using default: hourly"
    RUN_INTERVAL="hourly"
fi

echo "📅 RunInterval from config: $RUN_INTERVAL"

# Convert common values to systemd OnCalendar format
case "$RUN_INTERVAL" in
    minutely)
        CALENDAR="*:*:00"
        ;;
    hourly)
        CALENDAR="hourly"
        ;;
    daily)
        CALENDAR="daily"
        ;;
    weekly)
        CALENDAR="weekly"
        ;;
    monthly)
        CALENDAR="monthly"
        ;;
    *)
        # Assume it's already in systemd calendar format
        CALENDAR="$RUN_INTERVAL"
        ;;
esac

echo "📅 OnCalendar format: $CALENDAR"

# Create override directory
sudo mkdir -p "$OVERRIDE_DIR"

# Create override file
sudo tee "$OVERRIDE_FILE" > /dev/null << EOF
[Timer]
OnCalendar=$CALENDAR
Persistent=true
RandomizedDelaySec=300
EOF

# Reload systemd
sudo systemctl daemon-reload

echo ""
echo "✅ Timer configured successfully!"
echo ""
echo "Timer status:"
echo "  systemctl status tires.timer"
echo ""
echo "Next scheduled run:"
echo "  systemctl list-timers tires.timer"
echo ""
echo "To modify the schedule, edit RunInterval in $CONFIG_FILE"
echo "Supported values: minutely, hourly, daily, weekly, monthly"
echo "Or use systemd calendar format (e.g., '*-*-* 02:00:00' for daily at 2 AM)"
echo ""
