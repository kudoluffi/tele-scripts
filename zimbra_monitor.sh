#!/bin/bash

# =========================================================
# Zimbra Monitoring Script
# Version : v1.6.1
# Author  : ChatG-Kudo
# =========================================================

# ================= CONFIG =================
TELEGRAM_BOT_TOKEN="ISI_BOT_TOKEN"
TELEGRAM_CHAT_ID="ISI_CHAT_ID"

HOSTNAME=$(hostname)

STATE_FILE="/tmp/zimbra_state"
DETAIL_FILE="/tmp/zimbra_detail"
DAILY_FILE="/tmp/zimbra_daily"

FORCE_SEND=0

NOW=$(date '+%Y-%m-%d %H:%M:%S')
CURRENT_HOUR_MIN=$(date '+%H:%M')
TODAY=$(date '+%Y-%m-%d')

DISK_CRITICAL=90

ZIMBRA_BIN="/opt/zimbra/bin"
ZIMBRA_USER="zimbra"

# ================= SERVICE =================
STATUS=$(sudo -u $ZIMBRA_USER $ZIMBRA_BIN/zmcontrol status 2>/dev/null)

SERVICE_LINES=$(echo "$STATUS" | grep -E "Running|Stopped" | grep -v "not running")

TOTAL_SERVICE=$(echo "$SERVICE_LINES" | wc -l)
RUNNING_SERVICE=$(echo "$SERVICE_LINES" | grep -c "Running")

STOPPED_LIST=$(echo "$SERVICE_LINES" \
    | grep "Stopped" \
    | awk '{print $1}' \
    | paste -sd ", " -)

# ================= RESOURCE =================
DISK_USAGE=$(df -h /opt/zimbra | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_AVAIL=$(df -h /opt/zimbra | awk 'NR==2 {print $4}')

RAM_USAGE=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')
RAM_INFO=$(free -h | awk '/Mem:/ {print $3 "/" $2}')

CPU_LOAD=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d',' -f1 | xargs)

QUEUE=$(su - $ZIMBRA_USER postqueue -p 2>/dev/null | grep -c "^[A-F0-9]")

# ================= SSL =================
SSL_DATE=$(sudo -u $ZIMBRA_USER $ZIMBRA_BIN/zmcertmgr viewdeployedcrt 2>/dev/null \
    | grep -m1 "notAfter=" | cut -d'=' -f2)

SSL_DAYS="N/A"
if [[ -n "$SSL_DATE" ]]; then
    SSL_EXP=$(date -d "$SSL_DATE" +%s 2>/dev/null)
    NOW_SEC=$(date +%s)
    [[ "$SSL_EXP" =~ ^[0-9]+$ ]] && SSL_DAYS=$(( (SSL_EXP - NOW_SEC) / 86400 ))
fi

# ================= BACKUP =================
LAST_BACKUP_FILE=$(ls -t /backup/zimbra/logs/ 2>/dev/null | head -1)
LAST_BACKUP_DATE=$(echo "$LAST_BACKUP_FILE" | grep -oE '[0-9]{8}')

BACKUP_DAYS=999
if [[ -n "$LAST_BACKUP_DATE" ]]; then
    BACKUP_TS=$(date -d "$LAST_BACKUP_DATE" +%s)
    NOW_TS=$(date +%s)
    BACKUP_DAYS=$(( (NOW_TS - BACKUP_TS) / 86400 ))
fi

# ================= PROBLEM FLAGS =================
SERVICE_PROBLEM=0
DISK_PROBLEM=0
SSL_PROBLEM=0
BACKUP_PROBLEM=0

[[ "$TOTAL_SERVICE" -eq 0 || "$RUNNING_SERVICE" -lt "$TOTAL_SERVICE" ]] && SERVICE_PROBLEM=1
[[ "$DISK_USAGE" -ge 90 ]] && DISK_PROBLEM=1
[[ "$SSL_DAYS" =~ ^[0-9]+$ && "$SSL_DAYS" -lt 30 ]] && SSL_PROBLEM=1
[[ "$BACKUP_DAYS" -gt 7 ]] && BACKUP_PROBLEM=1

CURRENT_DETAIL="$SERVICE_PROBLEM|$DISK_PROBLEM|$SSL_PROBLEM|$BACKUP_PROBLEM"

# ================= LOAD LAST =================
LAST_DETAIL="0|0|0|0"
[[ -f "$DETAIL_FILE" ]] && LAST_DETAIL=$(cat "$DETAIL_FILE")

IFS="|" read LAST_SERVICE LAST_DISK LAST_SSL LAST_BACKUP <<< "$LAST_DETAIL"

# ================= STATE =================
CURRENT_STATE="OK"
[[ $SERVICE_PROBLEM -eq 1 || $DISK_PROBLEM -eq 1 || $SSL_PROBLEM -eq 1 || $BACKUP_PROBLEM -eq 1 ]] && CURRENT_STATE="PROBLEM"

