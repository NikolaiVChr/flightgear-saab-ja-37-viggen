# Keep a list of friends/foes from a node (/ja37/faf/) with children friend[i] and foe[i]

var friends = {};
var foes = {};

var faf_node = props.globals.getNode("ja37/faf", 1);


var is_friend = func(callsign) {
    return contains(friends, callsign);
}

var is_foe = func(callsign) {
    return contains(foes, callsign);
}


var update_lists = func() {
    # Re-read the entire lists if an update is needed.
    # This is lazy coding, but it's not like the lists are changed frequently.
    friends = {};
    foreach(friend; faf_node.getNode("friends", 1).getChildren("friend")) {
        var callsign = friend.getValue();
        if(callsign != "") friends[callsign] = 1;
    }
    foes = {};
    foreach(foe; faf_node.getNode("foes", 1).getChildren("foe")) {
        var callsign = foe.getValue();
        if(callsign != "") foes[callsign] = 1;
    }
}

setlistener(faf_node, update_lists, 1, 2);
