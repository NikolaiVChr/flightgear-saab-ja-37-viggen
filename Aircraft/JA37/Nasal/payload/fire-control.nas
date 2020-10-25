var TRUE = 1;
var FALSE = 0;


var is_ja = (getprop("/ja37/systems/variant") == 0);


var input = {
    combat:     "/ja37/mode/combat",
    trigger:    "/controls/armament/trigger",
    unsafe:    "/controls/armament/trigger-unsafe",
    mp_msg:     "/payload/armament/msg",
    atc_msg:    "/sim/messages/atc",
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop], 1);
}



var fireLog = events.LogBuffer.new(echo: 0);
var ecmLog = events.LogBuffer.new(echo: 0);


### Pylon selection

# Pylon names.
var STATIONS = pylons.STATIONS;
var M75 = 0;

# Pylon lookup functions.
var station_by_id = func(id) {
    if (id == M75 and is_ja) return pylons.M75station;
    else return pylons.pylons[id];
}

var is_loaded_with = func(pylon, type) {
    return station_by_id(pylon).singleName == type;
}

var find_pylon_by_type = func(type, order, first=0) {
    var i = first;
    var looped = FALSE;
    while (i < first or !looped) {
        if (is_loaded_with(order[i], type)) return order[i];

        i += 1;
        if (i >= size(order)) {
            i = 0;
            looped = TRUE;
        }
    }
    return nil;
}

var find_all_pylons_by_type = func(type) {
    var res = [];
    for(var pylon=0; pylon<7; pylon+=1) {
        if (is_loaded_with(pylon, type)) {
            append(res, pylon);
        }
    }
    return res;
}


### Weapon logic API (abstract class)
#
# Different weapon types should inherit this object and define the methods,
# so as to implement custom firing logic.
var WeaponLogic = {
    init: func(type) {
        me.type = type;
        me.combat = FALSE;
        me.unsafe = FALSE;
    },

    # Select a weapon.
    # Either a specific pylon (if the argument is specified),
    # or this type of weapon in general.
    # Must return TRUE on successful selection, and FALSE if it failed.
    # In the later case, the state of the weapon should be the same as after deselect().
    select: func(pylon=nil) {
        die("Called unimplemented abstract class method");
    },

    # Select the next weapon of this type.
    cycle_selection: func {
        die("Called unimplemented abstract class method");
    },

    # Deselect this weapon type.
    deselect: func {
        die("Called unimplemented abstract class method");
    },

    # Called when entering/leaving combat mode while this weapon type is selected.
    set_combat: func(combat) {
        me.combat = combat;
        if (!combat) me.set_unsafe(FALSE);
        else me.update_unsafe();
    },

    update_combat: func {
        me.set_combat(input.combat.getBoolValue());
    },

    # Called when the trigger safety changes position while this weapon type is selected.
    set_unsafe: func(unsafe) {
        if (!me.combat) unsafe = FALSE;
        me.unsafe = unsafe;

        if (!me.unsafe) me.set_trigger(FALSE);
        # Explicitely do not update the trigger when switching to unsafe.
        # If the trigger is held pressed while unsafing, it will do nothing until the next press.
    },

    update_unsafe: func {
        me.set_unsafe(input.unsafe.getBoolValue());
    },

    armed: func {
        return me.combat and me.unsafe;
    },

    # Called when the trigger is pressed/released while this weapon type is selected.
    set_trigger: func(trigger) {
        die("Called unimplemented abstract class method");
    },
};


# Generic missile weapons, based on missiles.nas
var Missile = {
    parents: [WeaponLogic],

    # Selection order.
    pylons_priority: [STATIONS.V7V, STATIONS.V7H, STATIONS.S7V, STATIONS.S7H, STATIONS.R7V, STATIONS.R7H],

    new: func(type) {
        var w = { parents: [Missile], };
        w.init(type);
        w.selected = nil;
        w.station = nil;
        w.weapon = nil;
        return w;
    },

    # Internal function. pylon must be correct (loaded with correct type...)
    _select: func(pylon) {
        # First reset state
        me.deselect();

        me.selected = pylon;
        me.station = station_by_id(me.selected);
        me.weapon = me.station.getWeapons()[0];
        setprop("controls/armament/station-select-custom", pylon);

        me.update_combat();
        me.update_unsafe();
    },

    deselect: func {
        me.set_unsafe(FALSE);
        me.set_combat(FALSE);
        me.selected = nil;
        me.station = nil;
        me.weapon = nil;
        setprop("controls/armament/station-select-custom", -1);
    },

    select: func(pylon=nil) {
        if (pylon == nil) {
            # Pylon not given as argument. Find a matching one.
            pylon = find_pylon_by_type(me.type, me.pylons_priority);
        } else {
            # Pylon given as argument. Check that it matches.
            if (!is_loaded_with(pylon, me.type)) pylon = nil;
        }

        # If pylon is nil at this point, selection failed.
        if (pylon == nil) {
            me.deselect();
            return FALSE;
        } else {
            me._select(pylon);
            return TRUE;
        }
    },

    cycle_selection: func {
        var first = 0;
        if (me.selected != nil) {
            forindex(var i; me.pylons_priority) {
                if (me.pylons_priority[i] == me.selected) first = i+1;
                break;
            }
            if (first >= size(me.pylons_priority)) first = 0;
        }

        pylon = find_pylon_by_type(me.type, me.pylons_priority, first);
        if (pylon == nil) {
            me.deselect();
            return FALSE;
        } else {
            me._select(pylon);
            return TRUE;
        }
    },

    set_unsafe: func(unsafe) {
        # Call parent method
        call(WeaponLogic.set_unsafe, [unsafe], me);

        if (me.weapon != nil) {
            if (me.unsafe) me.weapon.start();
            else me.weapon.stop();
        }
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !trigger or me.weapon == nil) return;

        if (!me.weapon.status == armament.MISSILE_LOCK) return;

        var callsign = me.weapon.callsign;
        var brevity = me.weapon.brevity;
        var phrase = brevity~" at: "~callsign;
        if (input.mp_msg.getBoolValue()) {
            armament.defeatSpamFilter(phrase);
        } else {
            input.atc_msg.setValue(phrase);
        }
        fireLog.push("Self: "~phrase);

        me.station.fireWeapon(0);

        me.cycle_selection();
    },
};


