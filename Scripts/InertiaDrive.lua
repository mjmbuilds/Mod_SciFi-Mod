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

InertiaDrive.altitudeLockMargin = 0.1
InertiaDrive.locationLockMargin = 0.1

InertiaDrive.linPowerMult = 0.01
InertiaDrive.angPowerMult = 2
InertiaDrive.linDampingMult = 0.001
InertiaDrive.angDampingMult = 0.01

--[[ NOTES ---------------------------------------------------------------------
---- TODO:
-add global yaw mode
-add yaw lock mode
-ability to take input location values to automate movement
-should have protection against more than one drive used on the same creation (check for others upon creation or lift)
- ^ should have an error message GUI to tell the user things like "you can not use multiple drives"
-should have out-of-bounds detection automatically activate the EMERGENCY LIFT

---- comPossible future upgrades:
-speed ramping option (adjustable acceleration/decereration curves)
-hover shake module (connect as input to generate hover wobble/shake for effect)
-ground hover sensor (connect as input to maintain distance from terrain)

--------------------------------------------------------------------------------]]

InertiaDrive.helpMessage = ""..
	"To re-open this menu, click the \"HELP\" button in the upper right corner for the Inertia Drive menu.\n\n"..
	"WARNING: It is highly recommended that you use the \"EMERGENCY LIFT\" when configuring your Inertia Drive settings!!!\n"..
	"Activating it will place you and your build on your lift at the center of the world. This is good news if you find yourself flung into the void!\n\n"..
	"HOW TO USE: \n"..
	"Connect \"Advanced Button\"s as inputs and use their GUI to select a mode of input. The Inertia Drive will recognize those names when checking for input signals.\n"..
	"The Inertia Drive's movement orientation can be overridden by connecting either a seat or an \"Orientation Module\" as an input. Seats do not provide any WASD signal, for that you need to use a \"Seat Logic Breakout\" to read WASD and then send that through an \"Advanced Button\" to name it.\n"..
	"The GUI on the Inertia Drive itself will allow you to set the values for all the functions, and there are 6 profile \"modes\" that you can set up.\n"..
	"You must use trial and error to find the values that work best for your build's distribution of mass, but be careful, as setting values too high can launch you out of the world. For example, setting damping too high leads to exponentially worse overcorrection every tick. This is why you should use the \"EMERGENCY LIFT\" when dialing in your settings.\n"..
	"For convenience, you can set a button to open the GUI and make changes while seated. The changes may not take effect until closing the GUI."

---- list of the advanved input names that are recognized
InertiaDrive.inputList = {
	"OPEN GUI",
	"NEXT MODE",
	"PREV MODE",
	"MODE 1",
	"MODE 2",
	"MODE 3",
	"MODE 4",
	"MODE 5",
	"MODE 6",
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
	"EMERGENCY LIFT"
}

InertiaDrive.defaultMode = {
	["ANTIGRAV"] = true,			-- defaults on but can be toggled with a switch
	["AUTOLEVEL PITCH"] = false,	-- defaults off and can be turned on with switch, true = always on
	["AUTOLEVEL ROLL"] = false,		-- defaults off and can be turned on with switch, true = always on
	["POWER LATERAL"] = 500,		-- power level left/right translation
	["POWER AXIAL"] = 300,			-- power level forward/back translation
	["POWER VERTICAL"] = 200,		-- power level up/down translation
	["POWER PITCH"] = 500,			-- power level pitch rotation
	["POWER ROLL"] = 250,			-- power level roll rotation
	["POWER YAW"] = 650,			-- power level yaw rotation
	["DAMPING LATERAL"] = 1000,		-- drag damping left/right
	["DAMPING AXIAL"] = 1000,		-- drag damping forward/back
	["DAMPING VERTICAL"] = 1000,	-- drag damping up/down
	["DAMPING PITCH"] = 500,		-- drag damping pitch
	["DAMPING ROLL"] = 500,			-- drag damping roll
	["DAMPING YAW"] = 500,			-- drag damping yaw
	["POWER ANTIGRAV"] = 100,		-- % antigrav power
	["POWER AUTOLEVEL PITCH"] = 1000,-- power level autolevel pitch
	["POWER AUTOLEVEL ROLL"] = 500,	-- power level autolevel roll
}

