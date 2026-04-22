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

# Threshold
DISK_CRITICAL=90

# Emoji (unicode safe)
EMOJI_OK="\U00002705"
EMOJI_ALERT="\U0001F6A8"
EMOJI_REPORT="\U0001F4CA"

# ==========================================

# ================= SERVICE STATUS =================
STATUS=$(su - zimbra -c "zmcontrol status" 2>/dev/null)

TOTAL_SERVICE=$(echo "$STATUS" | grep -E "Running|Stopped" | wc -l)
RUNNING_SERVICE=$(echo "$STATUS" | grep -c "Running")
STOPPED_LIST=$(echo "$STATUS" | grep "Stopped" | awk '{print $1}' | paste -sd "," -)

# ================= DISK =================
DISK_USAGE=$(df -h /opt/zimbra | awk 'NR==2 {print $5}' | sed 's/%//')

# ================= RAM =================
RAM_USAGE=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')

# ================= CPU =================
CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d',' -f1 | xargs)

# ================= QUEUE =================
QUEUE=$(su - zimbra -c "postqueue -p" 2>/dev/null | grep -c "^[A-F0-9]")

# ================= SSL =================
SSL_DATE=$(su - zimbra -c "zmcertmgr viewdeployedcrt" 2>/dev/null | grep "Not After" | head -1 | cut -d':' -f2- | xargs)

SSL_DAYS=999
if [[ -n "$SSL_DATE" ]]; then
    SSL_EXP=$(date -d "$SSL_DATE" +%s 2>/dev/null)
    NOW_SEC=$(date +%s)
    SSL_DAYS=$(( (SSL_EXP - NOW_SEC) / 86400 ))
fi

# ================= BACKUP =================
LAST_BACKUP_FILE=$(ls -t /backup/zimbra/logs/ 2>/dev/null | head -1)
LAST_BACKUP_DATE=$(echo "$LAST_BACKUP_FILE" | grep -oE '[0-9]{8}')

BACKUP_STATUS="UNKNOWN"
if [[ -n "$LAST_BACKUP_DATE" ]]; then
    BACKUP_FORMATTED=$(date -d "$LAST_BACKUP_DATE" '+%Y-%m-%d')
    BACKUP_STATUS="$BACKUP_FORMATTED"
fi

# ================= STATE =================

CURRENT_STATE="OK"

# alert condition
if [[ "$RUNNING_SERVICE" -lt "$TOTAL_SERVICE" ]] || [[ "$DISK_USAGE" -ge "$DISK_CRITICAL" ]]; then
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

# daily jam 06:30
if [[ "$CURRENT_STATE" == "OK" && "$CURRENT_HOUR_MIN" == "06:30" ]]; then
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

    # service text
    if [[ "$RUNNING_SERVICE" -eq "$TOTAL_SERVICE" ]]; then
        SERVICE_STATUS="$RUNNING_SERVICE/$TOTAL_SERVICE Running ${EMOJI_OK}"
    else
        SERVICE_STATUS="$RUNNING_SERVICE/$TOTAL_SERVICE Running ❌"
    fi

    # disk status
    if [[ "$DISK_USAGE" -lt 80 ]]; then
        DISK_STATUS="$DISK_USAGE% (OK)"
    elif [[ "$DISK_USAGE" -lt "$DISK_CRITICAL" ]]; then
        DISK_STATUS="$DISK_USAGE% (WARN)"
    else
        DISK_STATUS="$DISK_USAGE% (CRITICAL)"
    fi

    # ssl status
    if [[ "$SSL_DAYS" -gt 30 ]]; then
        SSL_STATUS="$SSL_DAYS days (OK)"
    elif [[ "$SSL_DAYS" -gt 14 ]]; then
        SSL_STATUS="$SSL_DAYS days ⚠️"
    else
        SSL_STATUS="$SSL_DAYS days ❌"
    fi

    # header
    if [[ "$TYPE" == "PROBLEM" ]]; then
        HEADER="${EMOJI_ALERT} Zimbra Problem Detected"
    elif [[ "$TYPE" == "RECOVERY" ]]; then
        HEADER="${EMOJI_OK} Zimbra Recovered"
    else
        HEADER="${EMOJI_REPORT} Zimbra Daily Status"
    fi

    MESSAGE="$HEADER\n\n[$HOSTNAME]\nTime   : $NOW\n\nServices   : $SERVICE_STATUS"

    if [[ -n "$STOPPED_LIST" ]]; then
        MESSAGE="$MESSAGE\nDown       : $STOPPED_LIST"
    fi

    MESSAGE="$MESSAGE\n\nDisk       : $DISK_STATUS\nRAM        : $RAM_USAGE%\nCPU Load   : $CPU_LOAD\n\nQueue      : $QUEUE\nSSL Exp    : $SSL_STATUS\nBackup     : $BACKUP_STATUS"

fi

# ================= SEND =================

FORMATTED_MESSAGE=$(printf "%b" "$MESSAGE")

if [[ -n "$MESSAGE" ]]; then
    FORMATTED_MESSAGE=$(printf "%b" "$MESSAGE")

    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="$FORMATTED_MESSAGE"
fi

echo "$CURRENT_STATE" > "$STATE_FILE"
