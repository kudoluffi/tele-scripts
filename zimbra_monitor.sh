#!/bin/bash

# ================= CONFIG =================
TELEGRAM_BOT_TOKEN="ISI_BOT_TOKEN"
TELEGRAM_CHAT_ID="ISI_CHAT_ID"

HOSTNAME=$(hostname)

STATE_FILE="/tmp/zimbra_state"
DAILY_FILE="/tmp/zimbra_daily"

FORCE_SEND=0

NOW=$(date '+%Y-%m-%d %H:%M:%S')
CURRENT_HOUR_MIN=$(date '+%H:%M')
TODAY=$(date '+%Y-%m-%d')

DISK_CRITICAL=90

EMOJI_OK="✅"
EMOJI_ALERT="🚨"
EMOJI_REPORT="📊"

ZIMBRA_CMD="sudo -u zimbra"

# ==========================================

# ================= SERVICE =================
STATUS=$($ZIMBRA_CMD zmcontrol status 2>/dev/null)

# Detect Zimbra totally down
if echo "$STATUS" | grep -qi "not running"; then
    TOTAL_SERVICE=0
    RUNNING_SERVICE=0
    STOPPED_LIST="all"
else
    TOTAL_SERVICE=$(echo "$STATUS" | grep -E "Running|Stopped" | wc -l)
    RUNNING_SERVICE=$(echo "$STATUS" | grep -c "Running")
    STOPPED_LIST=$(echo "$STATUS" | grep "Stopped" | awk '{print $1}' | paste -sd "," -)
fi

# ================= DISK =================
DISK_USAGE=$(df -h /opt/zimbra | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_AVAIL=$(df -h /opt/zimbra | awk 'NR==2 {print $4}')

# ================= RAM =================
RAM_USAGE=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
RAM_INFO=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

# ================= CPU =================
CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d',' -f1 | xargs)
CPU_CORES=$(nproc)

# ================= QUEUE =================
QUEUE=$($ZIMBRA_CMD postqueue -p 2>/dev/null | grep -c "^[A-F0-9]")

# ================= SSL =================
SSL_DATE=$($ZIMBRA_CMD zmcertmgr viewdeployedcrt 2>/dev/null \
    | grep -m1 "notAfter=" \
    | cut -d'=' -f2)

SSL_DAYS="N/A"
if [[ -n "$SSL_DATE" ]]; then
    SSL_EXP=$(date -d "$SSL_DATE" +%s 2>/dev/null)
    NOW_SEC=$(date +%s)
    [[ -n "$SSL_EXP" ]] && SSL_DAYS=$(( (SSL_EXP - NOW_SEC) / 86400 ))
fi

# ================= BACKUP =================
LAST_BACKUP_FILE=$(ls -t /backup/zimbra/logs/ 2>/dev/null | head -1)
LAST_BACKUP_DATE=$(echo "$LAST_BACKUP_FILE" | grep -oE '[0-9]{8}')

BACKUP_STATUS="UNKNOWN"
[[ -n "$LAST_BACKUP_DATE" ]] && BACKUP_STATUS=$(date -d "$LAST_BACKUP_DATE" '+%Y-%m-%d')

# ================= STATE =================
CURRENT_STATE="OK"

if [[ "$TOTAL_SERVICE" -eq 0 ]]; then
    CURRENT_STATE="PROBLEM"
elif [[ "$RUNNING_SERVICE" -lt "$TOTAL_SERVICE" ]]; then
    CURRENT_STATE="PROBLEM"
elif [[ "$DISK_USAGE" -ge "$DISK_CRITICAL" ]]; then
    CURRENT_STATE="PROBLEM"
fi

LAST_STATE=""
[[ -f "$STATE_FILE" ]] && LAST_STATE=$(cat "$STATE_FILE")

SEND=0
TYPE=""

# ================= LOGIC =================
if [[ "$CURRENT_STATE" != "$LAST_STATE" ]]; then
    SEND=1
    [[ "$CURRENT_STATE" == "OK" ]] && TYPE="RECOVERY"
    [[ "$CURRENT_STATE" == "PROBLEM" ]] && TYPE="PROBLEM"
