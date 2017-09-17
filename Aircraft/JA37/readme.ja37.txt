#
#
#
#         JA-37Di Mini-manual
#
#
#

Some of these features that has to do with multiple plans or areas, wont work in less than FG 2017.3.1.

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
FR28     - Use top or belly antennae. Effect not implemented.
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
- REG/STR:

IN
- TI:     Can clear currently edited flightplan/map-area by pressing RESET.
- TILS:  
- CL/DA:  Set date/time. Entering 999999 for either date or time will reset.
- FUEL:   Set extra fuel warning in percent on display.
- LOLA:  
- ACDATA:
- REG/STR:

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