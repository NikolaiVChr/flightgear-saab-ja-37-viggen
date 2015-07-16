# grep 'name \"' throttle.ac | sed 's/name\ \"//' | sed s/\"//
# grep 'name \"' radarControl.ac | sed "s/name\ \"/\<object\-name\>/" | sed "s/\"/\<\/object\-name\>/"

# standard input
grep 'name \"' - | sed "s/name\ \"/\t\t\<object\-name\>/" | sed "s/\"/\<\/object\-name\>/"

