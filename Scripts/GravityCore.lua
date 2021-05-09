dofile "Utility.lua"
--[[ 
********** GravityCore by MJM ********** 
--]]

GravityCore = class()
GravityCore.maxParentCount = -1
GravityCore.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
GravityCore.connectionOutput = sm.interactable.connectionType.none
GravityCore.colorNormal = sm.color.new( 0xdb4e16ff )
GravityCore.colorHighlight = sm.color.new( 0xff5e19ff )
GravityCore.poseWeightCount = 1

function GravityCore.printDescription()
    local description = "\n"..
	"----- Gravity Core: (All settings are optional and have Default values)-----\n"..
	"--------------- Logic Input Settings ------------------------------------------------------------\n"..
    "Light Grey          : Power On/Off                  (Default ON)\n"..
	"--------------- Number Value Power Settings ---------------------------------------------\n"..
	"Dark Grey           : Anti-Grav Strength         (0-100, Default 100)\n"..
	"Black                  : Linear Drag Strength*** (0-100, Default 10)\n"..
	"Dark Yellow        : Fwd/Back Drag Strength (0-100, Default 10)\n"..
	"Dark LimeGreen : Right/Left Drag Strength (0-100, Default 10)\n"..
	"Dark Green        : Up/Down Drag Strength  (0-100, Default 10)\n"..
	"***NOTE: ^ Linear Drag Strength sets Fwd/Back, Right/Left, and Up/Down all at once \n"..
	"        you don't need to set them individually unless you need different values *** \n"..
	"Dark CyanBlue   : Pitch Drag Strength        (0-100, Default 100)\n"..
	"Dark Blue          : Roll Drag Strength           (0-100, Default 100)\n"..
	"DarkPurple        : Yaw Drag Strength          (0-100, Default 100)\n"..
	"Dark Pink          : Auto-Pitch Strength         (0-100, Default 100)\n"..
	"Dark Red           : Auto-Roll Strength           (0-100, Default 100)\n"..
	"Dark Brown       : Auto-Yaw Strength          (0-100, Default 100)\n"..
	"***NOTE: To disable a function (for example Auto-Yaw) just give it a 0 value"
    print(description)
end

-- ____________________________________ Server ____________________________________

function GravityCore.server_onCreate( self ) --- Server setup ---
	self.prevPower = false
	self.wasOnLift = true
	self.yawDir = self.shape.at
	
end
function GravityCore.server_onRefresh( self )
	print("* * * * * REFRESH GravityCore * * * * *")
	self:server_onCreate()
end

