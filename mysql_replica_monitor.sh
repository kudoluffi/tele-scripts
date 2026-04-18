#!/bin/bash

# ================= CONFIG =================
TELEGRAM_BOT_TOKEN="ISI_BOT_TOKEN"
TELEGRAM_CHAT_ID="ISI_CHAT_ID"

HOSTNAME=$(hostname)
STATE_FILE="/tmp/mysql_repl_state"
DAILY_FILE="/tmp/mysql_repl_daily"

FORCE_SEND=0
DELAY_THRESHOLD=3600    #1 hour
NOW=$(date '+%Y-%m-%d %H:%M:%S')
CURRENT_HOUR_MIN=$(date '+%H:%M')
TODAY=$(date '+%Y-%m-%d')

EMOJI_OK="\U00002705"
EMOJI_ALERT="\U0001F6A8"
EMOJI_REPORT="\U0001F4CA"

# ==========================================

STATUS=$(mysql -e "SHOW SLAVE STATUS\G" 2>/dev/null)

CURRENT_STATE="UNKNOWN"

if [[ -z "$STATUS" ]]; then
    CURRENT_STATE="DOWN"
else
    IO=$(echo "$STATUS" | grep -w "Slave_IO_Running:" | awk '{print $2}')
    SQL=$(echo "$STATUS" | grep -w "Slave_SQL_Running:" | awk '{print $2}')
    DELAY=$(echo "$STATUS" | grep -w "Seconds_Behind_Master:" | awk '{print $2}')
    MASTER_HOST=$(echo "$STATUS" | grep -w "Master_Host:" | awk '{print $2}')
    MASTER_PORT=$(echo "$STATUS" | grep -w "Master_Port:" | awk '{print $2}')
    STATE_TEXT=$(echo "$STATUS" | grep -w "Slave_SQL_Running_State:" | cut -d':' -f2- | xargs)
    LAST_IO_ERR=$(echo "$STATUS" | grep -w "Last_IO_Error:" | cut -d':' -f2- | xargs)
    LAST_SQL_ERR=$(echo "$STATUS" | grep -w "Last_SQL_Error:" | cut -d':' -f2- | xargs)

    [[ "$DELAY" == "NULL" || -z "$DELAY" ]] && DELAY=999999

    if [[ "$IO" == "Yes" && "$SQL" == "Yes" && "$DELAY" -lt "$DELAY_THRESHOLD" ]]; then
        CURRENT_STATE="OK"
    else
        CURRENT_STATE="PROBLEM"
    fi
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
    [[ "$CURRENT_STATE" == "DOWN" ]] && TYPE="DOWN"
fi

# daily report jam 06:30
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

    # status text
    [[ "$IO" == "Yes" ]] && IO_STATUS="Running ${EMOJI_OK}" || IO_STATUS="Stopped ❌"
    [[ "$SQL" == "Yes" ]] && SQL_STATUS="Running ${EMOJI_OK}" || SQL_STATUS="Stopped ❌"

    if [[ "$DELAY" -lt 10 ]]; then
        DELAY_STATUS="$DELAY sec ${EMOJI_OK}"
    elif [[ "$DELAY" -lt "$DELAY_THRESHOLD" ]]; then
        DELAY_STATUS="$DELAY sec ⚠️"
    else
        DELAY_STATUS="$DELAY sec ❌"
    fi

    # header sesuai kondisi
    if [[ "$CURRENT_STATE" == "DOWN" ]]; then
        HEADER="${EMOJI_ALERT} MySQL Replica DOWN"
    elif [[ "$TYPE" == "PROBLEM" ]]; then
        HEADER="${EMOJI_ALERT} MySQL Replica Problem"
    elif [[ "$TYPE" == "RECOVERY" ]]; then
        HEADER="${EMOJI_OK} MySQL Replica Recovered"
    else
        HEADER="${EMOJI_REPORT} MySQL Replica Daily Status"
    fi

    MESSAGE="$HEADER\n\n[$HOSTNAME]\nMaster : $MASTER_HOST\nTime   : $NOW\n\nIO Thread   : $IO_STATUS\nSQL Thread  : $S>

fi

# ================= SEND =================

FORMATTED_MESSAGE=$(printf "%b" "$MESSAGE")

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
-d chat_id="$TELEGRAM_CHAT_ID" \
-d text="$FORMATTED_MESSAGE"

        echo "$CURRENT_STATE" > "$STATE_FILE"
