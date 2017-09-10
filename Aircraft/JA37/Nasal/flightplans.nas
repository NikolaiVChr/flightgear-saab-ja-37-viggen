var TYPE_MIX  = 0;# plan has both mission and RTB
var TYPE_RTB  = 1;# return to base plan
var TYPE_MISS = 2;# mission plan

var TRUE  = 1;
var FALSE = 0;

var debugAll = TRUE;

var printDA = func (str) {
    if (debugAll) print (str);
}

var Polygon = {
	#
	# Class methods and variables
	#
	primary: nil,
	editing: nil,
	editRTB: nil,
	editMiss: nil,
	polys: {},
	_activating: FALSE,
	flyRTB: nil,
	flyMiss: nil,
	editSteer: FALSE,
	selectSteer: nil,
	selectL: nil,
	_apply: FALSE,

	setupJAPolygons: func {
		Polygon._setupListeners();
		me.multi = getprop("ja37/supported/multiple-flightplans");
		if (me.multi == TRUE) {
			var poly1 = Polygon.new("1", TYPE_MISS, getprop("xmlPlans/mission1"), FALSE);
			Polygon.polys["1"] = poly1;
			for (var i = 2; i<=4; i+=1) {
				var poly = Polygon.new(""~i, TYPE_MISS, getprop("xmlPlans/mission"~i));
				Polygon.polys[""~i] = poly;
			}
			var polyA = Polygon.new("A", TYPE_RTB, getprop("xmlPlans/rtbA"));
			Polygon.polys["A"]   = polyA;

			var polyB = Polygon.new("B", TYPE_RTB, getprop("xmlPlans/rtbB"));
			Polygon.polys["B"]   = polyB;

			
			#Polygon.editing      = poly1;
			Polygon.editRTB      = polyA;
			Polygon.editMiss     = poly1;
			Polygon.flyRTB       = polyA;
			Polygon.flyMiss      = poly1;
			poly1.setAsPrimary();
		} else {
			var poly1 = Polygon.new("1", TYPE_MIX, nil, TRUE);
			Polygon.primary      = poly1;
			#Polygon.editing      = poly1;
			Polygon.flyRTB       = poly1;
			Polygon.flyMiss      = poly1;
			Polygon.editRTB      = poly1;
			Polygon.editMiss     = poly1;
		}
		printDA("JA: finished plan Init");
	},

	setupAJPolygons: func {
		Polygon._setupListeners();
		var poly1 = Polygon.new("1", TYPE_MIX, nil, TRUE);
		Polygon.primary      = poly1;
		#Polygon.editing      = poly1;
		Polygon.flyRTB       = poly1;
		Polygon.flyMiss      = poly1;
		Polygon.editRTB      = poly1;
		Polygon.editMiss     = poly1;
		printDA("AJ: finished plan Init");
	},

	selectSteerpoint: func (planName, leg, index) {
		me.editIndex = Polygon.editing.plan.indexOfWP(leg);
		#printf("%s %s %d",planName, leg.id, me.editIndex);
		if (planName == Polygon.editing.name){#} and me.editIndex != nil and me.editIndex != -1) {
			Polygon.selectSteer = [leg, index];
			printDA("select");
			if (me.selectL != nil) {
				removelistener(me.selectL);
			}
			me.selectL = setlistener("autopilot/route-manager/signals/edited", func {Polygon._planEdited()});
		}
	},

	editApply: func (lati, long) {
		if (Polygon.editSteer) {
			Polygon._apply = TRUE;
			#Polygon.selectSteer[0].wp_lat = lat;
			#Polygon.selectSteer[0].wp_lon = lon;
			# TODO: what about name??!
			me.newName = sprintf("%s%d", Polygon.editing.name, (Polygon.selectSteer[1]+rand())*100);
			me.newSteerpoint = createWP({lat:lati,lon:long},me.newName,"pseudo");
			#print(me.newName);
			Polygon.editing.plan.deleteWP(Polygon.selectSteer[1]);
			#print("deleted WP");
			Polygon.editing.plan.insertWP(me.newSteerpoint, Polygon.selectSteer[1]);
			#print("inserted WP");
			Polygon.selectSteer = [me.newSteerpoint, Polygon.selectSteer[1]];
			Polygon._apply = FALSE;
		}
	},

	editSteerpoint: func () {
		if (Polygon.selectSteer != nil) {
			Polygon.editSteer = !Polygon.editSteer;
			printDA("toggle edit: "~Polygon.editSteer);
		}
		return Polygon.editSteer;
	},

	editSteerpointStop: func () {
		Polygon.editSteer = FALSE;
	},

	editPlan: func (plan) {
		if (plan != Polygon.editing) {
			Polygon.editSteer = FALSE;
			Polygon.selectSteer = nil;
		}
		Polygon.editing = plan;
	},

	_planEdited: func {
		if (Polygon._apply == FALSE) {
			removelistener(me.selectL);
			me.selectL = nil;
			printDA("plan edited, steer edit cancelled.");
			Polygon.editSteer = FALSE;
			Polygon.selectSteer = nil;
			return;
		}
		#print("plan not edited!!!");
	},

	getLandingBase: func {
		return Polygon.flyRTB.getBase();
	},

	isLandingBaseRunwayActive: func {
		if (Polygon.flyRTB == Polygon.primary and Polygon.isPrimaryActive() == TRUE and Polygon.primary.plan.destination_runway != nil and Polygon.primary.getSize()-1==Polygon.primary.plan.current) {
			return TRUE;
		}
	},

	startPrimary: func {
		fgcommand("activate-flightplan", props.Node.new({"activate": 1}));
	},

	activateLandingBase: func {
		me.base = Polygon.getLandingBase();
		Polygon.flyRTB.setAsPrimary();
		if (me.base != nil) {
			if(Polygon.primary.forceRunway()) {
				Polygon.startPrimary();
			}
			Polygon.primary.plan.current = Polygon.primary.getSize()-1;
		} else {
			Polygon.stopPrimary();
			return FALSE;
		}
	},

	stopPrimary: func {
		fgcommand("activate-flightplan", props.Node.new({"activate": 0}));
		#if (Polygon.isPrimaryActive() == TRUE) {
		#	Polygon.primary.plan.cleanPlan();#careful here, if called twice it will clean plan.
		#}
	},

	isPrimaryActive: func {
		return getprop("autopilot/route-manager/active");
	},

	_setupListeners: func {
		setlistener("autopilot/route-manager/signals/flightplan-changed", func {Polygon._planExchange()});
	},

	_planExchange: func {
		printDA("plan exhanged");
		if (Polygon._activating == TRUE) {
			Polygon._activating = FALSE;
			printDA("..it was planned");
		} else {
			# New plan was loaded in route-manager
			var poly = Polygon.primary;
			poly.plan = flightplan();
			poly.plan.id = poly.name;
			printDA("..it was unexpected");
		}
		if (Polygon.primary == Polygon.editing) {
			Polygon.editSteer = FALSE;
			Polygon.selectSteer = nil;
		}
	},

	_finishedPrimary: func (pln) {
		#called from RouteManagerDelegate
		var plns="";
		if (pln.id != nil) {
			plns = pln.id;
		}
		printDA("plan finished: "~plns);
		if (Polygon._activating == FALSE) {
			if (Polygon.primary.type == TYPE_MISS) {
				Polygon.flyRTB.setAsPrimary();
				Polygon.startPrimary();
				printDA("..starting "~Polygon.flyRTB.name);
			} elsif (Polygon.primary.type == TYPE_RTB and Polygon.primary.getSize() > 0) {
				Polygon.startPrimary();
				Polygon.selectDestinationOnPrimary();
				printDA("..restarted last on "~Polygon.primary.name);
			}
		} else {
			printDA("..for real");
		}
		# TODO Handle if finish is called just from activating another.
	},

	selectDestinationOnPrimary: func {
		Polygon.primary.plan.current = Polygon.primary.plan.getPlanSize()-1;
		return Polygon.primary.plan.getPlanSize() != 0;
	},

	#
	# Instance methods and variables
	#
	new: func (name, type, xml, default = 0) {
		var newPoly = { parents : [Polygon]};
		if (default == 1) {
			newPoly.plan = flightplan();
		} elsif (xml != nil) {
			newPoly.plan = flightplan(xml);
		} else {
			newPoly.plan = flightplan("C:/Users/Nikolai/AppData/Roaming/flightgear.org/Export/emptyPlan.xml");
			#newPoly.plan = flightplan().clone();    #TODO
			#newPoly.plan.cleanPlan();
			#if (type == TYPE_RTB) {
			#	newPoly.plan.departure = nil;
			#}
		}
		#newPoly.plan.destination = nil;   error in FG
		newPoly.plan.id = name;
		newPoly.name = name;
		newPoly.type = type;
		newPoly.tainted = FALSE;
		return newPoly;
	},

	getPolygon: func {
		me.numbers = me.plan.getPlanSize();
		me.polygon = [];
		for (var i = 0; i < me.numbers; i+=1) {
			append(me.polygon, me.plan.getWP(i));
		}
		return me.polygon;
	},

	getSteerpoint: func {
		if (me.plan.current == me.getSize()-1 and me.plan.destination_runway != nil and me.plan.destination != nil) {
			return [me.plan.destination_runway, me.plan.destination];
		}
		if (me.plan.current == me.getSize()-1 and me.plan.destination != nil) {
			return [me.plan.destination];
		}
		if (me.plan.current == 0 and me.plan.departure_runway != nil and me.plan.departure != nil) {
			return [me.plan.departure_runway, me.plan.departure];
		}
		if (me.plan.current == 0 and me.plan.departure != nil) {
			return [me.plan.departure];
		}
		return [me.plan.currentWP()];
	},

	getIndex: func {
		return me.plan.current;
	},

	getLeg: func {
		return me.plan.currentWP();
	},

	setAsPrimary: func {
		if (!me.isPrimary()) {
			Polygon._activating = TRUE;
			Polygon.primary = me;
			#fgcommand("activate-flightplan", props.Node.new({"activate": 0}));#TODO: temp line
			if (me.tainted) {
				me.plan = me.plan.clone();
				me.plan.id = me.name;
			}
			me.plan.activate();
			me.tainted = TRUE;
		}
	},

	isPrimary: func {
		return Polygon.primary == me;
	},

	getSize: func {
		return me.plan.getPlanSize();
	},

	cycle: func {
		# Cycle waypoints
		if (me.plan.current == me.getSize()-1) {
			me.plan.current = 0;
		} else {
			me.plan.current = me.plan.current +1;
		}
	},

	getBase: func {
		# Will return destination or last waypoint (if its a airport).
		if (me.getSize() > 0) {
			if(me.plan.destination != nil) {
				printDA("getBase returning dest which is airport "~me.plan.destination.id);
				return me.plan.destination;
			} else {
				me.base = me.plan.getWP(me.getSize()-1);
				if (ghosttype(me.base) == "airport") {
					printDA("getBase returning "~(me.getSize()-1)~" which is airport "~me.base.id);
					return me.base;
				}
			}
		}
		return nil;
	},

	forceRunway: func {
		# will only force a runway onto a destination.
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
};

var poly_start = func {
	removelistener(lsnr);
	if (getprop("ja37/systems/variant") == 0) {
		Polygon.setupJAPolygons();
	} else {
		Polygon.setupAJPolygons();
	}
}

var lsnr = setlistener("ja37/supported/initialized", poly_start);
