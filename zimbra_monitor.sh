#!/bin/bash

# =========================================================
# Zimbra Monitoring Script
# Version : v1.4.0
# Author  : ChatG-Kudo
# Desc    : Zimbra monitoring + Telegram alert (clean & smart)
# =========================================================

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

ZIMBRA_BIN="/opt/zimbra/bin"
ZIMBRA_USER="zimbra"

# =========================================================
# ================= SERVICE =================
STATUS=$(sudo -u $ZIMBRA_USER $ZIMBRA_BIN/zmcontrol status 2>/dev/null)

SERVICE_LINES=$(echo "$STATUS" \
    | grep -E "Running|Stopped" \
    | grep -v "not running")

TOTAL_SERVICE=$(echo "$SERVICE_LINES" | wc -l)
RUNNING_SERVICE=$(echo "$SERVICE_LINES" | grep -c "Running")

STOPPED_LIST=$(echo "$SERVICE_LINES" \
    | grep "Stopped" \
    | awk '{print $1}' \
    | paste -sd ", " -)

# =========================================================
# ================= RESOURCE =================
DISK_USAGE=$(df -h /opt/zimbra | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_AVAIL=$(df -h /opt/zimbra | awk 'NR==2 {print $4}')

RAM_USAGE=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
RAM_INFO=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d',' -f1 | xargs)
CPU_CORES=$(nproc)

QUEUE=$(su - $ZIMBRA_USER postqueue -p 2>/dev/null | grep -c "^[A-F0-9]")

# =========================================================
# ================= SSL =================
SSL_DATE=$(sudo -u $ZIMBRA_USER $ZIMBRA_BIN/zmcertmgr viewdeployedcrt 2>/dev/null \
    | grep -m1 "notAfter=" \
    | cut -d'=' -f2)

SSL_DAYS="N/A"

if [[ -n "$SSL_DATE" ]]; then
    SSL_EXP=$(date -d "$SSL_DATE" +%s 2>/dev/null)
    NOW_SEC=$(date +%s)

    if [[ "$SSL_EXP" =~ ^[0-9]+$ ]]; then
        SSL_DAYS=$(( (SSL_EXP - NOW_SEC) / 86400 ))
    fi
fi

# =========================================================
# ================= BACKUP =================
LAST_BACKUP_FILE=$(ls -t /backup/zimbra/logs/ 2>/dev/null | head -1)
LAST_BACKUP_DATE=$(echo "$LAST_BACKUP_FILE" | grep -oE '[0-9]{8}')

BACKUP_STATUS="UNKNOWN"
if [[ -n "$LAST_BACKUP_DATE" ]]; then
    BACKUP_STATUS=$(date -d "$LAST_BACKUP_DATE" '+%Y-%m-%d')
fi

# =========================================================
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

# =========================================================
# ================= LOGIC =================
if [[ "$CURRENT_STATE" != "$LAST_STATE" ]]; then
    SEND=1
    [[ "$CURRENT_STATE" == "OK" ]] && TYPE="RECOVERY"
    [[ "$CURRENT_STATE" == "PROBLEM" ]] && TYPE="PROBLEM"
fi

# DAILY (05:30)
if [[ "$CURRENT_STATE" == "OK" && "$CURRENT_HOUR_MIN" == "05:30" ]]; then
    LAST_DAILY=""
    [[ -f "$DAILY_FILE" ]] && LAST_DAILY=$(cat "$DAILY_FILE")

    if [[ "$LAST_DAILY" != "$TODAY" ]]; then
        SEND=1
        TYPE="DAILY"
        echo "$TODAY" > "$DAILY_FILE"
    fi
fi

