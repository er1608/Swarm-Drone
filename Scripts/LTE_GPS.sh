#!/bin/bash

LOG_DIR="$HOME/lte_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/lte_gps_$(date +%Y%m%d_%H%M%S).csv"

MODEM_ID=0
PING_TARGET="8.8.8.8"
INTERVAL=5

disconnect_count=0
last_connected=1

# Header CSV
echo "timestamp,rsrp_dbm,rsrq_db,sinr_db,rssi_db,lat,lon,alt_m,speed_kmh,fix,latency_ms,packet_loss,disconnect_count" > "$LOG_FILE"

echo "[INFO] Logging to $LOG_FILE"
echo "[INFO] Press Ctrl+C to stop"

# Hàm parse NMEA - FIXED
parse_nmea() {
    local nmea_output="$1"
    
    # Default values
    local lat="0"
    local lon="0"
    local alt="0"
    local speed="0"
    local fix="V"
    
    # Tìm GNGNS sentence
    local gngns=$(echo "$nmea_output" | grep -o '\$GNGNS,[^ ]*')
    
    if [[ -n "$gngns" ]]; then
        echo "[DEBUG] Found GNGNS: $gngns" >&2
        
        IFS=',' read -r -a fields <<< "$gngns"
        
        # Debug field count
        echo "[DEBUG] Field count: ${#fields[@]}" >&2
        
        if [[ ${#fields[@]} -ge 8 ]]; then
            # Field indices:
            # [0]: $GNGNS
            # [1]: Time (142508.00)
            # [2]: Latitude (1046.247338)
            # [3]: N/S (N)
            # [4]: Longitude (10635.971740)
            # [5]: E/W (E)
            # [6]: Fix quality (AAA, AAN, etc.)
            # [7]: Number of satellites (13)
            # [8]: HDOP (0.9)
            # [9]: Altitude (31.3)
            # [10]: Geoid separation (-1.0)
            
            local lat_raw="${fields[2]}"
            local lat_dir="${fields[3]}"
            local lon_raw="${fields[4]}"
            local lon_dir="${fields[5]}"
            local fix_quality="${fields[6]}"
            
            echo "[DEBUG] Raw: $lat_raw $lat_dir, $lon_raw $lon_dir, Fix: $fix_quality" >&2
            
            # Check fix quality - FIXED
            # "AAA" means GPS, GLONASS, GALILEO all active
            # "AAN" means GPS+GLONASS active, GALILEO void
            if [[ "$fix_quality" == *"A"* ]]; then
                fix="A"
                echo "[DEBUG] Fix is ACTIVE" >&2
            else
                fix="V"
                echo "[DEBUG] Fix is VOID" >&2
            fi
            
            # Convert coordinates if we have fix
            if [[ "$fix" == "A" && -n "$lat_raw" && "$lat_raw" != "" ]]; then
                # Latitude: DDMM.MMMMMM
                local lat_deg=${lat_raw:0:2}
                local lat_min=${lat_raw:2}
                
                # Longitude: DDDMM.MMMMMM
                local lon_deg=${lon_raw:0:3}
                local lon_min=${lon_raw:3}
                
                # Calculate decimal degrees
                lat=$(echo "$lat_deg + ($lat_min / 60)" | bc -l 2>/dev/null || echo "0")
                [[ "$lat_dir" == "S" ]] && lat=$(echo "-1 * $lat" | bc -l 2>/dev/null || echo "0")
                
                lon=$(echo "$lon_deg + ($lon_min / 60)" | bc -l 2>/dev/null || echo "0")
                [[ "$lon_dir" == "W" ]] && lon=$(echo "-1 * $lon" | bc -l 2>/dev/null || echo "0")
                
                # Altitude (field 10, index 9)
                if [[ -n "${fields[9]}" ]]; then
                    alt="${fields[9]}"
                fi
                
                echo "[DEBUG] Converted: lat=$lat, lon=$lon, alt=$alt" >&2
            fi
        fi
    fi
    
    # Tìm speed từ GPVTG
    local gpvtg=$(echo "$nmea_output" | grep -o '\$GPVTG,[^ ]*')
    if [[ -n "$gpvtg" ]]; then
        IFS=',' read -r -a fields <<< "$gpvtg"
        if [[ ${#fields[@]} -ge 8 && -n "${fields[7]}" ]]; then
            speed="${fields[7]}"
            echo "[DEBUG] Speed from GPVTG: $speed km/h" >&2
        fi
    fi
    
    echo "$lat,$lon,$alt,$speed,$fix"
}

# Hàm lấy signal
get_signal_value() {
    local output="$1"
    local key="$2"
    echo "$output" | grep -o "$key: [-0-9.]*" | awk '{print $2}'
}

# Main loop
trap 'echo -e "\n[INFO] Stopping..."; exit 0' INT

while true; do
    ts=$(date "+%Y-%m-%d %H:%M:%S")
    
    ### 1. GET LTE SIGNAL ###
    signal_output=$(sudo mmcli -m $MODEM_ID --signal-get 2>/dev/null)
    
    rsrp=$(get_signal_value "$signal_output" "rsrp")
    rsrq=$(get_signal_value "$signal_output" "rsrq")
    sinr=$(get_signal_value "$signal_output" "s/n")
    rssi=$(get_signal_value "$signal_output" "rssi")
    
    rsrp=${rsrp:--999}
    rsrq=${rsrq:--999}
    sinr=${sinr:--999}
    rssi=${rssi:--999}
    
    ### 2. GET GPS DATA ###
    gps_output=$(sudo mmcli -m $MODEM_ID --location-get 2>/dev/null)
    
    # Extract NMEA
    nmea_data=$(echo "$gps_output" | grep "^\s*|" | sed 's/^\s*|.*nmea: //' | tr -d '|' | tr '\n' ' ')
    
    # Parse NMEA
    parsed_gps=$(parse_nmea "$nmea_data")
    
    lat=$(echo "$parsed_gps" | cut -d',' -f1)
    lon=$(echo "$parsed_gps" | cut -d',' -f2)
    alt=$(echo "$parsed_gps" | cut -d',' -f3)
    speed=$(echo "$parsed_gps" | cut -d',' -f4)
    fix=$(echo "$parsed_gps" | cut -d',' -f5)
    
    # Debug output
    echo "[DEBUG] GPS result: lat=$lat, lon=$lon, fix=$fix" >&2
    
    ### 3. PING TEST ###
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
    
    ### 4. DISCONNECT COUNT ###
    if [[ $last_connected -eq 1 && $connected -eq 0 ]]; then
        disconnect_count=$((disconnect_count + 1))
        echo "[WARN] Connection lost! Total drops: $disconnect_count"
    fi
    last_connected=$connected
    
    ### 5. LOG TO CSV ###
    echo "$ts,$rsrp,$rsrq,$sinr,$rssi,$lat,$lon,$alt,$speed,$fix,$latency,$loss,$disconnect_count" >> "$LOG_FILE"
    
    ### 6. CONSOLE OUTPUT ###
    clear
    echo "============================================="
    echo "  LTE/GPS Monitor - $(date)"
    echo "  Log: $(basename "$LOG_FILE")"
    echo "============================================="
    echo ""
    echo "📶 LTE Signal:"
    printf "  %-10s: %8s dBm\n" "RSRP" "$rsrp"
    printf "  %-10s: %8s dB\n" "RSRQ" "$rsrq"
    printf "  %-10s: %8s dB\n" "SINR" "$sinr"
    printf "  %-10s: %8s dBm\n" "RSSI" "$rssi"
    echo ""
    echo "📍 GPS:"
    if [[ "$fix" == "A" ]]; then
        echo "  Status:  ✅ FIXED"
        printf "  %-10s: %12.6f\n" "Latitude" "$lat"
        printf "  %-10s: %12.6f\n" "Longitude" "$lon"
        printf "  %-10s: %8s m\n" "Altitude" "$alt"
        printf "  %-10s: %8s km/h\n" "Speed" "$speed"
    else
        echo "  Status:  ❌ NO FIX"
        echo "  (Fix quality field: ${fix_quality:-unknown})"
    fi
    echo ""
    echo "🌐 Network:"
    printf "  %-10s: %8s ms\n" "Latency" "$latency"
    printf "  %-10s: %8s %%\n" "Loss" "$loss"
    printf "  %-10s: %8s\n" "Drops" "$disconnect_count"
    echo ""
    echo "============================================="
    echo "[INFO] Next update in ${INTERVAL}s..."
    
    sleep $INTERVAL
done