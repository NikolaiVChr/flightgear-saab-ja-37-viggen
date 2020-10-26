#### Weapons firing logic.

var TRUE = 1;
var FALSE = 0;


var find_index = func(val, vec) {
    forindex(var i; vec) if (vec[i] == val) return i;
    return nil;
}


var input = {
    combat:     "/ja37/mode/combat",
    trigger:    "/controls/armament/trigger-final",
    unsafe:     "/controls/armament/trigger-unsafe",
    mp_msg:     "/payload/armament/msg",
    atc_msg:    "/sim/messages/atc",
    rb05_pitch: "/payload/armament/rb05-control-pitch",
    rb05_yaw:   "/payload/armament/rb05-control-yaw",
    speed_kt:   "/velocities/groundspeed-kt",
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop], 1);
}



### Pylon names
var STATIONS = pylons.STATIONS;


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

    # Select the next weapon of this type (when it makes sense).
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
    },

    update_combat: func {
        me.set_combat(input.combat.getBoolValue());
    },

    # Called when the trigger safety changes position while this weapon type is selected.
    set_unsafe: func(unsafe) {
        if (!me.combat) unsafe = FALSE;
        me.unsafe = unsafe;
        if (!me.unsafe) me.set_trigger(FALSE);
    },

    armed: func {
        return me.combat and me.unsafe;
    },

    # Called when the trigger is pressed/released while this weapon type is selected.
    set_trigger: func(trigger) {
        die("Called unimplemented abstract class method");
    },

    weapon_ready: func { return FALSE; },

    # Return ammo count for this type of weapon.
    get_ammo: func { return pylons.get_ammo(me.type); },

    # Return the active weapon object (created from missile.nas), when it makes sense.
    get_weapon: func { return nil; },

    # Return an array containing selected stations.
    get_selected_pylons: func { return []; },
};


### Generic missile weapons, based on missiles.nas
var Missile = {
    parents: [WeaponLogic],

    # Selection order.
    pylons_priority: [STATIONS.R7V, STATIONS.R7H, STATIONS.V7V, STATIONS.V7H, STATIONS.S7V, STATIONS.S7H],

    new: func(type) {
        var w = { parents: [Missile], };
        w.init(type);
        w.selected = nil;
        w.station = nil;
        w.weapon = nil;
        w.fired = FALSE;
        return w;
    },

    # Internal function. pylon must be correct (loaded with correct type...)
    _select: func(pylon) {
        # First reset state
        me.deselect();

        me.selected = pylon;
        me.station = pylons.station_by_id(me.selected);
        me.weapon = me.station.getWeapons()[0];
        me.fired = FALSE;
        setprop("controls/armament/station-select-custom", pylon);

        me.update_combat();
    },

    deselect: func {
        me.set_unsafe(FALSE);
        me.set_combat(FALSE);
        me.selected = nil;
        me.station = nil;
        me.weapon = nil;
        me.fired = FALSE;
        setprop("controls/armament/station-select-custom", -1);
    },

    select: func(pylon=nil) {
        if (pylon == nil) {
            # Pylon not given as argument. Find a matching one.
            pylon = pylons.find_pylon_by_type(me.type, me.pylons_priority);
        } else {
            # Pylon given as argument. Check that it matches.
            if (!pylons.is_loaded_with(pylon, me.type)) pylon = nil;
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
        # Cycling is only possible when trigger is safed.
        if (me.unsafe) return !me.fired;

        var first = 0;
        if (me.selected != nil) {
            first = find_index(me.selected, me.pylons_priority)+1;
            if (first >= size(me.pylons_priority)) first = 0;
        }

        pylon = pylons.find_pylon_by_type(me.type, me.pylons_priority, first);
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
            if (me.unsafe) {
                # Setup weapon
                me.weapon.start();

                # IR weapons parameters. For AJS, locked on bore.
                # I'm not sure about the JA, keeping it simple to use for now.
                if (!variant.JA and me.weapon.guidance == "heat") {
                    me.weapon.setAutoUncage(FALSE);
                    me.weapon.setCaged(TRUE);
                    me.weapon.setBore(TRUE);
                }
            } else {
                me.weapon.stop();
            }
        }

        # Select next weapon when safing after firing.
        if (me.fired and !me.unsafe) {
            me.fired = FALSE;
            me.cycle_selection();
        }
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !trigger or me.weapon == nil) return;

        if (me.weapon.status != armament.MISSILE_LOCK) return;

        var callsign = me.weapon.callsign;
        var brevity = me.weapon.brevity;
        var phrase = brevity~" at: "~callsign;
        if (input.mp_msg.getBoolValue()) {
            armament.defeatSpamFilter(phrase);
        } else {
            input.atc_msg.setValue(phrase);
        }
        events.fireLog.push("Self: "~phrase);

        me.station.fireWeapon(0);

        me.weapon = nil;
        me.fired = TRUE;
    },

    # IR seeker manipulation
    uncage_IR_seeker: func {
        if (variant.JA or me.weapon == nil or me.weapon.status != armament.MISSILE_LOCK
            or (me.weapon.type != "RB-24J" and me.weapon.type != "RB-74")) return;

        me.weapon.setAutoUncage(TRUE);
        me.weapon.setBore(FALSE);
    },

    reset_IR_seeker: func {
        if (variant.JA or me.weapon == nil or (me.weapon.type != "RB-24J" and me.weapon.type != "RB-74")) return;

        me.weapon.stop();
        me.weapon.start();
        me.weapon.setAutoUncage(FALSE);
        me.weapon.setCaged(TRUE);
        me.weapon.setBore(TRUE);
    },

    get_weapon: func { return me.weapon; },

    weapon_ready: func { return me.weapon != nil; },

    get_selected_pylons: func { return [me.selected]; },
};

