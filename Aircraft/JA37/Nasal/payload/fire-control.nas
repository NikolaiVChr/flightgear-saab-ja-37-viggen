#### Weapons firing logic.

var TRUE = 1;
var FALSE = 0;


var find_index = func(val, vec) {
    forindex(var i; vec) if (vec[i] == val) return i;
    return nil;
}


var input = {
    trigger:        "/controls/armament/trigger",
    unsafe:         "/controls/armament/trigger-unsafe",
    trigger_m70:    "/controls/armament/trigger-m70",
    release:        "/instrumentation/indicators/release-complete",
    release_fail:   "/instrumentation/indicators/release-failed",
    mp_msg:         "/payload/armament/msg",
    atc_msg:        "/sim/messages/atc",
    rb05_pitch:     "/payload/armament/rb05-control-pitch",
    rb05_yaw:       "/payload/armament/rb05-control-yaw",
    speed_kt:       "/velocities/groundspeed-kt",
    gear_pos:       "/gear/gear/position-norm",
    nose_WOW:       "fdm/jsbsim/gear/unit[0]/WOW",
    time:           "/sim/time/elapsed-sec",
    wpn_knob:       "/controls/armament/weapon-panel/selector-knob",
    ep13:           "ja37/avionics/vid",
    # Ground crew weapon panel settings
    start_left:     "/controls/armament/ground-panel/start-left",
    gnd_wpn_knob:   "/controls/armament/ground-panel/weapon-selector-knob",
    gnd_wpn_switch: "/controls/armament/ground-panel/weapon-selector-switch",
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop], 1);
}


var fireLog = events.LogBuffer.new(echo: 0);


### Pylon names
var STATIONS = pylons.STATIONS;


### Don't do anything as long as this is off.
var firing_computer_on = func {
    return power.prop.acMainBool.getBoolValue();
}


#### Weapons firing logic