function InertiaDrive.server_onCreate( self )
	self.sv_data = self.storage:load() or {}
	self.sv_data.currentMode = self.sv_data.currentMode or 1
	for m = 1, 6 do
		for k, v in pairs(self.defaultMode) do
			local value = self.sv_data[k..m]
			if value == nil then
				self.sv_data[k..m] = v
			else
				self.sv_data[k..m] = value
			end
			--self.sv_data[k..m] = (value ~= nil) and value or v
		end
	end
	self.publicData = {}
	self.publicData.inputList = self.inputList
	self.publicData.partName = "Inertia Drive"
	self.publicData.gear = self.sv_data.currentMode -- "gear" will be the name a display would look for
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
	if data.currentMode then
		self.publicData.gear = data.currentMode
		self.interactable:setPublicData(self.publicData)
	end
end

function InertiaDrive.sv_requestGuiData( self, player )
	self.network:sendToClient(player, "cl_openGui", self.sv_data)
end

function InertiaDrive.server_onFixedUpdate( self, dt )
	--self.shape:destroyShape()
	
	----- get inputs from advanced buttons
	local inputs = {}
	local player = nil
	inputs["ANTIGRAV"] = nil
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

	----- calc orientation reference if required
	local driveUp = nil
	local driveDown = nil
	local driveRight = nil
	local driveLeft = nil
	local driveFront = nil
	local driveBack = nil
	local moduleShape = nil
	local seatShape = nil
	if inputs["POWER"] then
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
		driveDown = driveUp * -1
		driveLeft = driveRight * -1
		driveBack = driveFront * -1
	end
	
	----- check for usage of Emergency Lift
	if inputs["EMERGENCY LIFT"] and not self.prevEmergencyLift then
		self:sv_emergencyLift(player)
	end
	self.prevEmergencyLift = inputs["EMERGENCY LIFT"]

	----- check for use of openeing Gui from button
	if inputs["OPEN GUI"] and not self.prevOpenGui and player then
		self:sv_requestGuiData(player)
	end
	self.prevOpenGui = inputs["OPEN GUI"]

	----- check for Mode changes
	if inputs["NEXT MODE"] and not self.prevNextMode then
		local newMode = tonumber(self.sv_data.currentMode)
		newMode = newMode < 6 and newMode + 1 or 6
		self:sv_setData({currentMode = newMode})
	end
	self.prevNextMode = inputs["NEXT MODE"]
	if inputs["PREV MODE"] and not self.prevPrevMode then
		local newMode = tonumber(self.sv_data.currentMode)
		newMode = newMode > 1 and newMode - 1 or 1
		self:sv_setData({currentMode = newMode})
	end
	self.prevPrevMode = inputs["PREV MODE"]
	if inputs["MODE 1"] and not self.prevMode1 then
		self:sv_setData({currentMode = 1})
	end
	self.prevMode1 = inputs["MODE 1"]
	if inputs["MODE 2"] and not self.prevMode2 then
		self:sv_setData({currentMode = 2})
	end
	self.prevMode2 = inputs["MODE 2"]
	if inputs["MODE 3"] and not self.prevMode3 then
		self:sv_setData({currentMode = 3})
	end
	self.prevMode3 = inputs["MODE 3"]
	if inputs["MODE 4"] and not self.prevMode4 then
		self:sv_setData({currentMode = 4})
	end
	self.prevMode4 = inputs["MODE 4"]
	if inputs["MODE 5"] and not self.prevMode5 then
		self:sv_setData({currentMode = 5})
	end
	self.prevMode5 = inputs["MODE 5"]
	if inputs["MODE 6"] and not self.prevMode6 then
		self:sv_setData({currentMode = 6})
	end
	self.prevMode6 = inputs["MODE 6"]

	----- calc impulses if powered on
	if inputs["POWER"] then
		local m = self.sv_data.currentMode
		local d = self.sv_data
	
		---- adjustments related to power reset
		local applyImpulse = true
		if not self.prevPower then
			applyImpulse = false        -- impusle needs to be skipped on first tick of power
			self.prevAltitudeLock = nil -- reset previous altitude lock flag
			self.prevLocationLock = nil -- reset previous location lock flag
		end

		----- calc linear input
		local linInput = sm.vec3.zero()
		local inputRight = (inputs["RIGHT"] and 1 or 0) + (inputs["LEFT"] and -1 or 0)
		if inputRight ~= 0 then
			linInput = linInput + (driveRight * inputRight * d["POWER LATERAL"..m] * self.linPowerMult)
		end
		local inputUp = (inputs["UP"] and 1 or 0) + (inputs["DOWN"] and -1 or 0)
		if inputUp ~= 0 then
			linInput = linInput + (driveUp * inputUp * d["POWER VERTICAL"..m] * self.linPowerMult)
		end
		local inputForward = (inputs["FORWARD"] and 1 or 0) + (inputs["BACK"] and -1 or 0)
		if inputForward ~= 0 then
			linInput = linInput + (driveFront * inputForward * d["POWER AXIAL"..m] * self.linPowerMult)
		end
		local inputRightGlobal = (inputs["RIGHT GLOBAL"] and 1 or 0) + (inputs["LEFT GLOBAL"] and -1 or 0)
		if inputRightGlobal ~= 0 then
			local globRight = driveRight
			globRight.z = 0
			linInput = linInput + (globRight * inputRightGlobal * d["POWER LATERAL"..m] * self.linPowerMult)
		end
		local inputUpGlobal = (inputs["UP GLOBAL"] and 1 or 0) + (inputs["DOWN GLOBAL"] and -1 or 0)
		if inputUpGlobal ~= 0 then
			local globUp = sm.vec3.new(0,0,1)
			linInput = linInput + (globUp * inputUpGlobal * d["POWER VERTICAL"..m] * self.linPowerMult)
		end
		local inputForwardGlobal = (inputs["FORWARD GLOBAL"] and 1 or 0) + (inputs["BACK GLOBAL"] and -1 or 0)
		if inputForwardGlobal ~= 0 then
			local globForward = driveFront
			globForward.z = 0
			linInput = linInput + (globForward * inputForwardGlobal * d["POWER AXIAL"..m] * self.linPowerMult)
		end
		
		----- calc rotational input
		local pitchInput = sm.vec3.zero()
		local rollInput = sm.vec3.zero()
		local yawInput = sm.vec3.zero()
		local inputPitch = (inputs["PITCH UP"] and 1 or 0) + (inputs["PITCH DOWN"] and -1 or 0)
		if inputPitch ~= 0 then
			pitchInput = (driveDown * inputPitch * d["POWER PITCH"..m] * self.angPowerMult)
		end
		local inputRoll = (inputs["ROLL RIGHT"] and 1 or 0) + (inputs["ROLL LEFT"] and -1 or 0)
		if inputRoll ~= 0 then
			rollInput = (driveDown * inputRoll * d["POWER ROLL"..m] * self.angPowerMult)
		end
		local inputYaw = (inputs["YAW RIGHT"] and 1 or 0) + (inputs["YAW LEFT"] and -1 or 0)
		if inputYaw ~= 0 then
			yawInput = (driveRight * inputYaw * d["POWER YAW"..m] * self.angPowerMult)
		end
		
		----- setup for velocity and force
		local body = self.shape.body
		local comPos = body:getCenterOfMassPosition()
		local isStatic = body:isStatic()
		if not isStatic and self.wasStatic then	self.lastComPos = comPos end	
		if not self.lastComPos then self.lastComPos = comPos end
		
		----- calc linear velocity and force for drag
		local axialVel = sm.vec3.zero()
		local lateralVel = sm.vec3.zero()
		local verticalVel = sm.vec3.zero()
		local axialForce = sm.vec3.zero()
		local lateralForce = sm.vec3.zero()
		local verticalForce = sm.vec3.zero()
		local shape = self.shape
		if moduleShape then	shape = moduleShape	elseif seatShape then shape = seatShape	end
		local localVel = toLocal(shape, shape.velocity)
		local localForce = toLocal(shape, (self.lastComPos - comPos))
		if shape == seatShape then
			axialVel = toGlobal(shape, sm.vec3.new(0,0,localVel.z))
			lateralVel = toGlobal(shape, sm.vec3.new(localVel.x,0,0))
			verticalVel = toGlobal(shape, sm.vec3.new(0,localVel.y,0))
			if not inputs["ALTITUDE LOCK"] then
				verticalForce = toGlobal(shape, sm.vec3.new(0,localForce.y,0))
			end
			if not inputs["LOCATION LOCK"] then
				axialForce = toGlobal(shape, sm.vec3.new(0,0,localForce.z))
				lateralForce = toGlobal(shape, sm.vec3.new(localForce.x,0,0))
			end
		else
			axialVel = toGlobal(shape, sm.vec3.new(0,localVel.y,0))
			lateralVel = toGlobal(shape, sm.vec3.new(localVel.x,0,0))
			verticalVel = toGlobal(shape, sm.vec3.new(0,0,localVel.z))
			if not inputs["ALTITUDE LOCK"] then
				verticalForce = toGlobal(shape, sm.vec3.new(0,0,localForce.z))	
			end
			if not inputs["LOCATION LOCK"] then
				axialForce = toGlobal(shape, sm.vec3.new(0,localForce.y,0))
				lateralForce = toGlobal(shape, sm.vec3.new(localForce.x,0,0))
			end		
		end
		
		----- calc altitude lock
		if inputs["ALTITUDE LOCK"] then
			if not self.prevAltitudeLock then
				self.lockZ = comPos.z
			end
			verticalForce = sm.vec3.new(0,0,self.lockZ - comPos.z)
		end
		self.prevAltitudeLock = inputs["ALTITUDE LOCK"]

		----- calc location lock
		if inputs["LOCATION LOCK"] then
			if not self.prevLocationLock then
				self.lockX = comPos.x
				self.lockY = comPos.y
			end
			axialForce = sm.vec3.new(self.lockX - comPos.x,0,0)
			lateralForce = sm.vec3.new(0,self.lockY - comPos.y,0)
		end
		self.prevLocationLock = inputs["LOCATION LOCK"]
		
		----- calc rotational drag from moment of inertia and angular velocity
		--[[
		Angular Momentum = Angular Velocity * Moment of Inertia
		Moment of Inertia = the sum of (the mass of each block times, the square of the distance each block is from the axis of rotation)
		--]]
		local creationMass = 0
		for _,cBody in pairs(shape.body:getCreationBodies()) do
			creationMass = creationMass + cBody.mass
		end
		--print(creationMass)
		local pitchUnitSum = 0
		local rollUnitSum = 0
		local yawUnitSum = 0
		for _,cShape in pairs(shape.body:getCreationShapes()) do
			local localComOffset = toLocal(shape,(cShape.worldPosition - comPos))
			pitchComOffset = sm.vec3.new(0,localComOffset.y,localComOffset.z)
			rollComOffset = sm.vec3.new(localComOffset.x,0,localComOffset.z)
			yawComOffset = sm.vec3.new(localComOffset.x,localComOffset.y,0)
			local pitchDistance = pitchComOffset:length2()
			local rollDistance = rollComOffset:length2()
			local yawDistance = yawComOffset:length2()
			if shape == seatShape then
				pitchUnitSum = pitchUnitSum + (cShape.mass * pitchDistance)
				rollUnitSum = rollUnitSum + (cShape.mass * yawDistance)
				yawUnitSum = yawUnitSum + (cShape.mass * rollDistance)
			else
				pitchUnitSum = pitchUnitSum + (cShape.mass * pitchDistance)
				rollUnitSum = rollUnitSum + (cShape.mass * rollDistance)
				yawUnitSum = yawUnitSum + (cShape.mass * yawDistance)
			end
		end
		pitchUnitSum = pitchUnitSum / 200
		rollUnitSum = rollUnitSum / 200
		yawUnitSum = yawUnitSum / 200
		
		local minUnit = 0.01
		local pitchMOI = math.max(minUnit,pitchUnitSum)
		local rollMOI = math.max(minUnit,rollUnitSum)
		local yawMOI = math.max(minUnit,yawUnitSum)

		local angVelPitch = sm.vec3.zero()
		local angVelRoll = sm.vec3.zero()
		local angVelYaw = sm.vec3.zero()
		local localAngVelocity = toLocal(shape, shape.body.angularVelocity) * -1
		if shape == seatShape then
			angVelPitch = toGlobal(shape, sm.vec3.new(0,localAngVelocity.x * -1,0))
			angVelRoll = toGlobal(shape, sm.vec3.new(0,(localAngVelocity.z * -1),0))
			angVelYaw = toGlobal(shape, sm.vec3.new((localAngVelocity.y),0,0))
		else
			angVelPitch = toGlobal(shape, sm.vec3.new(0,0,localAngVelocity.x))
			angVelRoll = toGlobal(shape, sm.vec3.new(0,0,(localAngVelocity.y * -1)))
			angVelYaw = toGlobal(shape, sm.vec3.new((localAngVelocity.z * -1),0,0))
		end
		
		local dampingPitch = (angVelPitch * pitchMOI * 2.0) * (d["DAMPING PITCH"..m] * self.angDampingMult) * (dt * 40)
		local dampingRoll = (angVelRoll * rollMOI * 2.0) * (d["DAMPING ROLL"..m] * self.angDampingMult) * (dt * 40)
		local dampingYaw = (angVelYaw * yawMOI * 2.0) * (d["DAMPING YAW"..m] * self.angDampingMult) * (dt * 40)
		
		if creationMass < 50 then 
			dampingPitch = dampingPitch / 3
			dampingRoll = dampingRoll / 3
			dampingYaw = dampingYaw / 3
		end
		
		----- calc antigrav
		local antigrav = sm.vec3.zero()
		local useAntigrav = false
		if inputs["ANTIGRAV"] ~= nil then
			useAntigrav = inputs["ANTIGRAV"]
		elseif d["ANTIGRAV"..m] then
			useAntigrav = true
		end
		if useAntigrav then
			local antigravStrength = sm.physics.getGravity() * 1.047494 * dt * (d["POWER ANTIGRAV"..m]/100)
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
		if inputs["AUTOLEVEL PITCH"] or d["AUTOLEVEL PITCH"..m] then
			pitchLeveling = driveUp * (driveBack.z - driveFront.z)* d["POWER AUTOLEVEL PITCH"..m] * self.angPowerMult
		end
		if inputs["AUTOLEVEL ROLL"] or d["AUTOLEVEL ROLL"..m] then
			rollLeveling = driveUp * (driveLeft.z - driveRight.z)* d["POWER AUTOLEVEL ROLL"..m] * self.angPowerMult
		end
				
		----- calc compiled vec forces to apply
		local rightVec = rollInput + rollLeveling + dampingRoll --    + rollNoise 
		local leftVec = (rollInput * -1) - rollLeveling - dampingRoll --    - rollNoise
		local frontVec = pitchInput + dampingPitch + pitchLeveling + yawInput + dampingYaw --    + pitchNoise
		local backVec = (pitchInput * -1) - dampingPitch - pitchLeveling - yawInput - dampingYaw --    - pitchNoise
		
		----- applyImpulse(target,impulse,global,offset)
		if applyImpulse then
			-- translational impulses
			for _,cBody in pairs(body:getCreationBodies()) do
				local cbMass = cBody.mass
				local cbAntigrav = antigrav * cbMass
				local cbLinInput = linInput * cbMass
				local linDragFwd = ((axialForce * cbMass * 2) - (axialVel * cbMass * 0.3)) * (d["DAMPING AXIAL"..m] * self.linDampingMult) * (dt * 40)
				local linDragRight = ((lateralForce * cbMass * 2) - (lateralVel * cbMass * 0.3)) * (d["DAMPING LATERAL"..m] * self.linDampingMult) * (dt * 40)
				local linDragUp = ((verticalForce * cbMass * 2) - (verticalVel * cbMass * 0.3)) * (d["DAMPING VERTICAL"..m] * self.linDampingMult) * (dt * 40)
				local coreVec = cbAntigrav + cbLinInput + linDragFwd + linDragRight + linDragUp -- + (heightNoise * cbMass)
				sm.physics.applyImpulse(body, coreVec, true)
			end
			-- rotational impulses
			sm.physics.applyImpulse(body, leftVec, true, driveRight * -1)
			sm.physics.applyImpulse(body, rightVec, true, driveRight)
			sm.physics.applyImpulse(body, frontVec, true, driveFront)
			sm.physics.applyImpulse(body, backVec, true, driveFront * -1)
		end
		
		----- update values
		self.wasStatic = isStatic
		self.lastComPos = comPos
		
	end
	self.prevPower = inputs["POWER"]
	self.interactable:setActive(inputs["POWER"] or false)
