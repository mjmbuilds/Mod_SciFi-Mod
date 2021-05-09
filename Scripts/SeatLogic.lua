--[[ 
********** Seat Logic by MJM ********** 
--]]
SeatLogic = class()
SeatLogic.maxChildCount = -1
SeatLogic.maxParentCount = -1
SeatLogic.connectionInput = sm.interactable.connectionType.power
SeatLogic.connectionOutput = sm.interactable.connectionType.logic
SeatLogic.colorNormal = sm.color.new( 0x7d0388ff )
SeatLogic.colorHighlight = sm.color.new( 0x9e0caaff )
SeatLogic.poseWeightCount = 2

SeatLogic.modes = {"W", "S", "A", "D", "Left Click", "Right Click", "Space", "Scroll Up", "Scroll Down", "Seated", "Seated (not)", "W (exclusive)", "S (exclusive)", "A (exclusive)", "D (exclusive)", "W,A (and)", "W,D (and)", "S,A (and)", "S,D (and)", "W,A,S,D (or)", "W,A,S,D (nor)", "W,S (or)", "W,S (nor)", "A,D (or)", "A,D (nor)"}


function SeatLogic.server_onCreate( self )
	self.prevSteerAngle = 0
	
	self.data = self.storage:load()
	if self.data == null then
		self.data = {}
	end
	if self.data.modeIndex == null then
		self.data.modeIndex = 1
		self.storage:save(self.data)
	end
	
end

function SeatLogic.sv_requestMode(self)
	self.network:sendToClients("cl_setMode", self.data.modeIndex)
end

function SeatLogic.sv_changeMode( self, newIndex )
	self.data.modeIndex = newIndex
	self.storage:save(self.data)
	self.network:sendToClients("cl_setMode", newIndex)
end

function SeatLogic.server_onFixedUpdate( self, dt )
	local active = false
	local wDown = false
	local sDown = false
	local aDown = false
	local dDown = false
	local seated = false
	local leftClick = false
	local rightClick = false
	local scrollUp = false
	local scrollDown = false
	local space = false
	
	-- check for seat signals
	for k,parent in pairs(self.interactable:getParents()) do
		if parent:hasOutputType(sm.interactable.connectionType.seated) and parent:isActive() then
			seated = true -- seated
		
			local power = parent:getPower()
			if power > 0 then -- W is pressed
				wDown = true
			elseif power < 0 then -- S is pressed
				sDown = true
			end
			
			local steerAngle = parent:getSteeringAngle()
			if steerAngle < 0 then -- A is pressed
				aDown = true
			elseif steerAngle > 0 then -- D is pressed
				dDown = true
			end
			self.prevSteerAngle = steerAngle
			
			local parentID = parent.id
			if _G[parentID.."space"] then
				space = true
			end
			if _G[parentID.."leftClick"] then
				leftClick = true
			end
			if _G[parentID.."rightClick"] then
				rightClick = true
			end
			if _G[parentID.."scrollUp"] then
				scrollUp = true
			end
			if _G[parentID.."scrollDown"] then
				scrollDown = true
			end
		end
	end
	
	if seated then -- a player is seated in a connected seat
		if self.data.modeIndex == 1 then -- W
			if wDown then
				active = true
			end
		elseif self.data.modeIndex == 2 then -- S
			if sDown then
				active = true
			end
		elseif self.data.modeIndex == 3 then -- A
			if aDown then
				active = true
			end
		elseif self.data.modeIndex == 4 then -- D
			if dDown then
				active = true
			end
		elseif self.data.modeIndex == 5 then -- Left Click
			if leftClick then
				active = true
			end
		elseif self.data.modeIndex == 6 then -- Right Click
			if rightClick then
				active = true
			end
		elseif self.data.modeIndex == 7 then -- Space
			if space then
				active = true
			end			
		elseif self.data.modeIndex == 8 then -- Scroll Up
			if scrollUp then
				active = true
			end
		elseif self.data.modeIndex == 9 then -- Scroll Down
			if scrollDown then
				active = true
			end
		elseif self.data.modeIndex == 10 then -- Seated
			if seated then
				active = true
			end
		-- skip modeIndex 11 (Not Seated) because it is checked elsewhere
		elseif self.data.modeIndex == 12 then -- W exclusive
			if wDown and not (sDown or aDown or dDown) then
				active = true
			end
		elseif self.data.modeIndex == 13 then -- S exclusive
			if sDown and not (wDown or aDown or dDown) then
				active = true
			end
		elseif self.data.modeIndex == 14 then -- A exclusive
			if aDown and not (wDown or sDown or dDown) then
				active = true
			end
		elseif self.data.modeIndex == 15 then -- D exclusive
			if dDown and not (wDown or sDown or aDown) then
				active = true
			end
		elseif self.data.modeIndex == 16 then -- W+A
			if wDown and aDown then
				active = true
			end
		elseif self.data.modeIndex == 17 then -- W+D
			if wDown and dDown then
				active = true
			end
		elseif self.data.modeIndex == 18 then -- S+A
			if sDown and aDown then
				active = true
			end
		elseif self.data.modeIndex == 19 then -- S+D
			if sDown and dDown then
				active = true
			end
		elseif self.data.modeIndex == 20 then -- WASD (or)
			if wDown or sDown or aDown or dDown then
				active = true
			end
		elseif self.data.modeIndex == 21 then -- WASD (nor)
			if not (wDown or sDown or aDown or dDown) then
				active = true
			end
		elseif self.data.modeIndex == 22 then -- WS (or)
			if wDown or sDown then
				active = true
			end
		elseif self.data.modeIndex == 23 then -- WS (nor)
			if not (wDown or sDown) then
				active = true
			end
		elseif self.data.modeIndex == 24 then -- AD (or)
			if aDown or dDown then
				active = true
			end
		elseif self.data.modeIndex == 25 then -- AD (nor)
			if not (aDown or dDown) then
				active = true
			end
		end
	else -- no player is seated in a connected seat
		if self.data.modeIndex == 11 -- Not Seated
		or self.data.modeIndex == 21 -- WASD (nor)
		or self.data.modeIndex == 23 -- WS (nor)
		or self.data.modeIndex == 25 then -- AD (nor)
			active = true
		end
	end
	
	-- apply active	
	if active ~= self.interactable:isActive() then
		self.interactable:setActive(active)
	end
	
