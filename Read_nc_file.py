"""
=====================================
TME131 - Project in Applied Mechanics
Code to read/examine .nc file 
=====================================
"""

from netCDF4 import Dataset 

# Open the NetCDF file 
ds = Dataset("Data\\Wind\\2021_Baltic_wind.nc", mode='r')

# Print all variable names 
print(ds.variables.keys()) 

# Get dimensions 
print(ds.dimensions.keys()) 

# Print all variable attributes
for var_name in ds.variables:
    var = ds.variables[var_name]
    print(f"Variable: {var_name}")
    print(f"  standard_name: {var.__dict__.get('standard_name')}")
    print(f"  long_name: {var.__dict__.get('long_name')}")
    print(f"  units: {var.__dict__.get('units')}")
    print()