### Weapon logic API (abstract class)
#
# Different weapon types should inherit this object and define the methods,
# so as to implement custom firing logic.
var WeaponLogic = {
    # Args:
    # - type: the weapon type (as used by missile.nas, uppercase)
    #         for which an instance of this class is implementing the logic.
    # - multi_types: An array of weapon types (in the sense of missile.nas), or nil.
    #                Used if an instance of this class implements the logic of
    #                several weapon types simultaneously (this generally means that
    #                these weapon types can not be selected separately, e.g. AJS IR missiles).
    #                When 'multi_types' is defined, 'type' is not used internally.
    #                It may still be queried by external code to know which weapon type is selected.
    #                Thus it should be set to something sensible, summarising 'multi_types'.
    new: func(type, multi_types=nil) {
        var m = { parents: [WeaponLogic] };
        m.type = type;
        # Array of weapon types (in the sense of missile.nas).
        # Used internally when selecting pylons.
        m.types = (multi_types != nil) ? multi_types : [type];
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

    # Used by the HUD. Only bombs, guns, and rockets use it.
    is_firing: func { return FALSE; },

    weapon_ready: func { return FALSE; },

    # Return ammo count for this type of weapon.
    get_ammo: func {
        var sum = 0;
        foreach (var type; me.types) {
            sum += pylons.get_ammo(type);
        }
        return sum;
    },

    # Return the active weapon object (created from missile.nas), when it makes sense.
    get_weapon: func { return nil; },

    # Return an array containing selected stations.
    get_selected_pylons: func { return []; },
};


### Generic missile weapons, based on missiles.nas
var Missile = {
    parents: [WeaponLogic],

    # Selection order.
    pylons_priority_left: [STATIONS.R7V, STATIONS.R7H, STATIONS.V7V, STATIONS.V7H, STATIONS.S7V, STATIONS.S7H],
    pylons_priority_right: [STATIONS.R7H, STATIONS.R7V, STATIONS.V7H, STATIONS.V7V, STATIONS.S7H, STATIONS.S7V],

    pylons_priority: func {
        if (me.can_start_right and !input.start_left.getBoolValue()) {
            return me.pylons_priority_right;
        } else {
            return me.pylons_priority_left;
        }
    },

    # parameters:
    #   type, multi_types: see WeaponLogic
    #   falld_last: (bool) If the FALLD LAST indicator (for AJS) should light up after release.
    #   fire_delay: (float) Delay between trigger pull and firing.
    #   at_everything: (bool) Required for any lock after launch, change of lock, multiple target hit...
    #   no_lock: (bool) Allow firing without missile lock.
    #   cycling: (bool) Cycling pylon is allowed with the FRAMSTEGN button. default ON
    #   can_start_right: (bool) The AJS ground panel L/R switch is taken in account to choose the first fired side.
    new: func(type, multi_types=nil, falld_last=0, fire_delay=0, at_everything=0, no_lock=0, cycling=1, can_start_right=0) {
        var w = { parents: [Missile, WeaponLogic.new(type, multi_types)], };
        w.selected = nil;
        w.station = nil;
        w.weapon = nil;
        w.fired = FALSE;
        w.falld_last = falld_last;
        w.fire_delay = fire_delay;
        w.at_everything = at_everything;
        w.no_lock = no_lock;
        w.cycling = cycling;
        w.can_start_right = can_start_right;

        if (w.fire_delay > 0) {
            w.release_timer = maketimer(w.fire_delay, w, w.release_weapon);
            w.release_timer.simulatedTime = TRUE;
            w.release_timer.singleShot = TRUE;
        }

        w.seeker_timer = maketimer(0.5, w, w.seeker_loop);

        # Flags for special weapons
        w.is_IR = TRUE;
        w.is_rb75 = TRUE;
        foreach (var ty; w.types) {
            if (ty != "RB-24" and ty != "RB-24J" and ty != "RB-74") w.is_IR = FALSE;
            if (ty != "RB-75") w.is_rb75 = FALSE;
        }
        if (w.is_IR and variant.JA) w.last_IR_lock = nil;
        if (w.is_rb75) {
            # Note: separate from seeker_timer, high refresh rate needed.
            w.rb75_timer = maketimer(0.05, w, w.rb75_loop);

            w.rb75_last_seeker_on = FALSE;
            w.last_click = FALSE;
            w.rb75_lock = FALSE;
            # Seeker position in degrees
            w.rb75_pos_x = 0;
            w.rb75_pos_y = -1.3;
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
        me.start_seeker();
    },

    deselect: func {
        me.stop_seeker();
        me.set_unsafe(FALSE);
        me.selected = nil;
        me.station = nil;
        me.weapon = nil;
        me.fired = FALSE;
    },

    select: func(pylon=nil) {
        if (pylon == nil) {
            # Pylon not given as argument. Find a matching one.
            pylon = pylons.find_pylon_by_types(me.types, me.pylons_priority());
        } else {
            # Pylon given as argument. Check that it matches.
            if (!pylons.is_loaded_with(pylon, me.types)) pylon = nil;
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

        var priority = me.pylons_priority();

        var first = 0;
        if (me.selected != nil) {
            first = find_index(me.selected, priority)+1;
            if (first >= size(priority)) first = 0;
        }

        pylon = pylons.find_pylon_by_types(me.types, priority, first);
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
        fireLog.push("Self: "~phrase);

        me.station.fireWeapon(0, me.at_everything ? radar_logic.complete_list : nil);

        me.weapon = nil;
        me.fired = TRUE;
        input.release.setBoolValue(me.falld_last);
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !trigger or me.weapon == nil
            or (!me.no_lock and me.weapon.status != armament.MISSILE_LOCK)
            or (me.is_rb75 and !me.rb75_can_fire())) return;

        if (me.fire_delay > 0) me.release_timer.start();
        else me.release_weapon();
    },

    start_seeker: func {
        if (me.weapon == nil) return;

        # Setup weapon
        me.weapon.start();
        me.seeker_timer.start();

        # IR weapons parameters.
        if (me.is_IR) {
            if (!variant.JA) {
                # For AJS, locked on bore.
                me.weapon.setAutoUncage(FALSE);
                me.weapon.setCaged(TRUE);
                me.weapon.setSlave(TRUE);
                # Boresight position: 0.8 deg down, except for outer pylons (AJS SFI part 3);
                if (me.selected == STATIONS.R7V or me.selected == STATIONS.R7H) {
                    me.weapon.commandDir(0,0);
                } else {
                    me.weapon.commandDir(0,-0.8);
                }
            } else {
                me.weapon.setUncagedPattern(3, 2.5, -12);
            }
        }

        if (me.is_rb75) {
            # Make sure the Rb 75 seeker gets initialised in the seeker loop.
            me.rb75_last_seeker_on = FALSE;
            me.rb75_timer.start();
        }
    },

    stop_seeker: func {
        if (me.weapon == nil) return;

        if (me.is_rb75) {
            input.ep13.setBoolValue(FALSE);
            me.rb75_timer.stop();
        }

        me.seeker_timer.stop();
        me.weapon.stop();
    },

    # Allows the seeker to follow a target it is locked on.
    _uncage_seeker: func {
        # With these specific parameters, the seeker is free to follow the target,
        # but will become non-functioning and require reset if it looses lock.
        # (alternative is it coming back to boresight or uncaged pattern after loosing lock...)
        me.weapon.setAutoUncage(TRUE);
        me.weapon.setSlave(FALSE);
    },

    # Reset seeker after calling _uncage_seeker()
    _reset_seeker: func {
        me.weapon.setAutoUncage(FALSE);
        me.weapon.setCaged(TRUE);
        me.weapon.setSlave(TRUE);
    },

    # IR seeker manipulation
    uncage_IR_seeker: func {
        if (variant.JA or me.weapon == nil or me.weapon.status != armament.MISSILE_LOCK
            or (me.weapon.type != "RB-24J" and me.weapon.type != "RB-74")) return;
        me._uncage_seeker();
    },

    reset_IR_seeker: func {
        if (variant.JA or me.weapon == nil
            or (me.weapon.type != "RB-24J" and me.weapon.type != "RB-74")) return;
        me._reset_seeker();
        # 0.8 deg down, except for outer pylons (AJS SFI part 3);
        if (me.selected == STATIONS.R7V or me.selected == STATIONS.R7H) {
            me.weapon.commandDir(0,0);
        } else {
            me.weapon.commandDir(0,-0.8);
        }
    },

    seeker_loop: func {
        if (!me.weapon_ready()) {
            me.seeker_timer.stop();
            return;
        }

        # For JA IR, switch between bore sight and radar command automatically.
        # Note: not using 'setBore()' for bore sight. Instead keeping 'setSlave()'
        # and using 'commandDir()' to allow to adjust bore position, if we want to.
        if (me.is_IR and variant.JA and me.weapon.isCaged()) {
            if (radar_logic.selection == nil or TI.ti.rb74_force_bore) {
                # 0.8 deg down is from AJS
                if (me.weapon.command_tgt) me.weapon.commandDir(0,-0.8);
            } else {
                if (!me.weapon.command_tgt) me.weapon.commandRadar();
            }
        }

        # Update list of contacts on which to lock on.
        # For IR/Rb 75, don't do anything if the missile has already locked. It would mess with the lock.
        if ((!me.is_IR and !me.is_rb75) or me.weapon.status != armament.MISSILE_LOCK) {
            # IR missiles and Rb 75 can lock without radar command.
            if ((me.is_IR or me.is_rb75) and (!me.weapon.isCaged() or !me.weapon.command_tgt)) {
                # Send list of all contacts to allow searching.
                me.weapon.setContacts(radar_logic.complete_list);
                armament.contact = nil;
            } else {
                # Slave onto radar target.
                me.weapon.setContacts([]);
                armament.contact = radar_logic.selection;
            }
        }

        # Log lock event
        if (me.is_IR and variant.JA) {
            if (me.weapon.status == armament.MISSILE_LOCK) {
                if (me.last_IR_lock != me.weapon.callsign) {
                    radar_logic.lockLog.push(sprintf("IR lock on to %s (%s)", me.weapon.callsign, me.weapon.type));
                    me.last_IR_lock = me.weapon.callsign;
                }
            } else {
                me.last_IR_lock = nil;
            }
        }
    },

    rb75_loop: func {
        if (!me.weapon_ready()) {
            me.rb75_timer.stop();
            return;
        }

        # Turn seeker on.
        var seeker_on = (firing_enabled() and (me.armed() or modes.selector_ajs == modes.COMBAT));
        if (seeker_on and !me.rb75_last_seeker_on) {
            # Seeker just turned on, initialise
            displays.common.resetCursorDelta();
            me.rb75_lock = FALSE;
            me.rb75_pos_x = 0;
            me.rb75_pos_y = -1.3; # 1.3deg down initially (manual).
            me.weapon.commandDir(me.rb75_pos_x, me.rb75_pos_y);
        }
        me.rb75_last_seeker_on = seeker_on;
        # Property for EP-13 (Rb75 screen) visual effect
        input.ep13.setBoolValue(seeker_on);

        # Cursor control
        var cursor = displays.common.getCursorDelta();
        displays.common.resetCursorDelta();

        if (cursor[2] and !me.last_click) {
            # Clicked
            if (me.rb75_lock) {
                # Unlock and reset position
                me.rb75_lock = FALSE;
                me.rb75_pos_x = 0;
                me.rb75_pos_y = -1.3; # 1.3deg down initially (manual).
                me._reset_seeker();
                me.weapon.commandDir(me.rb75_pos_x, me.rb75_pos_y);
            } elsif (me.weapon.status == armament.MISSILE_LOCK) {
                # Lock
                me.rb75_lock = TRUE;
                me._uncage_seeker();
            }
        }
        if (!me.rb75_lock) {
            # Slew cursor
            me.rb75_pos_x = math.clamp(me.rb75_pos_x + cursor[0]*5, -15, 15);
            me.rb75_pos_y = math.clamp(me.rb75_pos_y - cursor[1]*5, -15, 15);
            me.weapon.commandDir(me.rb75_pos_x, me.rb75_pos_y);
        }
        me.last_click = cursor[2];
    },

    rb75_can_fire: func {
        if (!me.rb75_lock) return FALSE;
        var seeker_pos = me.weapon.getSeekerInfo();
        return seeker_pos != nil
            and seeker_pos[0] >= -15 and seeker_pos[0] <= 15
            and seeker_pos[1] >= -15 and seeker_pos[1] <= 15;
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
    parents: [Missile.new(type:"RB-05A", cycling:0, can_start_right:1)],

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

        fireLog.push("Self: "~me.weapon.brevity);

        me.station.fireWeapon(0, radar_logic.complete_list);

        me.weapon = nil;
        me.fired = TRUE;
    },
};


### Generic submodel based weapon (gun, rockets).
# Expect the underlying weapon to be an instance of stations.SubModelWeapon.
var SubModelWeapon = {
    parents: [WeaponLogic],

    new: func(type, multi_types=nil, ammo_factor=1) {
        var w = { parents: [SubModelWeapon, WeaponLogic.new(type, multi_types)], };
        w.selected = [];
        w.stations = [];
        w.weapons = [];

        w.firing = FALSE;
        w.is_ARAK = (type == "M70");

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

        me.selected = pylons.find_all_pylons_by_types(me.types);
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

        return TRUE;
    },

    deselect: func (pylon=nil) {
        me.set_unsafe(FALSE);
        me.selected = [];
        me.stations = [];
        me.weapons = [];
    },

    cycle_selection: func {},

    set_unsafe: func(unsafe) {
        # Call parent method
        call(WeaponLogic.set_unsafe, [unsafe], me);

        var trigger_prop = input.trigger;

        if (me.is_ARAK) {
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

        if (me.is_ARAK) {
            # For rockets, set the trigger ON as required, but do not set it OFF, so that all rockets get fired.
            if (trigger) {
                input.trigger_m70.setBoolValue(TRUE);
                me.firing = TRUE;
            }
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

    new: func(type, multi_types) {
        var w = { parents: [Bomb, WeaponLogic.new(type, multi_types)], };
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
        w.drop_bomb_timer.simulatedTime = TRUE;
        w.drop_bomb_timer.singleShot = FALSE;

        w.firing = FALSE;

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
        return pylons.is_loaded_with(pos[0], me.types)
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
        me.firing = TRUE;
        me.drop_next_bomb();
        me.drop_bomb_timer.restart(me.release_interval(me.release_distance));
    },

    stop_drop_sequence: func {
        me.firing = FALSE;
        me.drop_bomb_timer.stop();
    },

    set_unsafe: func(unsafe) {
        # Call parent method
        call(WeaponLogic.set_unsafe, [unsafe], me);

        if (!me.unsafe) {
            # 'FALLD LAST' off when securing the trigger.
            input.release.setBoolValue(FALSE);
            me.firing = FALSE;
        }
    },

    set_trigger: func(trigger) {
        if (!me.armed() or !me.weapon_ready()) trigger = FALSE;

        if (trigger) {
            fireLog.push("Self: "~me.next_weapon.brevity);
            me.start_drop_sequence();
        } else {
            me.stop_drop_sequence();
        }
    },

    weapon_ready: func {
        return me.next_weapon != nil;
    },

    is_firing: func {
        return me.firing;
    },

    # Return the active weapon (object from missile.nas), when it makes sense.
    get_weapon: func {
        return me.next_weapon;
    },

    get_selected_pylons: func {
        return [];
    },
};


#### Weapons selection

### Selected weapon access functions.
var selected = nil;

var get_type = func {
    if (selected == nil) return nil;
    else return selected.type;
}

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

var weapon_ready = func {
    if (selected == nil) return FALSE;
    else return selected.weapon_ready();
}

var is_armed = func {
    if (selected == nil) return FALSE;
    else return selected.armed();
}

var is_firing = func {
    if (selected == nil) return FALSE;
    else return selected.is_firing();
}

### Selection functions

if (variant.JA) {
    ### JA weapon selection.

    # List of weapon types.
    var weapons = [
        SubModelWeapon.new(type:"M75", ammo_factor:22), # get_ammo gives firing time
        Missile.new(type:"RB-74", fire_delay:0.7),
        Missile.new(type:"RB-99", fire_delay:0.7),
        Missile.new(type:"RB-71", fire_delay:0.7),
        Missile.new(type:"RB-24J", fire_delay:0.7),
        SubModelWeapon.new(type:"M70", ammo_factor:6),  # get_ammo gives number of pods
    ];

    # Set of indices considered for quick_select_missile() (A/A missiles)
    var quick_select = {1:1, 2:1, 3:1, 4:1,};

    var internal_gun = weapons[0];

    ## Functions to cycle through weapon list.
    var selected_index = -1;

    # Internal selection function.
    var _set_selected_index = func(index) {
        selected_index = index;
        if (index >= 0) selected = weapons[index];
        else selected = nil;
    }

    var _deselect_current = func {
        if (selected != nil) selected.deselect();
    }

    # Select next weapon type in the list.
    #
    # If the argument 'subset' is given, only weapons whose index is in 'subset' are considered.
    var cycle_weapon_type = func(subset=nil) {
        if (!firing_computer_on()) return;

        _deselect_current();

        # Cycle through weapons, starting from the previous one.
        var prev = selected_index;
        if (prev < 0) prev = size(weapons)-1;
        var i = prev;
        i += 1;
        if (i >= size(weapons)) i = 0;

        while (i != prev) {
            if ((subset == nil or contains(subset, i)) and weapons[i].select()) {
                _set_selected_index(i);
                if (!variant.JA) ja37.notice("Selected "~selected.type);
                return
            }
            i += 1;
            if (i >= size(weapons)) i = 0;
        }
        # We are back to the first weapon. Last try
        if ((subset == nil or contains(subset, i)) and weapons[i].select()) {
            _set_selected_index(i);
            if (!variant.JA) ja37.notice("Selected "~selected.type);
        } else {
            # Nothing found
            _set_selected_index(-1);
            if (!variant.JA) ja37.notice("No weapon selected");
        }
    }

    # For TI button
    var select_cannon = func {
        if (!firing_computer_on()) return;

        _deselect_current();
        if(internal_gun.select()) {
            _set_selected_index(0);
        } else {
            _set_selected_index(-1);
        }
    }

    # Throttle quick select buttons. Automatically engage aiming mode.
    var quick_select_cannon = func {
        if (!firing_computer_on()) return;

        # Switch to A/A aiming mode
        modes.set_aiming_mode(TRUE);
        TI.ti.ModeAttack = FALSE;
        select_cannon();
    }

    var quick_select_missile = func {
        if (!firing_computer_on()) return;

        # Switch to A/A aiming mode
        modes.set_aiming_mode(TRUE);
        TI.ti.ModeAttack = FALSE;
        cycle_weapon_type(quick_select);
    }

    # Direct pylon selection through JA TI.
    var select_pylon = func(pylon) {
        if (!firing_computer_on()) return;

        _deselect_current();

        var type = pylons.get_pylon_load(pylon);
        forindex(var i; weapons) {
            # Find matching weapon type.
            if (weapons[i].type == type) {
                # Attempt to load this pylon.
                if (weapons[i].select(pylon)) {
                    _set_selected_index(i);
                } else {
                    _set_selected_index(-1);
                }
                return;
            }
        }
    }

    var deselect_weapon = func {
        _deselect_current();
        _set_selected_index(-1);
    }

} else {
    ### AJS weapon selection

    var weapons = {
        ir_rb: Missile.new(type:"IR-RB", multi_types: ["RB-24", "RB-24J", "RB-74"], fire_delay:0.7),
        akan: SubModelWeapon.new("M55"),
        arak: SubModelWeapon.new(type:"M70"),
        rb04: Missile.new(type:"RB-04E", falld_last:1, fire_delay:1, at_everything:1, no_lock:1, cycling:0),
        rb15: Missile.new(type:"RB-15F", falld_last:1, at_everything:1, no_lock:1, can_start_right:1),
        m90: Missile.new(type:"M90", at_everything:1, no_lock:1, can_start_right:1),
        rb05: Rb05,
        rb75: Missile.new(type:"RB-75", fire_delay:1, can_start_right:1),
        bomb: Bomb.new(type:"M71", multi_types: ["M71", "M71R"]),
    };

    # Weapon panel selector knob positions.
    # (not the same as ground_panel.WPN_SEL, for the ground crew panel selector knob).
    var WPN_SEL = {
        IR_RB: 0,
        ATTACK: 1,
        AKAN_JAKT: 2,
        RR_LUFT: 3,
        DYK_MARK_RB75: 4,
        PLAN_SJO: 5,
    };

    # Select weapon according to weapon selection knob.
    var update_selected_weapon = func {
        if (!firing_computer_on()) return;

        # Cleanup previous
        if (selected != nil) {
            selected.deselect();
            selected = nil;
        }

        # Invalid loadout, just give up.
        if (!loaded_weapons_valid) return;

        # Select weapon type
        var gnd_knob = input.gnd_wpn_knob.getValue();
        var gnd_switch = input.gnd_wpn_switch.getValue();
        var wpn_knob = input.wpn_knob.getValue();

        if (wpn_knob == WPN_SEL.IR_RB) {
            selected = weapons.ir_rb;
        } elsif (wpn_knob == WPN_SEL.ATTACK) {
            if (gnd_knob == ground_panel.WPN_SEL.AKAN or gnd_knob == ground_panel.WPN_SEL.AK_05) {
                selected = weapons.akan;
            } elsif (gnd_knob == ground_panel.WPN_SEL.ARAK) {
                selected = weapons.arak;
            } elsif (gnd_knob == ground_panel.WPN_SEL.RB04) {
                if (!gnd_switch) selected = weapons.rb04;
                elsif (has_rb15) selected = weapons.rb15;
                elsif (has_m90) selected = weapons.m90;
            }
        } elsif (wpn_knob == WPN_SEL.AKAN_JAKT) {
            if (gnd_knob == ground_panel.WPN_SEL.AKAN or gnd_knob == ground_panel.WPN_SEL.AK_05) {
                selected = weapons.akan;
            }
        } elsif (wpn_knob == WPN_SEL.RR_LUFT or wpn_knob == WPN_SEL.DYK_MARK_RB75 or wpn_knob == WPN_SEL.PLAN_SJO) {
            if (gnd_knob == ground_panel.WPN_SEL.BOMB) {
                selected = weapons.bomb;
            } elsif (gnd_knob == ground_panel.WPN_SEL.AK_05 or gnd_knob == ground_panel.WPN_SEL.RB05) {
                if (!gnd_switch) selected = weapons.rb05;
                elsif (wpn_knob == WPN_SEL.DYK_MARK_RB75) selected = weapons.rb75;
            }
        }

        # If a weapon type was selected by the previous logic, try to select a weapon of this type.
        if (selected != nil) {
            selected.select();
        }
    }

    # Toggle back and forth between IR-RB and the weapon knob selection.
    var quick_select_missile = func {
        if (!firing_computer_on()) return;

        if (input.wpn_knob.getValue() == WPN_SEL.IR_RB) return; # Nothing to do here

        if (selected != nil and selected.type == "IR-RB") {
            # Back to knob selection
            update_selected_weapon();
        } else {
            # Switch to IR-RB
            if (selected != nil) selected.deselect();
            selected = weapons.ir_rb;
            selected.select();
        }
    }
}



### Other controls.

# Next pylon of same type (left wall button)
var cycle_pylon = func {
    if (selected != nil) selected.cycle_selection();
}

# IR seeker release button, AJS only
var uncageIR = func {
    if (selected != nil and selected.type == "IR-RB") {
        selected.uncage_IR_seeker();
    }
}

var resetIR = func {
    if (selected != nil and selected.type == "IR-RB") {
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

# Small window to display 'trigger unsafe' message.
var safety_window = screen.window.new(x:nil, y:-15, maxlines:1, autoscroll:0);

var safety_window_clear_timer = maketimer(3, func { safety_window.clear(); });
safety_window_clear_timer.singleShot = TRUE;

var unsafe_listener = func (node) {
    var unsafe = node.getBoolValue();
    if (selected != nil) selected.set_unsafe(unsafe);

    # Reminder message
    if (unsafe) {
        safety_window.write("Trigger unsafe", 1, 0, 0);
        safety_window_clear_timer.stop();
    } else {
        safety_window.write("Trigger safe", 0, 0, 1);
        safety_window_clear_timer.start();
    }
}



#### Fire control inhibit.

if (variant.AJS) {
    ## AJS firing computer weapons check.
    #
    # Check that only weapons allowed by the ground crew weapon panel settings are loaded.
    # Otherwise, firing controls are disabled.

    # Table of allowed weapons, indexed by [weapon selection knob pos, weapon selection switch pos]
    #
    # In the definition each entry is an array of allowed weapons.
    # Each entry is then converted to a hash whose keys are the allowed weapons, for ease of use.
    # IR missiles are omitted in this table, and are added later.
    var allowed_weapons = [
        # IR_RB
        [[], []],
        # AKAN
        [["M55"], ["M55"]],
        # AKAN / RB 05 / RB 75
        [["M55", "RB-05A"], ["M55", "RB-75"]],
        # RB 05 / RB 75
        [["RB-05A"], ["RB-75"]],
        # LYSB
        [[], []],
        # BOMB
        # Allow both low and high drag, disregarding switch position.
        # I do not think the computer can distinguish the two types.
        [["M71", "M71R"], ["M71", "M71R"]],
        # RB 04
        # RB 15 and m/90 can not be combined. This check is implemented separately.
        [["RB-04E"], ["RB-15F", "M90"]],
        # ARAK
        [["M70"], ["M70"]],
    ];

    var IR_RB = ["RB-24", "RB-24J", "RB-74"];

    forindex (var i; allowed_weapons) {
        forindex (var j; allowed_weapons[i]) {
            # Convert array of values to hash
            var arr = allowed_weapons[i][j];
            var hash = {};
            foreach (var weapon; arr) hash[weapon] = TRUE;
            # Add IR missiles
            foreach (var weapon; IR_RB) hash[weapon] = TRUE;
            allowed_weapons[i][j] = hash;
        }
    }

    # Flags indicating if a rb15 / m90 is loaded.
    # (they use the same ground panel and weapon panel settings, so this is used to know which one to select).
    # If the loadout / ground panel settings
    var has_rb15 = FALSE;
    var has_m90 = FALSE;

    var check_loaded_weapons = func {
        var allowed = allowed_weapons[input.gnd_wpn_knob.getValue()][input.gnd_wpn_switch.getValue()];

        # Reset flags
        has_rb15 = FALSE;
        has_m90 = FALSE;

        foreach (var pylon; keys(STATIONS)) {
            var type = pylons.get_pylon_load(STATIONS[pylon]);
            if (type == "") continue; # no load
            if (!contains(allowed, type)) return FALSE;

            if (type == "RB-15F") {
                if (has_m90) return FALSE;
                else has_rb15 = TRUE;
            } elsif (type == "M90") {
                if (has_rb15) return FALSE;
                else has_m90 = TRUE;
            }
        }

        return TRUE;
    };

    # Store result of weapons check.
    var loaded_weapons_valid = TRUE;

    # Call this whenever the result of check_loaded_weapons() might change.
    var loaded_weapons_check_callback = func {
        loaded_weapons_valid = check_loaded_weapons();
        inhibit_callback();
    }
}


## Fire control inhibit test function.
var firing_enabled = func {
    return firing_computer_on()
        and input.gear_pos.getValue() == 0
        and power.prop.acSecondBool.getBoolValue()
        and (!variant.AJS or loaded_weapons_valid);
}

# Call this whenever the result of firing_enabled() might change.
var inhibit_callback = func {
    # Disarm weapon if fire controls are inhibited.
    if (selected != nil and selected.armed() and !firing_enabled()) selected.set_unsafe(FALSE);
}



### Listeners

# Reload callback for station-manager.nas
var ReloadCallback = {
    updateAll: func {
        if (variant.JA) {
            # JA: reset logic, deselect all
            deselect_weapon();
        } else {
            # AJS: check loaded weapons, update selected weapon
            loaded_weapons_check_callback();
            update_selected_weapon();
        }
    },

    init: func {
        foreach(var station; pylons.stations_list) {
            pylons.station_by_id(station).setPylonListener(me);
        }
    },
};


var init = func {
    ReloadCallback.init();

    setlistener(input.trigger, trigger_listener, 0, 0);
    setlistener(input.unsafe, unsafe_listener, 0, 0);


    # Deselect any weapon if power turns off.
    setlistener(power.prop.acMainBool, func (n) {
        if (!n.getBoolValue()) {
            if (variant.JA) {
                deselect_weapon();
            } else {
                if (selected != nil) {
                    selected.deselect();
                    selected = nil;
                }
            }
        }
    }, 0, 0);

    if (variant.AJS) {
        # Check loaded weapons when changing ground crew weapon panel settings, and at power on.
        setlistener(input.gnd_wpn_knob, loaded_weapons_check_callback, 0, 0);
        setlistener(input.gnd_wpn_switch, loaded_weapons_check_callback, 0, 0);
        setlistener(power.prop.acMainBool, func (n) {
            if (n.getBoolValue()) loaded_weapons_check_callback();
        }, 0, 0);

        # Update selected weapon (from AJS manual part 1 chap 25 sec 1.2.3)
        # - power on in mode BER
        setlistener(power.prop.acMainBool, func (n) {
            if (n.getBoolValue() and modes.selector_ajs == modes.STBY) update_selected_weapon();
        }, 0, 0);
        # - when changing ground crew panel settings
        setlistener(input.gnd_wpn_knob, update_selected_weapon, 0, 0);
        setlistener(input.gnd_wpn_switch, update_selected_weapon, 0, 0);
        # - when touching the weapon selection knob
        setlistener(input.wpn_knob, update_selected_weapon, 0, 0);
        # - at rotation
        setlistener(input.nose_WOW, func (n) {
            if (!n.getBoolValue()) update_selected_weapon();
        }, 0, 0);
    }

    # Landing gear pos and AC power secondary bus: update inhibit.
    setlistener(input.gear_pos, inhibit_callback, 0, 0);
    setlistener(power.prop.acSecond, inhibit_callback, 0, 0);
};