end

-- ____________________________________ Client ____________________________________

function SeatLogic.client_onCreate(self)
	self.cl_modeIndex = 1
	self.network:sendToServer("sv_requestMode")
end

function SeatLogic.client_onDestroy( self )
	if self.cl_ID then
		_G[self.cl_ID.."leftClick"] = nil
		_G[self.cl_ID.."rightClick"] = nil
		_G[self.cl_ID.."space"] = nil
		_G[self.cl_ID.."scrollUp"] = nil
		_G[self.cl_ID.."scrollDown"] = nil
	end
end

function SeatLogic.client_onFixedUpdate( self, dt )
	if self.cl_ID == null and self.interactable then
		self.cl_ID = self.interactable.id
		self:cl_setMode(self.cl_modeIndex)
	end

	if self.interactable:isActive() then
		self.interactable:setPoseWeight(0, 1)
	else
		self.interactable:setPoseWeight(0, 0)
	end
end

function SeatLogic.cl_setMode( self, modeIndex )
	self.cl_modeIndex = modeIndex
	self.interactable:setUvFrameIndex(modeIndex - 1)
	if self.cl_ID then
		_G[self.cl_ID.."leftClick"] = nil
		_G[self.cl_ID.."rightClick"] = nil
		_G[self.cl_ID.."space"] = nil
		_G[self.cl_ID.."scrollUp"] = nil
		_G[self.cl_ID.."scrollDown"] = nil
		if modeIndex == 5 then
			_G[self.cl_ID.."leftClick"] = true
		elseif modeIndex == 6 then
			_G[self.cl_ID.."rightClick"] = true
		elseif modeIndex == 7 then
			_G[self.cl_ID.."space"] = true
		elseif modeIndex == 8 then
			_G[self.cl_ID.."scrollUp"] = true
		elseif modeIndex == 9 then
			_G[self.cl_ID.."scrollDown"] = true
		end
	end
end

function SeatLogic.client_onInteract(self, character, lookAt)
    if not lookAt then return end
	if self.gui == nil then
		self.gui = sm.gui.createEngineGui()
		self.gui:setSliderCallback( "Setting", "cl_onSliderChange")
		self.gui:setText("Name", "Seat Logic")
		self.gui:setText("Interaction", "Select Mode")		
		self.gui:setIconImage("Icon", sm.uuid.new("6f64d36d-5e23-4f6b-bcb5-e0057ba43fce"))
		self.gui:setVisible("FuelContainer", false )
	end
	self.gui:setSliderData("Setting", #self.modes, self.cl_modeIndex-1)
	self.gui:setText("SubTitle", "Mode: "..self.modes[self.cl_modeIndex])
	self.gui:open()
end

function SeatLogic.cl_onSliderChange( self, sliderName, sliderPos )
	local newIndex = sliderPos + 1
	self.cl_modeIndex = newIndex
	if self.gui ~= nil then
		self.gui:setText("SubTitle", "Mode: "..self.modes[newIndex])
	end
	self.network:sendToServer("sv_changeMode", newIndex)
	--sm.audio.play("Button on", self.shape.worldPosition)
end
