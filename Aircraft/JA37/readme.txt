==================================================================
Readme for the JA-37 Viggen aircraft for the Flightgear simulator:
==================================================================

Install
----------
1 - Have flightgear installed. Version 2.8.0.2 to 3.4.0 is tested. Earlier version will not work, later might.
2 - Copy the entire 'JA37' folder into a folder (must be called Aircraft) where Flightgear will look for aircraft.
3 - Happy flying. Check the aircraft help page inside the sim for instructions.


Suggested Settings
------------------
Wildfire: On (for crashing)
Particles: On (Used for various stuff)
Advanced weather: Generate aloft-waypoints, Generate thermals, Terrain Effects, Realistic visibility. (it's an all-weather fighter, it can handle it)
Model-shader: top setting
Cockpit view options: Enable dynamic cockpit view. Enable redout/blackout.


Compatibility with Flightgear 2.8
---------------------------------
Delete the Material shaders section in JA37/Models/ja37-model.xml and it will fly fine.
Radar and custom HUD will be disabled automatically when using FG 2.8


Notes
---------
The aircraft is sorta Rembrandt ready, no glaring issues. ALS is recommended though.
It models the mid 80'ties upgraded version of JA-37 (not to be confused with JA-37D)
Be mindful of failure messages, if a gear locking mechanism fails due to being deployed at too high speed, that gear will not be able to support the weight of the aircraft till you repair it from the menu.


Homepage:  (check here to download the newest version)
------------------
Hangar: https://sites.google.com/site/fghangar
Wiki: http://wiki.flightgear.org/Saab_JA-37_Viggen
Issues: https://code.google.com/p/flightgear-saab-ja37-viggen/issues/list
Git: https://gitorious.org/saab-ja-37-viggen


Help?
-----
Looking for a contributor for these features, or what else you would like to work on: (I have many photos of these)

- Modeling of more detailed cockpit interior.
- More accurate gears and gear doors.
- Engine reverser.
- Black livery.
- Grey/black livery.

Contact Necolatis on the forums to get in contact, got plenty of cockpit pictures.

Liberties taken:
----------------
In the orig plane the HUD decimal delimiter is ','. I choose to use the english '.' instead.
The Radar is able to look through hills and mountains, and the missiles is also able to fly through those.
The air-to-air RB-24J missiles is also able to hit ground targets, as no air-to-ground misslies can be mounted at the moment.