
Helper = {};

############################################################
##
## All members of Helper.
##

# use: Chooser.new(parent,Linenumber)
 # Bound to the calling menu, multiple can exist
Helper.new = func() {
   var me = {parents : [Helper],
   };
   return me;
};

# Fitstring returns string s  of max-size n with ... at 1/3 of the string
Helper.FitString = func (s,n) {
   #printf("Helper.FitString called with %s",s);
   if ( size(str(s)) < n ) return s;
   var l = substr(s, 0, (n - 2) / 3);
   var r = substr(s, size(s) + size(l) + 3 - n);
   return l ~ "..." ~ r;
};

