dofile "Utility.lua"
dofile("ModPaths.lua")
dofile("ModShapes.lua")

InertiaDrive = class()
InertiaDrive.maxParentCount = -1
InertiaDrive.maxChildCount = -1
InertiaDrive.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
InertiaDrive.connectionOutput = sm.interactable.connectionType.logic
InertiaDrive.colorNormal = sm.color.new( 0xdb4e16ff )
InertiaDrive.colorHighlight = sm.color.new( 0xff5e19ff )
InertiaDrive.poseWeightCount = 1

InertiaDrive.altitudeHoldMargin = 0.1
InertiaDrive.locationHoldMargin = 0.1

--[[ NOTES ---------------------------------------------------------------------
---- TODO:
-COM calc, try using body:getCenterOfMassPosition()
-linear forces should be applied per body (mass should be left out of initial liner vextors, and added per body in a loop)
-should have protection against more than one drive used on the saem reation (check for others upon creation or lift)
-should have an error message GUI to tell the user things like "you can not use multiple drives"
-SAFETY: inertia drive could have a safety feature where if it goes out of world bounds it will put itself on the lift
-troubleshoot linear forces not always acting like on the COG
-GUI should have instructions panel

---- Possible future upgrades:
-speed ramping option (adjustable acceleration/decereration curves)
-hover shake module (connect as input to generate hover wobble/shake for effect)
-ground hover sensor (connect as input to maintain distance from terrain)

--------------------------------------------------------------------------------]]


---- list of the advanved input names that are recognized
InertiaDrive.inputList = {
	"OPEN GUI",
	"NEXT GEAR",
	"PREV GEAR",
	"GEAR 1",
	"GEAR 2",
	"GEAR 3",
	"GEAR 4",
	"GEAR 5",
	"GEAR 6",
	"PITCH UP",
	"PITCH DOWN",
	"ROLL LEFT",
	"ROLL RIGHT",
	"YAW LEFT",
	"YAW RIGHT",
	"FORWARD",
	"BACK",
	"LEFT",
	"RIGHT",
	"UP",
	"DOWN",
	"FORWARD GLOBAL",
	"BACK GLOBAL",
	"LEFT GLOBAL",
	"RIGHT GLOBAL",
	"UP GLOBAL",
	"DOWN GLOBAL",
	"POWER",
	"ANTIGRAV", -- default ON
	"AUTOLEVEL", -- includes pitch and roll
	"AUTOLEVEL ROLL",
	"AUTOLEVEL PITCH",
	"ALTITUDE LOCK",
	"LOCATION LOCK",
	"LANDING LIFT",
	"EMERGENCY LIFT"
}

InertiaDrive.defaultGear = {
	antigravEnabled = true,		-- defaults on but can be toggled with a switch
	pitchAutoLevel = false,		-- defaults off and can be turned on with switch, true = always on
	rollAutoLevel = false,		-- defaults off and can be turned on with switch, true = always on
	powerRight = 500,			-- power level left/right translation (1000)
	powerForward = 500,			-- power level forward/back translation (3000)
	powerUp = 500,				-- power level up/down translation (2000)
	powerPitch = 100,			-- power level pitch rotation (450)
	powerRoll = 50,				-- power level roll rotation (250)
	powerYaw = 100,				-- power level yaw rotation (450)
	dragRight = 25,				-- drag damping left/right (400)
	dragForward = 25,			-- drag damping forward/back(100)
	dragUp = 25,				-- drag damping up/down (400)
	dragPitch = 1,				-- drag damping pitch (200)
	dragRoll = 0.25,			-- drag damping roll (100)
	dragYaw = 1,				-- drag damping yaw (200)
	antigravPower = 100,		-- 0-100%
	powerAutoLevelPitch = 50,	-- power level autolevel pitch (200)
	powerAutoLevelRoll = 5,		-- power level autolevel roll (200)
	powerAltitudeLock = 20,		-- power level altitude lock
	powerLocationLock = 20		-- power level location lock
}