### Rb-05 has some special additional logic for remote control.
var Rb05 = {
    parents: [Missile.new("RB-05A")],

    active_rb05: nil,

    makeMidFlightFunction: func(pylon) {
        return func(state) {
            # Missile can be controlled ~1.7s after launch (manual)
            if (state.time_s < 1.7 or Rb05.active_rb05 != pylon) return {};
            else return {
                remote_yaw: input.rb05_yaw.getValue(),
                remote_pitch: input.rb05_pitch.getValue(),
            };
        };
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !trigger or me.weapon == nil) return;

        me.active_rb05 = me.selected;
        me.weapon.mfFunction = me.makeMidFlightFunction(me.selected);

        var callsign = me.weapon.callsign;
        var brevity = me.weapon.brevity;
        var phrase = brevity~" at: "~callsign;
        if (input.mp_msg.getBoolValue()) {
            armament.defeatSpamFilter(phrase);
        } else {
            input.atc_msg.setValue(phrase);
        }
        events.fireLog.push("Self: "~phrase);

        me.station.fireWeapon(0);

        me.weapon = nil;
        me.fired = TRUE;
    },
};


### Generic submodel based weapon (gun, rockets).
# Expect the underlying weapon to be an instance of stations.SubModelWeapon.
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
        me.selected = pylons.find_all_pylons_by_type(me.type);

        if (size(me.selected) == 0) {
            me.deselect();
            return FALSE;
        }

        setsize(me.stations, size(me.selected));
        setsize(me.weapons, size(me.selected));
        forindex(var i; me.selected) {
            me.stations[i] = pylons.station_by_id(me.selected[i]);
            me.weapons[i] = me.stations[i].getWeapons()[0];
        }

        if (!me.weapon_ready()) {
            # no ammo
            me.deselect();
            return FALSE;
        }

        setprop("controls/armament/station-select-custom", size(me.selected) > 0 ? me.selected[0] : -1);

        me.update_combat();

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

    cycle_selection: func {},

    set_unsafe: func(unsafe) {
        # Call parent method
        call(WeaponLogic.set_unsafe, [unsafe], me);

        foreach(var weapon; me.weapons) {
            if (me.unsafe) weapon.start(input.trigger);
            else weapon.stop();
        }
    },

    set_trigger: func(trigger) {
        if (!me.armed()) trigger = FALSE;

        foreach(var weapon; me.weapons) {
            weapon.trigger.setBoolValue(trigger and weapon.operableFunction());
        }
    },

    weapon_ready: func {
        return me.get_ammo() > 0;
    },

    get_selected_pylons: func {
        return me.selected;
    },
};

