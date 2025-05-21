#!/usr/bin/env python
"""
=====================================
TME131 - Project in Applied Mechanics
Opendrift simulation code
=====================================
"""
 
from datetime import timedelta
from opendrift.readers import reader_netCDF_CF_generic
from opendrift.models.plastdrift import PlastDrift
import os
import time
 
# Read current data
reader_x_current = reader_netCDF_CF_generic.Reader('Data\\Current\\2021_Baltic_x_current.nc')
reader_y_current = reader_netCDF_CF_generic.Reader('Data\\Current\\2021_Baltic_y_current.nc')
# Read wind data
reader_wind = reader_netCDF_CF_generic.Reader('Data\\Wind\\2021_Baltic_wind.nc')

# Simulation time
start_time = reader_x_current.start_time  # 2021-01-01
# end_time = reader_x_current.start_time + timedelta(hours=24*31) # Different end_time to run shorter simulations
end_time = reader_x_current.end_time      # 2021-12-31
time_window = [start_time, start_time + timedelta(hours=24*7)] # Seed elements continously over 1 week
 
# Location coordinates
locations = {
    'Stockholm': (19.5, 59.154416),
    'Oslo': (10.651439, 59.165165),
    'Gothenburg': (11.705960, 57.657308),
    'Copenhagen': (12.854807, 55.635840),
    'Oder': (14.080797, 54.054322),
    'Gdansk': (18.827874, 54.461684), 
    'Visby': (17.970688, 57.656943),
    'Helsingfors': (24.985232, 60.099697),
    'St_Petersburg': (29.527928, 60.045289),
    'Riga': (24.000448, 57.076058)
}

# Loop over locations
for name, (lon, lat) in locations.items():
    print(f"\n▶ Running simulation for {name}...")
 
    o = PlastDrift(loglevel=20)
    o.set_config('drift:vertical_mixing', False) # No vertical mixing
    o.set_config('drift:stokes_drift', True) # Wind results in Stoke's drift
    o.set_config('general:coastline_action', 'stranding') # Elements stranded when in contact with coastline/islands
    o.set_config('drift:horizontal_diffusivity', 1) # Horizontal diffusivity, 1 m^2/s
    o.set_config('drift:wind_drift_depth', 0.5) # Only relevant when vertical mixing is True
 
    o.add_reader([reader_x_current, reader_y_current, reader_wind]) # Choose what data you want to include in the simulation
 
    o.seed_elements(lon, lat, radius=50, number=1000, time=time_window) # Seed 1000 elements within a 50 m radius
 
    # Output file (Change name depending on what simulation you run)
    outfile = f"Outfiles\\{name}_wind_stranding_output.nc"

    # Run the simulation
    try:
        o.run(end_time=end_time, time_step=3*3600, time_step_output=3*3600, outfile=outfile)
        print(f"✅ Finished {name} → {outfile}")
    except Exception as run_error:
        print(f"❌ Error during run for {name}: {run_error}")
        continue  # Skip to next location if this one fails


