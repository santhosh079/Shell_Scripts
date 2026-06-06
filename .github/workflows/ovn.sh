#!/bin/bash

# --- Configuration ---
ALPEBIFDIR="/data/inft/prd/lcm_ebif/SrcFiles"
ALPODSDIR="/data/inft/prd/lcm_ebif/SrcFiles/ods"
RECIPIENT="santhoshmohan079@gmail.com santhoshsmarttv079@gmail.com"

ALPEBIFFILE="alp_ebif_cycle_date.dat"
ALPODSFILE="alp_ods_cycle.dat"
SLA_EBIF="Follow up: 12:40 AM | SLA: 01:00 AM"
SLA_ODS="Follow up: 02:40 AM | SLA: 03:00 AM"

# Safety flags for Follow-up alerts
SENT_EBIF_ALR=false
SENT_ODS_ALR=false

# ---------------------------------------------------------
# FUNCTION: GENERATE STATUS REPORT
# ---------------------------------------------------------
send_report() {
    local TYPE=$1
    local SUBJECT="$TYPE: ALP & ODS File Status - $(date +%F)"
    local BODY="File Transfer Status Report ($TYPE) - $(date '+%Y-%m-%d %H:%M:%S')\n"
    BODY+="----------------------------------------------------------\n"

    # --- EBIF SECTION ---
    if [[ -f "${ALPEBIFDIR}/${ALPEBIFFILE}" ]]; then
        local EBIF_TIME=$(stat -c '%y' "${ALPEBIFDIR}/${ALPEBIFFILE}" | cut -d'.' -f1)
        BODY+="FILE: ${ALPEBIFFILE}\nSTATUS: RECEIVED\nReceived TIME: ${EBIF_TIME}\nNOTES: ${SLA_EBIF}\n"
    else
        BODY+="FILE: ${ALPEBIFFILE}\nSTATUS: NOT RECEIVED\nNOTES: ${SLA_EBIF}\n"
    fi

    BODY+="\n---------------------------\n\n"

    # --- ODS SECTION (Notes added here) ---
    if [[ -f "${ALPODSDIR}/${ALPODSFILE}" ]]; then
        local ODS_TIME=$(stat -c '%y' "${ALPODSDIR}/${ALPODSFILE}" | cut -d'.' -f1)
        BODY+="FILE: ${ALPODSFILE}\nSTATUS: RECEIVED\nReceived TIME: ${ODS_TIME}\nNOTES: ${SLA_ODS}\n"
    else
        BODY+="FILE: ${ALPODSFILE}\nSTATUS: NOT RECEIVED\nNOTES: ${SLA_ODS}\n"
    fi

    echo -e "$BODY" | mailx -s "$SUBJECT" $RECIPIENT
}

# ---------------------------------------------------------
# STEP 1: INITIAL CHECK (Sends status of BOTH files with Notes)
# ---------------------------------------------------------
send_report "INITIAL"

# If both files are already present at the start, exit the script.
if [[ -f "${ALPEBIFDIR}/${ALPEBIFFILE}" && -f "${ALPODSDIR}/${ALPODSFILE}" ]]; then
    exit 0
fi

# ---------------------------------------------------------
# STEP 2: MONITORING LOOP
# ---------------------------------------------------------
while true; do
    CURR=$(date +%H%M)
    
    # Refresh status variables
    [[ -f "${ALPEBIFDIR}/${ALPEBIFFILE}" ]] && FOUND_EBIF=true || FOUND_EBIF=false
    [[ -f "${ALPODSDIR}/${ALPODSFILE}" ]] && FOUND_ODS=true || FOUND_ODS=false

    # --- SUCCESS LOGIC: BOTH FILES NOW RECEIVED ---
    if [[ "$FOUND_EBIF" == "true" && "$FOUND_ODS" == "true" ]]; then
        send_report "SUCCESS"
        exit 0  
    fi

    # --- EBIF FOLLOW-UP ALERT (12:40 AM) ---
    if [[ "$CURR" -ge "0040" && "$CURR" -lt "0100" && "$SENT_EBIF_ALR" == "false" ]]; then
        send_report "FOLLOW-UP (EBIF Milestone)"
        SENT_EBIF_ALR=true
    fi

    # --- ODS FOLLOW-UP ALERT (02:40 AM) ---
    if [[ "$CURR" -ge "0240" && "$CURR" -lt "0300" && "$SENT_ODS_ALR" == "false" ]]; then
        send_report "FOLLOW-UP (ODS Milestone)"
        SENT_ODS_ALR=true
    fi

    # --- 06:00 AM FINAL CUTOFF ---
    if [[ "$CURR" == "06" ]]; then
        send_report "FINAL CUTOFF STATUS"
        exit 0 
    fi

    sleep 900 # Check every 15 minutes
done