dofile "Utility.lua"

InertiaDrive = class()
InertiaDrive.maxParentCount = -1
InertiaDrive.maxChildCount = -1
InertiaDrive.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
InertiaDrive.connectionOutput = sm.interactable.connectionType.logic
InertiaDrive.colorNormal = sm.color.new( 0xdb4e16ff )
InertiaDrive.colorHighlight = sm.color.new( 0xff5e19ff )
InertiaDrive.poseWeightCount = 1

----- Hard coded settings
InertiaDrive.altitudeHoldMargin = 0.1
InertiaDrive.locationHoldMargin = 0.1
InertiaDrive.levelNoise = 100 -- pitch/roll angle noise
InertiaDrive.hoverNoise = 250 -- hover height noise

----- Button Map
InertiaDrive.bindingMap = {
"Power", 				--
"Pitch Up", 			--
"Pitch Down", 			--
"Roll Left", 			--
"Roll Right", 			--
"Yaw Left", 			--
"Yaw Right", 			--
"Forward (Relative)", 	--
"Back (Relative)", 		--
"Left (Relative)", 		--
"Right (Relative)", 	--
"Up (Relative)", 		--
"Down (Relative)", 		--
"Forward (Global)", 	--
"Back (Global)", 		--
"Left (Global)", 		--
"Right (Global)", 		--
"Up (Global)", 			--
"Down (Global)", 		--
"Auto Leveling", 		--
"Pitch-Hold Roll-Level",--
"Altitude Hold", 		--
"Location Hold", 		--
"Hover Shake" 			--
}

function InertiaDrive.printDescription()
    local description = "\n"..
	"Inertia Drive Number Value Power Settings: \n"..
    "White             : Pitch Power\n"..
	"Yellow 1         : Roll Power\n"..
	"MossGreen 1 : Yaw Power\n"..
	"Light Grey     : Fwd/Back Power\n"..
	"Yellow 2        : Left/Right Power\n"..
	"MossGreen 2 : Up/Down Power\n"..
	"Dark Grey     : Pitch Drag\n"..
	"Yellow 3        : Roll Drag\n"..
	"MossGreen 3 : Yaw Drag\n"..
	"Black             : Fwd/Back Drag\n"..
	"Yellow 4         : 4Left/Right Drag\n"..
	"MossGreen 4 : Up/Down Drag\n"..
	"Blue 1        : Auto-Level Pitch Power \n"..
	"Blue 2        : Auto-Level Roll Power\n"..
	"Blue 3        : Altitude-Hold Power\n"..
	"Blue 4        : Location-Hold Power\n"..
	"----------------For binding main logic inputs---------------\n"..
	"Press E to choose desired input: Press button to BIND! \n"
    print(description)
end

--TODO... speed ramping option?

-- ____________________________________ Server ____________________________________

function InertiaDrive.server_onCreate( self ) --- Server setup ---
	
	local availableModes = {"Mode A", "Mode B", "Mode C", "Mode D"}
	self.interactable:setPublicData({availableModes})

	self.currentBindings = {}
	
	self.data = {[0] = 0}
	self.loaded = self.storage:load()
	if self.loaded then
		self.data.bindings = self.loaded.bindings or {}
		self:loadBindings()
	else
		self.data.bindings = {}
	end
	
	self.pitchPower = 100--450
	self.rollPower = 50--250
	self.yawPower = 100--450

	self.fwdPower = 500--3000
	self.rightPower = 500--1000
	self.upPower = 500--2000

	self.pitchDrag = 1--200
	self.rollDrag = 0.25--100
	self.yawDrag = 1--200
	
	self.fwdDrag = 25--100
	self.rightDrag = 25--400
	self.vertDrag = 25--400
	
	self.autoLevelPitchPower = 5--200
	self.autoLevelRollPower = 5--200
	self.altitudeHoldPower = 20--
	self.locationHoldPower = 20--

	self.pitchHoldDelay = 0	
	self.binding = nil
	self.lastPlayerId = 1
	self.lastBoundIndex = 0
end
function InertiaDrive.server_onRefresh( self )
	print("* * * * * REFRESH Hover Controller * * * * *")
	self:server_onCreate()
end

function InertiaDrive.saveBindings( self )
	--[
	self.data.bindings = {}
	for button,buttonBindings in pairs(self.currentBindings) do
		if sm.exists(button) then
			--I can't trust the connection index so this will do for now, hopefully no 2 buttons end up with the same shitty-psudo-hash code
			local shittyPsudoHashLoc = ((button.shape.localPosition * 2) + button.shape.xAxis + button.shape.yAxis)
			local shittyPsudoHashLoc = string.format(tostring(math.floor(shittyPsudoHashLoc.x))..tostring(math.floor(shittyPsudoHashLoc.y))..tostring(math.floor(shittyPsudoHashLoc.y)))
			self.data.bindings[shittyPsudoHashLoc] = buttonBindings
		end
	end
	self.storage:save(self.data)
	--]]