function InertiaDrive.server_onCreate( self )
	self.sv_data = self.storage:load() or {}
	self.sv_data.currentGear = self.sv_data.currentGear or 1
	for g = 1, 6 do
		for k, v in pairs(self.defaultGear) do
			self.sv_data[k..g] = self.sv_data[k..g] or v
		end
	end
	self.publicData = {}
	self.publicData.inputList = self.inputList
	self.publicData.partName = "Inertia Drive"
	self.publicData.gear = self.sv_data.currentGear
	self.interactable:setPublicData(self.publicData)
end
function InertiaDrive.server_onRefresh( self )
	print("* * * * * REFRESH Inertia Drive * * * * *")
	self:server_onCreate()
end

function InertiaDrive.sv_setData( self, data )
	for k, v in pairs(data) do
		self.sv_data[k] = v
	end
	self.storage:save(self.sv_data)
	if data.currentGear then
		self.publicData.gear = data.currentGear
		self.interactable:setPublicData(self.publicData)
	end
end

function InertiaDrive.sv_requestGuiData( self, player )
	self.network:sendToClient(player, "cl_openGui", self.sv_data)
end

function InertiaDrive.server_onFixedUpdate( self, dt )
		
	----- get inputs from advanced buttons
	local inputs = {}
	local player = nil
	inputs["ANTIGRAV"] = true -- antigrad defaults true, all others default false(nil)
	for _, input in pairs(self.interactable:getParents()) do
		if input.type == "scripted" and input:getPublicData() and input:getPublicData().name then
			local name = input:getPublicData().name
			if name == "ANTIGRAV" then
				inputs["ANTIGRAV"] = false
			end
			if input:isActive() then
				inputs[name] = true
				if name == "EMERGENCY LIFT" or name == "OPEN GUI" then
					player = input:getPublicData().player
				end
			end
		end
	end

	----- check if last lift data needs updating (also affects need to cal orientation reference)
	local updateLift = false
	local isOnLift = self.shape.body:isOnLift()
	if not self.prevOnLift and isOnLift then
		updateLift = true
	end
	self.prevOnLift = isOnLift
	
	----- calc orientation reference if required
	local driveUp = nil
	local driveRight = nil
	local driveFront = nil
	local moduleShape = nil
	local seatShape = nil
	if inputs["POWER"] or updateLift or inputs["LANDING LIFT"] then
		for _, parent in pairs(self.interactable:getParents()) do
			if parent:getShape():getShapeUuid() == mjm_orientation_module then
				moduleShape = parent:getShape()
				break
			elseif not seatShape and parent:hasOutputType(sm.interactable.connectionType.seated) then
				seatShape = parent:getShape()
			end
		end
		if moduleShape then
			driveUp = moduleShape.up
			driveRight = moduleShape.right
			driveFront = moduleShape.at
		elseif seatShape then
			driveUp = seatShape.at
			driveRight = seatShape.right * -1
			driveFront = seatShape.up
		else
			driveUp = self.shape.up
			driveRight = self.shape.right
			driveFront = self.shape.at
		end
	end
	
	----- update last lift data if required
	if updateLift then
		self.lastLiftLocation = self.shape:getWorldPosition()
		if driveFront.y == -1 then
			self.lastLiftRotation = 1
		elseif driveFront.x == 1 then
			self.lastLiftRotation = 2
		elseif driveFront.y == 1 then
			self.lastLiftRotation = 3
		else --driveFront.x == -1
			self.lastLiftRotation = 4
		end
	end

	----- check for usage of Emergency Lift
	if inputs["EMERGENCY LIFT"] and not self.prevEmergencyLift then
		self:sv_emergencyLift(player)
	end
	self.prevEmergencyLift = inputs["EMERGENCY LIFT"]

	----- check for usage of Landing Lift
	if inputs["LANDING LIFT"] and not self.prevLiftLanding then
		local liftRotation = 1
		if driveFront.x > 0.707107 then
			liftRotation = 2
		elseif driveFront.y > 0.707107 then
			liftRotation = 3
		elseif driveFront.x < -0.707107 then
			liftRotation = 4
		end
		self:sv_liftLanding(player, liftRotation)
	end
	self.prevLiftLanding = inputs["LANDING LIFT"]

	----- check for use of openeing Gui from button
	if inputs["OPEN GUI"] and not self.prevOpenGui and player then
		self:sv_requestGuiData(player)
	end
	self.prevOpenGui = inputs["OPEN GUI"]

	----- check for Gear changes
	if inputs["NEXT GEAR"] and not self.prevNextGear then
		local newGear = self.sv_data.currentGear
		newGear = newGear < 6 and newGear + 1 or 6
		self:sv_setData({currentGear = newGear})
	end
	self.prevNextGear = inputs["NEXT GEAR"]
	if inputs["PREV GEAR"] and not self.prevPrevGear then
		local newGear = self.sv_data.currentGear
		newGear = newGear > 1 and newGear - 1 or 1
		self:sv_setData({currentGear = newGear})
	end
	self.prevPrevGear = inputs["PREV GEAR"]
	if inputs["GEAR 1"] and not self.prevGear1 then
		self:sv_setData({currentGear = 1})
	end
	self.prevGear1 = inputs["GEAR 1"]
	if inputs["GEAR 2"] and not self.prevGear2 then
		self:sv_setData({currentGear = 2})
	end
	self.prevGear2 = inputs["GEAR 2"]
	if inputs["GEAR 3"] and not self.prevGear3 then
		self:sv_setData({currentGear = 3})
	end
	self.prevGear3 = inputs["GEAR 3"]
	if inputs["GEAR 4"] and not self.prevGear4 then
		self:sv_setData({currentGear = 4})
	end
	self.prevGear4 = inputs["GEAR 4"]
	if inputs["GEAR 5"] and not self.prevGear5 then
		self:sv_setData({currentGear = 5})
	end
	self.prevGear5 = inputs["GEAR 5"]
	if inputs["GEAR 6"] and not self.prevGear6 then
		self:sv_setData({currentGear = 6})
	end
	self.prevGear6 = inputs["GEAR 6"]

	----- calc impulses if powered on
	if inputs["POWER"] then
		local g = self.sv_data.currentGear
		local d = self.sv_data
	
		---- adjustments related to power reset
		local applyImpulse = true
		if not self.prevPower then
			applyImpulse = false        -- impusle needs to be skipped on first tick of power
			self.prevAltitudeLock = nil -- reset previous altitude lock flag
			self.prevLocationLock = nil -- reset previous location lock flag
		end

		----- calc linear input
		local linearInput = sm.vec3.zero()
		local inputRight = (inputs["RIGHT"] and 1 or 0) + (inputs["LEFT"] and -1 or 0)
		if inputRight ~= 0 then
			linearInput = linearInput + (driveRight * inputRight * d["powerRight"..g])
		end
		local inputUp = (inputs["UP"] and 1 or 0) + (inputs["DOWN"] and -1 or 0)
		if inputUp ~= 0 then
			linearInput = linearInput + (driveUp * inputUp * d["powerUp"..g])
		end
		local inputForward = (inputs["FORWARD"] and 1 or 0) + (inputs["BACK"] and -1 or 0)
		if inputForward ~= 0 then
			linearInput = linearInput + (driveFront * inputForward * d["powerForward"..g])
		end
		local inputRightGlobal = (inputs["RIGHT GLOBAL"] and 1 or 0) + (inputs["LEFT GLOBAL"] and -1 or 0)
		if inputRightGlobal ~= 0 then
			local globRight = driveRight
			globRight.z = 0
			linearInput = linearInput + (globRight * inputRightGlobal * d["powerRight"..g])
		end
		local inputUpGlobal = (inputs["UP GLOBAL"] and 1 or 0) + (inputs["DOWN GLOBAL"] and -1 or 0)
		if inputUpGlobal ~= 0 then
			local globUp = sm.vec3.new(0,0,1)
			linearInput = linearInput + (globUp * inputUpGlobal * d["powerUp"..g])
		end
		local inputForwardGlobal = (inputs["FORWARD GLOBAL"] and 1 or 0) + (inputs["BACK GLOBAL"] and -1 or 0)
		if inputForwardGlobal ~= 0 then
			local globForward = driveFront
			globForward.z = 0
			linearInput = linearInput + (globForward * inputForwardGlobal * d["powerForward"..g])
		end
		
		----- calc rotational input
		local pitchInput = sm.vec3.zero()
		local rollInput = sm.vec3.zero()
		local yawInput = sm.vec3.zero()
		local inputPitch = (inputs["PITCH UP"] and 1 or 0) + (inputs["PITCH DOWN"] and -1 or 0)
		if inputPitch ~= 0 then
			pitchInput = ((driveUp * -1) * inputPitch * d["powerPitch"..g])
		end
		local inputRoll = (inputs["ROLL RIGHT"] and 1 or 0) + (inputs["ROLL LEFT"] and -1 or 0)
		if inputRoll ~= 0 then
			rollInput = ((driveUp * -1) * inputRoll * d["powerRoll"..g])
		end
		local inputYaw = (inputs["YAW RIGHT"] and 1 or 0) + (inputs["YAW LEFT"] and -1 or 0)
		if inputYaw ~= 0 then
			yawInput = (driveRight * inputYaw * d["powerYaw"..g])
		end
		
		----- calc mass and COM offset
		local mass = 0
		local sumPos = sm.vec3.zero()
		for _,shape in pairs(self.shape.body:getCreationShapes()) do
			mass = mass + shape.mass
			sumPos = sumPos + (shape.worldPosition * shape.mass)
		end
		local comWorldPosition = sumPos / mass
		local comOffset = comWorldPosition - self.shape.worldPosition
		
		----- calc offset positions used when applying forces
		local frontOffset = comOffset + driveFront
		local backOffset = comOffset + (driveFront * -1)
		local rightOffset = comOffset + driveRight
		local leftOffset = comOffset + (driveRight * -1)
		
		----- calc world positions 
		local frontLoc = self.shape.worldPosition + frontOffset
		local backLoc = self.shape.worldPosition + backOffset
		local rightLoc = self.shape.worldPosition + rightOffset
		local leftLoc = self.shape.worldPosition + leftOffset
		
		----- calc linear drag
		local localLinDrag = toLocal(self.shape, self.shape.velocity) * -1
		local linDragFwd = toGlobal(self.shape, sm.vec3.new(0,localLinDrag.y,0)) * d["dragForward"..g]
		local linDragRight = toGlobal(self.shape, sm.vec3.new(localLinDrag.x,0,0)) * d["dragRight"..g]
		local linDragUp = toGlobal(self.shape, sm.vec3.new(0,0,localLinDrag.z)) * d["dragUp"..g]
		
		----- calc rotational drag
		local localRotDrag = toLocal(self.shape, self.shape.body.angularVelocity) * -1
		local angDragPitch = toGlobal(self.shape, sm.vec3.new(0,0,localRotDrag.x)) * d["dragPitch"..g]
		local angDragRoll = toGlobal(self.shape, sm.vec3.new(0,0,(localRotDrag.y * -1))) * d["dragRoll"..g]
		local angDragYaw = toGlobal(self.shape, sm.vec3.new((localRotDrag.z * -1),0,0)) * d["dragYaw"..g]
		
		----- calc antigrav
		local antigrav = sm.vec3.zero()
		if d["antigravEnabled"..g] then
			local antigravStrength = sm.physics.getGravity() * mass * 1.047494 * dt * (d["antigravPower"..g]/100)
			antigrav = sm.vec3.new(0,0,antigravStrength)
		end

		----- noise
		--local pitchNoise = sm.vec3.zero()
		--local rollNoise = sm.vec3.zero()
		--local heightNoise = sm.vec3.zero()
		--if hoverShake then
		--	heightNoise = driveUp * sm.noise.randomRange( (self.hoverNoise * -1), self.hoverNoise )
		--	pitchNoise = driveUp * sm.noise.randomRange( (self.levelNoise * -1), self.levelNoise )
		--	rollNoise = driveUp * sm.noise.randomRange( (self.levelNoise * -1), self.levelNoise )
		--end
		
		----- calc auto leveling
		local pitchLeveling = sm.vec3.zero()
		local rollLeveling = sm.vec3.zero()
		if inputs["AUTOLEVEL"] then -- AUTOLEVEL includes both pitch and roll
			inputs["AUTOLEVEL PITCH"] = true
			inputs["AUTOLEVEL ROLL"] = true
		end
		if inputs["PITCH LOCK"] then -- PITCH LOCK includes roll
			inputs["AUTOLEVEL ROLL"] = true
		end
		if inputs["AUTOLEVEL PITCH"] then
			pitchLeveling = driveUp * (backLoc.z - frontLoc.z)* d["powerAutoLevelPitch"..g]
		end
		if inputs["AUTOLEVEL ROLL"] then
			rollLeveling = driveUp * (leftLoc.z - rightLoc.z)* d["powerAutoLevelRoll"..g]
		end
		
		----- calc altitude lock
		local altitudeVec = sm.vec3.zero()
		if inputs["ALTITUDE LOCK"] then
			if not self.prevAltitudeLock then
				self.hoverAltitude = self.shape.worldPosition.z
			end
			if self.shape.worldPosition.z < self.hoverAltitude - self.altitudeHoldMargin then
				altitudeVec = altitudeVec + sm.vec3.new(0,0,d["powerAltitudeLock"..g])
			elseif self.shape.worldPosition.z > self.hoverAltitude + self.altitudeHoldMargin then
				altitudeVec = altitudeVec + sm.vec3.new(0,0,d["powerAltitudeLock"..g] * -1)
			end
		end
		self.prevAltitudeLock = inputs["ALTITUDE LOCK"]
		
		----- calc location lock
		local locationVec = sm.vec3.zero()
		if inputs["LOCATION LOCK"] then
			if not self.prevLocationLock then
				self.lockLocationX = self.shape.worldPosition.x
				self.lockLocationY = self.shape.worldPosition.y
			end
			if self.shape.worldPosition.x < self.lockLocationX - self.locationHoldMargin then
				locationVec = locationVec + sm.vec3.new(d["powerLocationLock"..g],0,0)
			elseif self.shape.worldPosition.x > self.lockLocationX + self.locationHoldMargin then
				locationVec = locationVec + sm.vec3.new(d["powerLocationLock"..g] * -1,0,0)
			end
			if self.shape.worldPosition.y < self.lockLocationY - self.locationHoldMargin then
				locationVec = locationVec + sm.vec3.new(0,d["powerLocationLock"..g],0)
			elseif self.shape.worldPosition.y > self.lockLocationY + self.locationHoldMargin then
				locationVec = locationVec + sm.vec3.new(0,d["powerLocationLock"..g] * -1,0)
			end
		end
		self.prevLocationLock = inputs["LOCATION LOCK"]
		
		----- calc compiled vec forces to apply
		local coreVec = antigrav + linearInput + linDragFwd + linDragRight + linDragUp + altitudeVec + locationVec --    + heightNoise
		local rightVec = rollInput + rollLeveling + angDragRoll --    + rollNoise 
		local leftVec = (rollInput * -1) - rollLeveling - angDragRoll --    - rollNoise
		local frontVec = pitchInput + angDragPitch + pitchLeveling + yawInput + angDragYaw --    + pitchNoise
		local backVec = (pitchInput * -1) - angDragPitch - pitchLeveling - yawInput - angDragYaw --    - pitchNoise
		
		----- apply impulses
		---------- applyImpulse(target,impulse,global,offset) ----------
		if applyImpulse then
			sm.physics.applyImpulse(self.shape, coreVec, true, comOffset)
			sm.physics.applyImpulse(self.shape, leftVec, true, leftOffset)
			sm.physics.applyImpulse(self.shape, rightVec, true, rightOffset)
			sm.physics.applyImpulse(self.shape, frontVec, true, frontOffset)
			sm.physics.applyImpulse(self.shape, backVec, true, backOffset)
		end
		
	end
	self.prevPower = inputs["POWER"]
	self.interactable:setActive(inputs["POWER"] or false)
