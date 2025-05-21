"""
=====================================
TME131 - Project in Applied Mechanics
Code to edit wind .nc file 
=====================================
"""
# This code basically takes data from a .nc file and creates a new .nc file with the following changes:
# - wind data as U and V components instead of wind speed and wind direction (specifically relevant for CERRA single level wind data)
# - specified geographical range (lat, lon)
# - standard_name, variable names and units that are compatible with opendrift

import numpy as np
from netCDF4 import Dataset

# Input and output files
input_file = "Data\\Wind\\input_file.nc"
output_file = "Data\\Wind\\output_file.nc"

# Open input file
nc_in = Dataset(input_file, 'r')

# Load 2D latitude and longitude
lat = nc_in.variables['latitude'][:]  # shape (lat, lon)
lon = nc_in.variables['longitude'][:]  # shape (lat, lon)

# Create mask for the region we are interested in
# corners_baltic_region = [9.5,30.5,53.5,61.0]
mask = (lon >= 9.5) & (lon <= 30.5) & (lat >= 53.5) & (lat <= 61.0)

# Get indices for bounding box
rows = np.any(mask, axis=1)
cols = np.any(mask, axis=0)
lat_inds = np.where(rows)[0]
lon_inds = np.where(cols)[0]
lat_start, lat_end = lat_inds[0], lat_inds[-1]+1
lon_start, lon_end = lon_inds[0], lon_inds[-1]+1

# Slice coordinates and variables
lat_sub = lat[lat_start:lat_end, lon_start:lon_end]
lon_sub = lon[lat_start:lat_end, lon_start:lon_end]
ws = nc_in.variables['si10'][:, lat_start:lat_end, lon_start:lon_end]    # Wind speed
wd = nc_in.variables['wdir10'][:, lat_start:lat_end, lon_start:lon_end]  # Wind direction

# Convert wind direction and wind speed to U and V components instead since that is what Opendrift readers are compatible with
# Direction is FROM (meteorological), so we reverse the angle by adding 180
wd_rad = np.deg2rad(wd + 180)
u10 = ws * np.sin(wd_rad)
v10 = ws * np.cos(wd_rad)

# Time variable
time = nc_in.variables['valid_time'][:]

# Create output file
nc_out = Dataset(output_file, 'w')

# Define dimensions
nc_out.createDimension('time', len(time))
nc_out.createDimension('y', lat_sub.shape[0])
nc_out.createDimension('x', lat_sub.shape[1])

# Create coordinate variables
time_var = nc_out.createVariable('time', 'f8', ('time',))
lat_var = nc_out.createVariable('latitude', 'f4', ('y', 'x'))
lon_var = nc_out.createVariable('longitude', 'f4', ('y', 'x'))

# Assign values
time_var[:] = time
lat_var[:, :] = lat_sub
lon_var[:, :] = lon_sub

# Create u10 and v10 variables
u_var = nc_out.createVariable('u10', 'f4', ('time', 'y', 'x'), zlib=True)
v_var = nc_out.createVariable('v10', 'f4', ('time', 'y', 'x'), zlib=True)
# Set correct standard_name and units for the new variables
time_var.standard_name = "time"
lat_var.standard_name = "latitude"
lon_var.standard_name = "longitude"
u_var.standard_name = "x_wind"
v_var.standard_name = "y_wind"
if 'units' in nc_in.variables['valid_time'].ncattrs():
    time_var.units = nc_in.variables['valid_time'].units
lat_var.units = "degrees_north"
lon_var.units = "degrees_east"
u_var.units = "m s-1"
v_var.units = "m s-1"

# Assign wind component data
u_var[:, :, :] = u10
v_var[:, :, :] = v10

# Close files
nc_in.close()
nc_out.close()

print(f"Subset and converted data saved to {output_file}")