end

function InertiaDrive.loadBindings( self )
	--[
	self.currentBindings = {}
	for savedHash,buttonBindings in pairs(self.data.bindings) do
		for _,parent in pairs(self.interactable:getParents()) do
			local shittyPsudoHashLoc = ((parent.shape.localPosition * 2) + parent.shape.xAxis + parent.shape.yAxis)
			local shittyPsudoHashLoc = string.format(tostring(math.floor(shittyPsudoHashLoc.x))..tostring(math.floor(shittyPsudoHashLoc.y))..tostring(math.floor(shittyPsudoHashLoc.y)))
			if savedHash == shittyPsudoHashLoc then
				self.currentBindings[parent] = buttonBindings
				break
			end
		end
	end
	--]]
end

function InertiaDrive.server_startBinding( self, data )
	self.binding = self.bindingMap[data.bindingIndex]
	self.lastBoundIndex = data.bindingIndex
	self.lastPlayerId = data.playerId
end

function InertiaDrive.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
	
	----- bound inputs
	local power = false

	local forward = 0	
	local right = 0
	local up = 0

	local globalForward = 0	
	local globalRight = 0
	local globalUp = 0
	
	local pitch = 0
	local roll = 0
	local yaw = 0
	
	local autoLevel = false
	local pitchHoldRollLevel = false
	local altitudeHold = false
	local locationHold = false
	local hoverShake = false
	
	----- color inputs
	
	local pitchPower = nil
	local rollPower = nil
	local yawPower = nil
	
	local fwdPower = nil
	local rightPower = nil
	local upPower = nil
	
	local pitchDrag = nil
	local rollDrag = nil
	local yawDrag = nil
	
	local fwdDrag = nil
	local rightDrag = nil
	local vertDrag = nil
	
	local autoLevelPitchPower = nil
	local autoLevelRollPower = nil
	local altitudeHoldPower = nil
	local locationHoldPower = nil
	
	----- check for binding
	if self.binding then
		if self.binding == "CANCEL" then
			self.binding = nil
		else
			for _,parent in pairs(self.interactable:getParents()) do
				if isLogic(parent) and parent:isActive() then
					local btnMatch = false
					for button,buttonBindings in pairs(self.currentBindings) do
						if button == parent then
							btnMatch = true
							if self.binding == "Clear Binding" then
								self.currentBindings[button] = nil
							else
								self.currentBindings[button][self.binding] = true
							end
							self:saveBindings()
							break
						end
					end
					if not btnMatch and self.binding ~= "Clear Binding" then
						self.currentBindings[parent] = {}
						self.currentBindings[parent][self.binding] = true
						self:saveBindings()
					end
					self.network:sendToClients('client_confirmBinding', { playerId = self.lastPlayerId, boundIndex = self.lastBoundIndex })
					self.binding = nil
					break
				end
			end
		end
	end	
	
	----- get inputs
	local inputCount = 0
	local hasInput = false
	for _,parent in pairs(self.interactable:getParents()) do
		inputCount = inputCount + 1
		if isLogic(parent) then
			if parent:isActive() then
				for button,buttonBindings in pairs(self.currentBindings) do
					if button == parent then
						for bind,_ in pairs(buttonBindings) do
							--print(bind)
							if bind == "Power" then
								power = true
							elseif bind == "Forward (Relative)" then
								forward = forward + 1
								hasInput = true
							elseif bind == "Back (Relative)" then
								forward = forward - 1
								hasInput = true
							elseif bind == "Left (Relative)" then
								right = right - 1
								hasInput = true
							elseif bind == "Right (Relative)" then
								right = right + 1
								hasInput = true
							elseif bind == "Up (Relative)" then
								up = up + 1
								hasInput = true
							elseif bind == "Down (Relative)" then
								up = up - 1
								hasInput = true
							elseif bind == "Forward (Global)" then
								globalForward = globalForward + 1
								hasInput = true
							elseif bind == "Back (Global)" then
								globalForward = globalForward - 1
								hasInput = true
							elseif bind == "Left (Global)" then
								globalRight = globalRight - 1
								hasInput = true
							elseif bind == "Right (Global)" then
								globalRight = globalRight + 1
								hasInput = true
							elseif bind == "Up (Global)" then
								globalUp = globalUp + 1
								hasInput = true
							elseif bind == "Down (Global)" then
								globalUp = globalUp - 1
								hasInput = true
							elseif bind == "Pitch Down" then
								pitch = pitch +1
								self.prevPitchHoldLevel = nil
								hasInput = true
							elseif bind == "Pitch Up" then
								pitch = pitch - 1
								self.prevPitchHoldLevel = nil
								hasInput = true
							elseif bind == "Roll Left" then
								roll = roll - 1
								hasInput = true
							elseif bind == "Roll Right" then
								roll = roll + 1
								hasInput = true
							elseif bind == "Yaw Left" then
								yaw = yaw - 1
								hasInput = true
							elseif bind == "Yaw Right" then
								yaw = yaw + 1
								hasInput = true
							elseif bind == "Auto Leveling" then
								autoLevel = true
							elseif bind == "Pitch-Hold Roll-Level" then
								pitchHoldRollLevel = true
							elseif bind == "Altitude Hold" then
								altitudeHold = true
							elseif bind == "Location Hold" then
								locationHold = true
							elseif bind == "Hover Shake" then
								hoverShake = true
							end
						end
						break
					end
				end
			end
		else
			local color = tostring(parent.shape.color)
			
			if color == "eeeeeeff" then -- pitch power (white)
				pitchPower = parent:getPower()
			elseif color == "f5f071ff" then -- roll power (yellow 1)
				rollPower = parent:getPower()
			elseif color == "cbf66fff" then -- yaw power (lime-green 1)
				yawPower = parent:getPower()
		
			elseif color == "7f7f7fff" then -- forward power (light grey)
				fwdPower = parent:getPower()
			elseif color == "e2db13ff" then -- horizontal power (yellow 2)
				rightPower = parent:getPower()
			elseif color == "a0ea00ff" then -- vertical power (lime-green 2)
				upPower = parent:getPower()
		
			elseif color == "4a4a4aff" then -- pitch drag (dark grey)
				pitchDrag = parent:getPower()
			elseif color == "817c00ff" then -- roll drag (yellow 3)
				rollDrag = parent:getPower()
			elseif color == "577d07ff" then -- yaw Drag (lime-green 3)
				yawDrag = parent:getPower()
			
			elseif color == "222222ff" then -- forward drag (black)
				fwdDrag = parent:getPower()
			elseif color == "323000ff" then -- horizontal drag (yellow 4)
				rightDrag = parent:getPower()
			elseif color == "375000ff" then -- vertical Drag (lime-green 4)
				vertDrag = parent:getPower()			
				
			elseif color == "4c6fe3ff" then -- autoLevel pitch power (blue 1)
				autoLevelPitchPower = parent:getPower()
			elseif color == "0a3ee2ff" then -- autoLevel roll power (blue  2)
				autoLevelRollPower = parent:getPower()
			elseif color == "0f2e91ff" then -- altitude hold power (blue  3)
				altitudeHoldPower = parent:getPower()
			elseif color == "0a1d5aff" then -- location hold power (blue  4)
				locationHoldPower = parent:getPower()
				
			end
		end
	end
	if self.prevInputCount and inputCount < self.prevInputCount then
		self:saveBindings()
	end
	self.prevInputCount = inputCount
	
	local surpresPower = false
	if power then
		if not self.interactable.active then
			self.interactable:setActive(true)
		end
		
		if not self.prevPower then
			surpresPower = true
			self.prevAltitudeHold = nil
			self.prevpitchHoldRollLevel = nil
		end
		
		----- clamp movement inputs
		right = sm.util.clamp(right,-1,1)
		up = sm.util.clamp(up,-1,1)
		forward = sm.util.clamp(forward,-1,1)
		globalRight = sm.util.clamp(globalRight,-1,1)
		globalUp = sm.util.clamp(globalUp,-1,1)
		globalForward = sm.util.clamp(globalForward,-1,1)
		pitch = sm.util.clamp(pitch,-1,1)
		roll = sm.util.clamp(roll,-1,1)
		yaw = sm.util.clamp(yaw,-1,1)
		
		----- calc linear input
		local linearInput = sm.vec3.zero()
		if right ~= 0 then
			linearInput = linearInput + (self.shape.right * right * (rightPower or self.rightPower))
		end
		if up ~= 0 then
			linearInput = linearInput + (self.shape.up * up * (upPower or self.upPower))
		end
		if forward ~= 0 then
			linearInput = linearInput + (self.shape.at * forward * (fwdPower or self.fwdPower))
		end
		if globalRight ~= 0 then
			local adjRight = self.shape.right
			adjRight.z = 0
			linearInput = linearInput + (adjRight * globalRight * (rightPower or self.rightPower))
		end
		if globalUp ~= 0 then
			linearInput = linearInput + (sm.vec3.new(0,0,1) * globalUp * (upPower or self.upPower))
		end
		if globalForward ~= 0 then
			local adjForward = self.shape.at
			adjForward.z = 0
			linearInput = linearInput + (adjForward * globalForward * (fwdPower or self.fwdPower))
		end
		
		----- calc rotational input
		local pitchInput = sm.vec3.zero()
		local rollInput = sm.vec3.zero()
		local yawInput = sm.vec3.zero()
		if pitch ~= 0 then
			pitchInput = ((self.shape.up * -1) * pitch * (pitchPower or self.pitchPower))
		end
		if roll ~= 0 then
			rollInput = ((self.shape.up * -1) * roll * (rollPower or self.rollPower))
		end
		if yaw ~= 0 then
			yawInput = (self.shape.right * yaw * (yawPower or self.yawPower))
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
		local localLinDrag = toLocal(self.shape, self.shape.velocity) * -1
		local linDragFwd = toGlobal(self.shape, sm.vec3.new(0,localLinDrag.y,0)) * (fwdDrag or self.fwdDrag)
		local linDragRight = toGlobal(self.shape, sm.vec3.new(localLinDrag.x,0,0)) * (rightDrag or self.rightDrag)
		local linDragUp = toGlobal(self.shape, sm.vec3.new(0,0,localLinDrag.z)) * (vertDrag or self.vertDrag)
		
		----- calc rotational drag
		local localRotDrag = toLocal(self.shape, self.shape.body.angularVelocity) * -1
		local angDragPitch = toGlobal(self.shape, sm.vec3.new(0,0,localRotDrag.x)) * (pitchDrag or self.pitchDrag)
		local angDragRoll = toGlobal(self.shape, sm.vec3.new(0,0,(localRotDrag.y * -1))) * (rollDrag or self.rollDrag)
		local angDragYaw = toGlobal(self.shape, sm.vec3.new((localRotDrag.z * -1),0,0)) * (yawDrag or self.yawDrag)
		
		----- calc antigrav
		local antigrav = sm.vec3.new(0,0,(sm.physics.getGravity()/10) * mass * 0.2618735)
		
		----- noise
		local pitchNoise = sm.vec3.zero()
		local rollNoise = sm.vec3.zero()
		local heightNoise = sm.vec3.zero()
		if hoverShake then
			heightNoise = self.shape.up * sm.noise.randomRange( (self.hoverNoise * -1), self.hoverNoise )
			pitchNoise = self.shape.up * sm.noise.randomRange( (self.levelNoise * -1), self.levelNoise )
			rollNoise = self.shape.up * sm.noise.randomRange( (self.levelNoise * -1), self.levelNoise )
		end
		
		----- auto leveling
		local pitchLeveling = sm.vec3.zero()
		local rollLeveling = sm.vec3.zero()
		if autoLevel then
			pitchLeveling = self.shape.up * (backLoc.z - frontLoc.z)* (autoLevelPitchPower or self.autoLevelPitchPower)
			rollLeveling = self.shape.up * (leftLoc.z - rightLoc.z)* (autoLevelRollPower  or self.autoLevelRollPower )
		end
		
		----- pitch-hold leveling
		if pitchHoldRollLevel then
			if not self.prevpitchHoldRollLevel then
				self.pitchHoldDelay = 10 -- ticks to delay getting new pitch value
			else
				if self.pitchHoldDelay > 0 then
					self.pitchHoldDelay = self.pitchHoldDelay - 1
				elseif self.pitchHoldDelay == 0 then
					self.pitchHoldDelay = -1
					local currentPitch = frontLoc.z - backLoc.z
					self.pitchTarget = currentPitch			
				else -- delay is -1
					local currentPitch = frontLoc.z - backLoc.z
					pitchLeveling = self.shape.up * (self.pitchTarget - currentPitch)* (autoLevelPitchPower or self.autoLevelPitchPower)
					rollLeveling = self.shape.up * (leftLoc.z - rightLoc.z)* (autoLevelRollPower  or self.autoLevelRollPower )
				end
			end
		end
		self.prevpitchHoldRollLevel = pitchHoldRollLevel
		
		----- altitude hold
		local altitudeVec = sm.vec3.zero()
		if altitudeHold then
			if not self.prevAltitudeHold then
				self.hoverAltitude = self.shape.worldPosition.z
			end
			if self.shape.worldPosition.z < self.hoverAltitude - self.altitudeHoldMargin then
				altitudeVec = altitudeVec + sm.vec3.new(0,0,self.altitudeHoldPower)
			elseif self.shape.worldPosition.z > self.hoverAltitude + self.altitudeHoldMargin then
				altitudeVec = altitudeVec + sm.vec3.new(0,0,self.altitudeHoldPower * -1)
			end
		end
		self.prevAltitudeHold = altitudeHold
		
		----- location hold
		local locationVec = sm.vec3.zero()
		if locationHold then
			if not self.prevLocationHold then
				self.holdLocationX = self.shape.worldPosition.x
				self.holdLocationY = self.shape.worldPosition.y
			end
			if self.shape.worldPosition.x < self.holdLocationX - self.locationHoldMargin then
				locationVec = locationVec + sm.vec3.new(self.locationHoldPower,0,0)
			elseif self.shape.worldPosition.x > self.holdLocationX + self.locationHoldMargin then
				locationVec = locationVec + sm.vec3.new(self.locationHoldPower * -1,0,0)
			end
			if self.shape.worldPosition.y < self.holdLocationY - self.locationHoldMargin then
				locationVec = locationVec + sm.vec3.new(0,self.locationHoldPower,0)
			elseif self.shape.worldPosition.y > self.holdLocationY + self.locationHoldMargin then
				locationVec = locationVec + sm.vec3.new(0,self.locationHoldPower * -1,0)
			end
		end
		self.prevLocationHold = locationHold
		
		----- calc compiled vec forces to apply
		local coreVec = antigrav + linearInput + linDragFwd + linDragRight + linDragUp + heightNoise + altitudeVec + locationVec
		local rightVec = rollInput + rollLeveling + angDragRoll + rollNoise 
		local leftVec = (rollInput * -1) - rollLeveling - angDragRoll - rollNoise
		local frontVec = pitchInput + angDragPitch + pitchLeveling + yawInput + angDragYaw + pitchNoise
		local backVec = (pitchInput * -1) - angDragPitch - pitchLeveling - yawInput - angDragYaw - pitchNoise
		
		----- apply forces
		---------- applyImpulse(target,impulse,global,offset) ----------
		if not surpresPower then
			sm.physics.applyImpulse(self.shape, coreVec, true, comOffset)
			sm.physics.applyImpulse(self.shape, leftVec, true, leftOffset)
			sm.physics.applyImpulse(self.shape, rightVec, true, rightOffset)
			sm.physics.applyImpulse(self.shape, frontVec, true, frontOffset)
			sm.physics.applyImpulse(self.shape, backVec, true, backOffset)
		end
		
		----- debug print
		--[[
		print()
		print("power: "..tostring(power))
		print("forward: "..forward)
		print("right: "..right)
		print("up: "..up)
		--print("globalForward: "..globalForward)
		--print("globalRight: "..globalRight)
		--print("globalUp: "..globalUp)
		print("pitch: "..pitch)
		print("roll: "..roll)
		print("yaw: "..yaw)
		--]]
		--[[
		print("pitchPower: "..tostring(pitchPower))
		print("rollPower: "..tostring(rollPower))
		print("yawPower: "..tostring(yawPower))
		print("fwdPower: "..tostring(fwdPower))
		print("rightPower: "..tostring(rightPower))
		print("upPower: "..tostring(upPower))
		print("pitchDrag: "..tostring(pitchDrag))
		print("rollDrag: "..tostring(rollDrag))
		print("yawDrag: "..tostring(yawDrag))
		print("fwdDrag: "..tostring(fwdDrag))
		print("rightDrag: "..tostring(rightDrag))
		print("upDrag: "..tostring(upDrag))
		--print("autoLevelPitchPower: "..tostring(autoLevelPitchPower))
		--print("autoLevelRollPower: "..tostring(autoLevelRollPower))
		--print("altitudeHoldPower: "..tostring(altitudeHoldPower))
		--print("locationHoldPower: "..tostring(locationHoldPower))
		--]]
	else
		if self.interactable.active then
			self.interactable:setActive(false)
		end
	end
	self.prevPower = power
	
	if self.interactable.active ~= power then
		self.interactable:setActive(power)
	end
	
end

-- ____________________________________ Client ____________________________________

function InertiaDrive.client_onCreate( self ) --- Client setup ---

end

function InertiaDrive.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------
	
	if self.interactable.active then
		self.interactable:setPoseWeight(0, 1)
	else
		self.interactable:setPoseWeight(0, 0)
	end
end

function InertiaDrive.client_onInteract(self, character, state)
    if not state then return end

	--sm.audio.play("SequenceController change rotation", self.shape.worldPosition)
end