function GravityCore.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
	local isOnLift = self.shape.body:isOnLift()
	
	----- power setting
	local power = true
	
	----- antigrav strength
	local antiGravPower = 100
	
	----- linear drag scale (0-100)
	local linearDrag = 10
	local fwdDrag = linearDrag
	local rightDrag = linearDrag
	local upDrag = linearDrag
	
	----- rotational drag scale (0-100)
	local pitchDrag = 100
	local rollDrag = 100
	local yawDrag = 100
	
	----- orientation strength (0-100)
	local autoPitch = 100
	local autoRoll = 100
	local autoYaw = 100
	
	---- get input values
	for _,parent in pairs(self.interactable:getParents()) do
		local color = tostring(parent.shape.color)
		if color == "7f7f7fff" then -- Power (Light Grey)
			power = parent:isActive()
		elseif color == "4a4a4aff" then -- AntiGrav Power (Darg Grey)
			antiGravPower = parent:getPower()
		elseif color == "222222ff" then -- Linear Drag (Black)
			linearDrag = parent:getPower()
			fwdDrag = linearDrag
			rightDrag = linearDrag
			upDrag = linearDrag
		elseif color == "323000ff" then -- Forward Drag (Dark Yellow)
			fwdDrag = parent:getPower()
		elseif color == "375000ff" then -- Right Drag (Dark LimeGreen)
			rightDrag = parent:getPower()
		elseif color == "064023ff" then -- Up Drag (Dark Green)
			upDrag = parent:getPower()
		elseif color == "0a4444ff" then -- Pitch Drag (Dark CyanBlue)
			pitchDrag = parent:getPower()
		elseif color == "0a1d5aff" then -- Roll Drag (Dark Blue)
			rollDrag = parent:getPower()
		elseif color == "35086cff" then -- Yaw Drag (Dark Purple)
			yawDrag = parent:getPower()
		elseif color == "520653ff" then -- Auto Pitch (Dark Pink)
			autoPitch = parent:getPower()
		elseif color == "560202ff" then -- Auto Roll (Dark Red)
			autoRoll = parent:getPower()
		elseif color == "472800ff" then -- Auto Yaw (Dark Brown)
			autoYaw = parent:getPower()
		end
	end
	
	----- clamp values
	antiGravPower = sm.util.clamp(antiGravPower,0,100)
	linearDrag = sm.util.clamp(linearDrag,0,100)
	fwdDrag = sm.util.clamp(fwdDrag,0,100)
	rightDrag = sm.util.clamp(rightDrag,0,100)
	upDrag = sm.util.clamp(upDrag,0,100)
	pitchDrag = sm.util.clamp(pitchDrag,0,100)
	rollDrag = sm.util.clamp(rollDrag,0,100)
	yawDrag = sm.util.clamp(yawDrag,0,100)
	autoPitch = sm.util.clamp(autoPitch,0,100)
	autoRoll = sm.util.clamp(autoRoll,0,100)
	autoYaw = sm.util.clamp(autoYaw,0,100)
	
	local surpresPower = false
	if power then
		if not self.prevPower then
			surpresPower = true
		end
		
		if not self.interactable.active then
			self.interactable:setActive(true)
		end
		
		if not self.prevPower then
			surpresPower = true
			self.prevAltitudeHold = nil
			self.prevpitchHoldRollLevel = nil
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
		local frontOffset = comOffset + self.shape.at
		local backOffset = comOffset + (self.shape.at * -1)
		local rightOffset = comOffset + self.shape.right
		local leftOffset = comOffset + (self.shape.right * -1)
		
		----- calc world positions 
		local frontLoc = self.shape.worldPosition + frontOffset
		local backLoc = self.shape.worldPosition + backOffset
		local rightLoc = self.shape.worldPosition + rightOffset
		local leftLoc = self.shape.worldPosition + leftOffset
		
		----- calc linear drag
		local linDrag = mass^0.75 --mass * 0.5
		local vel = self.shape.velocity
		if not vel or vel:length() < 0.000001 then
			vel = sm.vec3.zero()
		end
		local localLinDrag = toLocal(self.shape, vel) * -1
		local linDragFwd = toGlobal(self.shape, sm.vec3.new(0,localLinDrag.y,0)) * (linDrag * (fwdDrag / 100))
		local linDragRight = toGlobal(self.shape, sm.vec3.new(localLinDrag.x,0,0)) * (linDrag * (rightDrag / 100))
		local linDragUp = toGlobal(self.shape, sm.vec3.new(0,0,localLinDrag.z)) * (linDrag * (upDrag / 100))
		
		----- calc angular drag from moment of inertia
		--[[
		Angular Momentum = Angular Velocity * Moment of Inertia
		Moment of Inertia = sum of the mass of each block times the square of the distance each block is from the axis of rotation
		--]]
		local pitchUnitSum = 0
		local rollUnitSum = 0
		local yawUnitSum = 0
		for _,shape in pairs(self.shape.body:getCreationShapes()) do
			local distanceVec = toLocal(self.shape,(shape.worldPosition - comWorldPosition))
			pitchDistanceVec = sm.vec3.new(0,distanceVec.y,distanceVec.z)
			rollDistanceVec = sm.vec3.new(distanceVec.x,0,distanceVec.z)
			yawDistanceVec = sm.vec3.new(distanceVec.x,distanceVec.y,0)
			local pitchDistance = pitchDistanceVec:length2()
			local rollDistance = rollDistanceVec:length2()
			local yawDistance = yawDistanceVec:length2()
			pitchUnitSum = pitchUnitSum + (shape.mass * pitchDistance)
			rollUnitSum = rollUnitSum + (shape.mass * rollDistance)
			yawUnitSum = yawUnitSum + (shape.mass * yawDistance)
		end
		--local unitMultp = 0.5 --0.33 -- 0.5
		local unitMultp = (self.shape.body.mass/75) -- adjustment because forces still too high
		pitchUnitSum = pitchUnitSum * unitMultp
		rollUnitSum = rollUnitSum * unitMultp
		yawUnitSum = yawUnitSum * unitMultp
		local minUnit = mass/500 -- needs a minimum value in case distance form axis is 0
		local pitchAngDrag = math.max(minUnit,pitchUnitSum)
		local rollAngDrag = math.max(minUnit,rollUnitSum)
		local yawAngDrag = math.max(minUnit,yawUnitSum)
		
		--[[ --debug
		print()
		print(string.format("pitchAngDrag %6.3f",pitchAngDrag))
		print(string.format("pitchDrag %6.3f",pitchDrag))
		print(string.format("rollAngDrag %6.3f",rollAngDrag))
		print(string.format("yawAngDrag %6.3f",yawAngDrag))
		--]]
		
		----- calc rotational drag
		local localRotDrag = toLocal(self.shape, self.shape.body.angularVelocity) * -1
		local angDragPitch = toGlobal(self.shape, sm.vec3.new(0,0,localRotDrag.x)) * (pitchAngDrag * (pitchDrag / 100))
		local angDragRoll = toGlobal(self.shape, sm.vec3.new(0,0,(localRotDrag.y * -1))) * (rollAngDrag * (rollDrag / 100))
		local angDragYaw = toGlobal(self.shape, sm.vec3.new((localRotDrag.z * -1),0,0)) * (yawAngDrag * (yawDrag / 100))
		
		----- calc antigrav
		local antigrav = sm.vec3.new(0,0,(sm.physics.getGravity()/10) * mass * 0.2618735) * (antiGravPower / 100)
		
		----- auto leveling
		local autoLevel = not(autoPitch == 0 and autoRoll == 0)
		local levelStrengthMult = 2
		local pitchLeveling = sm.vec3.zero()
		local rollLeveling = sm.vec3.zero()
		if autoLevel then
			local pitchSkew = backLoc.z - frontLoc.z
			pitchLeveling = self.shape.up * pitchSkew * (pitchAngDrag * levelStrengthMult) * (autoPitch / 100)
			local rollSkew = leftLoc.z - rightLoc.z
			rollLeveling = self.shape.up * rollSkew * (rollAngDrag * levelStrengthMult) * (autoRoll / 100)
		end
		
		----- yaw lock
		local yawLock = not(autoYaw == 0)
		local yawLockStrengthMult = 2
		local yawLeveling = sm.vec3.zero()
		if yawLock then
			if self.wasOnLift and not isOnLift then
				self.yawDir = self.shape.at
			end
			local skew = self.yawDir:dot(sm.vec3.new(self.shape.right.x,self.shape.right.y,0))
			yawLeveling = self.shape.right * skew * (yawAngDrag * yawLockStrengthMult) * (autoYaw / 100)
		end
		
		----- calc compiled vec forces to apply
		local coreVec = linDragFwd + linDragRight + linDragUp
		--local coreVec = antigrav + linDragFwd + linDragRight + linDragUp
		local rightVec = angDragRoll + rollLeveling
		local leftVec = (angDragRoll * -1) - rollLeveling
		local frontVec = angDragPitch + pitchLeveling + angDragYaw + yawLeveling
		local backVec = (angDragPitch * -1) - pitchLeveling - angDragYaw - yawLeveling

		----- apply forces
		if not surpresPower then
			for _,body in pairs (self.shape.body:getCreationBodies()) do
			local portion = body.mass / mass
				local ag = sm.vec3.new(0,0,(sm.physics.getGravity()/10) * body.mass * 0.2618735) * (antiGravPower / 100)
				sm.physics.applyImpulse(body, ((coreVec * portion) + ag), true, nil)
			end
			---------- applyImpulse(target,impulse,global,offset) ----------
			sm.physics.applyImpulse(self.shape, leftVec, true, leftOffset)
			sm.physics.applyImpulse(self.shape, rightVec, true, rightOffset)
			sm.physics.applyImpulse(self.shape, frontVec, true, frontOffset)
			sm.physics.applyImpulse(self.shape, backVec, true, backOffset)
		end
		
	else
		if self.interactable.active then
			self.interactable:setActive(false)
		end
	end
	
	self.prevPower = power
	self.wasOnLift = isOnLift
end

-- ____________________________________ Client ____________________________________

function GravityCore.client_onCreate( self ) --- Client setup ---
	self:printDescription()
end
function GravityCore.client_onRefresh( self )
	self:client_onCreate()
end

function GravityCore.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------
	if self.interactable.active then
		self.interactable:setPoseWeight(0, 1)
	else
		self.interactable:setPoseWeight(0, 0)
	end
end

