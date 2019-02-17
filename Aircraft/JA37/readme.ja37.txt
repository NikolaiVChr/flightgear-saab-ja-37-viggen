#
#
#
#         JA-37Di Mini-manual
#
#
#


This manual describes systems when aircraft is in English/imperial mode.
The menu item names and units etc. is different in Swedish/metric mode, maybe in future will make manual for that also.



Flightplans
===========
The aircraft has 12 plans. 4 mission (1-4) and 8 return to base plans (A & B for each landing base). Additionally it can have 6 map-areas defined.
Notice since clicking key 'Y' is the same as LS on TI display, this will also switch plan if you are already on a mission plan.




Concise English overview of TI (right color display)
==============================
Click a sidebutton for quick SYST menu.
Click a bottom button for main menus.
Click MENU to exit menus.

The rocker switch C change contrast of display (only if model shaders is on, and not in Rembrandt).
The rocker switch B change brightness of display.

Menus
-----
WEAP - Weapons
SYST - System (default quick menu)
  TRAP - Tactical reports
DISP - Display
MSDA - Mission data
FAIL - Failures
CONF - Configuration
  GPS  - GPS configuration
  SIDV - TI sideview configuration

WEAP
----
CLR  - Not implemented.
AKAN - Cannon.
x7x  - Various pylons. W=wing, T=wingtip, F=fuselage, L=left, R=right.
STA
  STBY - Standby status for missiles. Does not show for cannon.
  RDY  - Ready to be fired status. From the signal is sent to get ready when its selected and master-arm is ON, a small duration will pass before its ready.

The following menu items only show when a sidewinder (RB74/RB24) is selected:

CAGE
  AUTO - Automatic uncage of heatseeker head when lock is achieved.
  MAN  - Manual uncage of seeker head.
SEEK
  CAGE - When framed the seeker head is caged. Need to be set to manual for pilot to be able to change it.
         When uncaged without lock, the seeker head will scan the sky ahead in a small pattern and lock onto anything it see.
         This is handy for dogfight with radar off when enemy can be hard to spot.
SEEK
  WARM - The seeker head is not cooled down. When framed cooling has be commanded, but not yet achieved.
  COOL - The seeker head is cooled down, and the sidewinder range is increased. Cooling fluids last for about 1 hour for RB74. RB24J is electrical cooled, so it wont run out.
MODE
  BORE - When caged it will look straight ahead looking for something within range to lock on (and for RB24J it prefers to have view of a hot engine).
         This is another mode that is handy for dogfight with radar off when the enemy can be seen and manouvred onto bore.
MODE
  SLAV - Seeker slaved to either radar or cursor on MI/HUD. To use cursor make sure to have the seeker caged.
         Then make sure you haven't transfered the cursor to the TI display and that PEK is lit up. See cursor section in this document for details on how to control it.
         Then make sure the radar haven't selected anything (click to deselect).
         Then use cursor to tell the seeker where to look. You will see the seeker head position both in MI and in HUD (when inside its view).

SYST
----
S      - Mission steerpoint nav. or switch to next. Will also switch of landing mode and switch to mission plan.
L      - Navigate direct for landing base or switch runway. Will switch to RTB plan landing base.
LT     - Nav. for touchdown point or short approach. Will switch to RTB plan landing base. Notice if this is done on runway, OPT will engage.
LS     - Nav. for approach circle (long approach). Will switch to RTB plan landing base. Notice if this is done on runway, OPT will engage.
OPT    - Optical landing mode. Can only be engaged with gears down or in landing mode (LS or LT). Will auto engage at low alt in those modes.
DL     - STRIL data-link  (not implemented)
LR     - Return to base polygon navigation. Or switch to next steerpoint in that.
MPOL   - Select which mission polygon.
RPOL   - Select which RTB polygon.
RR     - Only shown when airborne. Steer order from radar on selected radar echo. This gives intercept vector to selected target. ('f' key does the same)
         If an intercept course at present speed cannot be computed it will show pure pursuit vector.
OFF/EP - Option only shown on ground. Turn off EP12 Electronic presentations (MI+TI displays).
ACRV   - Attack curve (not implemented)
FGHT   - Fighter mode. HUD shows IAS
ATCK   - Attack mode. HUD shows groundspeed (at low alt)

