dofile "Utility.lua"
--[[ 
********** FourDigitDisplay by MJM ********** 
--]]

FourDigitDisplay = class()
FourDigitDisplay.maxParentCount = -1
FourDigitDisplay.maxChildCount = -1
FourDigitDisplay.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
FourDigitDisplay.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
FourDigitDisplay.colorNormal = sm.color.new( 0x505050ff )
FourDigitDisplay.colorHighlight = sm.color.new( 0x707070ff )

FourDigitDisplay.uuid = "b85adaa4-0af0-4c7f-8a13-69af46da2f84"

FourDigitDisplay.boneDigitMap = {
	{0,0,0,0,0,0,1}, -- 0
	{1,0,0,1,1,1,1}, -- 1
	{0,0,1,0,0,1,0}, -- 2
	{0,0,0,0,1,1,0}, -- 3
	{1,0,0,1,1,0,0}, -- 4
	{0,1,0,0,1,0,0}, -- 5
	{0,1,0,0,0,0,0}, -- 6
	{0,0,0,1,1,1,1}, -- 7
	{0,0,0,0,0,0,0}, -- 8
	{0,0,0,0,1,0,0} -- 9
}

FourDigitDisplay.mpMemUuid = sm.uuid.new("b39faec9-1ed0-4475-8bc0-78d125df1b58")

-- ____________________________________ Server ____________________________________

function FourDigitDisplay.server_onCreate( self ) --- Server setup ---
	self.prevPower = 0
	self.data = {[0] = 0}
	self.loaded = self.storage:load()
	if self.loaded then
		self.data.value = self.loaded.value or 0
		self.data.decimals = self.loaded.decimals or 0
	else
		self.data.value = 0
		self.data.decimals = 0
	end
end
function FourDigitDisplay.server_onRefresh( self )
	print("* * * * * REFRESH FourDigitDisplay * * * * *")
	self:server_onCreate()
end

function FourDigitDisplay.server_requestData( self )
	self.network:sendToClients("client_setData", self.data)
end

function FourDigitDisplay.server_changeValue( self, value )
	if tostring(self.shape.color) ~= "eeeeeeff" then
		self.sendTick = true
	end
	self.data.value = self.data.value + value
	self.storage:save(self.data)
	self.network:sendToClients("client_setData", self.data)
end

function FourDigitDisplay.server_changeDecimals( self, decimals )
	self.data.decimals = decimals
	self.storage:save(self.data)
	self.network:sendToClients("client_setData", self.data)
end

function FourDigitDisplay.server_clear( self )
	if tostring(self.shape.color) ~= "eeeeeeff" then
		self.sendTick = true
	end
	self.data.value = 0
	self.storage:save(self.data)
	self.network:sendToClients("client_setData", self.data)
end

function FourDigitDisplay.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------

	-- if sending a single output logic tick
	if self.sendTick then
		self.interactable:setActive(true)
		self.sendTick = false
		self.interactable:setPower(self.data.value)
		self.prevPower = self.data.value
	else
		if self.interactable:isActive() then
			self.interactable:setActive(false)
		else
			-- check if extending another screen
			local isExtension = false
			for k,parent in pairs(self.interactable:getParents()) do
				if tostring(parent.shape.shapeUuid) == self.uuid then
					self.data.value = parent:getPower()
					isExtension = true
				end
			end
			
			-- check if has input power
			if not isExtension then
				local hasPowerInput = false
				local powerInputSum = 0
				for k,parent in pairs(self.interactable:getParents()) do
					if not isLogic(parent) then
						hasPowerInput = true
						powerInputSum = powerInputSum + parent:getPower()
					end
				end
				if hasPowerInput then
					self.data.value = powerInputSum
					
				-- check if editing power of a memory panel
				elseif tostring(self.shape.color) ~= "eeeeeeff" then
					for k,child in pairs(self.interactable:getChildren()) do
						if child.shape.shapeUuid == self.mpMemUuid then
							self.data.value = child:getPower()
							break
						end
					end
				end
			end
			
			-- update output power
			if self.prevPower ~= self.data.value then
				self.interactable:setPower(self.data.value)
				self.prevPower = self.data.value
			end
		end
	end

	--print("Power: "..self.interactable.power)
