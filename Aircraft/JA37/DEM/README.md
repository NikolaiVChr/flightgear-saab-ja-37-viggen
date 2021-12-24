Terrain Profile
===============

The JA 37 had a terrain elevation map of Sweden used mainly for terrain collision warning.
It had a very low resolution, consisting of a 12.5km grid,
with 64m or 128m vertical resolution, depending on the area.

This simulates a similar map, for the entire world except Antartica.
The grid has a resolution of 0.1° (or 6 arc minutes = 6nm ~ 11km for latitude).
Elevations have a 64m resolution.


File Format
-----------
Elevation data is represented in a single file ja37.elev
It consists of 1500 rows from 60°S to 90°N, and 3600 columns
from 180°W to 180°E, each of which spans 0.1°
Each data point corresponds to a 0.1° x 0.1° cell with
its borders aligned to multiples of 0.1°.
Data is in row major order, meaning that all cells of the first row are stored first.

Thus, the first cell is 180.0°W--179.9°W x 60.0°S--59.9°S,
the second is 179.9°W--179.8°W x 60.0°S--59.9°S, etc.
until 179.9°E--180.0°E x 60.0°S--59.9S.
The second row then starts with 180.0°W--179.9°W x 59.9°S--59.8°S.

Each cell is stored as a single byte. A byte 'b' is interpreted as follows.
If b >= 192, subtract 256 from 'b'. Thus [192,255] is interpreted as [-64,-1].
'b' is then multiplied by 64 to get the elevation in meters.
Thus elevations from -4096 to 12224 can be represented.


Data Source
-----------
Elevation data is based on the SRTM v3.0 30 arc second data set, aka SRTMGL30 [1].
It covers latitudes 60S to 90N, i.e. everything but Antartica.
It is available at https://search.earthdata.nasa.gov (free account required).


[1] NASA JPL (2013). NASA Shuttle Radar Topography Mission Global
    30 arc second [Data set]. NASA EOSDIS Land Processes DAAC.


Generating Data
---------------
Download and extract the STRMGL30 data (section Data Source).
You should end up with files named e.g. `E020N40.DEM` in this directory.
Then, simply compile and run `gen_terrain_profile.c` to create ja37.elev.

If you end up with different file names, you may adapt the function
`dem_file_idx_to_name()` and `DEM_FILENAME_SIZE` as neccesary.

If you wish to use a different data source, with a file format comparable
to STRMGL30, you might get away with simply changing the DEM file format
constants at the begining of `gen_terrain_profile.c`.


Sampling Algorithm
------------------
According to the JA 37 manual:

> Each square has been allotted its own terrain level,
> which is based on average elevation and maximum elevation.

This leaves a lot to interpretation...

Currently, `gen_terrain_profile.c` simply computes the average in each square.

If you are interested in improving this, you only need to look at
the function `compute_out_cell_elev()`.