TRAP
----
LOCK - Radar lock events
FIRE - Weapon fire events
ECM  - Weapon hit events and radar-silence events.
MAN  - Manual events log
LAND - Landing events
CLR  - Clear all TRAP.
ALL  - Show all tactical reports on one page.
DOWN - scroll down
UP   - scroll up

DISP
----
EMAP - Electronic map. NORM/MAX toggles if map places on map. AIRP toggles airports on map (might give some stutter).
SCAL - Map scale.
AAA  - Anti aircraft fire zones (LV). FRND/HSTL show friendly/hostile zones. Green is friendly, red is hostile, yellow is unknown/hostile.
TIME - Show ZULU time at top of display. (when editing MPOL or RPOL in MSDA menu, time is also shown)
HORI - Show FPI, artificial horizon and ground symbol. CLR = certain conditions. ON = always. OFF = only at terrain impact warning.
CURS - Toggle if cursor is on MI or TI. (PEK on MI must be enabled to see/use cursor)
DAY  - Map contrast for daytime or NGHT for night time.

MSDA
----
EDIT
  BEYE  - Edit bulls-eye. Use cursor to click on the map where it should be.
          Notice when the cursor is on the TI and over the map, and small info box will appear showing bearing and distance to the cursor from bulls-eye.
          That same infobox will give directions to radar selection instead, when cursor is on the MI display.
  POLY  - Edit area polygons. Click with cursor on top field in infobox to control from DAP which area is edited.
  RPOL  - Edit a RTB polygon.
  MPOL  - Edit a mission polygon.
  S/P   - Enable dragging of point/steerpoint in current edited polygon.
INS S/P - Insert selected point/steerpoint in current edited polygon. Then use cursor.
ADD S/P - Append point/steerpoint to current edited polygon (if it has room for more). Then use cursor.
          Notice if adding to a RTB plan when its landing base has been defined in route-manager is not possible.
RPOL    - If RPOL being edited, this is which one. To select one from another landing base, use the landing base selector on nav-panel and press 'L' button.
MPOL    - If MPOL being edited, this is which one.
MYPS    - Move own position in chunks up/down the display.
MMAN    - MapManual movement, and map no longer follows own position. See cursor for more details.

FAIL
----
Is just a log page. FAIL will blink at new unseen failures, when main menu is shown, also a text will display on the MI about unread fails.

CONF
----
SIDV     - Sideview menu. See MI section on how to activate sideview.
GPS      - Activate GPS menu.
FR28     - Use top or belly radio antennae. (Effect not implemented.)
READDATA - Technician data readout. (Not implemented.)

GPS
---
FIX  - Used for establishing a GPS fix to correct INS drift. (not implemented)
INIT - Start GPS. (approx 40 seconds to start, including BIT self-test)

SIDV
----
WIN  - Sideview size
SHOW - Inclusion setting. Not implemented.
SCAL - If RMAX set to SCAL this controls the horizon distance shown.
RMAX - Horizontal distance. MI=follow radar setting. SCAL=see SCAL. MAP=Follow map scale.
AMAX - Max altitude shown.





Cursor on TI/MI
===============
The cursor can be slewed: Pressing key 'y' will toggle slaving flight-controls to the cursor instead.
Terrain impact warning will switch the slaving off, so you get immediate control of the aircraft to avoid terrain impact.
Per default the cursor is located on the MI display. See the DISP menu on the TI on how to transfer it between displays.
Use trigger to click on something (the click will have to last up till half a second on the TI sometimes).
On the TI you can click on all side and bottom buttons, except when EDIT, ADD or INS steerpoint/map-area-point. Also when not in any menu.
Sometimes in menu MSDA a white info box is shown. Some fields can be clicked, and then input on the data-panel. Field will blink when input active.
When MMAN is enabled, map will be moved instead of cursor.
When clicking on a radar echo in MI, it get selected/locked. Same for TI, but on the TI it will also set steer order on that echo.
In MSDA/UDAT menu LV/FF points can be dragged when no polygon is being edited. To grab them hold trigger on center of symbol.
When a polygon is being edited and a steerpoint/aera-point has been selected, pressing |X| button on nav panel will delete it. (cannot delete landing bases or take-off base, use route-manager for that)

In Flightgear joystick settings you can bind cursor control to your stick/hotas.

If you are skilled with editing stick/hotas input files, you can manually bind these properties:

ja37/systems/cursor-control-X
ja37/systems/cursor-control-Y
ja37/systems/cursor-select