### M71 Bomb logic.
#
# In this class, a position is a pair [pylon, bomb] where
# pylon is the number of the station, bomb is the number of the bomb of that station.
var Bomb = {
    parents: [WeaponLogic],

    release_distance: 20,   # meter

    release_order: [],      # list of positions indicating release priority order.

    new: func(type) {
        var w = { parents: [Bomb], };
        w.init(type);
        w.positions = [];
        w.next_pos = 0;
        w.next_weapon = nil;

        # Release order: fuselage R/L alternating, then wing R/L alternating (AJS manual)
        for(var i=0; i<4; i+=1) {
            append(w.release_order, [STATIONS.S7H, i]);
            append(w.release_order, [STATIONS.S7V, i]);
        }
        for(var i=0; i<4; i+=1) {
            append(w.release_order, [STATIONS.V7H, i]);
            append(w.release_order, [STATIONS.V7V, i]);
        }

        w.drop_bomb_timer = maketimer(0, w, w.drop_next_bomb);
        w.simulatedTime = TRUE;
        w.singleShot = FALSE;
        return w;
    },

    select: func(pylon=nil) {
        me.weapons = [];

        foreach(var pos; me.release_order) {
            if (me.is_pos_loaded(pos)) append(me.positions, pos);
        }

        if (size(me.positions) == 0) {
            me.deselect();
            return FALSE;
        } else {
            me.next_pos = 0;
            me.next_weapon = me.get_bomb_pos(me.positions[0]);
            me.update_combat();
            return TRUE;
        }
    },

    deselect: func {
        me.set_unsafe(FALSE);
        me.set_combat(FALSE);
        me.positions = [];
        me.next_pos = 0;
        me.next_weapon = nil;
    },

    cycle_selection: func {},

    is_pos_loaded: func (pos) {
        return pylons.is_loaded_with(pos[0], me.type)
            and pylons.station_by_id(pos[0]).getWeapons()[pos[1]] != nil;
    },

    drop_bomb_pos: func (pos) {
        pylons.station_by_id(pos[0]).fireWeapon(pos[1], radar_logic.complete_list);
    },

    get_bomb_pos: func (pos) {
        return pylons.station_by_id(pos[0]).getWeapons()[pos[1]];
    },

    drop_next_bomb: func {
        if (!me.weapon_ready()) {
            me.stop_drop_sequence();
            return;
        }

        me.drop_bomb_pos(me.positions[me.next_pos]);

        me.next_pos += 1;
        if (me.next_pos < size(me.positions)) {
            me.next_weapon = me.get_bomb_pos(me.positions[me.next_pos]);
        } else {
            me.next_weapon = nil;
        }
    },

    release_interval: func(distance) {
        return distance / (input.speed_kt.getValue() * KT2MPS);
    },

    start_drop_sequence: func {
        me.drop_next_bomb();
        me.drop_bomb_timer.restart(me.release_interval(me.release_distance));
    },

    stop_drop_sequence: func {
        me.drop_bomb_timer.stop();
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !me.weapon_ready()) trigger = FALSE;

        if (trigger) {
            var brevity = me.next_weapon.brevity;
            if (input.mp_msg.getBoolValue()) {
                armament.defeatSpamFilter(brevity);
            } else {
                input.atc_msg.setValue(brevity);
            }
            me.start_drop_sequence();
        } else {
            me.stop_drop_sequence();
        }
    },

    weapon_ready: func {
        return me.next_weapon != nil;
    },

    # Return the active weapon (object from missile.nas), when it makes sense.
    get_weapon: func {
        return me.next_weapon;
    },

    get_selected_pylons: func {
        return [];
    },
};



### List of weapon types.
if (variant.JA) {
    var weapons = [
        Missile.new("RB-74"),
        Missile.new("RB-99"),
        Missile.new("RB-71"),
        Missile.new("RB-24J"),
        SubModelWeapon.new("M70 ARAK"),
    ];

    # Indices in the previous array for IR missiles.
    var IRRB = [0, 3];

    var internal_gun = SubModelWeapon.new("M75 AKAN");
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
        Rb05,
        Missile.new("M90"),
        Bomb.new("M71"),
        Bomb.new("M71R"),
    ];

    # Indices in the previous array for IR missiles.
    var IRRB = [0, 1, 2];
}