end

function InertiaDrive.sv_emergencyLift( self, player )
	local body = self.shape:getBody()
	if player == nil then player = sm.player.getAllPlayers()[1]	end
	if body:isOnLift() then
		player:removeLift()
		return
	end
	local liftPos = self.lastLiftLocation or sm.vec3.zero()
	local raycastStart = sm.vec3.new(liftPos.x,liftPos.y,(liftPos.z + 1000))
	local raycastEnd = sm.vec3.new(liftPos.x,liftPos.y,(liftPos.z -1000))
	local success, result = sm.physics.raycast(raycastStart, raycastEnd)
	if success then
		liftPos = result.pointWorld
	end
	local liftRotation = self.lastLiftRotation or 1
	local liftHeight = 1
	player:placeLift({body}, (liftPos * 4), liftHeight, liftRotation)
end

function InertiaDrive.sv_liftLanding( self, player, liftRotation )
	local body = self.shape:getBody()
	if player == nil then player = sm.player.getAllPlayers()[1]	end
	if body:isOnLift() then
		player:removeLift()
		return
	end
	
	local maxX = nil
	local minX = nil
	local maxY = nil
	local minY = nil
	for _,shape in pairs(self.shape.body:getCreationShapes()) do
		local pos = shape.worldPosition
		if maxX == nil then
			maxX = pos.x
		else
			maxX = math.max(pos.x, maxX)
		end
		if minX == nil then
			minX = pos.x
		else
			minX = math.min(pos.x, minX)
		end
		if maxY == nil then
			maxY = pos.y
		else
			maxY = math.max(pos.y, maxY)
		end
		if minY == nil then
			minY = pos.y
		else
			minY = math.min(pos.y, minY)
		end
	end
	local castLen = 6
	local raycastStart = sm.vec3.new((maxX+minX)/2, (maxY+minY)/2, body:getCenterOfMassPosition().z)
	local raycastEnd = sm.vec3.new(raycastStart.x,raycastStart.y,(raycastStart.z - castLen))
	local success, result = sm.physics.raycast(raycastStart, raycastEnd, self.shape.body)
	if success then
		local liftPos = result.pointWorld
		local liftHeight = 10
		local heightSuccess, heightResult = sm.physics.raycast(liftPos + sm.vec3.new(0,0,0.25), liftPos + sm.vec3.new(0,0,castLen))
		if heightSuccess then
			liftHeight = math.floor(heightResult.fraction * castLen * 4 - 0.5)
		end
		if liftRotation == nil then
			liftRotation = 1
		elseif liftRotation == 1 then
			liftPos = sm.vec3.new(liftPos.x + 0.25, liftPos.y - 1.25, liftPos.z)
		elseif liftRotation == 2 then
			liftPos = sm.vec3.new(liftPos.x + 1.25, liftPos.y, liftPos.z)
		elseif liftRotation == 3 then
			liftPos = sm.vec3.new(liftPos.x, liftPos.y + 1, liftPos.z)
		else --liftRotation == 4
			liftPos = sm.vec3.new(liftPos.x - 1, liftPos.y - 0.25, liftPos.z)
		end
		player:placeLift({body}, (liftPos * 4), liftHeight, liftRotation)
	end
