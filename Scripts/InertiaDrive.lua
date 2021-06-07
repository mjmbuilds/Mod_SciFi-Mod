dofile "Utility.lua"

InertiaDrive = class()
InertiaDrive.maxParentCount = -1
InertiaDrive.maxChildCount = -1
InertiaDrive.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
InertiaDrive.connectionOutput = sm.interactable.connectionType.logic
InertiaDrive.colorNormal = sm.color.new( 0xdb4e16ff )
InertiaDrive.colorHighlight = sm.color.new( 0xff5e19ff )
InertiaDrive.poseWeightCount = 1

--[[ NOTES
- should have protection against more than one drive used on the saem reation (check for others upon creation or lift)
- should have an error message GUI to tell the user things like "you can not use multiple drives"
- should publish list of understood signals
- should have gears
- GUI should have instructions panel

---GUI options per gear
-Antigrav INPUT/ON/OFF
-Antigrav Power (0-100%)
-Pitch AutoLevel INPUT/ON/OFF
-Roll AutoLevel INPUT/ON/OFF
-Power level linear L/R
-Power level linear F/B
-Power level linear U/D
-Power level pitch
-Power level roll
-Power level yaw
-Accereration Ramp (linear)
-Deceleration Tamp (linear)
-Drag level linear L/R
-Drag level linear F/B
-Drag level linear U/D
-Drag level pitch
-Drag level roll
-Drag level yaw
--]]

InertiaDrive.recognizedInputs = {
"GUI", -- opens the GUI menu
"Power",
"Gear up",
"Gear down",
"Gear 1",
"Gear 2",
"Gear 3",
"Gear 4",
"Gear 5",
"Gear 6",
"Pitch Up",
"Pitch Down",
"Roll Left",
"Roll Right",
"Yaw Left",
"Yaw Right",
"Forward)",
"Back",
"Left",
"Right",
"Up",
"Down",
"Forward Global",
"Back Global",
"Left Global",
"Right Global",
"Up Global",
"Down Global",
"Antigrav", -- if not used, defaults to on
"Autolevel", -- pitch and roll
"Autolevel Roll",
"Autolevel Pitch",
"Pitch Lock", -- saves current pitch as value for pitch leveling
"Altitude Hold",
"Location Hold",
"Hover Shake"
}

function InertiaDrive.server_onCreate( self )
	self.interactable:setPublicData({"recognizedInputs" = self.recognizedInputs})


end
































