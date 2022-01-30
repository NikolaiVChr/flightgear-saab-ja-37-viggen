var RB99Datalink = {
    max_range: 50,
    missile_types: { "rb-99": 1, },

    isEnabled: func {
        return power.prop.dcSecondBool.getBoolValue() and power.prop.acSecondBool.getBoolValue();
    },

    display_str: func(contact) {
        var eta = contact.getETA();
        var hit = contact.getHitPercent();
        eta = eta == nil ? "XX" : sprintf("%2d", math.clamp(eta, -9, 99));
        hit = hit == nil ? "XX" : sprintf("%2d", math.clamp(hit, -9, 99));
        return sprintf("%ss%s%%", eta, hit);
    },
};


var rb99_datalink = MissileDatalink.new(RB99Datalink);
