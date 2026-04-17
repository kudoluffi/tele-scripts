#!/bin/bash

# ================= CONFIG =================
TELEGRAM_BOT_TOKEN="ISI_BOT_TOKEN"
TELEGRAM_CHAT_ID="ISI_CHAT_ID"

HOSTNAME=$(hostname)
STATE_FILE="/tmp/mysql_repl_state"
DAILY_FILE="/tmp/mysql_repl_daily"

DELAY_THRESHOLD=60   # detik
NOW=$(date '+%Y-%m-%d %H:%M:%S')
CURRENT_HOUR_MIN=$(date '+%H:%M')
TODAY=$(date '+%Y-%m-%d')

# ==========================================

STATUS=$(mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null)

# default
CURRENT_STATE="UNKNOWN"
MESSAGE=""

if [[ -z "$STATUS" ]]; then
    CURRENT_STATE="DOWN"
else
    IO=$(echo "$STATUS" | grep -w "Slave_IO_Running" | awk '{print $2}')
    SQL=$(echo "$STATUS" | grep -w "Slave_SQL_Running" | awk '{print $2}')
    DELAY=$(echo "$STATUS" | grep -w "Seconds_Behind_Master" | awk '{print $2}')
    MASTER_HOST=$(echo "$STATUS" | grep "Master_Host" | awk '{print $2}')
    MASTER_PORT=$(echo "$STATUS" | grep "Master_Port" | awk '{print $2}')
    STATE_TEXT=$(echo "$STATUS" | grep "Slave_SQL_Running_State" | cut -d':' -f2- | xargs)
    LAST_IO_ERR=$(echo "$STATUS" | grep "Last_IO_Error:" | cut -d':' -f2- | xargs)
    LAST_SQL_ERR=$(echo "$STATUS" | grep "Last_SQL_Error:" | cut -d':' -f2- | xargs)

    # normalisasi delay NULL
    [[ "$DELAY" == "NULL" || -z "$DELAY" ]] && DELAY=999999

    if [[ "$IO" == "Yes" && "$SQL" == "Yes" && "$DELAY" -lt "$DELAY_THRESHOLD" ]]; then
        CURRENT_STATE="OK"
    else
        CURRENT_STATE="PROBLEM"
    fi
fi

# ambil state sebelumnya
LAST_STATE=""
[[ -f "$STATE_FILE" ]] && LAST_STATE=$(cat $STATE_FILE)

SEND=0
TYPE=""

# ================= LOGIC =================

# 1. kirim jika ada perubahan status
if [[ "$CURRENT_STATE" != "$LAST_STATE" ]]; then
    SEND=1

    if [[ "$CURRENT_STATE" == "OK" ]]; then
        TYPE="RECOVERY"
    elif [[ "$CURRENT_STATE" == "DOWN" ]]; then
        TYPE="DOWN"
    else
        TYPE="PROBLEM"
    fi
fi

# 2. kirim laporan harian jam 06:30 (hanya jika OK)
if [[ "$CURRENT_STATE" == "OK" && "$CURRENT_HOUR_MIN" == "06:30" ]]; then
    LAST_DAILY=""
    [[ -f "$DAILY_FILE" ]] && LAST_DAILY=$(cat $DAILY_FILE)

    if [[ "$LAST_DAILY" != "$TODAY" ]]; then
        SEND=1
        TYPE="DAILY"
        echo "$TODAY" > "$DAILY_FILE"
    fi
fi

# ================= KIRIM =================

if [[ "$SEND" -eq 1 ]]; then

    if [[ "$CURRENT_STATE" == "DOWN" ]]; then

MESSAGE="🚨 MySQL Replica DOWN
━━━━━━━━━━━━━━━━━━━━━━
Host        : $HOSTNAME
Waktu       : $NOW
━━━━━━━━━━━━━━━━━━━━━━"

    else

# format status
[[ "$IO" == "Yes" ]] && IO_STATUS="Running ✅" || IO_STATUS="Stopped ❌"
[[ "$SQL" == "Yes" ]] && SQL_STATUS="Running ✅" || SQL_STATUS="Stopped ❌"

if [[ "$DELAY" -lt 10 ]]; then
    DELAY_STATUS="$DELAY sec ✅"
elif [[ "$DELAY" -lt "$DELAY_THRESHOLD" ]]; then
    DELAY_STATUS="$DELAY sec ⚠️"
else
    DELAY_STATUS="$DELAY sec 🚨"
fi

HEADER=""

if [[ "$TYPE" == "PROBLEM" ]]; then
    HEADER="🚨 MySQL Replica PROBLEM"
elif [[ "$TYPE" == "RECOVERY" ]]; then
    HEADER="✅ MySQL Replica RECOVERED"
else
    HEADER="✅ MySQL Replica Status (Daily)"
fi

MESSAGE="$HEADER
━━━━━━━━━━━━━━━━━━━━━━
Host        : $HOSTNAME
Master      : $MASTER_HOST:$MASTER_PORT
Waktu       : $NOW

IO Thread   : $IO_STATUS
SQL Thread  : $SQL_STATUS
Delay       : $DELAY_STATUS

State       : $STATE_TEXT"

# tampilkan error hanya jika ada
[[ -n "$LAST_IO_ERR" ]] && MESSAGE+="
Last IO Err : $LAST_IO_ERR"

[[ -n "$LAST_SQL_ERR" ]] && MESSAGE+="
Last SQL Err: $LAST_SQL_ERR"

MESSAGE+="
━━━━━━━━━━━━━━━━━━━━━━"
    fi

    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$MESSAGE"

    echo "$CURRENT_STATE" > "$STATE_FILE"
fi