end

function InertiaDrive.sv_emergencyLift( self, player )
	if self.shape.body:isOnLift() then 
		if self.liftPlayer then
			self.liftPlayer:removeLift()
			self.liftPlayer = nil
		end
		return
	end
	if player == nil then player = sm.player.getAllPlayers()[1]	end
	local liftPos = sm.vec3.zero()
	local raycastStart = sm.vec3.new(liftPos.x,liftPos.y,(liftPos.z + 1000))
	local raycastEnd = sm.vec3.new(liftPos.x,liftPos.y,(liftPos.z -1000))
	local success, result = sm.physics.raycast(raycastStart, raycastEnd)
	if success then	liftPos = result.pointWorld	end
	local liftRotation = 1
	local liftHeight = 1
	player:placeLift({self.shape:getBody()}, (liftPos * 4), liftHeight, liftRotation)
	self.liftPlayer = player
end

-- ____________________________________ Client ____________________________________

function InertiaDrive.client_onFixedUpdate( self, dt )
	-- set comPose to show it power is on
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
	self.gui:setButtonCallback("HELP", "cl_onHelpButtonClick")
	for m = 1, 6 do
		self.gui:setButtonCallback("MODE"..m, "cl_onGuiButtonClick")
		self.gui:setButtonCallback("COPY"..m, "cl_onGuiButtonClick")
		self.gui:setButtonCallback("PASTE"..m, "cl_onGuiButtonClick")
		for k, v in pairs(self.defaultMode) do
			self.gui:setButtonCallback(k..m, "cl_onGuiButtonClick")
		end
	end
	self:cl_drawGui()
	if self.hasSeenHelpMenu then
		self.gui:open()
	else
		self:cl_openHelpMenu()
	end
