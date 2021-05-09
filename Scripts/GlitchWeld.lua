dofile "Utility.lua"
--[[ 
********** GlitchWeld by MJM ********** 
--]]
GlitchWeld = class()
GlitchWeld.maxParentCount = 2
GlitchWeld.maxChildCount = 0
GlitchWeld.connectionInput = sm.interactable.connectionType.power + sm.interactable.connectionType.logic
GlitchWeld.connectionOutput = sm.interactable.connectionType.none
GlitchWeld.colorNormal = sm.color.new( 0x910640ff )
GlitchWeld.colorHighlight = sm.color.new( 0xb60e55ff )

GlitchWeld.staticColor = sm.color.new( 0x68ff88ff ) -- light green
GlitchWeld.dynamicColor = sm.color.new( 0x7eededff ) -- light aqua-blue
GlitchWeld.defaultColor = sm.color.new( 0x3094ffff ) -- custom blue

--[[
function GlitchWeld.printDescription()
    local description = "\n\n"..
    "---------------Glitch Welder Usage----------------------------------------------------------------\n"..
    "Place the glitch welder on a creation.\n"..
    "Paint parts light-cyan blue then 'Press [E] to use' to cut/paste.\n"..
    "Paint parts light green to paste as static in the world.\n"..
	"Paint the glitch welder itself the color you want to spawn the parts.\n"..
    "Attach a button to re-paste the last items copied over and over.\n"..
	"Attach a seat and use WASD to move the selected blocks relative to the \n"..
	" seat:     W:Forward   S:Back   A:Left   D:Right   A+W:Up   A+S:Down\n"..
    "-------------------------------------------------------------------------------------------------------------\n\n\n\n\n\n\n\n\n\n"
    print(description)
end
--]]

-- ____________________________________ Server ____________________________________

function GlitchWeld.server_onCreate( self )

	self.clipBoard = {}
	self.replayBoard = {}

	--_G["globalClipBoard"] = {}
	--_G["globalReplayBoard"] = {}
	
	self.shiftBodies = {}
	self.shiftBoard = {}
	self.shiftOffset = sm.vec3.zero()
	
	self.particleLocations = {}
	
	self.seat = nil
	self.s_poseWeight = 0.0
	self.prevPoseWeight = 0.0
	self.prevBtnDown = false
	self.prevInputANY = false
	self.canBeLEFT = true
	self.canBeRIGHT = true
end
function GlitchWeld.server_onRefresh( self )
	print(" * * * GlitchWeld REFRESH * * * ")
	self:server_onCreate()
end

