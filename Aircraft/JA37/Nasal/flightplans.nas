var TYPE_MIX  = 0;# plan has both mission and RTB
var TYPE_RTB  = 1;# return to base plan
var TYPE_MISS = 2;# mission plan
var TYPE_AREA = 3;# polygon area

var COLOR_GREY_LIGHT = [0.70,0.70,0.70];

var TRUE  = 1;
var FALSE = 0;

var maxArea = 8;# max number of polygon areas
var maxSteers = 48;# max number of steers in each plan

var debugAll = FALSE;

setprop("sim/fg-home-export", getprop("sim/fg-home")~"/export");

var printDA = func (str) {
    if (debugAll) print (str);
}

var Polygon = {
	#
	# Class methods and variables
	#
	primary: nil,#its used in routemanager
	editing: nil,#its set for being edited
	editRTB: nil,#when edit RTB is triggered this is the plan to be edited
	editMiss: nil,#when edit mission is triggered this is the plan to be edited
	polys: {},# contains the plans
	_activating: FALSE,# in progress of a plan being set into route-manager
	flyRTB: nil,#when fly RTB is triggered this is the plan to be flown
	flyMiss: nil,#when fly RTB is triggered this is the plan to be flown
	editSteer: FALSE,  # selectSteer is currently being dragged
	dragSteer: FALSE,  # TI237 is in drag steer mode
	appendSteer: FALSE,# set for append
	insertSteer: FALSE,# selectSteer set for having something inserted
	selectSteer: nil,# content: [leg ghost, index]
	selectL: nil,# when selectSteer is non nil, this will be listener for route-manager edit of plan. Such edit will cancel all editing. Hackish.
	editDetail: FALSE,# selectSteer ready for having an attribute edited
	_apply: FALSE,# when an edit is being applied this is set to true. When route-manager edit something editing will stop unless its in apply phase.
	_doingBases: FALSE,# currently setting properties for dest/dep.
	jumpToSteer: nil,#used by TI for selecting steerpoint in active plan.
	editBullsEye: FALSE,# bullseye being edited
	landBase: [nil,nil,nil,nil],# ghost-airport
	#polyEdit: FALSE,

	setupJAPolygons: func {
		#class:
		# setup 4 mission and 2 RTB plans. Plus 6 polygon areas.
		#
		me.multi = getprop("ja37/supported/multiple-flightplans");
		if (me.multi == TRUE) {
			var poly1 = Polygon.new("1", "", TYPE_MISS, getprop("xmlPlans/mission1"), FALSE);
			Polygon.polys["1"] = poly1;
			for (var i = 2; i<=4; i+=1) {
				var poly = Polygon.new(""~i, "", TYPE_MISS, getprop("xmlPlans/mission"~i));
				Polygon.polys[""~i] = poly;
			}
			for (var i = 1; i<=4; i+=1) {
				var polyA = Polygon.new(""~i, "A", TYPE_RTB, getprop("xmlPlans/rtb"~i~"A"));
				Polygon.polys[polyA.getName()]   = polyA;

				var polyB = Polygon.new(""~i, "B", TYPE_RTB, getprop("xmlPlans/rtb"~i~"B"));
				Polygon.polys[polyB.getName()]   = polyB;
			}
			for (var i = 1; i<=6; i+=1) {
				var poly = Polygon.new("OP"~i, "", TYPE_AREA, getprop("xmlPlans/area"~i));
				Polygon.polys["OP"~i] = poly;
			}
		
			Polygon.editRTB      = Polygon.polys["1A"];
			Polygon.editMiss     = poly1;
			Polygon.flyRTB       = Polygon.polys["1A"];
			Polygon.flyMiss      = poly1;
			poly1.setAsPrimary();
			
			#now set current pos as start base:
            #var apts = findAirportsWithinRange(25.0);
            #if (size(apts)) {
            #	Polygon.takeoffBase = apts[0];
            #   	Polygon.setTakeoff();
            #}
		} else {
			var poly1 = Polygon.new("1", "", TYPE_MIX, nil, TRUE);
			Polygon.primary      = poly1;
			Polygon.flyRTB       = poly1;
			Polygon.flyMiss      = poly1;
			Polygon.editRTB      = poly1;
			Polygon.editMiss     = poly1;
		}
		Polygon._setupListeners();
		var dlg = gui.Dialog.new("/sim/gui/dialogs/route-manager/dialog", "Aircraft/JA37/gui/dialogs/route-manager.xml", "route-manager");
		printDA("JA: finished plan Init");
	},
	
	setTakeoff: func () {
		#class:
		# Set destination on mission plans [deprecated]
		#
		Polygon._doingBases = TRUE;
		var base = Polygon.takeoffBase;
		var icao = (base==nil)?"":base.id;
		
		setprop("autopilot/plan-manager/departure/airport", icao);

		Polygon.editStop();
		Polygon._apply = TRUE;
		if (Polygon.polys["1"].plan.departure == nil or Polygon.polys["1"].plan.departure.id != icao) {
			Polygon.polys["1"].plan.departure = base;
		}
		if (Polygon.polys["2"].plan.departure == nil or Polygon.polys["2"].plan.departure.id != icao) {
			Polygon.polys["2"].plan.departure = base;
		}
		if (Polygon.polys["3"].plan.departure == nil or Polygon.polys["3"].plan.departure.id != icao) {
			Polygon.polys["3"].plan.departure = base;
		}
		if (Polygon.polys["4"].plan.departure == nil or Polygon.polys["4"].plan.departure.id != icao) {
			Polygon.polys["4"].plan.departure = base;
		}
		Polygon._apply = FALSE;
		Polygon._doingBases = FALSE;
	},
	
	setLand: func (name) {
		#class:
		# Set destination on plan
		#
		Polygon._doingBases = TRUE;
		var number = num(left(name,1));
		var base = Polygon.landBase[number-1];
		var icao = (base==nil)?"":base.id;
		
		setprop("autopilot/plan-manager/destination/airport-"~number, icao);
		#print("setland setting "~icao~" on property "~number);
		
		if (Polygon.polys[name].plan.destination == nil or Polygon.polys[name].plan.destination.id != icao) {
			Polygon.editStop();
			Polygon._apply = TRUE;
			Polygon.polys[name].plan.destination = base;
			Polygon._apply = FALSE;
		}
		Polygon._doingBases = FALSE;
	},
		
	_takeoffTest: func {
		#class:
		# Start base was requested from dialog. [deprecated]
		#
		if (!Polygon._doingBases) {
			var icao = getprop("autopilot/plan-manager/departure/airport");
			if (icao != nil and size(icao)>1) {
				var result = airportinfo(icao);
			} else {
				var result = nil;
			}
			if (result!=nil) {
				Polygon.takeoffBase = result;
			} else {
				Polygon.takeoffBase = nil;
			}
			Polygon.setTakeoff();
		}
	},
	
	_landTest: func (number) {
		#class:
		# Landing base was requested from dialog.
		#
		if (!Polygon._doingBases) {
			var icao = getprop("autopilot/plan-manager/destination/airport-"~number);
			if (icao != nil and size(icao)>1) {
				var result = airportinfo(icao);
			} else {
				var result = nil;
			}
			if (result!=nil) {
				Polygon.landBase[number-1] = result;
				#print("_landtest setting "~icao~" on landbase "~number);
			} else {
				Polygon.landBase[number-1] = nil;
			}
			Polygon.setLand(number~"A");
			Polygon.setLand(number~"B");
		}
	},
	
	save: func (pln, file) {
		#class:
		# Save a plan to disc.
		#
		var success = 1;
		call(func { success = Polygon.polys[pln].plan.save(file);}, nil, var err = []);
		if (size(err) or !success) {
			print("saving failed.");
			gui.showDialog("savefail");
		}
	},
	
	load: func (pln, file, clear=0) {
		#class:
		# Load a plan from disc.
		#
		var newPlan = nil;
print("load "~pln~" clear "~clear~" file "~file);
		call(func {newPlan = createFlightplan(file);}, nil, var err = []);
		if (size(err) or newPlan == nil) {
			print(err[0]);
			print("Load failed.");
			if(clear) {
				# loading failed, we clear the plan.
				Polygon.editStop();
				Polygon.polys[pln].plan = createFlightplan();
				Polygon.polys[pln].plan.id = pln;
				if (Polygon.polys[pln].type == TYPE_RTB) {
					Polygon.setLand(pln);
				}
				if (Polygon.polys[pln].isPrimary()) {
					Polygon._activating = TRUE;
					Polygon.polys[pln].plan.activate();
					Polygon._activating = FALSE;
				}
			}
		} else {
			Polygon.editStop();
			Polygon.polys[pln].plan = newPlan;
print("newPlan set on a "~Polygon.polys[pln].type);
			if (Polygon.polys[pln].type == TYPE_RTB) {
				Polygon.setLand(pln);
			}
			newPlan.id = pln;
			#Polygon._setDestDep(Polygon.polys[pln]);# gpx does not have destination support, so we check if its likely to be an airport and set it
			if (Polygon.polys[pln].isPrimary()) {
				Polygon._activating = TRUE;
				Polygon.polys[pln].plan.activate();
				Polygon._activating = FALSE;
			}
			#if (size(pln)==2 and num(string.left(pln,2)==1)) {
			#	if (Polygon.polys[pln].plan.destination != nil) {
			#		Polygon.landBase[1] = Polygon.polys[pln].plan.destination;
			#	}
			#	Polygon.setLand("1A");
			#	Polygon.setLand("1B");
			#} els
		}
	},

	setupAJPolygons: func {
		#class:
		# setup 1 plan.
		#
		Polygon._setupListeners();
		var poly1 = Polygon.new("1", "", TYPE_MIX, nil, TRUE);
		Polygon.primary      = poly1;
		Polygon.flyRTB       = poly1;
		Polygon.flyMiss      = poly1;
		Polygon.editRTB      = poly1;
		Polygon.editMiss     = poly1;
		printDA("AJ: finished plan Init");
	},

	loadAll: func (path) {
		#class:
		# load all data in a folder
		#
		Polygon.landBase = [nil,nil,nil,nil];
		#Polygon.setLandA();
		#Polygon.setLandB();
		# no need to clear the starting base
		
		dap.loadPoints(path~"/ja37-data.ck37",1);#load first since it has landing bases (TODO:notice these will trigger setting dest on alot of old routes..hmmm)
		var key = keys(Polygon.polys);
		foreach (k; key) {
			call(func{Polygon.load(k,path~"/ja37-data-"~k~".fgfp",1);},nil,var err=[]);
		}
	},
	
	saveAll: func (path) {
		#class:
		# save all data in a folder
		#
		#var path = os.path.new(path);
		#call(func{path.create_dir();},nil,var err=[]);
		#if (size(err)) {
		#	print("saving all failed.");
		#	gui.showDialog("savefail");
		#}
		var key = keys(Polygon.polys);
		var s = dap.savePoints(path~"/ja37-data.ck37");
		if (s) {
			foreach (k; key) {
				var poly = Polygon.polys[k];
				call(func{poly.plan.save(path~"/ja37-data-"~k~".fgfp");},nil,var err=[]);
			}
		}
	},
	
	basePress: func {
		#class:
		# called from nav panel, another landing base was selected
		var newBase = getprop("autopilot/plan-manager/landing-base");
		Polygon.editStop();
		#var letterFly = Polygon.flyRTB.getNameVariant();
		#var letterEdit = Polygon.editRTB.getNameVariant();
		var primary = Polygon.flyRTB == Polygon.primary;
		var active  = Polygon.isPrimaryActive();
		Polygon.flyRTB = Polygon.polys[newBase~"A"];
		Polygon.editRTB = Polygon.polys[newBase~"A"];
		if (primary) {
			Polygon.flyRTB.setAsPrimary();
			if (active) {
				Polygon.startPrimary();
			}
		}
	},
	
	toggleEditRTB: func {
		#class:
		# called from ti. Switches editroute.
		var letter = Polygon.editRTB.getNameVariant();
		var number = Polygon.editRTB.getNameNumber();
		var letterToo = letter=="A"?"B":"A";
		
		me.replaceEdit = Polygon.editRTB == Polygon.editing;
		Polygon.editRTB = Polygon.polys[number~letterToo];
		if (me.replaceEdit == TRUE) {
			Polygon.editPlan(Polygon.editRTB);
		}
	},
	
	toggleFlyRTB: func {
		#class:
		# called from ti. Switches flyroute.
		me.activateAlso = FALSE;
		me.startAlso = FALSE;
		if (Polygon.flyRTB.isPrimary() == TRUE) {
			me.activateAlso = TRUE;
			if (Polygon.isPrimaryActive() == TRUE) {
				me.startAlso = TRUE;
			}
		}
		var letter = Polygon.flyRTB.getNameVariant();
		var number = Polygon.flyRTB.getNameNumber();
		var letterToo = letter=="A"?"B":"A";
		
		Polygon.flyRTB = Polygon.polys[number~letterToo];
		
		if (me.activateAlso == TRUE) {
			Polygon.flyRTB.setAsPrimary();
			if (me.startAlso == TRUE) {
				Polygon.startPrimary();
			}
		}
	},
	
	deletePlan: func {
		#class:
		# Called from DAP. Clear a plan. Will only happen if the plan is being set for edit.
		#
		if (Polygon.editing != nil) {
			printDA("deleting plan");
			Polygon.selectSteer = nil;
			Polygon.appendSteer = FALSE;
			Polygon.insertSteer = FALSE;
			Polygon.editSteer   = FALSE;
			Polygon.editDetail  = FALSE;
			Polygon.dragSteer = FALSE;
			Polygon.editing.plan = createFlightplan();
			Polygon.editing.plan.id = Polygon.editing.getName();
			if(Polygon.editing.isPrimary()) {
				Polygon._activating = TRUE;
				Polygon.editing.plan.activate();
				Polygon._activating = FALSE;
			}
			#Polygon.polyEdit = FALSE;
			#dap.set237(FALSE);
		}
	},

	selectSteerpoint: func (planName, leg, index) {
		#class:
		# Set a steerpoint as selected.
		#
		#me.editIndex = Polygon.editing.plan.indexOfWP(leg); TODO: in 2 years time from now, start using this, as noone will be using old FG 2017.2.1 anymore.
		#printf("%s %s %d",planName, leg.id, me.editIndex);
		if (planName == Polygon.editing.getName()) {#} and me.editIndex != nil and me.editIndex != -1) {
			Polygon.selectSteer = [leg, index, Polygon.isDraggable(leg, Polygon.editing)];
			printDA("select");
			if (me.selectL != nil) {
				removelistener(me.selectL);
			}
			me.selectL = setlistener("autopilot/route-manager/signals/edited", func {Polygon._planEdited()});
		}
	},

	jumpTo: func (leg, index) {
		#class:
		# prepare to select another steerpoint in primary plan
		#
		Polygon.jumpToSteer = [leg, index];
	},
	
	jumpExecute: func {
		#class:
		# Execute the jump.
		#
		if (Polygon.jumpToSteer != nil) {
			if (Polygon.primary != nil and Polygon.primary.getSize() > Polygon.jumpToSteer[1]) {
				Polygon.primary.plan.current = Polygon.jumpToSteer[1];
			} else {
				print("error in jump");
			}
			Polygon.jumpToSteer = nil;
		}
	},

	editSteerpoint: func () {
		#class:
		# Toggle dragging.
		#
		if (Polygon.editing != nil and !Polygon.dragSteer) {
			Polygon.dragSteer = TRUE;#we go into draggable mode TODO: put this all over
			Polygon.editDetail = FALSE;
			Polygon.appendSteer = FALSE;
			Polygon.insertSteer = FALSE;
			printDA("toggle edit: "~Polygon.editSteer);
		} else {
			Polygon.dragSteer = FALSE;
		}
		Polygon.editSteer = FALSE;# not currently dragging anything
		return Polygon.dragSteer;
	},
	
	startDragging: func {
		#class:
		# The selected steer is now being dragged if return true.
		if (Polygon.dragSteer and Polygon.editing != nil and Polygon.selectSteer != nil) {
			if (Polygon.selectSteer[2]) {
				Polygon.editSteer = TRUE;
				return 1;
			}
		}
		return 0;
	},
	
	isDraggable: func (leg, poly) {
		#class:
		# test is a steerpoint is draggable
		if (poly.type != TYPE_RTB or (poly.plan.destination == nil or leg.id != poly.plan.destination.id)) {
			return TRUE;
		}
		return FALSE;
	},
	
	editFinish: func {
		#class:
		# Finished dragging a steer.
		#
		Polygon.editSteer = FALSE;
	},

	editApply: func (lati, long) {
		#class:
		# Apply the new coord to the steerpoint being dragged.
		# Is not able to drag destination
		#
		if (Polygon.editSteer and Polygon.dragSteer and Polygon.editing != nil) {
			Polygon._apply = TRUE;
			# TODO: what about name??!
			me.tempSpeed  = Polygon.selectSteer[0].speed_cstr;
			me.tempSpeedT = Polygon.selectSteer[0].speed_cstr_type;
			me.tempAlt    = Polygon.selectSteer[0].alt_cstr;
			me.tempAltT   = Polygon.selectSteer[0].alt_cstr_type;
			me.newName = sprintf("%s%d", Polygon.editing.getName(), (Polygon.selectSteer[1]+rand())*100);
			me.newSteerpoint = createWP({lat:lati,lon:long},me.newName,"pseudo");
			if (Polygon.selectSteer[1] == 0 and Polygon.editing.plan.departure != nil) {
				Polygon.editing.plan.departure = nil;
				#TODO:check if this also sets runway to nil.
				#printDA("edit dep runway is nil:"~(Polygon.editing.plan.departure_runway == nil));
			} elsif (Polygon.selectSteer[1] == Polygon.editing.getSize()-1 and Polygon.editing.plan.destination != nil) {
				Polygon.editing.plan.destination = nil;
				#TODO:check if this also sets runway to nil.
				#printDA("edit dest runway is nil:"~(Polygon.editing.plan.destination_runway == nil));
			} else {
				Polygon.editing.plan.deleteWP(Polygon.selectSteer[1]);
			}
			Polygon.editing.plan.insertWP(me.newSteerpoint, Polygon.selectSteer[1]);
			Polygon.selectSteer = [Polygon.editing.plan.getWP(Polygon.selectSteer[1]), Polygon.selectSteer[1],Polygon.selectSteer[2]];
			if (me.tempAlt != nil and me.tempAltT != nil) {
				Polygon.selectSteer[0].setAltitude(me.tempAlt, me.tempAltT);
			}
			if (me.tempSpeed != nil and me.tempSpeedT != nil) {
				Polygon.selectSteer[0].setSpeed(me.tempSpeed,me.tempSpeedT);
			}
			Polygon._apply = FALSE;
		}
	},

	editDetailMethod: func (value) {
		#class:
		# Set if it should be allowed to edit a detail on selected steerpoint.
		#
		if (Polygon.selectSteer != nil) {
			# do not call editSteerpointStop() here as that can lead to endless loop from TI.
			Polygon.editDetail  = value;
			Polygon.appendSteer = FALSE;
			Polygon.insertSteer = FALSE;
			Polygon.editSteer   = FALSE;
			Polygon.dragSteer   = FALSE;
		} else {
			Polygon.editDetail = FALSE;
		}
	},

	setType: func (value) {
		#class:
		# Called from TI/DAP
		#
		if (Polygon.selectSteer != nil) {
			Polygon.selectSteer[0].fly_type = value==1?"flyOver":"flyBy";
		}
	},

	setLon: func (long) {
		#class:
		# Execute editing of detail: longitude.
		#
		if (Polygon.selectSteer != nil and Polygon.editDetail) {
			Polygon._apply = TRUE;
			# TODO: what about name??!
			me.newName    = sprintf("%s%d", Polygon.editing.getName(), (Polygon.selectSteer[1]+rand())*100);
			me.tempSpeed  = Polygon.selectSteer[0].speed_cstr;
			me.tempSpeedT = Polygon.selectSteer[0].speed_cstr_type;
			me.tempAlt    = Polygon.selectSteer[0].alt_cstr;
			me.tempAltT   = Polygon.selectSteer[0].alt_cstr_type;
			me.newSteerpoint = createWP({lat:Polygon.selectSteer[0].wp_lat,lon:long},me.newName,"pseudo");
			if (Polygon.selectSteer[1] == 0 and Polygon.editing.plan.departure != nil) {
				Polygon.editing.plan.departure = nil;
			} elsif (Polygon.selectSteer[1] == Polygon.editing.getSize()-1 and Polygon.editing.plan.destination != nil) {
				Polygon.editing.plan.destination = nil;
			} else {
				Polygon.editing.plan.deleteWP(Polygon.selectSteer[1]);
			}
			Polygon.editing.plan.insertWP(me.newSteerpoint, Polygon.selectSteer[1]);
			Polygon.selectSteer = [Polygon.editing.plan.getWP(Polygon.selectSteer[1]), Polygon.selectSteer[1],Polygon.selectSteer[2]];
			#Polygon.selectSteer[0].speed_cstr      = me.tempSpeed;
			#Polygon.selectSteer[0].speed_cstr_type = me.tempSpeedT;
			#Polygon.selectSteer[0].alt_cstr        = me.tempAlt;
			#Polygon.selectSteer[0].alt_cstr_type   = me.tempAltT;
			if (me.tempAlt != nil and me.tempAltT != nil) {
				Polygon.selectSteer[0].setAltitude(me.tempAlt, me.tempAltT);
			}
			if (me.tempSpeed != nil and me.tempSpeedT != nil) {
				Polygon.selectSteer[0].setSpeed(me.tempSpeed,me.tempSpeedT);
			}
			Polygon._apply = FALSE;
		}
	},

	setLat: func (lati) {
		#class:
		# Execute editing of detail: latitude.
		#
		if (Polygon.selectSteer != nil and Polygon.editDetail) {
			Polygon._apply = TRUE;
			# TODO: what about name??!
			me.newName    = sprintf("%s%d", Polygon.editing.getName(), (Polygon.selectSteer[1]+rand())*100);
			me.tempSpeed  = Polygon.selectSteer[0].speed_cstr;
			me.tempSpeedT = Polygon.selectSteer[0].speed_cstr_type;
			me.tempAlt    = Polygon.selectSteer[0].alt_cstr;
			me.tempAltT   = Polygon.selectSteer[0].alt_cstr_type;
			me.newSteerpoint = createWP({lat:lati,lon:Polygon.selectSteer[0].wp_lon},me.newName,"pseudo");
			if (Polygon.selectSteer[1] == 0 and Polygon.editing.plan.departure != nil) {
				Polygon.editing.plan.departure = nil;
			} elsif (Polygon.selectSteer[1] == Polygon.editing.getSize()-1 and Polygon.editing.plan.destination != nil) {
				Polygon.editing.plan.destination = nil;
			} else {
				Polygon.editing.plan.deleteWP(Polygon.selectSteer[1]);
			}
			Polygon.editing.plan.insertWP(me.newSteerpoint, Polygon.selectSteer[1]);
			Polygon.selectSteer = [Polygon.editing.plan.getWP(Polygon.selectSteer[1]), Polygon.selectSteer[1],Polygon.selectSteer[2]];
			#Polygon.selectSteer[0].speed_cstr      = me.tempSpeed;
			#Polygon.selectSteer[0].speed_cstr_type = me.tempSpeedT;
			#Polygon.selectSteer[0].alt_cstr        = me.tempAlt;
			#Polygon.selectSteer[0].alt_cstr_type   = me.tempAltT;
			if (me.tempAlt != nil and me.tempAltT != nil) {
				Polygon.selectSteer[0].setAltitude(me.tempAlt, me.tempAltT);
			}
			if (me.tempSpeed != nil and me.tempSpeedT != nil) {
				Polygon.selectSteer[0].setSpeed(me.tempSpeed,me.tempSpeedT);
			}
			Polygon._apply = FALSE;
		}
	},

	setMach: func (mach) {
		#class:
		# Execute editing of detail: mach.
		#
		if (Polygon.selectSteer != nil and Polygon.editDetail) {
			#Polygon.selectSteer[0].speed_cstr_type = "mach";
			#Polygon.selectSteer[0].speed_cstr      = mach;			
			call(func {Polygon.selectSteer[0].setSpeed(mach, "mach")},nil, var err = []);# error in FG 2017.3.1 it seems. Worked in 2017.3.0. Fixed in 2018.1.1
			#print(Polygon.selectSteer[0].speed_cstr_type);
			if (err != nil and size(err) > 0) {
				print("Harmless error M: "~err[0]);
			}
		}
	},

	setAlt: func (alt) {
		#class:
		# Execute editing of detail: altitude.
		#
		if (Polygon.selectSteer != nil and Polygon.editDetail) {
			#Polygon.selectSteer[0].alt_cstr      = alt;
			#Polygon.selectSteer[0].alt_cstr_type = "at";
			call(func {Polygon.selectSteer[0].setAltitude(alt, "at")},nil, var err = []);# error in FG 2017.3.1 it seems. Worked in 2017.3.0. Fixed in 2018.1.1
			if (err != nil and size(err) > 0) {
				print("Harmless error A: "~err[0]);
			}
		}
	},

	deleteSteerpoint: func {
		#class:
		# Delete the selected steerpoint. Can be done even if its not in edit mode.
		# Cannot delete dest(rtb) or dep(miss).
		#
		if (Polygon.selectSteer != nil and Polygon.editDetail == FALSE and !(Polygon.editing.type==TYPE_RTB and Polygon.selectSteer[1] == Polygon.editing.getSize()-1 and Polygon.editing.plan.destination != nil)) {
			Polygon.appendSteer = FALSE;
			Polygon.insertSteer = FALSE;
			Polygon.editSteer   = FALSE;
			Polygon.dragSteer   = FALSE;
			Polygon._apply = TRUE;
			if (Polygon.selectSteer[1] == 0 and Polygon.editing.plan.departure != nil) {
				Polygon.editing.plan.departure = nil;
			} elsif (Polygon.selectSteer[1] == Polygon.editing.getSize()-1 and Polygon.editing.plan.destination != nil) {
				Polygon.editing.plan.destination = nil;
			} else {
				Polygon.editing.plan.deleteWP(Polygon.selectSteer[1]);
			}
			#Polygon._setDestDep(Polygon.editing);
			Polygon.selectSteer = nil;
			Polygon._apply = FALSE;
			printDA("toggle delete. ");
			return TRUE;
		}
		return FALSE;
	},

	insertSteerpoint: func () {
		#class:
		# Prepare to insert a steerpoint before the selected steerpoint.
		#
		if (Polygon.selectSteer != nil and !Polygon.editing.isFull() and Polygon.editDetail == FALSE) {
			Polygon.appendSteer = FALSE;
			Polygon.insertSteer = !Polygon.insertSteer;
			Polygon.editSteer = FALSE;
			Polygon.dragSteer   = FALSE;
			printDA("toggle insert: "~Polygon.insertSteer);
		}
		return Polygon.insertSteer;
	},

	insertApply: func (lati, long) {
		#class:
		# Execute the insert.
		#
		if (Polygon.insertSteer and !Polygon.editing.isFull()) {
			Polygon._apply = TRUE;
			# TODO: what about name??!
			me.newName = sprintf("%s%d", Polygon.editing.getName(), (Polygon.selectSteer[1]+rand())*100);
			me.newSteerpoint = createWP({lat:lati,lon:long},me.newName,"pseudo");
			
			if (Polygon.selectSteer[1] == 0 and Polygon.editing.plan.departure != nil) {
				# replace departure with regular waypoint
				printDA("insert: clear dep");
				me.firstWP = Polygon.editing.plan.getWP(0);
				me.firstWP = createWP({lat: me.firstWP.lat, lon: me.firstWP.lon}, me.firstWP.id, "pseudo");
				me.firstWP.fly_type = "flyBy";
				Polygon.editing.plan.departure = nil;
				printDA("inserting old dep as navaid");
				#me.lastWP.wp_type = "navaid";#will prevent it from being cleared as a star/approach in future.
				Polygon.editing.plan.insertWP(me.firstWP,0);
			}
			Polygon.editing.plan.insertWP(me.newSteerpoint, Polygon.selectSteer[1]);
			Polygon.selectSteer = nil;
			Polygon.insertSteer = !Polygon.insertSteer;
			Polygon._apply = FALSE;
		} else {
			Polygon.insertSteer = FALSE;
		}
	},

	appendSteerpoint: func () {
		#class:
		# Prepare to append a steerpoint to the plan being edited.
		#
		if (Polygon.editing != nil and !Polygon.editing.isFull() and Polygon.editDetail == FALSE and Polygon.editing.canAdd()) {
			Polygon.insertSteer = FALSE;
			Polygon.appendSteer = !Polygon.appendSteer;
			Polygon.editSteer = FALSE;
			Polygon.dragSteer   = FALSE;
			printDA("toggle append: "~Polygon.appendSteer);
		}
		return Polygon.appendSteer;
	},

	appendApply: func (lati, long) {
		#class:
		# Execute the append.
		#
		if (Polygon.appendSteer and !Polygon.editing.isFull()) {
			Polygon._apply = TRUE;
			# TODO: what about name??!
			me.newName = sprintf("%s%d", Polygon.editing.getName(), (Polygon.editing.getSize()+rand())*100);
			me.newSteerpoint = createWP({lat:lati,lon:long},me.newName,"pseudo");
			me.lastWP = nil;
			if (Polygon.editing.plan.destination != nil) {
				me.lastWP = Polygon.editing.plan.getWP(Polygon.editing.getSize()-1);
				printDA("append: dest != nil and last "~(me.lastWP!= nil));
				me.lastWP = createWP({lat: me.lastWP.lat, lon: me.lastWP.lon}, me.lastWP.id, "pseudo");
				me.lastWP.fly_type = "flyBy";
				Polygon.editing.plan.destination = nil;# this will make the delegate clear wp from list.
				Polygon.editing.plan.appendWP(me.lastWP);
			}
			Polygon.editing.plan.appendWP(me.newSteerpoint);
			Polygon.selectSteer = [Polygon.editing.plan.getWP(Polygon.editing.getSize()-1), Polygon.editing.getSize()-1,1];
			Polygon._apply = FALSE;
		} else {
			Polygon.appendSteer = FALSE;
		}
	},

	editSteerpointStop: func () {
		#class:
		# Cancel editing of steerpoint.
		#
		Polygon.editSteer   = FALSE;
		Polygon.appendSteer = FALSE;
		Polygon.insertSteer = FALSE;
		Polygon.editDetail  = FALSE;
		Polygon.dragSteer   = FALSE;
		if (getprop("ja37/systems/variant") == 0 and TI.ti != nil) {
			TI.ti.stopDAP();
		}
	},
	
	editStop: func {
		Polygon.editSteerpointStop();
		Polygon.selectSteer = nil;
		Polygon.editing = nil;
	},

	setToggleAreaEdit: func {
		#class:
		# Toggle setting polygon area 1 to be editable. Not sure this method is used, it dont seem generic.
		#
		printDA("area edit");
		var poly = Polygon.polys["OP1"]; #TODO: temp stuff
		if (poly != Polygon.editing) {
			Polygon.editing = poly;
		} else {
			Polygon.editing = nil;
		}
		Polygon.editSteerpointStop;
		Polygon.selectSteer = nil;
		Polygon.editBullsEye = FALSE;
	},

	setToggleBEEdit: func {
		#class:
		# Set bullseye to be editable.
		#
		printDA("bulls-eye edit");
		Polygon.editStop();
		Polygon.editBullsEye = !Polygon.editBullsEye;
	},

	editPlan: func (poly) {
		#class:
		# Set a certain plan to be editable.
		#
		if (poly != Polygon.editing) {
			Polygon.editSteerpointStop();
			#if (Polygon.polyEdit) {
			#	dap.set237(FALSE);
			#}
			#Polygon.polyEdit    = FALSE;
			Polygon.selectSteer = nil;
			Polygon.editing = poly;
		}	
		Polygon.editBullsEye = FALSE;	
	},

	_planEdited: func {
		#class:
		# Called from route-manager. Cancels all editing of a plan, since it was external edited.
		#
		if (Polygon._apply == FALSE) {
			removelistener(me.selectL);
			me.selectL = nil;
			printDA("plan edited, edit cancelled.");
			Polygon.editStop();
			#Polygon.polyEdit    = FALSE;
			return;
		}
		#printDA("plan not edited!!!");
	},

	getLandingBase: func {
		#class:
		# Get the destination of current RTB plan.
		#
		return Polygon.flyRTB.getBase();
	},

	isLandingBaseRunwayActive: func {
		#class:
		# Return true if current steerpoint is the current RTB destination
		#
		if (Polygon.flyRTB == Polygon.primary and Polygon.isPrimaryActive() == TRUE and Polygon.primary.plan.destination_runway != nil and Polygon.primary.getSize()-1==Polygon.primary.plan.current) {
			return TRUE;
		}
	},

	startPrimary: func {
		#class:
		# Wakes up the primary plan in route-manager.
		#
		fgcommand("activate-flightplan", props.Node.new({"activate": 1}));
	},

	activateLandingBase: func {
		#class:
		# Set current RTB plan as active, and select the destination and a runway.
		#
		me.base = Polygon.getLandingBase();
		Polygon.flyRTB.setAsPrimary();
		if (me.base != nil) {
			printDA("activateLandingBase: found base");
			if(Polygon.primary.forceRunway()) {
				printDA("activateLandingBase: found runway, forced on");
				Polygon.startPrimary();#TODO: revisit all this, and logic in ladning mdoe for this. What should happen when there is no runway found?
			} else {
				printDA("activateLandingBase: did not find runway");
			}
			Polygon.primary.plan.current = Polygon.primary.getSize()-1;
			return TRUE;
		} else {
			printDA("activateLandingBase: did not find base");
			Polygon.stopPrimary();
			return FALSE;
		}
	},

	stopPrimary: func {
		#class:
		# Set primary plan to sleep.
		#
		fgcommand("activate-flightplan", props.Node.new({"activate": 0}));
	},

	isPrimaryActive: func {
		#class:
		# Return true if primary plan is awake.
		#
		return getprop("autopilot/route-manager/active");
	},
	
	_wpChanged: func {
		#class:
		# Called form auto.Delegate just after the current waypoint is changed.
		# Check if it was to last in RTB plan, if so activate L.
		if (Polygon.primary != nil and Polygon.primary == Polygon.flyRTB and Polygon.primary.plan.destination != nil and !land.mode_L_active) {
			var ind = Polygon.primary.getIndex();
			var max = Polygon.primary.plan.getPlanSize()-1;
			if (ind == max) {
				dap.syst();# TI will do this when clicking 'L', but should we do it here also?
				land.L();
				# this listener can trigger delicate order of execution in landing-mode.nas
			}
		}
	},

	_setupListeners: func {
		#class:
		# Setup listener for if route-manager loads a plan from disc.
		#
		setlistener("autopilot/route-manager/signals/flightplan-changed", func {Polygon._planExchange()});
		#setlistener("autopilot/plan-manager/departure/airport", func {Polygon._takeoffTest()});
		setlistener("autopilot/plan-manager/destination/airport-1", func {Polygon._landTest(1)});
		setlistener("autopilot/plan-manager/destination/airport-2", func {Polygon._landTest(2)});
		setlistener("autopilot/plan-manager/destination/airport-3", func {Polygon._landTest(3)});
		setlistener("autopilot/plan-manager/destination/airport-4", func {Polygon._landTest(4)});
	},

	_planExchange: func {
		#class:
		# Route-manager loaded a plan from disc.
		#
		printDA("plan exhanged");
		if (Polygon._activating == TRUE) {
			printDA("..it was planned");
		} else {
			# New plan was loaded in route-manager
			var poly = Polygon.primary;
			poly.plan = flightplan();
			poly.plan.id = poly.name;
			#me.alreadyApply = Polygon._apply;
			#Polygon._apply = TRUE;
			Polygon._setDestDep(poly);
			#Polygon._apply = me.alreadyApply;
			printDA("..it was unexpected");
		}
		if (Polygon.primary == Polygon.editing) {
			Polygon.editSteerpointStop();
			Polygon.selectSteer = nil;
		}
	},

	_setDestDep: func (poly) {
		#class:
		# Checks the first and last steerpoints of the plan and sets dest/dep if it is airports.
		# Must only be called inside _apply or on non-active plan
		#
		if (poly.type == TYPE_MIX) {
			# prioritize setting dest on rtb/mix
			if (poly.plan.destination == nil and poly.getSize()>0) {
				me.lookupID = poly.plan.getWP(poly.getSize()-1).id;
				if (me.lookupID != nil) {
					me.airport = airportinfo(me.lookupID);
					if (me.airport != nil and ghosttype(me.airport) == "airport") {
						poly.plan.deleteWP(poly.getSize()-1);
						poly.plan.destination = me.airport;
					}
				}
			}
			if (poly.plan.departure == nil and poly.getSize()>1) {
				me.lookupID = poly.plan.getWP(0).id;
				if (me.lookupID != nil) {
					me.airport = airportinfo(me.lookupID);
					if (me.airport != nil and ghosttype(me.airport) == "airport") {
						poly.plan.deleteWP(0);
						poly.plan.departure = me.airport;
					}
				}
			}
		}
	},

	_finishedPrimary: func (pln) {
		#class:
		# Called from auto.Delegate when passing the last waypoint on a flight plan.
		# If the plan was a mission route then the current RTB route will be started.
		# If the plan was a RTB, it is left as is, with the last waypoint (landing base) active.
		#
		var plns="";
		if (pln.id != nil) {
			plns = pln.id;
		}
		printDA("plan finished: "~plns);
		if (Polygon._activating == FALSE and plns == Polygon.primary.getName()) {
			if (Polygon.primary.type == TYPE_MISS) {
				Polygon.flyRTB.setAsPrimary();
				Polygon.startPrimary();
				printDA("..starting "~Polygon.flyRTB.getName());
			}
		} else {
			printDA("..it was deactivated. Nothing to worry about.");
		}
	},

	selectDestinationOnPrimary: func {
		#class:
		# Set current steerpoint to last steerpoint on primary plan.
		#
		if (Polygon.primary.plan.getPlanSize() != 0) {
			Polygon.primary.plan.current = Polygon.primary.plan.getPlanSize()-1;
			return 1;
		}
		return 0;
	},

	#
	# Instance methods and variables
	#
	new: func (nameNum, nameVari, type, xml, default = 0) {
		#instance:
		# Create a new polygon instance (plan). Content is loaded from disc if commanded.
		#
		var newPoly = { parents : [Polygon]};
		if (default == 1) {
			newPoly.plan = flightplan();
		} elsif (xml != nil) {
			newPoly.plan = nil;
			call(func {newPoly.plan = createFlightplan(xml);}, nil, var err = []);
			if (size(err)) {
				print(err[0]);
				print("That plan will be init empty.");
			}
			if (newPoly.plan == nil) {
				newPoly.plan = createFlightplan();
			}
		} else {
			newPoly.plan = createFlightplan();
		}
		newPoly.plan.id = nameNum~nameVari;
		newPoly.name = nameNum~nameVari;
		newPoly.nameNum = nameNum;
		newPoly.nameVari = nameVari;
		newPoly.type = type;
		newPoly.color = COLOR_GREY_LIGHT;
		return newPoly;
	},

	isFull: func {
		#instance:
		# Return true if plan is at max capacity.
		#
		return (me.type == TYPE_AREA and me.getSize()>=maxArea) or (me.type != TYPE_AREA and me.getSize()>=maxSteers);
	},
	
	canAdd: func {
		#instance:
		# Return false if plan is RTB and has a destination
		if (me.type == TYPE_MISS or me.type == TYPE_AREA) {
			return TRUE;
		}
		if (me.plan.destination != nil) {
			return FALSE;
		}
		return TRUE;
	},

	getName: func {
		#instance:
		# Return name of plan. For example "4A".
		#
		return me.name;
	},

	getNameNumber: func {
		#instance:
		# Return the number part of the name. For example "4".
		#
		return me.nameNum;
	},

	getNameVariant: func {
		#instance:
		# Return the letter part of the name.
		#
		return me.nameVari;
	},

	getPolygon: func {
		#instance:
		# Return a vector with all the legs.
		#
		me.numbers = me.plan.getPlanSize();
		me.polygon = [];
		for (var i = 0; i < me.numbers; i+=1) {
			append(me.polygon, me.plan.getWP(i));
		}
		return me.polygon;
	},

	getSteerpoint: func {
		#instance:
		# Return a vector with curent steerpoint. If runway [runway, airport]. If airport [airport]. Else [leg].
		#
		if (me.plan.current == me.getSize()-1 and me.plan.destination_runway != nil and me.plan.destination != nil) {
			return [me.plan.destination_runway, me.plan.destination];
		}
		if (me.plan.current == me.getSize()-1 and me.plan.destination != nil) {
			return [me.plan.destination];
		}
		#if (me.plan.current == 0 and me.plan.departure_runway != nil and me.plan.departure != nil) {
		#	return [me.plan.departure_runway, me.plan.departure];
		#}
		#if (me.plan.current == 0 and me.plan.departure != nil) {
		#	return [me.plan.departure];
		#}
		return [me.plan.currentWP()];
	},

	getIndex: func {
		#instance:
		# Return index of current steerpoint.
		#
		return me.plan.current;
	},
	
	isTarget: func (index) {
		#instance:
		#
		#
		return me.plan.getWP(index).fly_type == "flyOver";
	},

	getLeg: func {
		#instance:
		# Returns current leg.
		#
		return me.plan.currentWP();
	},

	setAsPrimary: func {
		#instance:
		# Put this polygon into route-manager as active, but do not awake it.
		#
		if (!me.isPrimary() and me.type != TYPE_AREA) {
			printDA("Polygon._activating = TRUE;");
			Polygon._activating = TRUE;
			Polygon.primary = me;
			printDA("activating plan "~me.getName());
			me.plan.activate();
			printDA("Polygon._activating = FALSE;");
			Polygon._activating = FALSE;
		}
	},

	isPrimary: func {
		#instance:
		# Returns if this is the plan in the route-manager.
		#
		return Polygon.primary == me;
	},

	getSize: func {
		#instance:
		# Returns number oof steerpoints in this polygon.
		#
		return me.plan.getPlanSize();
	},

	cycle: func {
		#instance:
		# Set next steerpoint as current.
		#
		if (me.plan.current == me.getSize()-1) {
			me.plan.current = 0;
		} else {
			me.plan.current = me.plan.current +1;
		}
	},

	getBase: func {
		#instance:
		# Will return destination or last waypoint (if its a airport).
		#
		if (me.getSize() > 0) {
			if(me.plan.destination != nil) {
				printDA("getBase returning dest which is airport "~me.plan.destination.id);
				return me.plan.destination;
			} else {
				me.base = me.plan.getWP(me.getSize()-1);
				if (ghosttype(me.base) == "airport") {
					printDA("getBase returning "~(me.getSize()-1)~" which is airport "~me.base.id);
					return me.base;
				} else {
					printDA("getBase: RTB does not have airport as last steerpoint.");
				}
			}
		}
		return nil;
	},

	forceRunway: func {
		#instance:
		# Sets a random runway as destination if the destination_runway is not set and the last steerpoint is an airport.
		#TODO: should setting runway be _apply protected?
		me.base = me.plan.destination;
		me.baseRwy = me.plan.destination_runway;
		if (me.baseRwy == nil and me.base != nil) {
			me.runways = me.base.runways;
	        me.runwaysVector = [];
	        foreach (var runwayKey ; keys(me.runways)) {
	            append(me.runwaysVector, me.runways[runwayKey]);
	        }
	        if (size(me.runwaysVector)!=0) {
	        	me.plan.destination_runway = me.runwaysVector[0];
	        	return TRUE;
	        }
		} elsif (me.baseRwy != nil) {
			return TRUE;
		}
		return FALSE;
	},

	cycleDestinationRunway: func {
		#instance:
		# cycle through destination runways.
		me.base = me.plan.destination;
		me.baseRwy = me.plan.destination_runway;
		me.shouldStart = me.isPrimary() == TRUE and Polygon.isPrimaryActive() == TRUE;
		if (me.base != nil) {
			me.runways = me.base.runways;
	        me.runwaysVector = [];
	        foreach (var runwayKey ; keys(me.runways)) {
	            append(me.runwaysVector, me.runways[runwayKey]);
	        }
	        if (size(me.runwaysVector)==0) {
	        	return FALSE;
	        }
	        me.currRWY = -1;
	        if (me.baseRwy != nil) {
		        for (var i = 0; i<size(me.runwaysVector);i+=1) {
		            if (me.runwaysVector[i].id == me.baseRwy.id) {
		                me.currRWY = i;
		                break;
		            }
		        }
		    }
	        me.currRWY += 1;
	        if (me.currRWY >= size(me.runwaysVector)) {
	            me.currRWY = 0;
	        }
	        me.plan.destination_runway = me.runwaysVector[me.currRWY];	 
	        if (me.shouldStart == TRUE) {
	        	Polygon.startPrimary();
	        	me.plan.current = me.getSize()-1;
	        }
	        return TRUE;
		} else {
			return FALSE;
		}
	},

	loop: func {
		#class:
		# A loop that set the DAP display info on next steerpoint, will only be shown in DAP POS/OUT mode.
		# It also enables the save buttons in the dialog.
		#
		if(!Polygon.multi) return;
		dap.posOutDisplay = "       ";
		if (Polygon.isPrimaryActive()) {
			me.steer = Polygon.primary.getSteerpoint();
			if (me.steer != nil) {
				me.distance = getprop("autopilot/route-manager/wp/dist");
				if(me.distance != nil) {
					if (ghosttype(me.steer[0]) == "runway" or ghosttype(me.steer[0]) == "airport") {
						me.distance = me.distance*NM2M*0.001;
						dap.posOutDisplay = sprintf(" 10%03d0",me.distance);
					} else {
						me.distance = me.distance*NM2M*0.001;
						dap.posOutDisplay = sprintf(" 00%03d0",me.distance);
					}
				}
			}
		}
		#TODO: check for multi enabled:
		setprop("autopilot/plan-manager/save-1", Polygon.polys["1"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-2", Polygon.polys["2"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-3", Polygon.polys["3"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-4", Polygon.polys["4"].plan.getPlanSize() > 1);
		
		setprop("autopilot/plan-manager/save-1a", Polygon.polys["1A"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-1b", Polygon.polys["1B"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-2a", Polygon.polys["2A"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-2b", Polygon.polys["2B"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-3a", Polygon.polys["3A"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-3b", Polygon.polys["3B"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-4a", Polygon.polys["4A"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-4b", Polygon.polys["4B"].plan.getPlanSize() > 1);
		
		setprop("autopilot/plan-manager/save-p1", Polygon.polys["OP1"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-p2", Polygon.polys["OP2"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-p3", Polygon.polys["OP3"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-p4", Polygon.polys["OP4"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-p5", Polygon.polys["OP5"].plan.getPlanSize() > 1);
		setprop("autopilot/plan-manager/save-p6", Polygon.polys["OP6"].plan.getPlanSize() > 1);
	},
};

var poly_start = func {
	#
	# Setup the polygon system for the aircraft.
	#
	#removelistener(lsnr);
	if (getprop("ja37/systems/variant") == 0) {
		Polygon.setupJAPolygons();
	} else {
		Polygon.setupAJPolygons();
	}
}

#var lsnr = setlistener("ja37/supported/initialized", poly_start);
