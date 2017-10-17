#
#
#
#         JA-37Di Mini-manual
#
#
#

Some of these features that has to do with multiple flightplans or map-areas, wont work in older than FG 2017.3.1.

Flightplans
===========
The aircraft has 6 plans. 4 mission (1-4) and 2 return to base plans (A & B).
When you switch to another plan, entire plan in route manager will be replaced. So don't panic if route-manager clears.
See also last section in this document: pre-loading plans.
If your FG is older than 2017.3.1 you will only have 1 plan, that is used for both mission and RTB.
Notice since clicking key 'Y' is the same as LS on TI display, this will also switch plan if you are already on a mission plan.

Concise English overview of TI (right color display)
==============================
Click a sidebutton for quick SYST menu.
Click a bottom button for main menus.
Click MENU to exit menus.

The rocker switch C will make minute adjustments for where on display own position is located.
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

SYST
----
S - Mission steerpoint nav. or switch to next. Will also switch of landing mode and switch to mission plan.
L - Navigate direct for landing base or switch runway. Will switch to RTB plan destination.
LT - Nav. for touchdown point or short approach. Will switch to RTB plan destination. Notice if this is done on runway, OPT will engage.
LS - Nav. for approach circle (long approach). Will switch to RTB plan destination. Notice if this is done on runway, OPT will engage.
OPT - Optical landing mode. Can only be engaged with gears down or in landing mode (LS or LT). Will auto engage at low alt in those modes.
DL - STRILL data-link  (not implemented)
LR - Return to base polygon navigation. Or switch to next steerpoint in that.
MPOL - Mission polygon
RPOL - RTB polygon
CC - Steer order from radar. Only work in air. (Right now it also unauthentically will set A/P to follow the steer order, will be fixed in future)
OFF/EP - Turn off EP12 Electronic presentations (MI+TI displays). Only work on ground.
ACRV - Attack curve (not implemented)
FGHT - Fighter mode. HUD shows IAS
ATCK - Attack mode. HUD shows groundspeed (at low alt)

TRAP
----
LOCK - Radar lock events
FIRE - Weapon fire events
ECM  - Weapon hit events (unauthentic)
MAN  - Manual events log
LAND - Landing events
CLR  - Clear all TRAP.
DOWN - scroll down
UP   - scroll up

DISP
----
EMAP - Electronic map. NORM/MAX toggles if map places on map. AIRP toggles airports on map (might give some stutter).
SCAL - Map scale.
AAA  - Anti aircraft fire zones. FRND/HSTL show friendly/hostile zones.
TIME - Show ZULU time.
HORI - Show FPI, artificial horizon and ground symbol. CLR = certain conditions. ON = always. OFF = only at terrain impact warning.
CURS - Toggle if cursor is on MI or TI. (PEK on MI must be enabled to see/use cursor)
DAY  - Map contrast for daytime or NGHT for night time.

MSDA
----
EDIT
  POLY  - Edit area polygons. Click with cursor on top field in infobox to control from DAP which area is edited.
  RPOL  - Edit a RTB polygon.
  MPOL  - Edit a mission polygon.
  S/P   - Move selected point/steerpoint in current edited polygon. Then use cursor.
INS S/P - Insert selected point/steerpoint in current edited polygon. Then use cursor.
ADD S/P - Append point/steerpoint to current edited polygon (if it has room for more). Then use cursor.
DEL S/P - Delete selected point/steerpoint in current edited polygon.
RPOL    - If RPOL being edited, this is which one.
MPOL    - If MPOL being edited, this is which one.
MYPS    - Move own position in chunks up/down the display. If not framed minute adjustments have been made.
MMAN    - MapManual movement, and map no longer follows own position. See cursor for more details.

FAIL
----
Is just a log page. FAIL will blink at new unseen failures.

CONF
----
SIDV     - Sideview menu. See Mi on hwo to activate sideview.
GPS      - Activate GPS menu.
FR28     - Use top or belly radio antennae. Effect not implemented.
READDATA - Technician data readout. Not implemented.

GPS
---
FIX  - When GPS has started this will make a fix on the TI/MI/HUD. Will stay until PEK switched off or something else selected.
INIT - Start GPS. (approx 30 seconds to start)