Concise English overview of MI on JA-37Di: (center radar display)
==========================================
bottom buttons (hold P3 for help)
--------------
2  - SDV - Toggle sideview on TI
X1 - BIT - RB99 self tests
X3 - EVN - Register manual event (can be viewed in TI TRAP menu)
M2 - ECM - Toggle ECM on TI (essentially a RWR)
X2 - LNK - Toggle RB99 telemetry on TI

left buttons
------------
PEK - Cursor toggle. If off then radar cannot lock anything, nor can cursor be shown/slewn on TI/MI.
A - Zoom out on TI
B - Zoom in on TI

right indicators
----------------
TLS - Tactical Instrument Landing System active. Steady=vertical guidance also available. Blink=only lateral guidance.
TNF - Inertial navigation. Blink=init. Steady=on.



Concise overview of Datapanel (DAP) and Navpanel 
================================================

DAP is located on right panel, has keypad and display, Navpanel is next to it

OK button is on nav panel.
<- (BACKSPACE) on navpanel will go one digit back when inputting.
|X| (CLEAR FIELD) on navpanel will clear current digits entered in input mode. Or in 237 mode it will clear the value altogether. If on TI a steerpoint is selected in a route being edited, this button will delete the steerpoint.
Other buttons used on the nav. panel is L and LB for yellow/green antiaircraft areas (LV).
Nav. panel is located just next to data-panel.
Notice the two lights with IN/OUT and POS/MSDA, those are buttons also.

If POS/MSDA button is in POS mode and the other button in OUT, the display will show steerpoint info. This is also the default state of the data-panel.
  nbaaau  - n: 0=steerpoint 1=airport, aaa: distance, u: uncertainty.

Below is listed what combination of IN/OUT with the knob will produce (if the other button is set to MSDA):

OUT
- TILS:   Shows current TILS frequency on display.
- CL/DA:  Show date/time on display. Cycle with OK.
- FUEL:   Show extra fuel warning setting in percent on display.
- LOLA:   Show current LON/LAT on display. Cycle with OK.

IN
- TILS:  
- CL/DA:  Set date/time. Entering 999999 for either date or time will reset.
- FUEL:   Set extra fuel warning in percent. (threshold will trigger master warning)
- LOLA:  

ACDATA:
- IN:  Input 2 digits for address, then either the value you want to set, or switch to OUT.
- OUT: If 2 first digits entered will show value of address in last 4 digits.
- ADDRESSES:
    15axcd Interoperability = 1, Swedish and metric = 0. a, c and d is ignored.
    30xbcd GPS Installed = 1, NO GPS = 0. b, c and d is ignored.

REG/STR:
- IN:  Input 2 digits for address, then either the value you want to set, or switch to OUT.
- OUT: If 2 first digits entered will show value of address in last 4 digits.
- ADDRESSES:
    00xxcd is maximum angle of attack setting. c and d is ignored. Setting 00 reverts to default.
    19xxxx is training floor altitude.
    52xxxd is loadfactor in percent for aural g-force warning. d is ignored. From 075 to 110.

TI
note1: the LV, FF and bulls-eye will be shown on TI display. If DAP knob is on TI or TI menu MSDA is active, the address number will also be shown.
note2: LV stands for airdefense area, and FF for pilot point.
- IN/MSDA:  Input 3 digits for address, then either switch to out or click OK (for red), L (for yellow), LB (for green) and continue inputting longitude, then latitude. (bulls-eye and FF is always tyrkouise)
            To unlock for deletion type the unlock code followed by CLEAR.
            If unlocked can enter a address range like 024123 (24 to 123) to delete a range of addresses.
- OUT/MSDA: If 3 first digits for address entered will show lon/lat of address, click OK to toggle between them. Hold OK down to see description before the value is shown.
            In this state flight time is shown on TI also.
- POS:
            Can clear currently edited flightplan/map-area by pressing CLEAR.
- ADDRESSES:
            001-039 LV circles with 5km radius
            040-099 LV circles with 8km radius
            100-109 FF squares
            110-178 LV circles with 15km radius
            179 is Bulls-eye
            180-189 LV circles with 40km radius
            654321 is code for unlocking delete option. Turning knob or switching IN/OUT will reengage lock.

"237" on display
- Input to TI press OK to send or press |X| to delete the value.

"Error" on display
- rotate knob or in/out switch to clear.

When inputting, pay notice to the switch +/-, as that is the sign of what you input. For some inputs its ignored though and hence not shown when you input.


