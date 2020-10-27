#### Cannon/rocket impact messages
# (other weapons are handled by missiles.nas)

var hits_count = 0;
var hit_timer = nil;
var hit_callsign = "";

var Mp = props.globals.getNode("ai/models");
var valid_mp_types = {
  multiplayer: 1, tanker: 1, aircraft: 1, ship: 1, groundvehicle: 1,
};

# Find a MP aircraft close to a given point (code from the Mirage 2000)
var findmultiplayer = func(targetCoord, dist) {
  if(targetCoord == nil) return nil;

  var raw_list = Mp.getChildren();
  var SelectedMP = nil;
  foreach(var c ; raw_list)
  {    
    var is_valid = c.getNode("valid");
    if(is_valid == nil or !is_valid.getBoolValue()) continue;
    
    var type = c.getName();
    
    var position = c.getNode("position");
    var name = c.getValue("callsign");
    if(name == nil or name == "") {
      # fallback, for some AI objects
      var name = c.getValue("name");
    }
    if(position == nil or name == nil or name == "" or !contains(valid_mp_types, type)) continue;

    var lat = position.getValue("latitude-deg");
    var lon = position.getValue("longitude-deg");
    var elev = position.getValue("altitude-ft") * FT2M;

    if(lat == nil or lon == nil or elev == nil) continue;

    MpCoord = geo.Coord.new().set_latlon(lat, lon, elev);
    var tempoDist = MpCoord.direct_distance_to(targetCoord);
    if(dist > tempoDist) {
      dist = tempoDist;
      SelectedMP = name;
    }
  }
  return SelectedMP;
}

var hitmessage = func(typeOrd) {
  if (getprop("payload/armament/msg")) {
    var msg = notifications.ArmamentNotification.new("mhit", 4, -1*(damage.shells[typeOrd][0]+1));
    msg.RelativeAltitude = 0;
    msg.Bearing = 0;
    msg.Distance = hits_count;
    msg.RemoteCallsign = hit_callsign;
    notifications.hitBridgedTransmitter.NotifyAll(msg);
    events.damageLog.push("You hit "~hit_callsign~" with "~typeOrd~", "~hits_count~" times.");
  }
  hit_callsign = "";
  hit_timer = nil;
  hits_count = 0;
}

var impact_listener = func (node) {
  var ballistic_name = node.getValue();
  var ballistic = props.globals.getNode(ballistic_name, 0);
  if (ballistic != nil and ballistic.getName() != "munition") {
    var typeNode = ballistic.getNode("impact/type");
    if (typeNode != nil and typeNode.getValue() != "terrain") {
      var lat = ballistic.getNode("impact/latitude-deg").getValue();
      var lon = ballistic.getNode("impact/longitude-deg").getValue();
      var elev = ballistic.getNode("impact/elevation-m").getValue();
      var impactPos = geo.Coord.new().set_latlon(lat, lon, elev);
      var target = findmultiplayer(impactPos, 80);

      if (target != nil) {
        var typeOrd = ballistic.getNode("name").getValue();

        if(target == hit_callsign) {
          # Previous impacts on same target
          hits_count += 1;
        } else {
          if(hit_timer != nil) {
            # Previous impacts on different target, flush them first
            hit_timer.stop();
            hitmessage(typeOrd);
          }
          hits_count = 1;
          hit_callsign = target;
          hit_timer = maketimer(1, func{hitmessage(typeOrd);});
          hit_timer.singleShot = 1;
          hit_timer.start();
        }
      }
    }
  }
}

setlistener("/ai/models/model-impact", impact_listener, 0, 0);