function GlitchWeld.server_onFixedUpdate( self, dt )
	if self.tempPart and sm.exists(self.tempPart) then
		sm.shape.destroyShape(self.tempPart,0)
		self.tempPart = nil
	end
	for k,parent in pairs(self.interactable:getParents()) do
		if parent.type == "steering" then
			self.seat = parent.shape
			local shiftType = ""
			local userInput = false
			local inputUP = parent:getPower() > 0
			local inputDOWN = parent:getPower() < 0
			local inputLEFT = self.s_poseWeight < 0 and not(self.s_poseWeight > self.prevPoseWeight)
			local inputRIGHT = self.s_poseWeight > 0 and not(self.s_poseWeight < self.prevPoseWeight)
			local inputANY = inputUP or inputDOWN or inputLEFT or inputRIGHT
			self.prevPoseWeight = self.s_poseWeight
			
			if inputANY then -- can be up or down
				if (inputLEFT and self.prevInputUP) and not(inputUP or inputDOWN or inputRIGHT or self.prevInputDOWN or self.prevInputRIGHT) then
					-- UP
					userInput = true
					shiftType = "UP"
					--self.shiftOffset = parent.shape.at / 4
					self.canBeLEFT = false
					self.prevInputUP = false
				elseif (inputLEFT and self.prevInputDOWN) and not(inputUP or inputDOWN or inputRIGHT or self.prevInputUP or self.prevInputRIGHT) then
					-- DOWN
					userInput = true
					shiftType = "DOWN"
					--self.shiftOffset = (parent.shape.at / 4 )* -1
					self.canBeLEFT = false
					self.prevInputDOWN = false
				elseif (inputRIGHT and self.prevInputUP) and not(inputUP or inputDOWN or inputLEFT or self.prevInputDOWN or self.prevInputLEFT) then
					-- ROTATE
					--userInput = true
					--print("ROTATE")
					--[[
						Not implimented yet.
						Plan is to rotate around an axis, like pressing 'Q' for a block						
					--]]
					self.canBeRIGHT = false
					self.prevInputUP = false
				elseif (inputRIGHT and self.prevInputDOWN) and not(inputUP or inputDOWN or inputLEFT or self.prevInputUP or self.prevInputLEFT) then
					-- CHANGE AXIS
					--userInput = true
					--print("SELECT")
					--[[
						Not implimented yet.
						Plan is to cycle through X, Y, Z axis for doing rotations.						
					--]]
					self.canBeRIGHT = false
					self.prevInputDOWN = false
				end
				if inputUP then self.prevInputUP = true end
				if inputDOWN then self.prevInputDOWN = true end
				if inputLEFT then self.prevInputLEFT = true end
				if inputRIGHT then self.prevInputRIGHT = true end
			else -- can be fwd, back, left, or right
				if self.prevInputUP and not (self.prevInputDOWN or self.prevInputLEFT or self.prevInputRIGHT) then
					-- FORWARD
					userInput = true
					shiftType = "FORWARD"
					--self.shiftOffset = parent.shape.up / 4
				elseif self.prevInputDOWN and not (self.prevInputUP or self.prevInputLEFT or self.prevInputRIGHT) then
					-- BACK
					userInput = true
					shiftType = "BACK"
					--self.shiftOffset = (parent.shape.up / 4) * -1
				elseif self.canBeLEFT and self.prevInputLEFT and not (self.prevInputUP or self.prevInputDOWN or self.prevInputRIGHT) then
					-- LEFT
					userInput = true
					shiftType = "LEFT"
					--self.shiftOffset = parent.shape.right / 4
				elseif self.canBeRIGHT and self.prevInputRIGHT and not (self.prevInputUP or self.prevInputDOWN or self.prevInputLEFT) then
					-- RIGHT
					userInput = true
					shiftType = "RIGHT"
					--self.shiftOffset = (parent.shape.right / 4) * -1
				end
				self.canBeLEFT = true
				self.canBeRIGHT = true
				self.prevInputUP = false
				self.prevInputDOWN = false
				self.prevInputLEFT = false
				self.prevInputRIGHT = false
			end
			self.prevInputANY = inputANY
			-- if user input trying to shift parts
			if userInput then
				self.shiftBoard = {}
				self.particleLocations = {}
				if not hasData(self.shiftBodies) then
					self.shiftBodies[tostring(self.shape.body.id)] = self.shape.body
				end
				-- check all known bodies for parts to shift
				for k,body in pairs(self.shiftBodies) do
					if sm.exists(body) then
						for k,shape in pairs(body:getShapes()) do
							if (shape.color == self.dynamicColor or shape.color == self.staticColor) and shape.id ~= self.shape.id then
								self.shiftBoard[tostring(shape.id)] = {
									shape = shape,
									id = shape.id,
									color = shape.color,
									size = shape:getBoundingBox(),
									shapeUuid = shape.shapeUuid, 
									localPosition = shape.localPosition,
									worldPosition = shape.worldPosition,
									relativePosition = toLocal(self.shape, (shape.worldPosition - self.shape.worldPosition)),
									worldRotation = shape.worldRotation,
									xAxisL = shape.xAxis,
									zAxisL = shape.zAxis,
									xAxisG = shape.right,
									yAxisG = shape.at,
									zAxisG = shape.up,
									xAxisR = toLocal(self.shape, shape.right),
									yAxisR = toLocal(self.shape, shape.at),
									zAxisR = toLocal(self.shape, shape.up),
									shiftType = shiftType
								}
								shape:destroyShape(0)
							end
						end
					else
						self.shiftBodies[k] = nil
					end
				end
				-- if any parts to shift were found
				if hasData(self.shiftBoard) then
					self:server_spawn("shiftBoard")
				-- else, error (no parts found to shift)
				else
					self.network:sendToClients('client_error')
				end
			end
		else
			local btnDown = parent:isActive()
			if btnDown and not self.prevBtnDown then
				self:server_spawn("replayBoard")
			end
			self.prevBtnDown = btnDown
		end
	end
end