end

function InertiaDrive.cl_onHelpButtonClick( self )
	self:cl_openHelpMenu()
end

function InertiaDrive.cl_openHelpMenu( self )
	if not self.helpGui then self.helpGui = sm.gui.createGuiFromLayout(LAYOUTS_PATH..'Instructions.layout') end
	self.helpGui:setOnCloseCallback("cl_onHelpMenuClose")
	self.helpGui:setText("Title", "INERTIA DRIVE - HELP")
	self.helpGui:setText("Message", self.helpMessage)
	self.helpGui:setButtonCallback("Ok", "cl_onHelpMenuOkButtonClick")
	self.gui:close()
	self.helpGui:open()
end

function InertiaDrive.cl_onHelpMenuOkButtonClick( self )
	self.helpGui:close()
end

function InertiaDrive.cl_onHelpMenuClose( self )
	self.hasSeenHelpMenu = true
	self:cl_openGui()
end

-- updates the GUI text and button states
function InertiaDrive.cl_drawGui( self )
	for m = 1, 6 do
		self.gui:setButtonState("MODE"..m, tostring(self.cl_guiData.currentMode) == tostring(m))
		for k, v in pairs(self.defaultMode) do
			if k == "ANTIGRAV" or k == "AUTOLEVEL PITCH" or k == "AUTOLEVEL ROLL" then
				self.gui:setText(k..m, self.cl_guiData[k..m] and "ON" or "OFF")
			else
				self.gui:setText(k..m, tostring(self.cl_guiData[k..m]))
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
	self.modeToCopy = nil
