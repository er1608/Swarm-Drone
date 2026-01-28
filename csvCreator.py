import csv
import math
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import numpy as np
import pandas as pd
from functions.export_and_plot_shape import export_and_plot_shape
from functions.trajectories import *
from functions.create_active_csv import create_active_csv

# Example usage
shape_name="heart_shape"
diameter = 30.0
direction = 1
maneuver_time = 90.0
start_x = 0
start_y = 0
initial_altitude = 15
climb_rate = 1.0
move_speed = 2.0  # m/s
hold_time = 4.0 #s
step_time = 0.1 #s
output_file = "shapes/active.csv"

create_active_csv(
    shape_name=shape_name,
    diameter=diameter,
    direction=direction,
    maneuver_time=maneuver_time,
    start_x=start_x,
    start_y=start_y,
    initial_altitude=initial_altitude,
    climb_rate=climb_rate,
    move_speed = move_speed,
    hold_time = hold_time,
    step_time = step_time,
    output_file = output_file,
)

output_file = "shapes/active.csv"
export_and_plot_shape(output_file)