var SubModelWeapon = {
    parents: [WeaponLogic],

    new: func(type) {
        var w = { parents: [SubModelWeapon], };
        w.init(type);
        w.selected = [];
        w.stations = [];
        w.weapons = [];
        return w;
    },

    # Argument ignored. Always select all weapons of this type.
    select: func (pylon=nil) {
        me.selected = find_all_pylons_by_type(me.type);

        if (size(me.selected) == 0) {
            me.deselect();
            return FALSE;
        }

        setsize(me.stations, size(me.selected));
        setsize(me.weapons, size(me.selected));
        forindex(var i; me.selected) {
            me.stations[i] = station_by_id(me.selected[i]);
            me.weapons[i] = me.stations[i].getWeapons()[0];
        }

        setprop("controls/armament/station-select-custom", size(me.selected) > 0 ? me.selected[0] : -1);

        me.update_combat();
        me.update_unsafe();

        return TRUE;
    },

    deselect: func (pylon=nil) {
        me.set_unsafe(FALSE);
        me.set_combat(FALSE);
        me.selected = [];
        me.stations = [];
        me.weapons = [];
        setprop("controls/armament/station-select-custom", -1);
    },

    set_unsafe: func(unsafe) {
        # Call parent method
        call(WeaponLogic.set_unsafe, [unsafe], me);

        foreach(var weapon; me.weapons) {
            if (me.unsafe) weapon.start();
            else weapon.stop();
        }
    },

    set_trigger: func(trigger) {
        if (!me.armed()) trigger = FALSE;

        foreach(var weapon; me.weapons) {
            weapon.trigger.setBoolValue(trigger and weapon.operableFunction());
        }
    },
};


if (is_ja) {
    var weapons = [
        SubModelWeapon.new("M75 AKAN"),
        Missile.new("RB-74"),
        Missile.new("RB-99"),
        Missile.new("RB-71"),
        Missile.new("RB-24J"),
        SubModelWeapon.new("M70 ARAK"),
    ];
} else {
    var weapons = [
        Missile.new("RB-74"),
        Missile.new("RB-24J"),
        Missile.new("RB-24"),
        SubModelWeapon.new("M55 AKAN"),
        SubModelWeapon.new("M70 ARAK"),
        Missile.new("RB-15F"),
        Missile.new("RB-04E"),
        Missile.new("RB-75"),
        Missile.new("RB-05A"),
        Missile.new("M90"),
    ];
}
var selected_type_index = 0;


### Controls
var cycle_weapons = func {
    weapons[selected_type_index].deselect();

    var prev = selected_type_index;
    selected_type_index += 1;
    if (selected_type_index >= size(weapons)) selected_type_index = 0;

    while (selected_type_index != prev) {
        if (weapons[selected_type_index].select()) return;

        selected_type_index += 1;
        if (selected_type_index >= size(weapons)) selected_type_index = 0;
    }
}

var toggle_trigger_safe = func {
    var unsafe = !input.unsafe.getBoolValue();
    input.unsafe.setBoolValue(unsafe);

    ja37.click();
    if (unsafe) {
        screen.log.write("Trigger unsafed", 1, 0, 0);
    } else {
        screen.log.write("Trigger safed", 0, 0, 1);
    }

    weapons[selected_type_index].set_unsafe(unsafe);
}

var trigger_listener = func (node) {
    weapons[selected_type_index].set_trigger(node.getBoolValue());
}

var combat_listener = func (node) {
    weapons[selected_type_index].set_combat(node.getBoolValue());
}


setlistener(input.combat, combat_listener, 0, 0);
setlistener(input.trigger, trigger_listener, 0, 0);