end

-- when GUI buttons are clicked
function InertiaDrive.cl_onGuiButtonClick( self, buttonName )
	local name = buttonName:sub(1, -2)
	local m = buttonName:sub(-1)
	if name == "COPY" then
		self.modeToCopy = m
	elseif name == "PASTE" then
		if self.modeToCopy then
			if not self.cl_newGuiData then self.cl_newGuiData = {} end
			for k,v in pairs(self.defaultMode) do
				local pasteVal = self.cl_guiData[k..self.modeToCopy]
				self.cl_newGuiData[k..m] = pasteVal
				self.cl_guiData[k..m] = pasteVal
			end
			self:cl_drawGui()
		end
	elseif name == "MODE" then
		if not self.cl_newGuiData then self.cl_newGuiData = {} end
		self.cl_newGuiData.currentMode = m
		self.cl_guiData.currentMode = m
		self:cl_drawGui()
	elseif name == "ANTIGRAV" or name == "AUTOLEVEL PITCH" or name == "AUTOLEVEL ROLL" then
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
	if not self.editValGui then
		self.editValGui = sm.gui.createGuiFromLayout(LAYOUTS_PATH..'InertiaDriveEditVal.layout')
		self.editValGui:setOnCloseCallback("cl_onEditValGuiClose")
		self.editValGui:setButtonCallback("Button.", "cl_onEditValGuiButtonClick")
		self.editValGui:setButtonCallback("Clear", "cl_onEditValGuiButtonClick")
		self.editValGui:setButtonCallback("Ok", "cl_onEditValGuiButtonClick")
		for i = 0, 9 do
			self.editValGui:setButtonCallback("Button"..tostring(i), "cl_onEditValGuiButtonClick")
		end
	end
	self.editValGui:setText("Name", name)
	self.editValGui:setText("Mode", g)
	self.editValGui:setText("CurrentVal", tostring(currentValue))
	self.editValGui:setText("NewVal", "")
	self.editValGui:open()
	
	self.editValGui_selection = buttonName
	self.editValGui_buffer = ""