fi

# DAILY 05:30
if [[ "$CURRENT_STATE" == "OK" && "$CURRENT_HOUR_MIN" == "05:30" ]]; then
    LAST_DAILY=""
    [[ -f "$DAILY_FILE" ]] && LAST_DAILY=$(cat "$DAILY_FILE")

    if [[ "$LAST_DAILY" != "$TODAY" ]]; then
        SEND=1
        TYPE="DAILY"
        echo "$TODAY" > "$DAILY_FILE"
    fi
fi

# ================= MESSAGE =================
if [[ "$SEND" -eq 1 || "$FORCE_SEND" -eq 1 ]]; then

    # SERVICE DISPLAY
    if [[ "$TOTAL_SERVICE" -eq 0 ]]; then
        SERVICE_LINE="❌ Services: Zimbra is DOWN"
    elif [[ "$RUNNING_SERVICE" -eq "$TOTAL_SERVICE" ]]; then
        SERVICE_LINE="✅ Services: $RUNNING_SERVICE running"
    else
        SERVICE_LINE="❌ Services: $RUNNING_SERVICE/$TOTAL_SERVICE running ($STOPPED_LIST)"
    fi

    # DISK
    if [[ "$DISK_USAGE" -lt 80 ]]; then
        DISK_LINE="💾 Disk: ${DISK_USAGE}% (${DISK_AVAIL} available) ✅"
    elif [[ "$DISK_USAGE" -lt 90 ]]; then
        DISK_LINE="💾 Disk: ${DISK_USAGE}% (${DISK_AVAIL} available) ⚠️"
    else
        DISK_LINE="💾 Disk: ${DISK_USAGE}% (${DISK_AVAIL} available) ❌"
    fi

    # RAM
    RAM_LINE="🧠 Memory: ${RAM_USAGE}% (${RAM_INFO})"

    # CPU
    if (( $(echo "$CPU_LOAD < $CPU_CORES" | bc -l) )); then
        CPU_LINE="⚙️ CPU: $CPU_LOAD ✅"
    else
        CPU_LINE="⚙️ CPU: $CPU_LOAD ❌"
    fi

    # QUEUE
    [[ "$QUEUE" -eq 0 ]] && QUEUE_LINE="📬 Queue: Mail queue is empty" || QUEUE_LINE="📬 Queue: $QUEUE messages"

    # SSL
    [[ "$SSL_DAYS" =~ ^[0-9]+$ ]] && SSL_LINE="🔒 SSL: $SSL_DAYS days remaining" || SSL_LINE="🔒 SSL: N/A"

    # BACKUP
    [[ "$BACKUP_STATUS" == "$TODAY" ]] && BACKUP_LINE="💿 Last backup: $BACKUP_STATUS (today)" || BACKUP_LINE="💿 Last backup: $BACKUP_STATUS"

    # HEADER
    if [[ "$TYPE" == "PROBLEM" ]]; then
        HEADER="${EMOJI_ALERT} Zimbra Problem Detected"
    elif [[ "$TYPE" == "RECOVERY" ]]; then
        HEADER="${EMOJI_OK} Zimbra Recovered"
    else
        HEADER="${EMOJI_REPORT} ZIMBRA DAILY SUMMARY"
    fi

    MESSAGE="$HEADER\n\n📍 Server: $HOSTNAME\n⏰ Time: $NOW\n\nService Status:\n$SERVICE_LINE\n\nResources:\n$DISK_LINE\n$RAM_LINE\n$CPU_LINE\n\nMail:\n$QUEUE_LINE\n\nSecurity:\n$SSL_LINE\n\nBackup:\n$BACKUP_LINE"
fi

# ================= SEND =================
[[ -z "$MESSAGE" ]] && exit 0

FORMATTED_MESSAGE=$(printf "%b" "$MESSAGE")

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
-d chat_id="$TELEGRAM_CHAT_ID" \
-d text="$FORMATTED_MESSAGE"

echo "$CURRENT_STATE" > "$STATE_FILE"