Aural warning tones
===================
There is different warning tones for the following:
- High angle-of-attack (3 stages, limits depends on altitude and gears)
- High G-force (3 stages, limits depend on aircraft weight and gears) 
- Low speed
- Below training floor
- Ground collision
- Flare/chaff release
- Flares out
- Master warning
- Entering transonic regime
- Vne speed exceeded.

Volume can be adjusted on left FR29 radio panel (the smaller knob).
Ground collision warning (including the displays/HUD arrows) can be switched off on the navpanel.



Testing
=======
The following conditions must be present before testing:
--------------------------------------------------------
- Wheels on ground
- INS (Inertial navigation system) not initializing

and either:

- External power supplying
or
- DC and AC power on.
- Throttle not idle
- Throttle not too high

Test
----
On test panel, click FK to get into testing mode. Displays, HUD and air-condition will shut off.
To abort either switch engine starter or click FK.
Click START/STOPP to start testing. While test of a system is ongoing data-panel minus sign will blink, and the 2 first digits will show which system being tested.
The result of a test is shown on the data-panel without a minus sign. First 2 digits is the system, next 4 digits is details of the result.
When a test is successful the green lamp will show.
  You can then click START/STOPP to acknowledge and start test of next system.
When a test is unsuccessful the red lamp will show.
  You can then click START/STOPP to acknowledge and start test of next system.
  Or click FEL to not acknowledge and start next test.
  Or click REP to repeat the test.
During a test you can click START/STOPP to skip to next test.
When last test has been acknowledged or dis-acknowledged the testing ends.
For now only AUTO testing can be done, meaning it will test all 20 systems. Testing through TI is not enabled yet.

Test programs
-------------
 1 CD - CPU
 2 ANP - Adaptation unit
 3 LD - Airdata
 4 TN - Inertial navigation
 5 SA - Autopilot
 6 GSA - Basic flight control system
 7 PRES - Presentation
 8 EP - Electronic presentation system
 9 PN
 10 MIS - Target aquisition system
 11 RRS - Radar beam
 12 BES - RB71 Illuminator
 13 
 14 TILS - Tactical landing system
 15 SD - Combat control data
 16 RHM - Radar altimeter
 17 A73
 18 BEV - Armament





Landing
=======
Rules
-----
Max allowed crosswind for short landing without flare: 30 Km/h - 16.2 kt
Max allowed crosswind for standard landing with flare: 55 Km/h - 29.7 kt
Landing must be standard with flare at aircraft weights over 15000 Kg or if there is fuel in the droptank.
Reversing handle must not be pulled out before landing gear is out and locked, and indicator panel has 3 green lights.
Max allowed EPR (engine pressure ratio) at initialization of reverser is 1.75.
Max allowed reverse at stationary aircraft is 1.4 EPR.
Max rolling speed in groundspeed: 320 Km/h (172.8 Kt).
Max touchdown pitch: 20.5 deg clearing uncompressed, 16 deg partial compressed at flare, 14 degs fully compressed.
Minimum touchdown speed 100 kt (only at 15.5 AoA short landings of course).
Nosewheel touchdown speed: latest at 160 KM/h (86 kt).



Check here for more up to date landing info: https://www.youtube.com/watch?v=lL3nb-itZqU&list=PLogi97V-ki0GfCLqimTtIq9RIVcm-GRFE&index=8

NOTICE: The following examples are outdated:

Example 1: Ad-hoc visual landing
--------------------------------
In no particular order do these:
1: If you know the barometer pressure at the airport then set into one of the altimeters.
2: Hit key 'Y'.
3: Tune into ILS. [optional]
4: Click the button 15.5 on front panel for short landing.

Align the aircraft for the approach and slow down to about 550 Km/h (297 kt) and be about 500 m (1640 ft) AGL.
At 15 Km (about 7.6 NM) distance from touchdown, extend gears. Engage reverse thrust if you want it to engage auto when you land.
At 10 Km (5.4 NM) out, start to descend. The HUD will show the 2.86 deg descent line, which of-course fits, since there is 10000m left to touchdown and you are 500m above it, so a 1:20 slope.
Notice though that that same line will start to indicate maximum sink rate (2.8 m/s) below 15m (or 35m if radar altimeter is off), so when that happens be sure to keep the flight path indicator above or on the line when that happens to not risk stress the landing gears, but still below the horizon so you don't overshoot.
You will notice when that happens if u keep your eyes peeled on the HUD, the line will do a 'jump' and no longer be fixed, and at the same time if ILS/glideslope is set, it will no longer follow that, so last part is always a non aided (except for sink rate) visual landing.
Also notice that the HUD will before descent when in landing mode assist you in hitting the 550Km/h speed, by moving the 'tail' on the flight path indicator.
That same tail will during descent help you keep your AoA (9-12 or 15.5 if that button is engaged).
Now if you did not press the 15.5 button, then do a small flare before you touchdown.
If you engaged reverser, then apply thrust after touchdown.