LAST_STATE=""
[[ -f "$STATE_FILE" ]] && LAST_STATE=$(cat "$STATE_FILE")

SEND=0
TYPE=""

# ================= STATE CHANGE =================
if [[ "$CURRENT_STATE" != "$LAST_STATE" ]]; then
    SEND=1
    [[ "$CURRENT_STATE" == "OK" ]] && TYPE="RECOVERY"
    [[ "$CURRENT_STATE" == "PROBLEM" ]] && TYPE="PROBLEM"
fi

# ================= DAILY =================
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

    # ================= PROBLEM =================
    if [[ "$TYPE" == "PROBLEM" ]]; then

        MESSAGE="🚨 Zimbra Problem Detected\n\n[$HOSTNAME]\nTime   : $NOW\n"

        [[ $SERVICE_PROBLEM -eq 1 ]] && MESSAGE="$MESSAGE\n\nServices   : $RUNNING_SERVICE/$TOTAL_SERVICE Running ❌\nDOWN ❌ : $STOPPED_LIST"
        [[ $DISK_PROBLEM -eq 1 ]] && MESSAGE="$MESSAGE\n\nDisk       : ${DISK_USAGE}% (CRITICAL)"

        if [[ $SSL_PROBLEM -eq 1 ]]; then
            [[ "$SSL_DAYS" -lt 15 ]] && MESSAGE="$MESSAGE\n\nSSL Exp    : $SSL_DAYS days ❌" || MESSAGE="$MESSAGE\n\nSSL Exp    : $SSL_DAYS days ⚠️"
        fi

        if [[ $BACKUP_PROBLEM -eq 1 ]]; then
            [[ "$BACKUP_DAYS" -gt 10 ]] && MESSAGE="$MESSAGE\n\nBackup     : $BACKUP_DAYS days ago ❌" || MESSAGE="$MESSAGE\n\nBackup     : $BACKUP_DAYS days ago ⚠️"
        fi

    # ================= RECOVERY =================
    elif [[ "$TYPE" == "RECOVERY" ]]; then

        MESSAGE="✅ Zimbra Recovered\n\n[$HOSTNAME]\nTime   : $NOW\n\n"

        [[ $LAST_SERVICE -eq 1 && $SERVICE_PROBLEM -eq 0 ]] && MESSAGE="$MESSAGE Services   : OK ✅\n"
        [[ $LAST_DISK -eq 1 && $DISK_PROBLEM -eq 0 ]] && MESSAGE="$MESSAGE Disk       : ${DISK_USAGE}% OK\n"
        [[ $LAST_SSL -eq 1 && $SSL_PROBLEM -eq 0 ]] && MESSAGE="$MESSAGE SSL        : OK\n"
        [[ $LAST_BACKUP -eq 1 && $BACKUP_PROBLEM -eq 0 ]] && MESSAGE="$MESSAGE Backup     : OK\n"

        MESSAGE="$MESSAGE\nStatus     : BACK TO NORMAL"

    # ================= DAILY =================
    else

        MESSAGE="📊 ZIMBRA DAILY SUMMARY\n\n📍 Server: $HOSTNAME\n⏰ Time: $NOW\n\n"

        MESSAGE="$MESSAGE Service Status:\n"
        MESSAGE="$MESSAGE ✅ Services: $RUNNING_SERVICE running\n\n"

        MESSAGE="$MESSAGE Resources:\n"
        MESSAGE="$MESSAGE 💾 Disk: ${DISK_USAGE}% (${DISK_AVAIL} available)\n"
        MESSAGE="$MESSAGE 🧠 Memory: ${RAM_USAGE}% (${RAM_INFO})\n"
        MESSAGE="$MESSAGE ⚙️ CPU: $CPU_LOAD\n\n"

        MESSAGE="$MESSAGE Mail:\n"
        MESSAGE="$MESSAGE 📬 Queue: $QUEUE messages\n\n"

        MESSAGE="$MESSAGE Security:\n"
        MESSAGE="$MESSAGE 🔒 SSL: $SSL_DAYS days\n\n"

        MESSAGE="$MESSAGE Backup:\n"
        MESSAGE="$MESSAGE 💿 Last backup: $BACKUP_DAYS days ago"
    fi
fi

# ================= SEND =================
[[ -z "$MESSAGE" ]] && exit 0

FORMATTED_MESSAGE=$(printf "%b" "$MESSAGE")

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
-d chat_id="$TELEGRAM_CHAT_ID" \
-d text="$FORMATTED_MESSAGE"

echo "$CURRENT_STATE" > "$STATE_FILE"
echo "$CURRENT_DETAIL" > "$DETAIL_FILE"