end

-- ____________________________________ Client ____________________________________

function FourDigitDisplay.client_onCreate( self ) --- Client setup ---
	self.value = 0
	self.decimals = 0
	_G[tostring(self.shape.id).."display"] = {}
	self.cgData = _G[tostring(self.shape.id).."display"]
	self.cgData.value = self.value
	self.cgData.decimals = self.decimals
	self.cgData.hasPowerInput = false
	self.cgData.isExtension = false
	self.network:sendToServer("server_requestData")
	self.isExtension = false
	self.displayDelay = 0
	
	self.interactable:setAnimEnabled( "Decimal", true )
	self.interactable:setAnimEnabled( "HideNumbers", true )
	self.interactable:setAnimEnabled( "Select", true )
	self.interactable:setAnimEnabled( "Select2", true )
	self.interactable:setAnimEnabled( "Negative", true )
	self.interactable:setAnimEnabled( "A", true )
	self.interactable:setAnimEnabled( "B", true )
	self.interactable:setAnimEnabled( "C", true )
	self.interactable:setAnimEnabled( "D", true )
	self.interactable:setAnimEnabled( "E", true )
	self.interactable:setAnimEnabled( "F", true )
	self.interactable:setAnimEnabled( "G", true )
	self.interactable:setUvFrameIndex(0)
	self.interactable:setAnimProgress( "Decimal", 1 )
	self.interactable:setAnimProgress( "HideNumbers", 0 )
	self.interactable:setAnimProgress( "Select", 1 )
	self.interactable:setAnimProgress( "Select", 0 )
	self.interactable:setAnimProgress( "Negative", 0 )
	self.interactable:setAnimProgress( "A", 0 )
	self.interactable:setAnimProgress( "B", 0 )
	self.interactable:setAnimProgress( "C", 0 )
	self.interactable:setAnimProgress( "D", 0 )
	self.interactable:setAnimProgress( "E", 0 )
	self.interactable:setAnimProgress( "F", 0 )
	self.interactable:setAnimProgress( "G", 1 )
	
	self.isPointing = false
	self.selecting = nil
end
function FourDigitDisplay.client_onRefresh( self )
	self:client_onCreate()
end

function FourDigitDisplay.client_setData( self, data )
	self.value = data.value
	self.decimals = data.decimals
end

function FourDigitDisplay.client_canInteract( self )
	self.isPointing = true
	return true
end

function FourDigitDisplay.client_onInteract(self, character, lookAt)
    if not lookAt then return end
	if self.selecting then
		if self.isExtension then
			self.cgData.selecting = self.selecting
		else
			self:client_select({selecting = self.selecting, isExtension = false})
		end
	end
end

function FourDigitDisplay.client_select( self, data )
	sm.audio.play("Button on", self.shape.worldPosition)
	local selecting = data.selecting
	local isExtension = data.isExtension
	if selecting == "clear" then
		self.network:sendToServer('server_clear')
	elseif selecting == "decimal-" then
		self.decimals = self.decimals - 1
		if self.decimals < 0  then
			self.decimals = 0
		end
		self.network:sendToServer('server_changeDecimals', self.decimals)
	elseif selecting == "decimal+" then
		self.decimals = self.decimals + 1
		if self.decimals > 3  then
			self.decimals = 3
		end
		self.network:sendToServer('server_changeDecimals', self.decimals)
	else
		local adjSelecting = selecting
		if isExtension then
			adjSelecting = adjSelecting * 10000
		end
		if self.decimals == 1 then
			adjSelecting = adjSelecting / 10
		elseif self.decimals == 2 then
			adjSelecting = adjSelecting / 100
		elseif self.decimals == 3 then
			adjSelecting = adjSelecting / 1000
		end
		self.network:sendToServer('server_changeValue', adjSelecting)
	end