function GlitchWeld.server_cutPaste( self )
	local selfColor = tostring(self.shape.color)
	--local globalMode = self.shape.color ~= self.defaultColor
	self.particleLocations = {}
	local didCopy = false
	local clearReplay = not hasData(self.clipBoard)
	--local clearGlobalReplay = not hasData(_G["globalClipBoard"][tostring(self.shape.color)])
	for k,shape in pairs(self.shape.body:getCreationShapes()) do
		if (shape.color == self.dynamicColor or shape.color == self.staticColor) and shape.id ~= self.shape.id then
			didCopy = true
			--[[
			if globalMode then
				-- global clipBoard
				if not _G["globalClipBoard"][tostring(self.shape.color)] then
					_G["globalClipBoard"][tostring(self.shape.color)] = {}
				end
				printT(_G["globalClipBoard"][tostring(self.shape.color)])
				print(tostring(self.shape.color))
				_G["globalClipBoard"][tostring(self.shape.color)][tostring(shape.id)] = {
					shape = shape,
					id = shape.id,
					color = shape.color,
					size = shape:getBoundingBox(),
					shapeUuid = shape.shapeUuid,
					body = shape.body,
					localPosition = shape.localPosition,
					worldPosition = shape.worldPosition,
					relativePosition = toLocal(self.shape, (shape.worldPosition - self.shape.worldPosition)),
					worldRotation = shape.worldRotation,
					xAxisL = shape.xAxis,
					zAxisL = shape.zAxis,
					xAxisG = shape.right,
					yAxisG = shape.at,
					zAxisG = shape.up,
					xAxisR = toLocal(self.shape, shape.right),
					yAxisR = toLocal(self.shape, shape.at),
					zAxisR = toLocal(self.shape, shape.up)
				}
				-- global globalReplayBoard
				if clearGlobalReplay or not _G["globalReplayBoard"][tostring(self.shape.color)] then
					_G["globalReplayBoard"][tostring(self.shape.color)] = {}
				end
				_G["globalReplayBoard"][tostring(self.shape.color)][tostring(shape.id)] = {
					shape = shape,
					id = shape.id,
					color = shape.color,
					size = shape:getBoundingBox(),
					shapeUuid = shape.shapeUuid,
					body = shape.body,
					localPosition = shape.localPosition,
					worldPosition = shape.worldPosition,
					relativePosition = toLocal(self.shape, (shape.worldPosition - self.shape.worldPosition)),
					worldRotation = shape.worldRotation,
					xAxisL = shape.xAxis,
					zAxisL = shape.zAxis,
					xAxisG = shape.right,
					yAxisG = shape.at,
					zAxisG = shape.up,
					xAxisR = toLocal(self.shape, shape.right),
					yAxisR = toLocal(self.shape, shape.at),
					zAxisR = toLocal(self.shape, shape.up)
				}
			else
			--]]
				-- default clipBoard
				self.clipBoard[tostring(shape.id)] = {
					shape = shape,
					id = shape.id,
					color = shape.color,
					size = shape:getBoundingBox(),
					shapeUuid = shape.shapeUuid,
					body = shape.body,
					localPosition = shape.localPosition,
					worldPosition = shape.worldPosition,
					relativePosition = toLocal(self.shape, (shape.worldPosition - self.shape.worldPosition)),
					worldRotation = shape.worldRotation,
					xAxisL = shape.xAxis,
					zAxisL = shape.zAxis,
					xAxisG = shape.right,
					yAxisG = shape.at,
					zAxisG = shape.up,
					xAxisR = toLocal(self.shape, shape.right),
					yAxisR = toLocal(self.shape, shape.at),
					zAxisR = toLocal(self.shape, shape.up)
				}
				-- default replayBoard
				if clearReplay then
				print("clear")
					self.replayBoard = {}
					clearReplay = false
				end
				self.replayBoard[tostring(shape.id)] = {
					shape = shape,
					id = shape.id,
					color = shape.color,
					size = shape:getBoundingBox(),
					shapeUuid = shape.shapeUuid,
					body = shape.body,
					localPosition = shape.localPosition,
					worldPosition = shape.worldPosition,
					relativePosition = toLocal(self.shape, (shape.worldPosition - self.shape.worldPosition)),
					worldRotation = shape.worldRotation,
					xAxisL = shape.xAxis,
					zAxisL = shape.zAxis,
					xAxisG = shape.right,
					yAxisG = shape.at,
					zAxisG = shape.up,
					xAxisR = toLocal(self.shape, shape.right),
					yAxisR = toLocal(self.shape, shape.at),
					zAxisR = toLocal(self.shape, shape.up)
				}
			--end
			shape:destroyShape(0)
			self.particleLocations[#self.particleLocations + 1] = shape.worldPosition
		end
	end
	-- if copying
	if didCopy then
		self.network:sendToClients('client_copy', self.particleLocations)
	-- if pasting
	else
		-- if global mode and has data to paste
		--if globalMode and hasData(_G["globalClipBoard"][tostring(self.shape.color)]) then
		--	self:server_spawn("globalClipBoard")
		--	_G["globalClipBoard"][tostring(self.shape.color)] = {}
		-- if local mode and has data to paste
		--elseif ...
		if hasData(self.clipBoard) then
			self:server_spawn("clipBoard")
			self.clipBoard = {}
		-- if there was nothing to paste
		else
			self.network:sendToClients('client_error')
		end
	end
end

function GlitchWeld.server_spawn( self, boardType )
	--local globalMode = self.shape.color ~= self.defaultColor
	local clipBoard = {}
	if boardType == "clipBoard" then
		clipBoard = self.clipBoard
	elseif boardType == "globalClipBoard" then
		clipBoard = _G["globalClipBoard"][tostring(self.shape.color)]
	elseif boardType == "shiftBoard" then
		clipBoard = self.shiftBoard
	elseif boardType == "replayBoard" then
		--if globalMode then 
			--clipBoard = _G["globalReplayBoard"][tostring(self.shape.color)]
		--else
			clipBoard = self.replayBoard
		--end
		self.particleLocations = {}
	end
	local didSpawn = false
	for k,item in pairs(clipBoard) do
		local spawnedShape = nil
		local static = item.color == self.staticColor
		local shiftOffset = sm.vec3.zero()
		if boardType == "shiftBoard" then
			if item.color == self.staticColor then
				if item.shiftType == "UP" then
					shiftOffset = self.seat.at / 4
				elseif item.shiftType == "DOWN" then
					shiftOffset = (self.seat.at / 4 )* -1
				elseif item.shiftType == "FORWARD" then
					shiftOffset = self.seat.up / 4
				elseif item.shiftType == "BACK" then
					shiftOffset = (self.seat.up / 4) * -1
				elseif item.shiftType == "LEFT" then
					shiftOffset = self.seat.right / 4
				elseif item.shiftType == "RIGHT" then
					shiftOffset = (self.seat.right / 4) * -1
				end
			else
				if item.shiftType == "UP" then
					shiftOffset = self.seat.yAxis
				elseif item.shiftType == "DOWN" then
					shiftOffset = self.seat.yAxis* -1
				elseif item.shiftType == "FORWARD" then
					shiftOffset = self.seat.zAxis
				elseif item.shiftType == "BACK" then
					shiftOffset = self.seat.zAxis * -1
				elseif item.shiftType == "LEFT" then
					shiftOffset = self.seat.xAxis
				elseif item.shiftType == "RIGHT" then
					shiftOffset = self.seat.xAxis * -1
				end
			end
		end
		local success,result = pcall( sm.shape.createPart, item.shapeUuid, sm.vec3.new(750,0,0), sm.quat.identity(), false, false)
		-- spawn PART
		if success then
			-- spawn STATIC PART
			if static then
				local rotation = item.worldRotation
				local position = item.worldPosition - (item.xAxisG * (item.size.x / 2)) - (item.yAxisG * (item.size.y / 2)) - (item.zAxisG * (item.size.z / 2))
				if boardType == "replayBoard" then
					self.tempPart = self.shape.body:createPart(item.shapeUuid, self.shape.worldPosition, item.zAxisL, item.xAxisL, false)
					rotation = self.tempPart.worldRotation
					position = (toGlobal(self.shape, item.relativePosition) + self.shape.worldPosition) - (toGlobal(self.shape, item.xAxisR) * (item.size.x / 2)) - (toGlobal(self.shape, item.yAxisR) * (item.size.y / 2)) - (toGlobal(self.shape, item.zAxisR) * (item.size.z / 2))
				end
				spawnedShape = sm.shape.createPart(item.shapeUuid, position + shiftOffset, rotation, false, true)
			-- spawn BODY PART
			else
				if sm.exists(item.body) then
					spawnedShape = item.body:createPart(item.shapeUuid, item.localPosition + shiftOffset, item.zAxisL, item.xAxisL, true)
				else
					spawnedShape = self.shape.body:createPart(item.shapeUuid, item.localPosition + shiftOffset, item.zAxisL, item.xAxisL, true)
				end
			end
		-- spawn BLOCK
		else 
			-- spawn STATIC BLOCK
			if static then
				local rotation = item.worldRotation
				local position = item.worldPosition - (item.xAxisG * (item.size.x / 2)) - (item.yAxisG * (item.size.y / 2)) - (item.zAxisG * (item.size.z / 2))
				if boardType == "replayBoard" then
					if sm.exists(item.body) then
						self.tempPart = item.body:createBlock(item.shapeUuid, item.size * 4, item.localPosition + shiftOffset, false)
					else
						self.tempPart = self.shape.body:createBlock(item.shapeUuid, item.size * 4, item.localPosition + shiftOffset, false)
					end
					--self.tempPart = self.shape.body:createPart(item.shapeUuid, self.shape.worldPosition, item.zAxisL, item.xAxisL, false)
					rotation = self.tempPart.worldRotation
					position = (toGlobal(self.shape, item.relativePosition) + self.shape.worldPosition) - (toGlobal(self.shape, item.xAxisR) * (item.size.x / 2)) - (toGlobal(self.shape, item.yAxisR) * (item.size.y / 2)) - (toGlobal(self.shape, item.zAxisR) * (item.size.z / 2))
				end
				spawnedShape = sm.shape.createBlock(item.shapeUuid, item.size * 4, position + shiftOffset, rotation, false, true)
			-- spawn BODY BLOCK
			else
				if sm.exists(item.body) then
					spawnedShape = item.body:createBlock(item.shapeUuid, item.size * 4, item.localPosition + shiftOffset, true)
				else
					spawnedShape = self.shape.body:createBlock(item.shapeUuid, item.size * 4, item.localPosition + shiftOffset, true)
				end
			end
		end
		self.particleLocations[#self.particleLocations + 1] = spawnedShape.worldPosition
		if boardType == "shiftBoard" then
			sm.shape.setColor(spawnedShape, item.color)
			self.shiftBodies[tostring(spawnedShape.body.id)] = spawnedShape.body
		else
			if self.shape.color ~= GlitchWeld.defaultColor then
				sm.shape.setColor(spawnedShape, self.shape.color)
			end
		end
		if spawnedShape then
			didSpawn = true
		end
	end
	if didSpawn then
		self.network:sendToClients('client_paste', self.particleLocations)
	elseif boardType == "replayBoard" then
		self:server_cutPaste()
	else
		self.network:sendToClients('client_error')
	end
end


-- ____________________________________ Client ____________________________________

--[[
function GlitchWeld.client_onCreate( self ) -- Client setup
	self:printDescription()
end
--]]

function GlitchWeld.client_onFixedUpdate( self, dt )
	if sm.isHost then
		for k,parent in pairs(self.interactable:getParents()) do
			if parent.type == "steering" then
				self.s_poseWeight = (parent:getPoseWeight(0) - 0.5) * 2
			end
		end
	end
end

function GlitchWeld.client_onInteract(self, character, lookAt)
	if not lookAt then return end 
	self.network:sendToServer('server_cutPaste')
end

function GlitchWeld.client_error( self )
    sm.audio.play( 'WeldTool - Error', self.shape.worldPosition )
end

function GlitchWeld.client_copy( self, particleLocations ) 
    sm.audio.play( 'WeldTool - Case 2', self.shape.worldPosition )
	sm.particle.createParticle('construct_welding', self.shape.worldPosition + (self.shape.at * 0.2))
	for k,position in pairs(particleLocations) do
		sm.particle.createParticle('hammer_plastic', position)
	end
end

function GlitchWeld.client_paste( self, particleLocations ) 
    sm.audio.play( 'WeldTool - Sparks', self.shape.worldPosition )
	sm.particle.createParticle('construct_welding', self.shape.worldPosition + (self.shape.at * 0.2))
	for k,position in pairs(particleLocations) do
		sm.particle.createParticle('construct_welding', position)
	end
end