end

-- ____________________________________ Client ____________________________________

function InertiaDrive.client_onFixedUpdate( self, dt )
	-- set pose to show it power is on
	self.interactable:setPoseWeight(0, self.interactable:isActive() and 1 or 0)
end

-- use client_canInteract to override the messages shown when looking at the part
function InertiaDrive.client_canInteract( self )
	local interactKey = sm.gui.getKeyBinding("Use")
	sm.gui.setInteractionText("", interactKey, "Settings")
	return true
end

-- when the player "uses" the part (E)
function InertiaDrive.client_onInteract( self, character, lookAt )
	if lookAt then
		self.network:sendToServer("sv_requestGuiData", character:getPlayer())
	end
end

-- when gui is opened, set up callbacks
function InertiaDrive.cl_openGui( self, data )
	if data then self.cl_guiData = data end
	if not self.gui then self.gui = sm.gui.createGuiFromLayout(LAYOUTS_PATH..'InertiaDrive.layout') end
	self.gui:setOnCloseCallback("cl_onGuiClose")
	for g = 1, 6 do
		self.gui:setButtonCallback("Gear"..g, "cl_onGuiButtonClick")
		for k, v in pairs(self.defaultGear) do
			self.gui:setButtonCallback(k..g, "cl_onGuiButtonClick")
		end
	end
	self:cl_drawGui()	
	self.gui:open()
