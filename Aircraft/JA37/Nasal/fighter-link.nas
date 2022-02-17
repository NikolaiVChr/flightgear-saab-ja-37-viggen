#### JA 37 Fighter link
#
# This file contains wrappers / helpers and so on for the Viggen fighter link.
# See datalink.nas for the generic datalink implementation.

var input = {
    on:             "instrumentation/datalink/on",
    power:          "instrumentation/datalink/power",
    identifier:     "instrumentation/datalink/ident",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


var IFF_UNKNOWN = datalink.IFF_UNKNOWN;
var IFF_HOSTILE = datalink.IFF_HOSTILE;
var IFF_FRIENDLY = datalink.IFF_FRIENDLY;


var datalink_range = 250000;    # 250km


### Full list of contacts, from radar system

var ai_contacts = [];           # everything
var mp_contacts = [];           # MP only
var callsign_to_contact = {};   # callsign to contact object lookup (MP only)

var radar_recipient = emesary.Recipient.new("FighterlinkContactsRecipient");
radar_recipient.Receive = func(notification) {
    if (notification.NotificationType != "AINotification")
        return emesary.Transmitter.ReceiptStatus_NotProcessed;

    ai_contacts = notification.vector;
    callsign_to_contact = {};
    foreach (var contact; ai_contacts) {
        if (contact.prop.getName() != "multiplayer") continue;

        callsign_to_contact[contact.getCallsign()] = contact;
        append(mp_contacts, contact);
    }

    return emesary.Transmitter.ReceiptStatus_OK;
}
emesary.GlobalTransmitter.Register(radar_recipient);


### Line of sight and range check

var can_transmit = func(callsign, mp_prop, mp_index) {
    var contact = callsign_to_contact[callsign];
    return contact != nil and contact.isVisible() and contact.getRangeDirect() < datalink_range;
}


### Transmission loop

var send_loop = func {
    var data = {};

    # Make sure the identifier is converted to a string.
    var ident = ""~input.identifier.getValue();
    # Do not send identifier if it is 0
    if (ident != "0") data.identifier = ident;

    var contacts = [];
    foreach (var track; radar.ps46.getTracks()) {
        if (track.prop.getName() != "multiplayer") continue;
        if (!track.hasTrackInfo()) continue;

        var contact = { callsign: track.getCallsign() };
        var iff = radar.stored_iff(track);
        if (iff != 0) {
            contact.iff = iff > 0 ? IFF_FRIENDLY : IFF_HOSTILE;
        }
        append(contacts, contact);
    }

    if (size(contacts) > 0) {
        data.contacts = contacts;
    }

    datalink.send_data(data);
}


### List of datalink contacts
#
# The following attributes are set:
# - dl_connected
# - dl_known (either connected or tracked by someone connected)
# - dl_iff (1=friendly, -1=hostile, 0=unknown, same as in radar. Always friendly if connected.)
# - dl_ident (own ident if connected, ident of tracker otherwise)

var dl_contacts = [];

var update_dl_contacts = func {
    dl_contacts = [];

    foreach (var contact; mp_contacts) {
        var callsign = contact.getCallsign();
        var data = datalink.get_data(callsign);
        if (data == nil or !data.is_known()) {
            contact.dl_connected = 0;
            contact.dl_known = 0;
            continue;
        }

        contact.dl_known = 1;
        if (data.on_link()) {
            contact.dl_connected = 1;
            contact.dl_iff = 1; # friendly
            contact.dl_ident = data.identifier();
        } else {
            contact.dl_connected = 0;

            var iff = data.iff();
            contact.dl_iff = iff == IFF_FRIENDLY ? 1 : iff == IFF_HOSTILE ? -1 : 0;

            var tracked_by = data.tracked_by();
            var tracked_by_data = tracked_by != nil ? datalink.get_data(tracked_by) : nil;
            contact.dl_ident = tracked_by_data != nil ? tracked_by_data.identifier() : nil;
        }
        # For viggen, identifier is truncated to 1, and "0" is ignored.
        if (contact.dl_ident != nil) {
            contact.dl_ident = substr(""~contact.dl_ident, 0, 1);
            if (contact.dl_ident == "0") contact.dl_ident = nil;
        }
        append(dl_contacts, contact);
    }
}

var clear_dl_contacts = func {
    foreach (var contact; mp_contacts) {
        contact.dl_connected = 0;
        contact.dl_known = 0;
    }
    dl_contacts = [];
}


var loop = func {
    if (!input.power.getBoolValue()) {
        # No power, turn off (don't want it turning back on if AC was down and comes back up)
        input.on.setBoolValue(0);
        clear_dl_contacts();
    } else {
        send_loop();
        update_dl_contacts();
    }
}

var init = func {
    # Set our own transmission check for line of sight and range.
    datalink.can_transmit = can_transmit;
}
