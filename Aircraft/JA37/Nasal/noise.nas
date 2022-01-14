### Noise library
#
# Ported to nasal from Thorsten Renk noise shader for FlightGear.

var rand2D = func(x, y) {
    var r = math.sin(x*12.9898, y*78.233) * 43758.5453;
    return r - math.floor(r);
}

var simple_interpolate = func(a, b, x) {
    return a + x * x * (3.0 - 2.0*x) * (b-a);
}

var interpolatedNoise2D = func(x, y) {
    var int_x = math.floor(x);
    var frac_x = x - int_x;
    var int_y = math.floor(y);
    var frac_y = y - int_y;

    var v1 = rand2D(int_x, int_y);
    var v2 = rand2D(int_x+1, int_y);
    var v3 = rand2D(int_x, int_y+1);
    var v4 = rand2D(int_x+1, int_y+1);

    return simple_interpolate(
        simple_interpolate(v1, v2, frac_x),
        simple_interpolate(v3, v4, frac_x),
        frac_y,
    );
}

# Perlin noise
var Noise2D = func(x, y, wavelength) {
    return interpolatedNoise2D(x/wavelength, y/wavelength);
}

# Perlin noise for geographic coordinates. wavelength is in meters.

var D2M = 60 * NM2M;

var geoNoise2D = func(lat, lon, wavelength) {
    lon *= D2M * math.cos(lat * D2R);
    lat *= D2M;
    return Noise2D(lat, lon, wavelength);
}

var wavesNoise2D = func(lat, lon, time, wave_speed, wind_dir, wavelength) {
    lon *= D2M * math.cos(lat * D2R);
    lat *= D2M;
    lat += time * wave_speed * math.cos(wind_dir * D2R);
    lon += time * wave_speed * math.sin(wind_dir * D2R);
    return Noise2D(lat, lon, wavelength);
}
