import csv
import math
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import numpy as np
import pandas as pd
from functions.trajectories import *

def create_active_csv(shape_name,diameter, direction, maneuver_time, start_x, start_y, initial_altitude, climb_rate,move_speed, hold_time , step_time, output_file="active.csv"):

    if shape_name == "eight_shape":
        shape_code = 0
        shape_fcn = eight_shape_trajectory
        shape_args = ()
    elif shape_name == "circle":
        shape_code = 1
        shape_fcn = circle_trajectory
        shape_args = ()
    elif shape_name == "square":
        shape_code = 2
        shape_fcn = square_trajectory
        shape_args = ()
    elif shape_name == "helix":
        shape_code = 3
        shape_fcn = helix_trajectory
        # Helix trajectory requires additional arguments for end altitude and number of turns
        end_altitude = 20
        turns = 3
        shape_args = ( end_altitude, turns,)
    elif shape_name == "heart_shape":
        shape_code = 4
        shape_fcn = heart_shape_trajectory
        shape_args = ()
    elif shape_name == "infinity_shape":
        shape_code = 5
        shape_fcn = infinity_shape_trajectory
        shape_args = ()
    elif shape_name == "spiral_square":
        shape_code = 6
        shape_fcn = spiral_square_trajectory
        # Spiral square trajectory requires additional argument for number of turns
        turns = 3
        shape_args = (turns,)
    elif shape_name == "star_shape":
        shape_code = 7
        shape_fcn = star_shape_trajectory
        # Star shape trajectory requires additional argument for number of points
        points = 5
        shape_args = (points,)
    elif shape_name == "zigzag":
        shape_code = 8
        shape_fcn = zigzag_trajectory
        # Zigzag trajectory requires additional argument for number of turns
        turns = 3
        shape_args = (turns,)
    elif shape_name == "sine_wave":
        shape_code = 9
        shape_fcn = sine_wave_trajectory
        # Sine wave trajectory requires additional argument for number of turns
        turns = 3
        shape_args = (turns,)
    else:
        # Raise an error for invalid shape names
        raise ValueError(f"Invalid shape name: {shape_name}")

   
   
    header = ["idx", "t", "px", "py", "pz", "vx", "vy", "vz", "ax", "ay", "az", "yaw", "mode", "ledr", "ledg", "ledb"]

    with open(output_file, mode="w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(header)



        # Calculate climb time and steps
        climb_time = initial_altitude / climb_rate
        climb_steps = int(climb_time / step_time)
        # Write climb trajectory
        for i in range(climb_steps):
            t = i * step_time
            x = 0
            y = 0
            z = (climb_rate * t) * -1
            vx = 0.0
            vy = 0.0
            vz = -climb_rate
            ax = 0
            ay = 0
            az = 0
            yaw = 0
            mode =10
            row = [i, t, x, y, z, vx, vy, vz, ax, ay, az, yaw,mode, "nan", "nan", "nan"]
            writer.writerow(row)


        # Hold at intial altitude
        hold_steps = int(hold_time / step_time)

        for i in range(hold_steps):
            t = climb_time + i * step_time
            x = 0
            y = 0
            z = -1 * initial_altitude
            vx = 0.0
            vy = 0.0
            vz = 0.0
            ax = 0
            ay = 0
            az = 0
            yaw = 0
            mode = 20
            row = [climb_steps + i, t, x, y, z, vx, vy, vz, 0,0,0, yaw,mode, "nan", "nan", "nan"]
            writer.writerow(row)  

    # Move to start position
        move_start_distance = math.sqrt(start_x**2 + start_y**2)
        move_start_time = move_start_distance / move_speed
        move_start_steps = int(move_start_time / step_time)

        for i in range(move_start_steps):
            t = climb_time + hold_time+ i * step_time
            ratio = i / move_start_steps
            x = start_x * ratio
            y = start_y * ratio
            z = -1 * initial_altitude
            vx = move_speed * (start_x / move_start_distance)
            vy = move_speed * (start_y / move_start_distance)
            vz = 0.0
            ax = 0
            ay = 0
            az = 0
            yaw = 0
            mode = 30
            row = [climb_steps + hold_steps + i, t, x, y, z, vx, vy, vz, 0 , 0 ,0, yaw,mode, "nan", "nan", "nan"]
            writer.writerow(row)

    # Hold start position for n seconds
        hold_steps = int(hold_time / step_time)

        for i in range(hold_steps):
            t = climb_time + hold_time +move_start_time + i * step_time
            x = start_x
            y = start_y
            z = -1 * initial_altitude
            vx = 0.0
            vy = 0.0
            vz = 0.0
            ax = 0
            ay = 0
            az = 0
            yaw = 0
            mode = 40
            row = [climb_steps + hold_steps + move_start_steps + i, t, x, y, z, vx, vy, vz, 0, 0, 0, yaw,mode, "nan", "nan", "nan"]
            writer.writerow(row)    

        # Check if start position is different from first setpoint of maneuver
        if 0 != shape_fcn(0, maneuver_time, diameter, direction, initial_altitude, step_time, *shape_args)[0] or 0 != shape_fcn(0, maneuver_time, diameter, direction, initial_altitude, step_time, *shape_args)[1]:
            print("different Start and Manuever")
            maneuver_start_x = shape_fcn(0, maneuver_time, diameter, direction, initial_altitude, step_time, *shape_args)[0];
            maneuver_start_y = shape_fcn(0, maneuver_time, diameter, direction, initial_altitude, step_time, *shape_args)[1];
            
            print(f"Origin Start: {start_x} , {start_y}")
            print(f"Manuever Start: {maneuver_start_x} , {maneuver_start_y}")

            # Calculate distance and time required to move to first setpoint of maneuver
            move_distance = math.sqrt(( maneuver_start_x)**2 + ( maneuver_start_y)**2)
            move_time = move_distance / 2.0
            move_steps = int(move_time / step_time)

            # Move drone to first setpoint of maneuver at 2 m/s
            for i in range(move_steps):
                t = climb_time + move_start_time + hold_time + hold_time + i * step_time
                ratio = i / move_steps
                x = start_x + (maneuver_start_x  ) * ratio
                y = start_y + (maneuver_start_y ) * ratio
                z = -1 * initial_altitude
                vx = move_speed * (maneuver_start_x ) / move_distance
                vy = move_speed * (maneuver_start_y ) / move_distance
                vz = 0.0
                ax = 0
                ay = 0
                az = 0
                yaw = 0
                
                mode = 50
                row = [climb_steps + hold_steps + move_start_steps + hold_steps  + i, t, x, y, z, vx, vy, vz,0,0,0, yaw,mode, "nan", "nan", "nan"]
                writer.writerow(row)

            # Hold drone at first setpoint for 2 seconds
            for i in range(hold_steps):
                t = climb_time + hold_time + move_start_time + move_time + hold_time + i * step_time
                x =  start_x + shape_fcn(0, maneuver_time, diameter, direction, initial_altitude, step_time, *shape_args)[0]
                y = start_y + shape_fcn(0, maneuver_time, diameter, direction, initial_altitude, step_time, *shape_args)[1]
                z = -1 * initial_altitude
                vx = 0.0
                vy = 0.0
                vz = 0.0
                ax = 0
                ay = 0
                az = 0
                yaw = 0
                mode = 60
                row = [climb_steps + hold_steps + move_steps + move_start_steps + hold_steps  + i, t, x, y, z, vx, vy, vz, 0 ,0,0, yaw,mode, "nan", "nan", "nan"]
                writer.writerow(row)

            # Calculate the start time after maneuver start
            start_time = climb_time + hold_time + move_start_time + move_time + hold_time  + hold_time
        else:
            # Calculate the start time after maneuver start
            start_time = climb_time + hold_time + move_start_time + hold_time
            move_distance=0
            move_steps =0
            move_time=0

        # Calculate the total duration of the trajectory after maneuver start
        total_duration = maneuver_time + start_time
        total_steps = int(total_duration / step_time)
        maneuver_steps = int(maneuver_time / step_time)

    

        # Fly the shape trajectory
        for step in range(maneuver_steps):
            
            # Call the appropriate shape function based on the shape code
            
            x, y, z, vx, vy, vz , ax , ay , az = shape_fcn(step, maneuver_time, diameter, direction, initial_altitude,step_time, *shape_args)
            x += start_x
            y += start_y
           
            yaw = 0
            missionTime = start_time + step * step_time
            mode = 70
            row = [climb_steps + hold_steps  +move_start_steps + hold_steps  + move_steps + hold_steps + step, missionTime, x, y, z, vx, vy, vz, ax , ay , az, yaw,mode, "nan", "nan", "nan"]
            writer.writerow(row)
            
        #  # Hold drone at end setpoint for 2 seconds
        #     for i in range(hold_steps):
        #         t = missionTime + maneuver_time + i * step_time
        #         x, y, z, vx, vy, vz = shape_fcn(step, maneuver_time, diameter, direction, initial_altitude,step_time, *shape_args)
        #         x += start_x
        #         y += start_y
        #         vx = 0.0
        #         vy = 0.0
        #         vz = 0.0
        #         yaw = 0
        #         mode = 80
        #         row = [climb_steps + hold_steps  +move_start_steps + hold_steps  + move_steps + hold_steps  + maneuver_steps + i, t, x, y, z, vx, vy, vz, "nan", "nan", "nan", yaw,mode, "nan", "nan", "nan"]
        #         writer.writerow(row)

        #later on add mode 80 for hold at the end of manuver, mode 90 for return and mode 100 for landing
        print(f"Created {output_file} with the {shape_name}.")
