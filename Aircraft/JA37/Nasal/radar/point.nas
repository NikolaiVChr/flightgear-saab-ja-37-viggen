# Contact defined by a coordinate
var ContactPoint = {
    new: func(callsign, coord) {
        var obj             = { parents : [ContactPoint, Contact]};
        obj.coord           = geo.Coord.new(coord);
        obj.callsign        = callsign;
        obj.unique          = rand();

        return obj;
    },

    update_coord: func(coord) {
        me.coord.set(coord);
    },

    isValid: func () {
        return 1;
    },

    isVirtual: func () {
        return 1;
    },

    isPainted: func () {
        return 0;
    },

    isLaserPainted: func{
        return 0;
    },

    isRadiating: func (c) {
        return 0;
    },

    getUnique: func () {
        return me.unique;
    },

    getElevation: func() {
        return vector.Math.getPitch(geo.aircraft_position(), me.coord);
    },

    getFlareNode: func () {
        return nil;
    },

    getChaffNode: func () {
        return nil;
    },

    get_Coord: func() {
        return me.coord;
    },

    getCoord: func {
        return me.coord;
    },

    getETA: func {
        return nil;
    },

    getHitChance: func {
        return nil;
    },

    get_Callsign: func(){
        return me.callsign;
    },

    getModel: func(){
        return "position";
    },

    get_Speed: func(){
        # return true airspeed
        return 0;
    },

    get_uBody: func {
        return 0;
    },
    get_vBody: func {
        return 0;
    },
    get_wBody: func {
        return 0;
    },

    get_Longitude: func(){
        return me.coord.lon();
    },

    get_Latitude: func(){
        return me.coord.lat();
    },

    get_Pitch: func(){
        return 0;
    },

    get_Roll: func(){
        return 0;
    },

    get_heading : func(){
        return 0;
    },

    get_bearing: func(){
        return me.get_bearing_from_Coord(geo.aircraft_position());
    },

    get_relative_bearing : func() {
        return geo.normdeg180(me.get_bearing()-getprop("orientation/heading-deg"));
    },

    getLastAZDeviation : func() {
        return me.get_relative_bearing();
    },

    get_altitude: func(){
        #Return Alt in feet
        return me.coord.alt()*M2FT;
    },

    get_range: func() {
        return me.coord.direct_distance_to(geo.aircraft_position()) * M2NM;
    },

    get_type: func () {
        return armament.POINT;
    },

    get_bearing_from_Coord: func(MyAircraftCoord){
        var myBearing = 0;
        if(me.coord.is_defined()) {
            myBearing = MyAircraftCoord.course_to(me.coord);
        }
        return myBearing;
    },
};
