-- SeatMJM.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")

SeatMJM = class()
SeatMJM.maxChildCount = 255
SeatMJM.connectionOutput = sm.interactable.connectionType.seated
SeatMJM.colorNormal = sm.color.new( 0x00ff80ff )
SeatMJM.colorHighlight = sm.color.new( 0x6affb6ff )

SeatMJM.maxConnections = 255 --game max is 255

function SeatMJM.server_onCreate( self )
	if self.interactable then
		self.ID = self.interactable.id
	end
end

function SeatMJM.server_onFixedUpdate( self )
	local currentActive = (self.interactable:getSeatCharacter() ~= nil)
	self.interactable:setActive(currentActive)
	
	if self.ID then
		
		if self.clearScrollUp then
			_G[self.ID.."scrollUp"] = false
			self.clearScrollUp = false
		end	
		if _G[self.ID.."scrollUp"] then
			self.clearScrollUp = true
		end

		if self.clearScrollDown then
			_G[self.ID.."scrollDown"] = false
			self.clearScrollDown = false
		end	
		if _G[self.ID.."scrollDown"] then
			self.clearScrollDown = true
		end
	elseif self.interactable then
		self.ID = self.interactable.id
	end
end

function SeatMJM.sv_setGlobalFlag( self, props )
	if self.ID then
		_G[self.ID..props.key] = props.state
	end
end

function SeatMJM.server_onDestroy( self )
	if self.ID then
		_G[self.ID.."space"] = nil
		_G[self.ID.."leftClick"] = nil
		_G[self.ID.."rightClick"] = nil
		_G[self.ID.."scrollUp"] = nil
		_G[self.ID.."scrollDown"] = nil
	end
end

-- ____________________________________ Client ____________________________________

function SeatMJM.client_onCreate( self )
	self.cl = {}
	self.cl.seatedCharacter = nil
end

function SeatMJM.client_onDestroy( self )
	if self.gui then
		self.gui:destroy()
		self.gui = nil
	end
end

function SeatMJM.client_onFixedUpdate( self, dt )
	if self.reSeatTarget then
		self.reSeatTarget:setSeatCharacter( self.reSeatChar )
		self.reSeatTarget = nil
		self.reSeatChar = nil
	end
	
	local currentActive = self.interactable:isActive()
	if currentActive and self.prevActive ~= currentActive then
		self:cl_setLogicFlags()
	end
	self.prevActive = currentActive
end

function SeatMJM.client_onUpdate( self, dt )
	-- Update gui upon character change in seat
	local seatedCharacter = self.interactable:getSeatCharacter()
	if self.cl.seatedCharacter ~= seatedCharacter then
		if seatedCharacter and seatedCharacter:getPlayer() and seatedCharacter:getPlayer():getId() == sm.localPlayer.getId() then
			self.gui = sm.gui.createSeatGui()
			self.gui:open()
		else
			if self.gui then
				self.gui:destroy()
				self.gui = nil
			end
		end
		self.cl.seatedCharacter = seatedCharacter
	end
	-- Update gui upon toolbar updates
	if self.gui then
		local interactables = self.interactable:getSeatInteractables()
		for i=1, 10 do
			local value = interactables[i]
			if value and value:getConnectionInputType() == sm.interactable.connectionType.seated then
				self.gui:setGridItem( "ButtonGrid", i-1, {
					["itemId"] = tostring(value:getShape():getShapeUuid()),
					["active"] = value:isActive()
				})
			else
				self.gui:setGridItem( "ButtonGrid", i-1, nil)
			end
		end
	end

end

function SeatMJM.client_canInteract( self, character )
	if character:getCharacterType() == unit_mechanic and not character:isTumbling() then
		return true
	end
	return false
end

function SeatMJM.client_onInteract( self, character, state )
	if state then
		self:cl_seat()
		if self.shape.interactable:getSeatCharacter() ~= nil then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_OCCUPIED}", 4.0 )
		end
	end
end

function SeatMJM.cl_seat( self )
	if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
		self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
	end
end

function SeatMJM.cl_checkForReSeat( self )
	for k,child in pairs(self.interactable:getChildren()) do
		local cUuid = tostring(sm.shape.getShapeUuid(child:getShape()))
		if cUuid == "229fd8b4-e098-4cb2-bd24-b4c01e470f53" then -- Seat ReExiter Teleporter
			self.reSeatTarget = child
			self.reSeatChar = sm.localPlayer.getPlayer():getCharacter()
		end
	end
end

