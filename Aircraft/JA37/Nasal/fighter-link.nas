#### JA 37 Fighter link
#
# This file contains wrappers / helpers and so on for the Viggen fighter link.
# See datalink.nas for the generic datalink implementation.

var input = {
    power:          "instrumentation/datalink/power",
    identifier:     "ja37/radio/kv3/ident",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


var IFF_UNKNOWN = datalink.IFF_UNKNOWN;
var IFF_HOSTILE = datalink.IFF_HOSTILE;
var IFF_FRIENDLY = datalink.IFF_FRIENDLY;


### Transmission loop

var send_period = 1;

var send_loop = func {
    # It would be safe to send_data() with power off (datalink will ignore it),
    # but there's no reason to do it.
    if (!input.power.getBoolValue()) return;

    var data = {};

    # Make sure the identifier is converted to a string.
    var ident = ""~input.identifier.getValue();
    # Do not send identifier if it is 0
    if (ident != "0") data.identifier = ident;

    if (radar_logic.selection != nil and radar_logic.selection.type == "multiplayer") {
        data.contacts = [
            {
                callsign: radar_logic.selection.get_Callsign(),
                iff: radar_logic.selection.getIFF() ? IFF_FRIENDLY : IFF_HOSTILE,
            },
        ];
    }

    datalink.send_data(data);
}

### TI helpers

var is_known = func(callsign) {
    var data = datalink.get_data(callsign);
    return data != nil and data.is_known();
}

var is_connected = func(callsign) {
    var data = datalink.get_data(callsign);
    return data != nil and data.on_link();
}

# Return IFF info from datalink:
# - IFF_FRIENDLY for connected aircrafts
# - whatever is transmitted by tracking aircraft for tracked aircrafts.
var get_iff = func(callsign) {
    var data = datalink.get_data(callsign);
    if (data == nil) return IFF_UNKNOWN;
    elsif (data.on_link()) return IFF_FRIENDLY;
    else return data.iff();
}

# If callsign is connected, return its datalink identifier.
# If callsign is not connected but is tracked, return the identifier of whoever is tracking him
# (unless argument only_connected:1 is set).
# Return nil if no valid identifier is found.
#
# Identifier is shortened to a single character and ignored if 0.
var get_identifier = func(callsign, only_connected=0) {
    var data = datalink.get_data(callsign);
    if (data == nil) return nil;

    if (data.on_link()) {
        var ident = data.identifier();
        if (ident != nil) ident = substr(ident, 0, 1);
        if (ident == "0") ident = nil;
        return return ident;
    } else {
        var tracked_by = data.tracked_by();
        if (tracked_by != nil) return get_identifier(tracked_by, 1);
    }
}



var loop = func {
    send_loop();
}