Example 2: Ad-hoc visual landing with A/T
-----------------------------------------
Do the same as above but with engaged auto-throttle.
When you extend gears, it will automatically keep your AoA.

Example 3: AJ37 landing with waypoint  (TODO: update and move to aj37 readme, and replace with ja37 version)
-------------------------------------
In no particular order do these:
1: get the barometer QFE from the ATC tower and set it.
2: be sure the active waypoint in the Route manager is set to the correct airport and runway.
3: use the switch LANDING MODE, or hit 'Y'
4: Tune into ILS. [optional]
5: Engage reverse thrust if you want it to engage auto when you land.
6: Adjust the approach length on the left panel with the switch APPROACH. 5.4 or 10.8 Nmiles.
7: Click the button 15.5 for short runways.

Notice there is now shown altitude lines on HUD and radar, start descending to align to them and aim for hitting tangentially the circle shown on radar Pinto talks about. When you hit the approach circle, you are supposed to be at 550Km/h or 297 Kt and 500m/1640ft above the airport, and you just follow the circle around keeping that speed. The approach circle is always 4.1 Km radius. For short approaches you will then immediately start descending when you hit the approach line, and for long approaches you will follow that line until half (5.4 NM out) and then start descending. The HUD will show the 2.86 deg descent line when you hit that 10 Km mark, which of-course fits, since there is 10000m left to touchdown and you are 500m above it, so a 1:20 slope. Notice though that that same line will start to indicate maximum sink rate (2.8 m/s) below 15m (or 35m if radar altimeter is off), so when that happens be sure to keep the flight path indicator above or on the line when that happens to not risk stress the landing gears, but still below the horizon so you don't overshoot. You will notice when that happens if u keep your eyes peeled on the HUD, the line will do a 'jump' and no longer be fixed, and at the same time if ILS/glideslope is set, it will no longer follow that, so last part is always a non aided (except for sink rate) visual landing. Also notice that the HUD will before descent when in landing mode assist you in hitting the 550Km/h speed, by moving the 'tail' on the flight path indicator. That same tail will during descent help you keep your AoA (9-12 or 15.5 if that button is engaged).



Pre-load flightplans and/or map areas on startup.
=================================================
Use these command lines to pass a plan/area in launcher: (they must be in GPX or FG route format)

--prop:string:/xmlPlans/mission1=
--prop:string:/xmlPlans/mission1=
--prop:string:/xmlPlans/mission1=
--prop:string:/xmlPlans/mission1=
--prop:string:/xmlPlans/rtb1A=
--prop:string:/xmlPlans/rtb1B=
--prop:string:/xmlPlans/rtb2A=
--prop:string:/xmlPlans/rtb2B=
--prop:string:/xmlPlans/rtb3A=
--prop:string:/xmlPlans/rtb3B=
--prop:string:/xmlPlans/rtb4A=
--prop:string:/xmlPlans/rtb4B=
--prop:string:/xmlPlans/area1=
--prop:string:/xmlPlans/area1=
--prop:string:/xmlPlans/area1=
--prop:string:/xmlPlans/area1=
--prop:string:/xmlPlans/area1=
--prop:string:/xmlPlans/area1=

Areas should have max 8 waypoints each.
Missions/RTB should have max 48 waypoints each.
Pre-loading needs FG 2017.3.1 to work.

Example: --prop:string:/xmlPlans/area3=c:\areas\myNoFlyZone.gpx

If a file cannot get loaded, the console will print a warning.

Bulls-eye can be preloaded with enabling 3 properties.

This example will place a Bulls-eye in Nevada, US:

--prop:bool:/ja37/navigation/bulls-eye-defined=true
--prop:double:ja37/navigation/bulls-eye-lat=37.20
--prop:double:ja37/navigation/bulls-eye-lon=-115.60
