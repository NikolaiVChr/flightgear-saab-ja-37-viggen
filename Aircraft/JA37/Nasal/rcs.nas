var test = func (echoHeading, echoPitch, echoRoll, bearing, frontRCS) {
  var myCoord = geo.aircraft_position();
  var echoCoord = geo.Coord.new(myCoord);
  echoCoord.apply_course_distance(bearing, 1000);#1km away
  echoCoord.set_alt(echoCoord.alt()+1000);#1km higher than me
  print("RCS final: "~getRCS(echoCoord, echoHeading, echoPitch, echoRoll, myCoord, frontRCS));
};

var testPintos = func {
    var rel_heading = rand()*360-180;
    var rel_pitch = rand()*180-90;
    var target_roll = rand()*360-180;
    testPinto(rel_heading, rel_pitch, target_roll);
    settimer(testPintos,0.25);
}


var testPinto = func (rel_heading, rel_pitch, target_roll) {
    #var abs_pitch = math.atan2(targetAircraftAlt-myAlt, distance);
    #var rel_pitch = math.abs((abs_pitch - my_pitch) + target_aircraft_pitch);
    # front + back + side + top should always equal 1.
    # rel_pitch is the relative pitch of the target aircraft in relation to the originating aircraft.
    # rel_heading is the relative heading of the target aircraft in relation to the originating aircraft.
    # front = rel_heading (90* = 0, 180* = 1) * pitch (0* = 1, 90* = 0)
    var front = math.clamp((rel_heading-90)/90,0,1) * math.abs((rel_pitch-90)/90);
    # back = rel_heading (0* = 1, 90* = 0) * pitch (0* = 1, 90* = 0)
    var back = math.clamp((90 - rel_heading)/90,0,1) * math.abs((rel_pitch-90)/90);
    # side = rel_heading (0* = 0, 90* = 1, 180* = 0) * roll (0* = 0, 90* = 1)
    var side = math.abs(math.abs(rel_heading/90-1)-1) * math.abs((target_roll-90)/90);
    # top = rel_heading (0* = 1, 90* = 0, 180* = 1) * pitch (0* = 0, 90* = 1) + rel_heading (0* = 0, 90* = 1, 180* = 0) * roll (0* = 0, 90* = 1)
    var top = (math.abs((rel_heading/90)-1) * (rel_pitch/90)) + (math.abs(math.abs(rel_heading/90-1)-1) * (target_roll/90));
    printf("top=%.2f back=%.2f side=%.2f front=%.2f sum=%.3f", top, back, side, front, top+back+side+front);
}

var testPinto2 = func (rel_heading, rel_pitch, rel_pitch_inv, target_roll) {
    # This does not take curvature of earth into account:
    var abs_pitch = math.atan2(targetAircraftAlt-myAlt, distance);#radians

    # This should be split up into 2 methods, since when target rel_heading is away from me its pitch will act opposite
    # my_pitch should not be used at all in this method, since the view of target aircraft does not change at all when I pitch up or down, as long as its in the radar cone.
    var rel_pitch = math.abs((abs_pitch - my_pitch) + target_aircraft_pitch);#degrees

    #
    # rel_pitch_inv: 0 = rear points at me
    var front = math.clamp( math.cos(rel_heading),0,1) * math.cos(rel_pitch);
    var back  = math.clamp(-math.cos(rel_heading),0,1) * math.cos(rel_pitch_inv);

    # this is difficult, but not impossible to calculate with trigonometry:
    var top = (math.abs((rel_heading/90)-1) * (rel_pitch/90)) + (math.abs(math.abs(rel_heading/90-1)-1) * (target_roll/90));

    # now here comes the real trouble:
    var side = math.abs(math.abs(rel_heading/90-1)-1) * math.abs((target_roll-90)/90);

    # getting all 4 to amount to 1, would give a headache from hell, so going another route..
    printf("top=%.2f back=%.2f side=%.2f front=%.2f", top, back, side, front);
}

var getRCS = func (echoCoord, echoHeading, echoPitch, echoRoll, myCoord, frontRCS) {
    var sideRCSFactor  = 2.50;
    var rearRCSFactor  = 1.75;
    var bellyRCSFactor = 3.50;
    #first we calculate the 2D RCS:
    var vectorToEcho   = vector.Math.eulerToCartesian2(myCoord.course_to(echoCoord), vector.Math.getPitch(myCoord,echoCoord));
    var vectorEchoNose = vector.Math.eulerToCartesian3X(echoHeading, echoPitch, echoRoll);
    var vectorEchoTop  = vector.Math.eulerToCartesian3Z(echoHeading, echoPitch, echoRoll);
    var view2D         = vector.Math.projVectorOnPlane(vectorEchoTop,vectorToEcho);
    print("top  "~vector.Math.format(vectorEchoTop));
    print("nose "~vector.Math.format(vectorEchoNose));
    print("view "~vector.Math.format(vectorToEcho));
    print("view2D "~vector.Math.format(view2D));
    var angleToNose    = geo.normdeg180(vector.Math.angleBetweenVectors(vectorEchoNose, view2D)+180);
    print("horz aspect "~angleToNose);
    var horzRCS = 0;
    if (math.abs(angleToNose) <= 90) {
      horzRCS = extrapolate(math.abs(angleToNose), 0, 90, frontRCS, sideRCSFactor*frontRCS);
    } else {
      horzRCS = extrapolate(math.abs(angleToNose), 90, 180, sideRCSFactor*frontRCS, rearRCSFactor*frontRCS);
    }
    print("RCS horz "~horzRCS);
    #next we calculate the 3D RCS:
    var angleToBelly    = geo.normdeg180(vector.Math.angleBetweenVectors(vectorEchoTop, vectorToEcho));
    print("angle to belly "~angleToBelly);
    var realRCS = 0;
    if (math.abs(angleToBelly) <= 90) {
      realRCS = extrapolate(math.abs(angleToBelly),  0,  90, bellyRCSFactor*frontRCS, horzRCS);
    } else {
      realRCS = extrapolate(math.abs(angleToBelly), 90, 180, horzRCS, bellyRCSFactor*frontRCS);
    }
    return realRCS;
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var getAspect = func (echoCoord, myCoord, echoHeading) {# ended up not using this
    # angle 0 deg = view of front
    var course = echoCoord.course_to(myCoord);
    var heading_offset = course - echoHeading;
    return geo.normdeg180(heading_offset);
};