SIDV
----
WIN  - Sideview size
SHOW - Inclusion setting. Not implemented.
SCAL - If RMAX set to SCAL this controls the horizon distance shown.
RMAX - Horizontal distance. MI=follow radar setting. SCAL=see SCAL. MAP=Follow map scale.
AMAX - Max altitude shown.

Cursor on TI
============
When cursor is on TI it can be slewed: Pressing key 'y' will toggle slaving flight-controls to the cursor.
Use trigger to click on something.
You can click on all side and bottom buttons, except when EDIT, ADD or INS steerpoint/map-area-point. Also when not in any menu.
Sometimes in menu MSDA a white info box is shown. Some fields can be clicked, and then input on the data-panel. Field will blink when input active.
When MMAN is enabled, manual map centering can be done by clicking on the map. Notice this can be confusing if MYPS is not set to 3.
Terrain impact warning will switch the slaving off.

Concise English overview of MI on JA-37Di: (center radar display)
==========================================
bottom buttons (hold P3 for help)
--------------
2  - SDV - Toggle sideview on TI
X1 - BIT - RB99 self tests
X3 - EVN - Register manual event (can be viewed in TRAP menu)
M2 - ECM - Toggle ECM on TI
X2 - LNK - Toggle RB99 telemetry on TI

left buttons
------------
PEK - Cursor toggle. If off then cant lock anything. Nor can cursor be shown/slewn on TI.
A - Zoom out on TI
B - Zoom in on TI

Concise overview of Datapanel (DAP) (on right panel, has keypad and display)
===================================

OK button is on nav panel, called BX. (due to the nav. panel is really from the AJ)
Nav. panel is located just next to data-panel.

Notice first the switch IN/OUT.
Below is listed what combination of that switch with the knob will produce:

OUT
- TI:     Show flight time on TI.
- TILS:   Shows current TILS frequency on display.
- CL/DA:  Show date/time on display. Cycle with OK.
- FUEL:   Show extra fuel warning setting in percent on display.
- LOLA:   Show current LON/LAT on display. Cycle with OK. (it will not show negative sign if longitude degrees is more than 2 digits, the JA was only used in Sweden)
- ACDATA:

IN
- TI:     Can clear currently edited flightplan/map-area by pressing CLEAR.
- TILS:  
- CL/DA:  Set date/time. Entering 999999 for either date or time will reset.
- FUEL:   Set extra fuel warning in percent on display.
- LOLA:  
- ACDATA:

REG/STR:
- IN:  Input 2 digits for address, then either the value you want to set, or switch to OUT.
- OUT: If 2 first digits entered will show value of address in last 4 digits.
- ADDRESSES:
    19xxxx is training floor altitude.

"237" on display
- Input to TI press OK to send.

"Error" on display
- rotate knob or in/out switch to clear.

When inputting, pay notice to the switch +/-, as that is the sign of what you input.

Pre-load flightplans and/or map areas on startup.
=================================================
Use these command lines to pass a plan/area in launcher: (they must be in GPX or FG route format)

--prop:string:/xmlPlans/mission1=
--prop:string:/xmlPlans/mission1=
--prop:string:/xmlPlans/mission1=
--prop:string:/xmlPlans/mission1=
--prop:string:/xmlPlans/rtb1A=
--prop:string:/xmlPlans/rtb1B=
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

Landing
=======
Rules
-----
Max allowed sidewind for short landing without flare: 30 Km/h - 16.2 kt
Max allowed sidewind for standard landing with flare: 55 Km/h - 29.7 kt
Landing must be standard with flare at aircraft weights over 15000 Kg or if there is fuel in the droptank.
Reversing handle must not be pulled out before landing gear is out and locked, and indicator panel has 3 green lights.
Max allowed EPR (engine pressure ratio) at initialization of reverser is 1.75.
Max allowed reverse at stationary aircraft is 1.4 EPR.
Max rolling speed in groundspeed: 320 Km/h (172.8 Kt).
Max touchdown pitch: 20.5 deg clearing uncompressed, 16 deg partial compressed at flare, 14 degs fully compressed.
Minimum touchdown speed 100 kt (only at 15.5 AoA short landings of course).
Nosewheel touchdown speed: latest at 160 KM/h (86 kt).

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