end

function FourDigitDisplay.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------
	
	--print(self.value)
	
	if self.interactable.active then
		self.displayDelay = 3
	end
	
	local dispError = false
	self.interactable:setAnimProgress( "Select", 1 ) -- reset select highlight
	self.interactable:setAnimProgress( "Select2", 0 )
	self.selecting = nil -- clear flag for telling onInteract what is selected
	local displayNumber = math.abs(self.value) -- adjusted value for the display
	
	-- check if there is an extension display
	local hasExtension = false
	for k,child in pairs(self.interactable:getChildren()) do
		if tostring(child.shape.shapeUuid) == self.uuid then
			hasExtension = true
			local extData = _G[tostring(child.shape.id).."display"]
			if extData and extData.selecting then
				self:client_select({selecting = extData.selecting, isExtension = true})
				extData.selecting = nil
			end
			break
		end
	end
	
	-- check if extending another display
	self.isExtension = false
	local extensionOfPowerInput = false
	local extensionDecimals = 0
	for k,parent in pairs(self.interactable:getParents()) do
		if tostring(parent.shape.shapeUuid) == self.uuid then
			self.isExtension = true
			local parentScreen = _G[tostring(parent.shape.id).."display"]
			if parentScreen then
				self.value = parentScreen.value or 0
				extensionDecimals = parentScreen.decimals or 0
				extensionOfPowerInput = parentScreen.hasPowerInput
				dispError = parentScreen.isExtension
			end
			break
		end
	end
	
	if dispError then
		self.cgData.isExtension = true
		self.interactable:setAnimProgress( "Decimal", 1 )
		self.interactable:setAnimProgress( "HideNumbers", 1 )
		self.interactable:setAnimProgress( "Select", 1 )
		self.interactable:setAnimProgress( "Select2", 0 )
		self.interactable:setAnimProgress( "Negative", 0 )
		self.interactable:setAnimProgress( "A", 0 )
		self.interactable:setAnimProgress( "B", 0 )
		self.interactable:setAnimProgress( "C", 0 )
		self.interactable:setAnimProgress( "D", 0 )
		self.interactable:setAnimProgress( "E", 0 )
		self.interactable:setAnimProgress( "F", 0 )
		self.interactable:setAnimProgress( "G", 0 )
	else
		-- check if has input power or else is in counter mode
		local hasPowerInput = false
		if not self.isExtension then
			for k,parent in pairs(self.interactable:getParents()) do
				if not isLogic(parent) then
					hasPowerInput = true
					self.value = parent:getPower()
					break
				end
			end
			-- check if editing power of a memory panel
			if not hasPowerInput and tostring(self.shape.color) ~= "eeeeeeff" then
				for k,child in pairs(self.interactable:getChildren()) do
					if child.shape.shapeUuid == self.mpMemUuid then
						self.value = child:getPower()
						break
					end
				end
			end
		end
		
		-- manual counter interaction
		if self.isPointing then --and not hasPowerInput and not extensionOfPowerInput then
			local start = sm.camera.getPosition() + (sm.localPlayer.getDirection() * 0.13)
			--local start = sm.camera.getPosition() + (sm.camera.getDirection() * 0.13)
			local hit, result = sm.physics.raycast( start, (start + sm.camera.getDirection() * 4.5) )
			if hit then
				if result:getShape() == self.shape then
					local hitVec = toLocal(self.shape, result.pointWorld - self.shape.worldPosition)
					
					--print(hitVec)
					
					if hitVec.z > -0.12 then
						if hitVec.x < -0.12 then -- 1000 place
							if hitVec.y > 0 then
								if not hasPowerInput and not extensionOfPowerInput then
									self.selecting = 1000
									self.interactable:setAnimProgress( "Select", 0 )
									--print("1000")
								end
							else
								if hitVec.x < -0.21 and hitVec.y < -0.08 then -- < Decimal
									self.selecting = "decimal+"
									self.interactable:setAnimProgress( "Select2", 0.4 )
									--print("< Decimal")
								else
									if not hasPowerInput and not extensionOfPowerInput then
										if not hasPowerInput and not extensionOfPowerInput then
											self.selecting = -1000
											self.interactable:setAnimProgress( "Select", 0.7 )
											--print("-1000")
										end
									end
								end
							end
						elseif hitVec.x < 0 then -- 100 place
							if not hasPowerInput and not extensionOfPowerInput then
								if hitVec.y > 0 then
									self.selecting = 100
									self.interactable:setAnimProgress( "Select", 0.1 )
									--print("100")
								else
									self.selecting = -100
									self.interactable:setAnimProgress( "Select", 0.6 )
									--print("-100")
								end
							end
						elseif hitVec.x < 0.12 then -- 10 place
							if not hasPowerInput and not extensionOfPowerInput then
								if hitVec.y > 0 then
									self.selecting = 10
									self.interactable:setAnimProgress( "Select", 0.2 )
									--print("10")
								else
									self.selecting = -10
									self.interactable:setAnimProgress( "Select", 0.5 )
									--print("-10")
								end
							end
						else -- 1 place
							if hitVec.y > 0 then
								if hitVec.x > 0.22 and hitVec.y > 0.08 then -- Clear
									self.selecting = "clear"
									self.interactable:setAnimProgress( "Select2", 0.2 )
									--print("Clear")
								else
									if not hasPowerInput and not extensionOfPowerInput then
										self.selecting = 1
										self.interactable:setAnimProgress( "Select", 0.3 )
										--print("1")
									end
								end
							else
								if hitVec.x > 0.22 and hitVec.y < -0.08 then -- Decimal >
									self.selecting = "decimal-"
									self.interactable:setAnimProgress( "Select2", 0.3 )
									--print("Decimal >")
								else
									if not hasPowerInput and not extensionOfPowerInput then
										self.selecting = -1
										self.interactable:setAnimProgress( "Select", 0.4 )
										--print("-1")
									end
								end
							end
						end
					else
						self.selecting = 0
					end
				end
			else
				self.selecting = 0
			end
		end
		
		-- set globals for linked displays
		self.cgData.value = self.value
		self.cgData.decimals = self.decimals
		self.cgData.hasPowerInput = hasPowerInput
		self.cgData.isExtension = self.isExtension
		
		------------- set display
		local showBoneDigit = true
		-- adjust display number
		if self.decimals == 1 or extensionDecimals == 1 then
			--if self.isExtension then
				--displayNumber = displayNumber * 100000
			--else
				displayNumber = displayNumber * 10
			--end	
		elseif self.decimals == 2 or extensionDecimals == 2 then
			--if self.isExtension then
				--displayNumber = displayNumber * 1000000
			--else
				displayNumber = displayNumber * 100
			--end
		elseif self.decimals == 3 or extensionDecimals == 3 then
			--if self.isExtension then
				--displayNumber = displayNumber * 10000000
			--else
				displayNumber = displayNumber * 1000
			--end
		end
		
		if self.isExtension then
			displayNumber = math.floor(displayNumber / 10000)
		end
		
		-- set decimals
		if self.isExtension or self.decimals == 0 then
			self.interactable:setAnimProgress( "Decimal", 1 )
		elseif self.decimals == 1 then
			self.interactable:setAnimProgress( "Decimal", 0 )
		elseif self.decimals == 2 then
			self.interactable:setAnimProgress( "Decimal", 0.1 )
		elseif self.decimals == 3 then
			self.interactable:setAnimProgress( "Decimal", 0.2 )
		end
		
		-- set hide leading zeros when connected to number inputs
		--[[
		if (hasPowerInput or extensionOfPowerInput) and displayNumber < 1000 then
			if displayNumber < 10 then
				self.interactable:setAnimProgress( "HideNumbers", 0.3 )
				showBoneDigit = false
			elseif displayNumber < 100 then
				self.interactable:setAnimProgress( "HideNumbers", 0.2 )
				showBoneDigit = false
			else
				self.interactable:setAnimProgress( "HideNumbers", 0.1 )
				showBoneDigit = false
			end
		else
			self.interactable:setAnimProgress( "HideNumbers", 0 )
		end
		--]]
		self.interactable:setAnimProgress( "HideNumbers", 0 )
		
		-- set negative sign
		if self.isExtension and self.value < 0 and displayNumber < 1 then
			self.interactable:setAnimProgress( "HideNumbers", 0.4 )
			if (extensionDecimals == 3) or (extensionDecimals == 2 and self.value <= -10 ) or (extensionDecimals == 1 and self.value <= -100 ) or (extensionDecimals == 0 and self.value <= -1000 )then
				self.interactable:setAnimProgress( "Negative", 0.4 )
			else
				self.interactable:setAnimProgress( "Negative", 0 )
			end
		elseif self.value >= 0 or self.decimals == 3 then --or hasExtension then 
			self.interactable:setAnimProgress( "Negative", 0 )
		elseif self.decimals == 2 then
			if displayNumber < 1000 then
				self.interactable:setAnimProgress( "Negative", 0.1 )
				self.interactable:setAnimProgress( "HideNumbers", 0.1 )
				showBoneDigit = false
			else
				self.interactable:setAnimProgress( "Negative", 0 )
			end
		elseif self.decimals == 1 then
			if displayNumber < 100 then
				self.interactable:setAnimProgress( "Negative", 0.2 )
				self.interactable:setAnimProgress( "HideNumbers", 0.2 )
				showBoneDigit = false
			elseif displayNumber < 1000 then
				self.interactable:setAnimProgress( "Negative", 0.1 )
				self.interactable:setAnimProgress( "HideNumbers", 0.1 )
				showBoneDigit = false
			else
				self.interactable:setAnimProgress( "Negative", 0 )
			end
		elseif self.decimals == 0 then
			if displayNumber < 10 then
				self.interactable:setAnimProgress( "Negative", 0.3 )
				self.interactable:setAnimProgress( "HideNumbers", 0.3 )
				showBoneDigit = false
			elseif displayNumber < 100 then
				self.interactable:setAnimProgress( "Negative", 0.2 )
				self.interactable:setAnimProgress( "HideNumbers", 0.2 )
				showBoneDigit = false
			elseif displayNumber < 1000 then
				self.interactable:setAnimProgress( "Negative", 0.1 )
				self.interactable:setAnimProgress( "HideNumbers", 0.1 )
				showBoneDigit = false
			else
				self.interactable:setAnimProgress( "Negative", 0 )
			end
		end
		
		-- set UV digits
		--print("display number: "..displayNumber)
		local uvIndex = (displayNumber % 1000)
		-- correct for uv map wrap-around weirdness
		local wrapPadding = 0
		if uvIndex > 170 then
			wrapPadding = math.floor((uvIndex) / 170)
		end
		
		if self.displayDelay > 0 then
			self.displayDelay = self.displayDelay - 1
		else
			uvIndex = uvIndex + wrapPadding
			self.interactable:setUvFrameIndex(uvIndex)
			
			-- set bone digit
			if showBoneDigit then
				local bdIndex = math.floor((displayNumber / 1000) % 10) + 1
				self.interactable:setAnimProgress( "A", self.boneDigitMap[bdIndex][1] )
				self.interactable:setAnimProgress( "B", self.boneDigitMap[bdIndex][2] )
				self.interactable:setAnimProgress( "C", self.boneDigitMap[bdIndex][3] )
				self.interactable:setAnimProgress( "D", self.boneDigitMap[bdIndex][4] )
				self.interactable:setAnimProgress( "E", self.boneDigitMap[bdIndex][5] )
				self.interactable:setAnimProgress( "F", self.boneDigitMap[bdIndex][6] )
				self.interactable:setAnimProgress( "G", self.boneDigitMap[bdIndex][7] )
			end
		end
		
		self.isPointing = false
	end
end