function SeatMJM.client_onAction( self, controllerAction, state )
	local consumeAction = true
	if state == true then
		if controllerAction == sm.interactable.actions.use then
			self:cl_checkForReSeat()
			self:cl_seat()
		elseif controllerAction == sm.interactable.actions.jump then
			if self.spaceLogic then
				self.network:sendToServer('sv_setGlobalFlag', { key = "space", state = true })
			else
				self:cl_checkForReSeat()
				self:cl_seat()
			end
		elseif controllerAction == sm.interactable.actions.item0 then
			self.interactable:pressSeatInteractable( 0 )
		elseif controllerAction == sm.interactable.actions.item1 then
			self.interactable:pressSeatInteractable( 1 )
		elseif controllerAction == sm.interactable.actions.item2 then
			self.interactable:pressSeatInteractable( 2 )
		elseif controllerAction == sm.interactable.actions.item3 then
			self.interactable:pressSeatInteractable( 3 )
		elseif controllerAction == sm.interactable.actions.item4 then
			self.interactable:pressSeatInteractable( 4 )
		elseif controllerAction == sm.interactable.actions.item5 then
			self.interactable:pressSeatInteractable( 5 )
		elseif controllerAction == sm.interactable.actions.item6 then
			self.interactable:pressSeatInteractable( 6 )
		elseif controllerAction == sm.interactable.actions.item7 then
			self.interactable:pressSeatInteractable( 7 )
		elseif controllerAction == sm.interactable.actions.item8 then
			self.interactable:pressSeatInteractable( 8 )
		elseif controllerAction == sm.interactable.actions.item9 then
			self.interactable:pressSeatInteractable( 9 )
		elseif controllerAction == sm.interactable.actions.create then
			if self.leftClickLogic then
				self.network:sendToServer('sv_setGlobalFlag', { key = "leftClick", state = true })
			end
		elseif controllerAction == sm.interactable.actions.attack then
			if self.rightClickLogic then
				self.network:sendToServer('sv_setGlobalFlag', { key = "rightClick", state = true })
			end
		elseif controllerAction == sm.interactable.actions.zoomIn then
			if self.scrollUpLogic then
				if self.otherKeyDown then
					consumeAction = false				
				else
					self.network:sendToServer('sv_setGlobalFlag', { key = "scrollUp", state = true })
				end
			else
				consumeAction = false
			end
		elseif controllerAction == sm.interactable.actions.zoomOut then
			if self.scrollDownLogic then
				if self.otherKeyDown then
					consumeAction = false
				else
					self.network:sendToServer('sv_setGlobalFlag', { key = "scrollDown", state = true })
				end
			else
				consumeAction = false
			end
		else
			self.otherKeyDown = true
			consumeAction = false
		end
	else
		if controllerAction == sm.interactable.actions.jump then
			if self.spaceLogic then
				self.network:sendToServer('sv_setGlobalFlag', { key = "space", state = false })
			end
		elseif controllerAction == sm.interactable.actions.item0 then
			self.interactable:releaseSeatInteractable( 0 )
		elseif controllerAction == sm.interactable.actions.item1 then
			self.interactable:releaseSeatInteractable( 1 )
		elseif controllerAction == sm.interactable.actions.item2 then
			self.interactable:releaseSeatInteractable( 2 )
		elseif controllerAction == sm.interactable.actions.item3 then
			self.interactable:releaseSeatInteractable( 3 )
		elseif controllerAction == sm.interactable.actions.item4 then
			self.interactable:releaseSeatInteractable( 4 )
		elseif controllerAction == sm.interactable.actions.item5 then
			self.interactable:releaseSeatInteractable( 5 )
		elseif controllerAction == sm.interactable.actions.item6 then
			self.interactable:releaseSeatInteractable( 6 )
		elseif controllerAction == sm.interactable.actions.item7 then
			self.interactable:releaseSeatInteractable( 7 )
		elseif controllerAction == sm.interactable.actions.item8 then
			self.interactable:releaseSeatInteractable( 8 )
		elseif controllerAction == sm.interactable.actions.item9 then
			self.interactable:releaseSeatInteractable( 9 )
		elseif controllerAction == sm.interactable.actions.create then
			if self.leftClickLogic then
				self.network:sendToServer('sv_setGlobalFlag', { key = "leftClick", state = false })
			end
		elseif controllerAction == sm.interactable.actions.attack then
			if self.rightClickLogic then	
				self.network:sendToServer('sv_setGlobalFlag', { key = "rightClick", state = false })
			end
		else
			self.otherKeyDown = false
			consumeAction = false
		end
	end
	return consumeAction
end

function SeatMJM.cl_setLogicFlags( self )
	self.spaceLogic = false
	self.leftClickLogic = false
	self.rightClickLogic = false
	self.scrollUpLogic = false
	self.scrollDownLogic = false	
	for k,child in pairs(self.interactable:getChildren()) do
		local cUuid = tostring(sm.shape.getShapeUuid(child:getShape()))
		if cUuid == "6f64d36d-5e23-4f6b-bcb5-e0057ba43fce" then -- Seat Logic Breakout
			if _G[child.id.."space"] then
				self.spaceLogic = true
			end
			if _G[child.id.."leftClick"] then
				self.leftClickLogic = true
			end
			if _G[child.id.."rightClick"] then
				self.rightClickLogic = true
			end
			if _G[child.id.."scrollUp"] then
				self.scrollUpLogic = true
			end
			if _G[child.id.."scrollDown"] then
				self.scrollDownLogic = true
			end
		end
	end
end

function SeatMJM.client_getAvailableChildConnectionCount( self, connectionType )
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	assert(level)
	local maxButtonCount = level.maxConnections or 255
	return maxButtonCount - #self.interactable:getChildren( sm.interactable.connectionType.seated )
end