var input = {
    main:       "/ja37/mode/main",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


var TAKEOFF = 0;
var NAV = 1;
var COMBAT = 2;
var LANDING = 3;

var main = TAKEOFF;
