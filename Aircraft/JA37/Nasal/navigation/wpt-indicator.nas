### AJS waypoint number display

var TRUE = 1;
var FALSE = 0;

var input = utils.property_map({
    wp_ind_type:    "instrumentation/waypoint-indicator/type",
    wp_ind_num:     "instrumentation/waypoint-indicator/number",
    landing_mode:   "ja37/hud/landing-mode",
});


## Texture symbols codes (=offset on the texture)

# Codes for waypoint type (first character)
var WP_TYPE = {
    OFF: 0,
    LAND: 1,
    LAND_B: 2,
    LAND_F: 3,
    WPT: 4,
    TGT: 5,
    POPUP: 6,
    FIX: 7,
    POLY: 8,
    TGT_RECO: 9,
    TGT_TRACK: 10,
    EXTRA: 11,
};

# Codes for waypoint number (second character)
# Digits 1-9 are displayed as-is.
var WP_NUM = {
    OFF: 0,
    ZERO: 10,   # not sure if this is ever used
    START: 11,
};

## Waypoint types / numbers used by route manager
var WPT = route.WPT;

# convert waypoint types to texture symbol code
var WP_MASK_TO_TYPE = {};

WP_MASK_TO_TYPE[WPT.L]  = WP_TYPE.LAND;
WP_MASK_TO_TYPE[WPT.B]  = WP_TYPE.WPT;
WP_MASK_TO_TYPE[WPT.U]  = WP_TYPE.POPUP;
WP_MASK_TO_TYPE[WPT.BX] = WP_TYPE.EXTRA;
WP_MASK_TO_TYPE[WPT.R]  = WP_TYPE.POLY;
WP_MASK_TO_TYPE[WPT.M]  = WP_TYPE.TGT_RECO;
WP_MASK_TO_TYPE[WPT.S]  = WP_TYPE.TGT_TRACK;


# Update waypoint indicator. Argument 'idx' as in route-ajs.nas
var set_wp_indicator = func(idx) {
    var idx = route.get_current_idx();

    # Waypoint number
    if (idx == WPT.LS)
        input.wp_ind_num.setIntValue(WP_NUM.START);
    else
        input.wp_ind_num.setIntValue(idx & WPT.nb_mask);

    # Waypoint type
    var type = WP_MASK_TO_TYPE[idx & WPT.type_mask];

    if (type == WP_TYPE.WPT and route.is_tgt(idx))
        type = WP_TYPE.TGT;

    if (type == WP_TYPE.POPUP and route.fix_mode_active())
        type = WP_TYPE.TGT;

    if (type == WP_TYPE.LAND and input.landing_mode.getBoolValue()) {
        if (land.mode == 1)
            type = WP_TYPE.LAND_B;
        else
            type = WP_TYPE.LAND_F;
    }

    input.wp_ind_type.setIntValue(type);
}