# =========================================================
# ================= MESSAGE =================
if [[ "$SEND" -eq 1 || "$FORCE_SEND" -eq 1 ]]; then

    # SERVICE DISPLAY SAFE
    if [[ "$TOTAL_SERVICE" -eq 0 ]]; then
        SERVICE_DAILY="❌ Services: UNKNOWN"
    elif [[ "$RUNNING_SERVICE" -eq "$TOTAL_SERVICE" ]]; then
        SERVICE_DAILY="✅ Services: $RUNNING_SERVICE running"
    else
        SERVICE_DAILY="❌ Services: $RUNNING_SERVICE/$TOTAL_SERVICE running"
    fi

    # BACKUP AGE
    BACKUP_LINE=""
    if [[ "$BACKUP_STATUS" != "UNKNOWN" ]]; then
        BACKUP_SEC=$(date -d "$BACKUP_STATUS" +%s)
        NOW_SEC=$(date +%s)
        BACKUP_DAYS=$(( (NOW_SEC - BACKUP_SEC) / 86400 ))

        [[ "$BACKUP_DAYS" -eq 0 ]] && BACKUP_LINE="Backup : today" || BACKUP_LINE="Backup : $BACKUP_DAYS days ago"
    fi

    # ================= PROBLEM =================
    if [[ "$TYPE" == "PROBLEM" ]]; then

        MESSAGE="🚨 Zimbra Problem Detected\n\n[$HOSTNAME]\nTime   : $NOW\n"

        if [[ "$TOTAL_SERVICE" -eq 0 ]]; then
            MESSAGE="$MESSAGE\n\nServices   : DOWN ❌"
        else
            MESSAGE="$MESSAGE\n\nServices   : $RUNNING_SERVICE/$TOTAL_SERVICE Running ❌"
            [[ -n "$STOPPED_LIST" ]] && MESSAGE="$MESSAGE\nDOWN ❌ : $STOPPED_LIST"
        fi

        [[ "$DISK_USAGE" -ge 90 ]] && MESSAGE="$MESSAGE\n\nDisk       : ${DISK_USAGE}% (CRITICAL)"

        if [[ "$SSL_DAYS" =~ ^[0-9]+$ && "$SSL_DAYS" -le 30 ]]; then
            MESSAGE="$MESSAGE\n\nSSL Exp    : $SSL_DAYS days"
        fi

        [[ -n "$BACKUP_LINE" ]] && MESSAGE="$MESSAGE\n\n$BACKUP_LINE"

    # ================= RECOVERY =================
    elif [[ "$TYPE" == "RECOVERY" ]]; then

        MESSAGE="✅ Zimbra Problem Recovered\n\n[$HOSTNAME]\nTime   : $NOW\n\nServices   : $RUNNING_SERVICE/$TOTAL_SERVICE Running ✅\nDisk       : ${DISK_USAGE}% (OK)\n\nStatus     : BACK TO NORMAL"

    # ================= DAILY =================
    else

        MESSAGE="📊 ZIMBRA DAILY SUMMARY\n\n📍 Server: $HOSTNAME\n⏰ Time: $NOW\n\n"

        MESSAGE="$MESSAGE Service Status:\n$SERVICE_DAILY\n\n"

        MESSAGE="$MESSAGE Resources:\n💾 Disk: ${DISK_USAGE}% (${DISK_AVAIL} available)\n🧠 Memory: ${RAM_USAGE}% (${RAM_INFO})\n⚙️ CPU: $CPU_LOAD\n\n"

        MESSAGE="$MESSAGE Mail:\n📬 Queue: $QUEUE messages\n\n"

        MESSAGE="$MESSAGE Security:\n🔒 SSL: $SSL_DAYS days\n\n"

        MESSAGE="$MESSAGE Backup:\n💿 Last backup: $BACKUP_STATUS"
    fi

fi

# =========================================================
# ================= SEND =================
[[ -z "$MESSAGE" ]] && exit 0

FORMATTED_MESSAGE=$(printf "%b" "$MESSAGE")

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
-d chat_id="$TELEGRAM_CHAT_ID" \
-d text="$FORMATTED_MESSAGE"

echo "$CURRENT_STATE" > "$STATE_FILE"

