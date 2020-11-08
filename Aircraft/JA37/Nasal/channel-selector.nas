#
# H = 121.50 MHz
#

var STANDBY = 0;
var INPUT = 1;
var mode = STANDBY;
var input_pos = nil;
var input_display = nil;


var input = {
    kv1:        "ja37/radio/kv1",
    kv3:        "ja37/radio/kv3",
    kv1_mhz:    "ja37/radio/kv1/button-mhz",
    kv1_chl:    "ja37/radio/kv1/button-nr",
    comm_mhz:   "instrumentation/comm/frequencies/selected-mhz",
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop], 1);
}


# Initialize properties for individual digits.
var displays = {
    top: [],
    middle: [],
    bottom: [],
};

var contents = {
    top: "36C",
    middle: "321",
    bottom: "12345",
};

for(var i=1; i<=3; i+=1) {
    append(displays.top, input.kv1.getChild("digit-top", i, 1));
}
for(var i=1; i<=3; i+=1) {
    append(displays.middle, input.kv1.getChild("digit-middle", i, 1));
}
for(var i=1; i<=5; i+=1) {
    append(displays.bottom, input.kv1.getChild("digit-bottom", i, 1));
}


var updateDisplayFromString = func(display, str) {
    forindex(var i; display) {
        display[i].setValue(chr(str[i]));
    }
}

var clearDisplay = func(display) {
    foreach(var digit; display) {
        digit.setValue(12);
    }
}


var updateDisplays = func {
    foreach(var disp; keys(displays)) {
        updateDisplayFromString(displays[disp], contents[disp]);
    }
};


var updateToRadio = func {
    if (input.kv1_mhz.getBoolValue()) {
        # Frequency selection
        var freq = num(contents.bottom)/100;
        input.comm_mhz.setValue(freq);
    } elsif (input.kv1_chl.getBoolValue()) {
        # Channel selection
        var ch = num(contents.middle);
        var freq = 117.975 + (ch-200)*0.025;
        input.comm_mhz.setValue(freq);
    }
};

var updateFromRadio = func {
    if (input.kv1_mhz.getBoolValue()) {
        var freq = math.round(input.comm_mhz.getValue() * 100);
        contents.bottom = sprintf("%05d", freq);
        mode = STANDBY;
        updateDisplays();
    }
};


var button = func (number) {
    if (mode != INPUT) return;

    # Update 'contents' strings.
    if (input_display == "top" and input_pos == 2) {
        # Special character for first display (3rd position)
        if (number == 2) {
            number = 10;
            var char = "C";
        } elsif (number == 3) {
            number = 11;
            var char = "C2";
        } else {
            var char = number;
        }
        contents[input_display] = contents[input_display]~char;
    } else {
        contents[input_display] = contents[input_display]~number;
    }

    # Update digit properties
    displays[input_display][input_pos].setValue(number);

    if (input_pos == size(displays[input_display])-1) {
        # Input complete
        mode = STANDBY;
        updateToRadio();
    } else {
        input_pos += 1;
    }
}

var startInput = func(display) {
    updateDisplays();
    clearDisplay(displays[display]);
    contents[display] = "";
    mode = INPUT;
    input_display = display;
    input_pos = 0;
}

var cl1 = func {
    startInput("top");
};

var cl2 = func {
    startInput("middle");
};

var cl3 = func {
    startInput("bottom");
};

updateFromRadio();
updateDisplays();
setlistener("instrumentation/comm/frequencies/selected-mhz", updateFromRadio);
