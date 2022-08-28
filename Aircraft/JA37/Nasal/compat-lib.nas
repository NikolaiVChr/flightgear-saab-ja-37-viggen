#### Nasal standard library backward compatibility
#
# This file defines functions from the nasal standard library
# which are missing in older FG versions, to avoid complete breakage.

# logprint(), added in 2020.1, deprecates printlog
if (!defined("logprint")) {
    globals.logprint = printlog;
    globals.LOG_BULK = "bulk";
    globals.LOG_DEBUG = "debug";
    globals.LOG_INFO = "info";
    globals.LOG_WARN = "warn";
    globals.LOG_ALERT = "alert";
    globals.DEV_WARN = "warn";
    globals.DEV_ALERT = "alert";
    globals.MANDATORY_INFO = "info";
}

# str(), added in 2020.4
if (!defined("str")) {
    globals.str = func(x) {
        return ""~x;
    }
}
