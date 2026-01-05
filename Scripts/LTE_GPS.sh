#!/bin/bash

LOG_DIR="./lte_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/lte_gps_full_$(date +%Y%m%d_%H%M%S).csv"

MODEM_ID=0
PING_TARGET="8.8.8.8"
INTERVAL=5

disconnect_count=0
last_connected=1

echo "timestamp,rsrp_dbm,rsrq_db,sinr_db,rssi_db,lat,lon,alt_m,speed_kmh,fix,fix_quality,hdop,vdop,sat_gps,sat_glonass,sat_beidou,sat_galileo,sat_active,sat_total,latency_ms,packet_loss,disconnect_count" > "$LOG_FILE"

echo "[INFO] Logging to $LOG_FILE"
echo "[INFO] Press Ctrl+C to stop"

count_satellites() {
    local nmea_output="$1"
    
    local sat_gps=0
    local sat_glonass=0
    local sat_beidou=0
    local sat_galileo=0
    
    local gpgsv=$(echo "$nmea_output" | grep -o '\$GPGSV,[^ ]*')
    if [[ -n "$gpgsv" ]]; then
        IFS=',' read -r -a fields <<< "$gpgsv"
        if [[ ${#fields[@]} -ge 4 ]]; then
            sat_gps="${fields[3]}"
        fi
    fi
    
    local glgsv=$(echo "$nmea_output" | grep -o '\$GLGSV,[^ ]*')
    if [[ -n "$glgsv" ]]; then
        IFS=',' read -r -a fields <<< "$glgsv"
        if [[ ${#fields[@]} -ge 4 ]]; then
            sat_glonass="${fields[3]}"
        fi
    fi
    
    local bdgsv=$(echo "$nmea_output" | grep -o '\$BDGSV,[^ ]*')
    if [[ -n "$bdgsv" ]]; then
        IFS=',' read -r -a fields <<< "$bdgsv"
        if [[ ${#fields[@]} -ge 4 ]]; then
            sat_beidou="${fields[3]}"
        fi
    fi
    
    local gaggsv=$(echo "$nmea_output" | grep -o '\$GAGSV,[^ ]*')
    if [[ -n "$gaggsv" ]]; then
        IFS=',' read -r -a fields <<< "$gaggsv"
        if [[ ${#fields[@]} -ge 4 ]]; then
            sat_galileo="${fields[3]}"
        fi
    fi
    
    echo "$sat_gps,$sat_glonass,$sat_beidou,$sat_galileo"
}

get_dop() {
    local nmea_output="$1"
    
    local hdop=0
    local vdop=0
    local sat_active=0
    
    local gngsa=$(echo "$nmea_output" | grep -o '\$GNGSA,[^ ]*')
    if [[ -z "$gngsa" ]]; then
        gngsa=$(echo "$nmea_output" | grep -o '\$GPGSA,[^ ]*')
    fi
    
    if [[ -n "$gngsa" ]]; then
        IFS=',' read -r -a fields <<< "$gngsa"
        
        if [[ ${#fields[@]} -gt 15 && -n "${fields[15]}" ]]; then
            hdop="${fields[15]}"
        fi
        
        if [[ ${#fields[@]} -gt 16 && -n "${fields[16]}" ]]; then
            vdop="${fields[16]}"
        fi
        
        for i in {2..13}; do
            if [[ $i -lt ${#fields[@]} && -n "${fields[$i]}" && "${fields[$i]}" != "" ]]; then
                ((sat_active++))
            fi
        done
    fi
    
    echo "$hdop,$vdop,$sat_active"
}

trap 'echo -e "\n[INFO] Stopping..."; exit 0' INT

while true; do
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    
    signal_output=$(sudo mmcli -m $MODEM_ID --signal-get 2>/dev/null)
    
    rsrp=$(echo "$signal_output" | grep -o "rsrp: [-0-9.]*" | awk '{print $2}')
    rsrq=$(echo "$signal_output" | grep -o "rsrq: [-0-9.]*" | awk '{print $2}')
    sinr=$(echo "$signal_output" | grep -o "s/n: [-0-9.]*" | awk '{print $2}')
    rssi=$(echo "$signal_output" | grep -o "rssi: [-0-9.]*" | awk '{print $2}')
    
    rsrp=${rsrp:--999}
    rsrq=${rsrq:--999}
    sinr=${sinr:--999}
    rssi=${rssi:--999}
    
    gps_output=$(sudo mmcli -m $MODEM_ID --location-get 2>/dev/null)
    nmea_data=$(echo "$gps_output" | grep "^\s*|" | sed 's/^\s*|.*nmea: //' | tr -d '|' | tr '\n' ' ')
    
    gngns=$(echo "$nmea_data" | grep -o '\$GNGNS,[^ ]*')
    
    lat="0"; lon="0"; alt="0"; speed="0"; fix="V"; fix_quality=""
    
    if [[ -n "$gngns" ]]; then
        IFS=',' read -r -a fields <<< "$gngns"
        
        if [[ ${#fields[@]} -ge 10 ]]; then
            fix_quality="${fields[6]}"
            
            if [[ "$fix_quality" == *"A"* ]]; then
                fix="A"
                
                lat_raw="${fields[2]}"
                lat_dir="${fields[3]}"
                lon_raw="${fields[4]}"
                lon_dir="${fields[5]}"
                
                if [[ -n "$lat_raw" ]]; then
                    lat_deg=${lat_raw:0:2}
                    lat_min=${lat_raw:2}
                    lat=$(echo "$lat_deg + ($lat_min / 60)" | bc -l 2>/dev/null || echo "0")
                    [[ "$lat_dir" == "S" ]] && lat=$(echo "-1 * $lat" | bc -l 2>/dev/null || echo "0")
                    
                    lon_deg=${lon_raw:0:3}
                    lon_min=${lon_raw:3}
                    lon=$(echo "$lon_deg + ($lon_min / 60)" | bc -l 2>/dev/null || echo "0")
                    [[ "$lon_dir" == "W" ]] && lon=$(echo "-1 * $lon" | bc -l 2>/dev/null || echo "0")
                    
                    [[ -n "${fields[9]}" ]] && alt="${fields[9]}"
                fi
            fi
        fi
    fi
    
    dop_info=$(get_dop "$nmea_data")
    hdop=$(echo "$dop_info" | cut -d',' -f1)
    vdop=$(echo "$dop_info" | cut -d',' -f2)
    sat_active=$(echo "$dop_info" | cut -d',' -f3)
    
    sat_info=$(count_satellites "$nmea_data")
    sat_gps=$(echo "$sat_info" | cut -d',' -f1)
    sat_glonass=$(echo "$sat_info" | cut -d',' -f2)
    sat_beidou=$(echo "$sat_info" | cut -d',' -f3)
    sat_galileo=$(echo "$sat_info" | cut -d',' -f4)
    
    sat_total=0
    for sat in $sat_gps $sat_glonass $sat_beidou $sat_galileo; do
        if [[ $sat =~ ^[0-9]+$ ]]; then
            sat_total=$((sat_total + sat))
        fi
    done
    
    gpvtg=$(echo "$nmea_data" | grep -o '\$GPVTG,[^ ]*')
    if [[ -n "$gpvtg" ]]; then
        IFS=',' read -r -a fields <<< "$gpvtg"
        if [[ ${#fields[@]} -ge 8 && -n "${fields[7]}" ]]; then
            speed="${fields[7]}"
        fi
    fi
    
    ping_output=$(ping -c 3 -W 2 "$PING_TARGET" 2>/dev/null)
    
    if echo "$ping_output" | grep -q "0 received"; then
        latency=""
        loss=100
        connected=0
    else
        latency=$(echo "$ping_output" | grep rtt | awk -F'/' '{print $5}')
        loss=$(echo "$ping_output" | grep packet | awk '{print $6}' | tr -d '%')
        connected=1
    fi
    
    latency=${latency:-999}
    loss=${loss:-100}
    
    if [[ $last_connected -eq 1 && $connected -eq 0 ]]; then
        disconnect_count=$((disconnect_count + 1))
        echo "[WARN] Connection lost! Total drops: $disconnect_count"
    fi
    last_connected=$connected
    
    echo "$ts,$rsrp,$rsrq,$sinr,$rssi,$lat,$lon,$alt,$speed,$fix,\"$fix_quality\",$hdop,$vdop,$sat_gps,$sat_glonass,$sat_beidou,$sat_galileo,$sat_active,$sat_total,$latency,$loss,$disconnect_count" >> "$LOG_FILE"
    
    clear
    echo "============================================================="
    echo "  LTE/GPS Monitor - $(date)"
    echo "  Log: $LOG_FILE"
    echo "============================================================="
    
    echo ""
    echo "📶 LTE Signal:"
    printf "  %-8s: %8s dBm\n" "RSRP" "$rsrp"
    printf "  %-8s: %8s dB\n" "RSRQ" "$rsrq"
    printf "  %-8s: %8s dB\n" "SINR" "$sinr"
    printf "  %-8s: %8s dBm\n" "RSSI" "$rssi"
    
    echo ""
    echo "📍 GPS Status:"
    if [[ "$fix" == "A" ]]; then
        printf "  %-12s: %8s ✅ FIXED\n" "Status" ""
        printf "  %-12s: %8s\n" "Quality" "$fix_quality"
        printf "  %-12s: %8.1f\n" "HDOP" "$hdop"
        printf "  %-12s: %8.1f\n" "VDOP" "$vdop"
    else
        printf "  %-12s: %8s ❌ NO FIX\n" "Status" ""
        printf "  %-12s: %8s\n" "Quality" "$fix_quality"
    fi
    
    echo ""
    echo "🛰️  Satellites:"
    printf "  %-10s: %8s (Active: %s)\n" "GPS" "$sat_gps" "$sat_active"
    printf "  %-10s: %8s\n" "GLONASS" "$sat_glonass"
    printf "  %-10s: %8s\n" "BeiDou" "$sat_beidou"
    printf "  %-10s: %8s\n" "Galileo" "$sat_galileo"
    printf "  %-10s: %8s\n" "Total View" "$sat_total"
    
    if [[ "$fix" == "A" ]]; then
        echo ""
        echo "📍 Location:"
        printf "  %-10s: %12.6f\n" "Latitude" "$lat"
        printf "  %-10s: %12.6f\n" "Longitude" "$lon"
        printf "  %-10s: %8.1f m\n" "Altitude" "$alt"
        printf "  %-10s: %8.1f km/h\n" "Speed" "$speed"
    fi
    
    echo ""
    echo "🌐 Network:"
    printf "  %-10s: %8.1f ms\n" "Latency" "$latency"
    printf "  %-10s: %8.1f %%\n" "Loss" "$loss"
    printf "  %-10s: %8d\n" "Drops" "$disconnect_count"
    
    echo ""
    echo "============================================================="
    echo "[INFO] Next update in ${INTERVAL}s..."
    
    sleep $INTERVAL
done