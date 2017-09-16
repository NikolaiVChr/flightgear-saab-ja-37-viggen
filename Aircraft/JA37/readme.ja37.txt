#
#
#         JA-37Di special help
#
#

Concise overview of datapanel (on right panel, has keypad and display)
=============================

OK button is on nav panel, called BX. (due to the nav. panel is really from the AJ)
Na. panel is located just next to data-panel.

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


Concise english overview of MI on JA-37Di: (center radar display)
==========================================
bottom buttons (hold P3 for help)
--------------
SDV - Sideview on TI
BIT - RB99 self tests
EVN - Register manual event (can be viewed in TRAP menu)
ECM - ECM on TI
LNK - RB99 telemetry on TI

left buttons
------------
PEK - Cursor toggle. If off then cant lock anything.
A - Zoom out on TI
B - Zoom in on TI


Concise english overview of TI abbreviations (right color display)
============================================
Click a sidebutton for quick menu (SYST).
Click a bottom button for main menus.
Click MENU to exit menus.

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
S - Steerpoint nav. or switch to next
P - Map-area point
L - Navigate direct for landing base or switch runway.
LT - Nav. for touchdown point or short approach
LS - Nav. for approach circle (long approach)
OPT - Optical landing mode
DL - STRILL data-link  (not implemented)
LR - Return to base polygon navigation. Or switch to next.
MPOL - Mission polygon
RPOL - RTB polygon
CC - Steer order from radar
OFF/EP - Turn off EP12 Electronic presentations (MI+TI displays)
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
CURS - Toggle if cursor is on MI or TI. 
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
MYPS    - Move own position in chunks up/down the display. If not framed minute adjustemnts have been made.
MMAN    - MapManual movement, and map no longer follows own position. See cursor for more details.

FAIL
----
Is just a log page. FAIL will blink at new unseen failures.

CONF
----
SIDV - Sideview menu. See Mi on hwo to activate sideview.
GPS  - Actiavte GPS menu.
FR28 - Use top or belly antennae.
READDATA- Not implemented.

GPS
---
FIX  - When GPS has started this will make a fix on the TI/MI/HUD. Will stay until PEK switched off or something else selected.
INIT - Start GPS. (approx 30 seconds to start)

SIDV
----
WIN  - Sideview size
SHOW - Not implemented.
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

Pre-load flightplans or map areas on startup.
=============================================
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