#### Weapons firing logic.

var TRUE = 1;
var FALSE = 0;


var find_index = func(val, vec) {
    forindex(var i; vec) if (vec[i] == val) return i;
    return nil;
}


var input = {
    trigger:    "/controls/armament/trigger-final",
    unsafe:     "/controls/armament/trigger-unsafe",
    trigger_m70:    "/controls/armament/trigger-m70",
    release:    "/instrumentation/indicators/release-complete",
    release_fail:   "/instrumentation/indicators/release-failed",
    mp_msg:     "/payload/armament/msg",
    atc_msg:    "/sim/messages/atc",
    rb05_pitch: "/payload/armament/rb05-control-pitch",
    rb05_yaw:   "/payload/armament/rb05-control-yaw",
    speed_kt:   "/velocities/groundspeed-kt",
    gear_pos:   "/gear/gear/position-norm",
    time:       "/sim/time/elapsed-sec",
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
    new: func(type) {
        var m = { parents: [WeaponLogic] };
        m.type = type;
        m.unsafe = FALSE;
        return m;
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

    # Called when the trigger safety changes position while this weapon type is selected.
    set_unsafe: func(unsafe) {
        if (!firing_enabled()) unsafe = FALSE;
        me.unsafe = unsafe;
        if (!me.unsafe) me.set_trigger(FALSE);
    },

    armed: func {
        return me.unsafe;
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

    # Additional parameters:
    #   falld_last: (bool) If the FALLD LAST indicator (for AJS) should light up after release.
    #   fire_delay: (float) Delay between trigger pull and firing.
    #   at_everything: (bool) Required for any lock after launch, change of lock, multiple target hit...
    #   no_lock: (bool) Allow firing without missile lock.
    #   cycling: (bool) If cycling pylon is allowed with the FRAMSTEGN button. default ON
    new: func(type, falld_last=0, fire_delay=0, at_everything=0, no_lock=0, cycling=1) {
        var w = { parents: [Missile, WeaponLogic.new(type)], };
        w.selected = nil;
        w.station = nil;
        w.weapon = nil;
        w.fired = FALSE;
        w.falld_last = falld_last;
        w.fire_delay = fire_delay;
        w.at_everything = at_everything;
        w.no_lock = no_lock;
        w.cycling = cycling;

        if (w.fire_delay > 0) {
            w.release_timer = maketimer(w.fire_delay, w, w.release_weapon);
            w.release_timer.simulatedTime = TRUE;
            w.release_timer.singleShot = TRUE;
        }

        if (type == "RB-24" or type == "RB-24J" or type == "RB-74") {
            w.is_IR = TRUE;
            w.IR_seeker_timer = maketimer(0.5, w, w.IR_seeker_loop);
        } else {
            w.is_IR = FALSE;
        }

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

        if (me.is_IR) me.IR_seeker_timer.start();
    },

    deselect: func {
        me.set_unsafe(FALSE);
        me.selected = nil;
        me.station = nil;
        me.weapon = nil;
        me.fired = FALSE;
        if (me.is_IR) me.IR_seeker_timer.stop();
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

    # Internal function, select next missile of same type.
    _cycle_selection: func {
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

    # Called when pressing the 'cycle missile' button.
    # Same as _cycle_selection, unless cycling is disabled by the argument cycling in the constructor.
    cycle_selection: func {
        if (me.cycling) me._cycle_selection();
    },

    set_unsafe: func(unsafe) {
        # Call parent method
        call(WeaponLogic.set_unsafe, [unsafe], me);

        if (me.weapon != nil) {
            if (me.unsafe) {
                # Setup weapon
                me.weapon.start();

                # IR weapons parameters.
                if (me.is_IR) {
                    if (!variant.JA) {
                        # For AJS, locked on bore.
                        me.weapon.setAutoUncage(FALSE);
                        me.weapon.setCaged(TRUE);
                        me.weapon.setSlave(TRUE);
                        me.weapon.commandDir(0,0);
                    } else {
                        me.weapon.setUncagedPattern(3, 2.5, -12);
                    }
                }
            } else {
                me.weapon.stop();
            }
        }

        # Select next weapon when safing after firing.
        if (me.fired and !me.unsafe) {
            me.fired = FALSE;
            me._cycle_selection();
        }

        # FALLD LAST off when safing.
        if (!me.unsafe) input.release.setBoolValue(FALSE);

        # Interupt firing sequence if timer is running.
        if (!me.unsafe and me.fire_delay > 0 and me.release_timer.isRunning) {
            me.release_timer.stop();
            input.release_fail.setBoolValue(TRUE);
        }
    },

    release_weapon: func {
        var phrase = me.weapon.brevity;
        if (me.weapon.status == armament.MISSILE_LOCK) {
            phrase = phrase~" at: "~me.weapon.callsign;
        }
        events.fireLog.push("Self: "~phrase);

        me.station.fireWeapon(0, me.at_everything ? radar_logic.complete_list : nil);

        me.weapon = nil;
        me.fired = TRUE;
        input.release.setBoolValue(me.falld_last);
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !trigger or me.weapon == nil
            or (!me.no_lock and me.weapon.status != armament.MISSILE_LOCK)) return;

        if (me.fire_delay > 0) me.release_timer.start();
        else me.release_weapon();
    },

    # IR seeker manipulation
    uncage_IR_seeker: func {
        if (variant.JA or me.weapon == nil or me.weapon.status != armament.MISSILE_LOCK
            or (me.weapon.type != "RB-24J" and me.weapon.type != "RB-74")) return;

        me.weapon.setAutoUncage(TRUE);
        me.weapon.setSlave(FALSE);
    },

    reset_IR_seeker: func {
        if (variant.JA or me.weapon == nil
            or (me.weapon.type != "RB-24J" and me.weapon.type != "RB-74")) return;

        me.weapon.stop();
        me.weapon.start();
        me.weapon.setAutoUncage(FALSE);
        me.weapon.setCaged(TRUE);
        me.weapon.setSlave(TRUE);
        me.weapon.commandDir(0,0);
    },

    IR_seeker_loop: func {
        if (!me.weapon_ready()) return;

        # For JA, switch between bore sight and radar command automatically.
        # Note: not using 'setBore()' for bore sight. Instead keeping 'setSlave()'
        # and using 'commandDir()' to allow to adjust bore position, if we want to.
        if (variant.JA and me.weapon.isCaged()) {
            if (radar_logic.selection == nil or TI.ti.rb74_force_bore) {
                if (me.weapon.command_tgt) me.weapon.commandDir(0,0);
            } else {
                if (!me.weapon.command_tgt) me.weapon.commandRadar();
            }
        }

        if (me.weapon.status != armament.MISSILE_LOCK) {
            # Don't do anything if the missile has already locked. It would mess with the lock.
            if (me.weapon.isCaged() and me.weapon.command_tgt) {
                # Slave onto radar target.
                me.weapon.setContacts([]);
            } else {
                # Send list of all contacts to allow searching.
                me.weapon.setContacts(radar_logic.complete_list);
            }
        }
    },

    get_weapon: func { return me.weapon; },

    weapon_ready: func { return me.weapon != nil; },

    get_selected_pylons: func {
        if (me.selected == nil) return [];
        else return [me.selected];
    },
};

### Rb-05 has some special additional logic for remote control.
var Rb05 = {
    parents: [Missile.new(type:"RB-05A", cycling:0)],

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

        events.fireLog.push("Self: "~me.weapon.brevity);

        me.station.fireWeapon(0, radar_logic.complete_list);

        me.weapon = nil;
        me.fired = TRUE;
    },
};


### Generic submodel based weapon (gun, rockets).
# Expect the underlying weapon to be an instance of stations.SubModelWeapon.
var SubModelWeapon = {
    parents: [WeaponLogic],

    new: func(type, ammo_factor=1) {
        var w = { parents: [SubModelWeapon, WeaponLogic.new(type)], };
        w.selected = [];
        w.stations = [];
        w.weapons = [];

        w.firing = FALSE;

        # Ammunition count is very important and a bit tricky, because it is used in 'weapon_ready()'.
        # Cache the results for efficiency.
        w.ammo = 0;
        w.ammo_factor = ammo_factor;
        w.ammo_update_timer = maketimer(0.05, w, w._update_ammo);
        w.simulatedTime = 1;
        return w;
    },

    # Argument ignored. Always select all weapons of this type.
    select: func (pylon=nil) {
        me.deselect();

        me.selected = pylons.find_all_pylons_by_type(me.type);
        if (size(me.selected) == 0) {
            me.selected = [];
            return FALSE;
        }

        setsize(me.stations, size(me.selected));
        setsize(me.weapons, size(me.selected));
        forindex(var i; me.selected) {
            me.stations[i] = pylons.station_by_id(me.selected[i]);
            me.weapons[i] = me.stations[i].getWeapons()[0];
        }
        me._update_ammo();
        if (!me.weapon_ready()) {
            # no ammo
            me.selected = [];
            me.stations = [];
            me.weapons = [];
            return FALSE;
        }

        setprop("controls/armament/station-select-custom", size(me.selected) > 0 ? me.selected[0] : -1);
        return TRUE;
    },

    deselect: func (pylon=nil) {
        me.set_unsafe(FALSE);
        me.selected = [];
        me.stations = [];
        me.weapons = [];
        setprop("controls/armament/station-select-custom", -1);
    },

    cycle_selection: func {},

    set_unsafe: func(unsafe) {
        # Call parent method
        call(WeaponLogic.set_unsafe, [unsafe], me);

        var trigger_prop = input.trigger;

        if (me.type == "M70 ARAK") {
            # For rockets, trigger logic is a bit different because all rockets must be fired.
            trigger_prop = input.trigger_m70;
            input.trigger_m70.setBoolValue(FALSE);
        }

        foreach(var weapon; me.weapons) {
            if (me.unsafe) weapon.start(trigger_prop);
            else weapon.stop();
        }

        if (me.unsafe) me.ammo_update_timer.start();
        else me.ammo_update_timer.stop();

        if (!me.unsafe) me.firing = FALSE;
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !me.weapon_ready()) return;

        if (me.type == "M70 ARAK") {
            # For rockets, set the trigger ON as required, but do not set it OFF, so that all rockets get fired.
            if (trigger) input.trigger_m70.setBoolValue(TRUE);
            me.firing = TRUE;
        } else {
            # For other weapons, there is nothing to do. Just remember that we are firing.
            me.firing = trigger;
        }
    },

    _update_ammo: func {
        me.ammo = call(WeaponLogic.get_ammo, [], me);
        # Update the 'firing' status if ammo is depleted.
        if (!me.weapon_ready()) me.firing = FALSE;
    },

    get_ammo: func {
        return math.ceil(me.ammo/me.ammo_factor);
    },

    weapon_ready: func {
        return me.ammo > 0;
    },

    get_selected_pylons: func {
        return me.selected;
    },

    # Method specific to gun/rockets, used by HUD.
    is_firing: func {
        return me.firing;
    },
};

### M71 Bomb logic.
#
# In this class, a position is a pair [pylon, bomb] where
# pylon is the number of the station, bomb is the number of the bomb of that station.
var Bomb = {
    parents: [WeaponLogic],

    new: func(type) {
        var w = { parents: [Bomb, WeaponLogic.new(type)], };
        w.positions = [];
        w.next_pos = 0;
        w.next_weapon = nil;

        w.release_distance = 20;   # meter

        w.release_order = [];      # list of positions indicating release priority order.
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
        me.deselect();

        foreach(var pos; me.release_order) {
            if (me.is_pos_loaded(pos)) append(me.positions, pos);
        }
        if (size(me.positions) == 0) {
            return FALSE;
        } else {
            me.next_pos = 0;
            me.next_weapon = me.get_bomb_pos(me.positions[0]);
            return TRUE;
        }
    },

    deselect: func {
        me.set_unsafe(FALSE);
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
            input.release.setBoolValue(TRUE);
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

    set_unsafe: func(unsafe) {
        # Call parent method
        call(WeaponLogic.set_unsafe, [unsafe], me);

        if (!me.unsafe) {
            # 'FALLD LAST' off when securing the trigger.
            input.release.setBoolValue(FALSE);
        }
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !me.weapon_ready()) trigger = FALSE;

        if (trigger) {
            events.fireLog.push("Self: "~me.next_weapon.brevity);
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
        Missile.new(type:"RB-74", fire_delay:0.7),
        Missile.new(type:"RB-99", fire_delay:0.7),
        Missile.new(type:"RB-71", fire_delay:0.7),
        Missile.new(type:"RB-24J", fire_delay:0.7),
        SubModelWeapon.new(type:"M70 ARAK", ammo_factor:6), # get_ammo gives number of pods
    ];

    var internal_gun = SubModelWeapon.new(type:"M75 AKAN", ammo_factor:22);  # get_ammo gives firing time
} else {
    var weapons = [
        Missile.new(type:"RB-74", fire_delay:0.7),
        Missile.new(type:"RB-24J", fire_delay:0.7),
        Missile.new(type:"RB-24", fire_delay:0.7),
        SubModelWeapon.new("M55 AKAN"),
        SubModelWeapon.new(type:"M70 ARAK"),
        Missile.new(type:"RB-04E", falld_last:1, fire_delay:1, at_everything:1, no_lock:1, cycling:0),
        Missile.new(type:"RB-15F", falld_last:1, at_everything:1, no_lock:1),
        Missile.new(type:"RB-75", fire_delay:1),
        Rb05,
        Missile.new(type:"M90", at_everything:1),
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
    if (prev < 0) prev = size(weapons)-1;
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

# For JA
var select_cannon = func {
    _deselect_current();
    internal_gun.select();
    _set_selected_index(-1);
}

# For AJS
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

# Next pylon of same type
var cycle_pylon = func {
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

setlistener(input.trigger, trigger_listener, 0, 0);
setlistener(input.unsafe, unsafe_listener, 0, 0);


### Fire control inhibit.
var firing_enabled = func {
    return input.gear_pos.getValue() == 0 and power.prop.acSecond.getBoolValue();
}

var inhibit_callback = func {
    if (selected != nil and selected.armed() and firing_enabled()) selected.set_unsafe(FALSE);
}

setlistener(input.gear_pos, inhibit_callback, 0, 0);
setlistener(power.prop.acSecond, inhibit_callback, 0, 0);


### Reset fire control logic when reloading.
var ReloadCallback = {
    updateAll: func {
        deselect_weapon();
    },

    init: func {
        foreach(var station; pylons.stations_list) {
            pylons.station_by_id(station).setPylonListener(me);
        }
    },
};

ReloadCallback.init();