# Selected weapon type.
var selected_index = -2;
var selected = nil;

# Internal selection function.
var _set_selected_index = func(index) {
    selected_index = index;
    if (index >= 0) selected = weapons[index];
    elsif (index == -1 and variant.JA) selected = internal_gun;
    else selected = nil;
}


### Access functions.
var get_weapon = func {
    if (selected == nil) return nil;
    else return selected.get_weapon();
}

var get_current_ammo = func {
    if (selected == nil) return -1;
    else return selected.get_ammo();
}

var get_selected_pylons = func {
    if (selected == nil) return [];
    else return selected.get_selected_pylons();
}


### Controls

## Weapon selection.
var _deselect_current = func {
    if (selected != nil) selected.deselect();
}

var cycle_weapon_type = func {
    _deselect_current();

    # Cycle through weapons, starting from the previous one.
    var prev = selected_index;
    if (prev < 0) prev = 0;
    var i = prev;
    i += 1;
    if (i >= size(weapons)) i = 0;

    while (i != prev) {
        if (weapons[i].select()) {
            _set_selected_index(i);
            return
        }
        i += 1;
        if (i >= size(weapons)) i = 0;
    }
    # We are back to the first weapon. Last try
    if (weapons[i].select()) {
        _set_selected_index(i);
    } else {
        # Nothing found
        _set_selected_index(-2);
    }
}

var select_cannon = func {
    _deselect_current();
    internal_gun.select();
    _set_selected_index(-1);
}

var select_IRRB = func {
    _deselect_current();
    foreach(var i; IRRB) {
        if (weapons[i].select()) {
            _set_selected_index(i);
            return;
        }
    }
    # Not found
    _set_selected_index(-2);
}

var cycle_weapon = func {
    if (selected != nil) selected.cycle_selection();
}

var deselect_weapon = func {
    _deselect_current();
    _set_selected_index(-2);
}

var select_pylon = func(pylon) {
    _deselect_current();

    var type = pylons.station_by_id(pylon).singleName;
    forindex(var i; weapons) {
        # Find matching weapon type.
        if (weapons[i].type == type) {
            # Attempt to load this pylon.
            if (weapons[i].select(pylon)) {
                _set_selected_index(i);
            } else {
                _set_selected_index(-2);
            }
            return;
        }
    }
}


## Other controls.

# Trigger safety.
# Note: toggling /controls/armament/trigger-unsafe also works, this is just for the nice message.
var toggle_trigger_safe = func {
    var unsafe = !input.unsafe.getBoolValue();
    input.unsafe.setBoolValue(unsafe);

    if (unsafe) {
        screen.log.write("Trigger unsafed", 1, 0, 0);
    } else {
        screen.log.write("Trigger safed", 0, 0, 1);
    }
}


# IR seeker release button
var uncageIR = func {
    if (selected != nil and (selected.type == "RB-24J" or selected.type == "RB-74")) {
        selected.uncage_IR_seeker();
    }
}

var resetIR = func {
    if (selected != nil and (selected.type == "RB-24J" or selected.type == "RB-74")) {
        selected.reset_IR_seeker();
    }
}

# Pressing the button uncages, holding it resets
var uncageIRButtonTimer = maketimer(1, resetIR);
uncageIRButtonTimer.singleShot = TRUE;
uncageIRButtonTimer.simulatedTime = TRUE;

var uncageIRButton = func (pushed) {
    if (pushed) {
        uncageIR();
        uncageIRButtonTimer.start();
    } else {
        uncageIRButtonTimer.stop();
    }
}


# Propagate controls to weapon logic.
var trigger_listener = func (node) {
    if (selected != nil) selected.set_trigger(node.getBoolValue());
}

var unsafe_listener = func (node) {
    if (selected != nil) selected.set_unsafe(node.getBoolValue());
}

var combat_listener = func (node) {
    if (selected != nil) selected.set_combat(node.getBoolValue());
}

setlistener(input.combat, combat_listener, 0, 0);
setlistener(input.unsafe, unsafe_listener, 0, 0);
setlistener(input.trigger, trigger_listener, 0, 0);
