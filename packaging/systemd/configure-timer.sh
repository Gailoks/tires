#!/bin/bash
# Script to configure tires.timer based on storage.json RunInterval

set -e

CONFIG_FILE="${1:-/etc/tires/storage.json}"
TIMER_FILE="/etc/systemd/system/tires.timer.d/override.conf"

# Extract RunInterval from config using grep/sed (works without jq)
RUN_INTERVAL=$(grep -o '"RunInterval"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*:.*"\([^"]*\)"/\1/' || echo "hourly")

# Default to hourly if empty
if [ -z "$RUN_INTERVAL" ]; then
    RUN_INTERVAL="hourly"
fi

echo "Configuring tires.timer to run: $RUN_INTERVAL"

# Convert human-readable intervals to systemd calendar format
case "$RUN_INTERVAL" in
    minutely)
        ON_CALENDAR="*:*:00"
        ;;
    hourly)
        ON_CALENDAR="*-*-* *:00:00"
        ;;
    daily)
        ON_CALENDAR="*-*-* 00:00:00"
        ;;
    weekly)
        ON_CALENDAR="Mon *-*-* 00:00:00"
        ;;
    monthly)
        ON_CALENDAR="*-*-01 00:00:00"
        ;;
    *)
        # Assume it's already in systemd calendar format
        ON_CALENDAR="$RUN_INTERVAL"
        ;;
esac

# Create override directory
mkdir -p "$(dirname "$TIMER_FILE")"

# Write override configuration
cat > "$TIMER_FILE" << EOF
[Timer]
OnCalendar=$ON_CALENDAR
Persistent=true
RandomizedDelaySec=300

[Unit]
Description=Run Tires every $RUN_INTERVAL
EOF

# Reload systemd and restart timer
systemctl daemon-reload
systemctl restart tires.timer || true

echo "✅ tires.timer configured to run: $RUN_INTERVAL ($ON_CALENDAR)"
echo ""
echo "Timer status:"
systemctl status tires.timer --no-pager || true
