#!/bin/bash

PX4_simulation() {
    echo "Starting PX4 simulation..."
    nohup make px4_sitl gz_x500 > ../px4_simulation.log 2>&1 &
    PX4_simulation_pid=$!
    echo $PX4_simulation_pid > ../px4_simulation.pid 
}

offboard_control() {
    echo "Starting offboard control script..."
    nohup python3 offboard_multiple_from_csv.py > ../offboard_control.log 2>&1 & offboard_control_pid=$!
    echo $offboard_control_pid > ../offboard_control.pid
}

main() {
    echo "Autostart script executed"

    if [ -d PX4-Autopilot ]; then 
        echo "PX4-Autopilot directory found, starting PX4 simulation"
        cd PX4-Autopilot || exit 1
        PX4_simulation
        cd .. || exit 1
    else
        echo "PX4-Autopilot directory not found"
        exit 1
    fi

    if python3 -m venv venv; then
        echo "Virtual environment created successfully"

        source venv/bin/activate
        
        pip install mavsdk==1.4.4
    else
        echo "Failed to create virtual environment"
        exit 1
    fi

    if [ -d "Swarm-Drone" ]; then 
        echo "Swarm-Drones directory found, starting offboard_multiple_from_csv.py"
        cd Swarm-Drone || exit 1
        chmod +x mavsdk_server
        offboard_control
        cd .. || exit 1
    else
        echo "Swarm-Drones directory not found, cannot start offboard_multiple_from_csv.py"
        exit 1
    fi
}

main 