end

-- updates the GUI text and button states
function InertiaDrive.cl_drawGui( self )
	for g = 1, 6 do
		self.gui:setButtonState("Gear"..g, self.cl_guiData.currentGear == tostring(g))
		for k, v in pairs(self.defaultGear) do
			if k == "antigravEnabled" or k == "pitchAutoLevel" or k == "rollAutoLevel" then
				self.gui:setText(k..g, self.cl_guiData[k..g] and "ON" or "OFF")
			else
				self.gui:setText(k..g, ""..self.cl_guiData[k..g])
			end
		end
	end
end

-- when the GUI closes, send the server the updates if anything has changed
function InertiaDrive.cl_onGuiClose( self )
	if self.cl_newGuiData then
		self.network:sendToServer("sv_setData", self.cl_newGuiData)
	end
	self.cl_newGuiData = nil
end

-- when GUI buttons are clicked
function InertiaDrive.cl_onGuiButtonClick( self, buttonName )
	local name = buttonName:sub(1, -2)
	local g = buttonName:sub(-1)
	if name == "Gear" then
		if not self.cl_newGuiData then self.cl_newGuiData = {} end
		self.cl_newGuiData.currentGear = g
		self.cl_guiData.currentGear = g
		self:cl_drawGui()
	elseif name == "antigravEnabled" or name == "pitchAutoLevel" or name == "rollAutoLevel" then
		if not self.cl_newGuiData then self.cl_newGuiData = {} end
		local newState = not self.cl_guiData[buttonName]
		self.cl_newGuiData[buttonName] = newState
		self.cl_guiData[buttonName] = newState
		self.gui:setText(buttonName, newState and "ON" or "OFF")
	else
		local currentValue = self.cl_guiData[buttonName]
		self.gui:close()
		self:cl_openPowerInputGui(buttonName, currentValue)
	end

end 

-- number pad gui for editing values
function InertiaDrive.cl_openPowerInputGui( self, buttonName, currentValue )
	local name = buttonName:sub(1, -2)
	local g = buttonName:sub(-1)
	print("---open---")
	print(name)
	print(g)
	print(currentValue)

end



















