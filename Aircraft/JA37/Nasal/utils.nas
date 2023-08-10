#### JA37 Misc library
#
# Copyright 2023 Colin Geniet - released under GPLv2+

# ensure_prop(prop-name) -> property
# ensure_prop(property) -> property
#
# Input:
# path: either a property node, or a property name
#
# If @path is a property node, return it as is.
# If @path is a property name, return the corresponding property node, creating it if necessary.

var ensure_prop = func(path) {
    if (typeof(path) == "scalar") return props.globals.getNode(path, 1);
    else return path;
}


# property_map({ key: prop-name, ...}) -> { key: property, ... }
#
# Input:
# map: hash whose values are property names.
#
# Modify @map by replacing the property names by the corresponding property nodes.
# Missing property nodes are created.
# Return the modified @map.

var property_map = func(map) {
    foreach (var name; keys(map)) {
        map[name] = ensure_prop(map[name]);
    }
    return map;
}
