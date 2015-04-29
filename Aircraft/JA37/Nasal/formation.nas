#####################################################################################
#                                                                                   #
#  this script runs the foramation selection utility                                #
#                                                                                   #
#####################################################################################

# ================================ Initalize ====================================== 
# Make sure all needed properties are present and accounted 
# for, and that they have sane default values.


for(var i = 0; i < 3; i = i + 1){
    setprop("/sim/model/formation/position[" ~ i ~ "]/x-offset", 0);
    setprop("/sim/model/formation/position[" ~ i ~ "]/y-offset", 0);
    setprop("/sim/model/formation/position[" ~ i ~ "]/z-offset", 0);
}



var formation_dialog = nil;

initialize = func {

	#print("Initializing formation ...");

	formation_variant_Node = props.globals.getNode("sim/formation/variant", 1);
	formation_variant_Node.setIntValue(0); 

	formation_index_Node = props.globals.getNode("sim/formation/index", 1);
	formation_index_Node.setIntValue(0);

	tgt_x_offset_Node = props.globals.getNode("ai/models/wingman/position/tgt-x-offset",1);
	tgt_y_offset_Node = props.globals.getNode("ai/models/wingman/position/tgt-y-offset",1);
	tgt_z_offset_Node = props.globals.getNode("ai/models/wingman/position/tgt-z-offset",1);
	tgt_x_offset_1_Node = props.globals.getNode("ai/models/wingman[1]/position/tgt-x-offset",1);
	tgt_y_offset_1_Node = props.globals.getNode("ai/models/wingman[1]/position/tgt-y-offset",1);
	tgt_z_offset_1_Node = props.globals.getNode("ai/models/wingman[1]/position/tgt-z-offset",1);
	tgt_x_offset_2_Node = props.globals.getNode("ai/models/wingman[2]/position/tgt-x-offset",1);
	tgt_y_offset_2_Node = props.globals.getNode("ai/models/wingman[2]/position/tgt-y-offset",1);
	tgt_z_offset_2_Node = props.globals.getNode("ai/models/wingman[2]/position/tgt-z-offset",1);

	props.globals.getNode("/sim/model/formation/position/x-offset",1);
	
	# initialise dialogs 

	aircraft.data.add("sim/model/formation/variant");
	formation_dialog = gui.OverlaySelector.new("Select Formation",
		"Aircraft/Generic/Formations",
		"sim/model/formation/variant",
		"sim/model/formation/variant", nil, func(no) {
			formation_variant_Node.setIntValue(no);
			tgt_x_offset_Node.setDoubleValue(getprop("/sim/model/formation/position/x-offset"));
			tgt_y_offset_Node.setDoubleValue(getprop("/sim/model/formation/position/y-offset"));
			tgt_z_offset_Node.setDoubleValue(getprop("/sim/model/formation/position/z-offset"));
			tgt_x_offset_1_Node.setDoubleValue(getprop("/sim/model/formation/position[1]/x-offset"));
			tgt_y_offset_1_Node.setDoubleValue(getprop("/sim/model/formation/position[1]/y-offset"));
			tgt_z_offset_1_Node.setDoubleValue(getprop("/sim/model/formation/position[1]/z-offset"));
			tgt_x_offset_2_Node.setDoubleValue(getprop("/sim/model/formation/position[2]/x-offset"));
			tgt_y_offset_2_Node.setDoubleValue(getprop("/sim/model/formation/position[2]/y-offset"));
			tgt_z_offset_2_Node.setDoubleValue(getprop("/sim/model/formation/position[2]/z-offset"));
		}
	);
	

	#set listeners

	setlistener("/sim/model/formation/variant", func {
		#print("formation listener: ", getprop("/sim/model/formation/position/x-offset"));
		if (tgt_x_offset_Node != nil){
			#print("formation listener getting", getprop("/sim/model/formation/position/x-offset"));
			tgt_x_offset_Node.setDoubleValue(getprop("/sim/model/formation/position/x-offset"));
			tgt_y_offset_Node.setDoubleValue(getprop("/sim/model/formation/position/y-offset"));
			tgt_z_offset_Node.setDoubleValue(getprop("/sim/model/formation/position/z-offset"));
		}
		if (tgt_x_offset_1_Node != nil){
			tgt_x_offset_1_Node.setDoubleValue(getprop("/sim/model/formation/position[1]/x-offset"));
			tgt_y_offset_1_Node.setDoubleValue(getprop("/sim/model/formation/position[1]/y-offset"));
			tgt_z_offset_1_Node.setDoubleValue(getprop("/sim/model/formation/position[1]/z-offset"));
		}
		if (tgt_x_offset_2_Node != nil){
			tgt_x_offset_2_Node.setDoubleValue(getprop("/sim/model/formation/position[2]/x-offset"));
			tgt_y_offset_2_Node.setDoubleValue(getprop("/sim/model/formation/position[2]/y-offset"));
			tgt_z_offset_2_Node.setDoubleValue(getprop("/sim/model/formation/position[2]/z-offset"));
		}
		},
	0,
	1);

} # end func

###
# ====================== end Initialization ========================================
###


# Fire it up

setlistener("sim/signals/fdm-initialized", initialize);

# end 
