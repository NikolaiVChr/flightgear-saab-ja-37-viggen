#### Comm channels preset file parser

var TRUE = 1;
var FALSE = 0;

var input = {
    preset_file:        "ja37/radio/channels-file",
    preset_group_file:  "ja37/radio/group-channels-file",
    preset_base_file:   "ja37/radio/base-channels-file",
    gui_file:           "sim/gui/dialogs/comm-channels/channels-file",
    gui_group_file:     "sim/gui/dialogs/comm-channels/group-channels-file",
    gui_base_file:      "sim/gui/dialogs/comm-channels/base-channels-file",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



### Character type functions.

var is_digit = func(c) {
    # nasal characters are numbers (ASCII code)...
    # I don't know a way to make this more readable.
    return c >= 48 and c <= 57;
}

# Space or tab
var is_whitespace = func(c) {
    return c == 32 or c == 9;
}


### Channels table
var channels = {
    # Guard channel, only one set by default.
    H: 121500,
};


### Channel names

# Suffixes for airbase channel names
var base_channel_names = ["A", "B", "C", "C2", "D"];
# Global configurable channels
var special_channels = ["M", "L", "S1", "S2", "S3"];
var special_base_channels = ["E", "F", "G"];

# ASCII characters for prefixes
var base_prefix = 66;    # 'B'
var group_prefix = 78;   # 'N'

# Test if 'str' is a valid group channel name. Also include the special channels.
var is_group_channel = func(str) {
    foreach (var channel; special_channels) {
        if (str == channel) return TRUE;
    }

    if (size(str) != 4) return FALSE;
    if (str[0] != group_prefix) return FALSE;
    for (var i=1; i<4; i+=1) {
        if (!is_digit(str[i])) return FALSE;
    }
    return TRUE;
}

# Test if 'str' is a valid airbase channel name.
var is_base_channel = func(str) {
    foreach (var channel; special_base_channels) {
        if (str == channel) return TRUE;
    }

    if (size(str) != 5 and size(str) != 6) return FALSE;
    if (str[0] != base_prefix) return FALSE;
    for (var i=1; i<4; i+=1) {
        if (!is_digit(str[i])) return FALSE;
    }

    var suffix = substr(str, 4);
    foreach (var channel; base_channel_names) {
        if (suffix == channel) return TRUE;
    }
    return FALSE;
}

# Test if 'str' is an airbase or group name, which should be silently ignored
# in the radio config file (used to add 'comments' for airbases or groups).
var is_comment_key = func(str) {
    return (size(str) == 3 and str[0] == group_prefix
            and is_digit(str[1]) and is_digit(str[2]))
        or (size(str) == 4 and  str[0] == base_prefix
            and is_digit(str[1]) and is_digit(str[2]) and is_digit(str[3]));
}


### Parser

# Parse a line, extract key (first whitespace separated token) and value (rest of line).
# Comments starting with '#' are allowed.
# Returns nil if the line is blank, [key,val] otherwise.
# 'key' is a non-empty string without whitespace.
# 'val' is a possibly empty string with whitespace stripped at both ends.
var parse_key_val = func(line) {
    # Strip comments
    var comment = find("#", line);
    if (comment >= 0) line = substr(line, 0, comment);
    var len = size(line);

    # Start of key
    var key_s = 0;
    while (key_s < len and is_whitespace(line[key_s])) key_s += 1;
    if (key_s >= len) return nil;
    # End of key
    var key_e = key_s;
    while (key_e < len and !is_whitespace(line[key_e])) key_e += 1;
    var key = substr(line, key_s, key_e-key_s);

    # Start of value
    var val_s = key_e;
    while (val_s < len and is_whitespace(line[val_s])) val_s += 1;
    if (val_s >= len) return [key, ""];
    # End of value
    var val_e = len;
    while (is_whitespace(line[val_e-1])) val_e -= 1;
    var val = substr(line, val_s, val_e-val_s);

    return [key,val];
}

# Parse a frequency string, return its value in KHz, or nil if it is invalid.
# Frequencies are rounded to the nearest KHz.
var parse_freq = func(str) {
    var f = num(str);
    if (f == nil) return nil;
    else return math.round(f * 1000.0);
}

# Clear channels table
var reset_channels = func(reset_group_channels=1, reset_base_channels=1) {
    foreach (var channel; keys(channels)) {
        if ((reset_group_channels and is_group_channel(channel))
            or (reset_base_channels and is_base_channel(channel))) {
            delete(channels, channel);
        }
    }
}

# Load a radio channels configuration file.
var read_file = func(path, load_group_channels=1, load_base_channels=1) {
    var file = nil;
    call(func { file = io.open(path, "r"); }, nil, nil, nil, var err = []);
    if (size(err)) {
        debug.printerror(err);
        printf("Failed to load radio channels file: %s\n", path);
        if (file != nil) io.close(file);
        return;
    }
    printf("Reading radio channels file %s\n", path);

    # Memorize loaded file paths, for GUI only.
    var short_path = path;
    if (size(short_path) > 50) {
        short_path = "... "~substr(short_path, size(short_path)-46);
    }
    if (load_group_channels and load_base_channels) {
        input.gui_file.setValue(short_path);
        input.gui_group_file.clearValue();
        input.gui_base_file.clearValue();
    } elsif (load_group_channels) {
        input.gui_group_file.setValue(short_path);
        if (input.gui_base_file.getValue() == nil and input.gui_file.getValue() != nil) {
            input.gui_base_file.setValue(input.gui_file.getValue());
        }
        input.gui_file.clearValue();
    } elsif (load_base_channels) {
        input.gui_base_file.setValue(short_path);
        if (input.gui_group_file.getValue() == nil and input.gui_file.getValue() != nil) {
            input.gui_group_file.setValue(input.gui_file.getValue());
        }
        input.gui_file.clearValue();
    }


    reset_channels(load_group_channels, load_base_channels);

    # for error messages
    var line_no = 0;

    while ((var line = io.readln(file)) != nil) {
        # Extract key and value from line
        line_no += 1;
        var res = parse_key_val(line);
        if (res == nil) continue;

        # 'Comment' key, skip
        if (is_comment_key(res[0])) continue;

        var is_group = is_group_channel(res[0]);
        var is_base = is_base_channel(res[0]);

        # Invalid channel name
        if (!is_group and !is_base) {
            printf("%s:%d: Warning: Ignoring unexpected channel name: %s", path, line_no, res[0]);
            continue;
        }
        # Skipped channel type.
        if ((is_group and !load_group_channels) or (is_base and !load_base_channels)) {
            printf("%s:%d: Skipping %s channel %s (only loading %s channels)",
                   path, line_no, is_group ? "group" : "base", res[0], is_group ? "base" : "group");
            continue;
        }
        # Warnings for redefined channels.
        if (contains(channels, res[0])) {
            printf("%s:%d: Warning: Redefinition of channel %s", path, line_no, res[0]);
        }
        # Parse and assign new frequency.
        var freq = parse_freq(res[1]);
        if (freq == nil) {
            printf("%s:%d: Warning: Ignoring invalid frequency: %s", path, line_no, res[1]);
            continue;
        }
        channels[res[0]] = freq;
    }

    io.close(file);

    # Notify radios
    freq_sel.channel_update_callback();
}

var read_group_file = func(path) {
    read_file(path:path, load_base_channels:0);
}

var read_base_file = func(path) {
    read_file(path:path, load_group_channels:0);
}

### Channels access functions

var get = func(channel) {
    if (contains(channels, channel)) return channels[channel];
    else return 0;
}

var get_group = func(channel) {
    return get("N"~channel);
}

var get_base = func(channel) {
    return get("B"~channel);
}


### Load initial configuration file

var default_group_channels = getprop("/sim/aircraft-dir")~"/Nasal/radios/channels-default.txt";

var init = func {
    # Load channels configuration files
    var path = input.preset_file.getValue();
    var group_path = input.preset_group_file.getValue();
    var base_path = input.preset_base_file.getValue();

    # Load default channels configuration
    read_file(default_group_channels);
    # Load custom ones
    if (path != nil)        read_file(path);
    if (group_path != nil)  read_group_file(group_path);
    if (base_path != nil)   read_base_file(base_path);
}