end

-- when edit val GUI buttons are clicked
function InertiaDrive.cl_onEditValGuiButtonClick( self, buttonName )
	if buttonName == "Ok" then
		self.editValGui:close()
	elseif buttonName == "Clear" then
		self.editValGui_buffer = ""
		self.editValGui:setText("NewVal", "")
	-- check if under max length of 6 digits
	elseif #self.editValGui_buffer < 7 then
		local newVal = buttonName:sub(-1)
		if self.editValGui_buffer == "0" then 
			-- if adding a 0 after a learing zero, skip
			if newVal == "0" then return end
			-- if adding other value after leading 0, remove the 0
			self.editValGui_buffer = ""
		end
		if newVal == "." then
			-- only allow one decimal point
			for i = 1, #self.editValGui_buffer do
				if self.editValGui_buffer:sub(i,i) == "." then return end
			end
			-- if decimal is first char then add leading 0
			if #self.editValGui_buffer < 1 then
				newVal = "0."
			end
		end
		self.editValGui_buffer = self.editValGui_buffer..newVal
		self.editValGui:setText("NewVal", self.editValGui_buffer)
	end
end

-- when the edit val GUI closes, send the server the updates if anything has changed and open main guio
function InertiaDrive.cl_onEditValGuiClose( self )
	if self.editValGui_buffer ~= "" then
		local newVal = tonumber(self.editValGui_buffer)
		local name = self.editValGui_selection:sub(1, -2)
		if newVal > 0 then
			newVal = math.max(newVal, 0.001) -- smallest non-0 value is 0.001
		end
		self.cl_guiData[self.editValGui_selection] = newVal
		self.network:sendToServer("sv_setData", {[self.editValGui_selection] = newVal})
	end
	self.editValGui_selection = nil
	self.editValGui_buffer = nil
	self:cl_openGui()
end

-- cleanup on destroy
function InertiaDrive.client_onDestroy( self )
	if self.gui then
		self.gui:destroy()
		self.gui = nil
	end
	if self.editValGui then
		self.editValGui:destroy()
		self.editValGui = nil
	end
	if self.helpGui then
		self.helpGui:destroy()
		self.helpGui = nil
	end
end

















