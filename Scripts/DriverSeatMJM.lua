-- DriverSeatMJM.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("ModPaths.lua")

DriverSeatMJM = class()
DriverSeatMJM.maxChildCount = -1
DriverSeatMJM.connectionOutput = sm.interactable.connectionType.seated + sm.interactable.connectionType.power + sm.interactable.connectionType.bearing
DriverSeatMJM.colorNormal = sm.color.new( 0x80ff00ff )
DriverSeatMJM.colorHighlight = sm.color.new( 0xb4ff68ff )

local SpeedPerStep = 1 / math.rad( 27 ) / 3

function DriverSeatMJM.server_onRefresh( self )
	print("* * * * * REFRESH DriverSeatMJM * * * * *")
end

function DriverSeatMJM.server_onFixedUpdate( self )
	if not self.interactable then return end
	local ID = self.interactable.id
	
	local currentActive = (self.interactable:getSeatCharacter() ~= nil)
	self.interactable:setActive(currentActive)

	if self.clearScrollUp then
		_G[ID.."scrollUp"] = false
		self.clearScrollUp = false
	end	
	if _G[ID.."scrollUp"] then
		self.clearScrollUp = true
	end

	if self.clearScrollDown then
		_G[ID.."scrollDown"] = false
		self.clearScrollDown = false
	end	
	if _G[ID.."scrollDown"] then
		self.clearScrollDown = true
	end

	if self.interactable:isActive() then
		self.interactable:setPower( self.interactable:getSteeringPower() )
	else
		self.interactable:setPower( 0 )
		self.interactable:setSteeringFlag( 0 )
	end
end

function DriverSeatMJM.sv_setGlobalFlag( self, props )
	if not self.interactable then return end
	_G[self.interactable.id..props.key] = props.state
end

function DriverSeatMJM.server_onDestroy( self )
	if not self.interactable then return end
	local ID = self.interactable.id
	_G[ID.."space"] = nil
	_G[ID.."leftClick"] = nil
	_G[ID.."rightClick"] = nil
	_G[ID.."scrollUp"] = nil
	_G[ID.."scrollDown"] = nil
end

function DriverSeatMJM.sv_getSeatInfo( self, player )
	local infoData = {}
	for i, interactable in pairs(self.interactable:getSeatInteractables()) do
		if i > 10 then break end
		local name = interactable:getType()
		if name == "lever" then
			name = "switch"
		elseif name == "scripted" then
			local publicData = interactable:getPublicData()
			if publicData and publicData.name then
				name = publicData.name
			end
		end
		infoData[i] = name:upper()
	end
	self.network:sendToClient(player, "cl_openInfoGui", infoData)
end

-- ____________________________________ Client ____________________________________

function DriverSeatMJM.client_onCreate( self )
	self.animWeight = 0.5
	if self.interactable:hasAnim("steering") then
		self.hasAnimation = true
		self.interactable:setAnimEnabled("steering", true)
	end

	self.cl = {}
	self.cl.updateDelay = 0.0
	self.cl.updateSettings = {}
	self.cl.seatedCharacter = nil
end

function DriverSeatMJM.client_onDestroy( self )
	if self.gui then
		self.gui:destroy()
		self.gui = nil
	end
end

function DriverSeatMJM.client_canInteract( self, character )
	local interactKey = sm.gui.getKeyBinding("Use")
	local tinkerKey = sm.gui.getKeyBinding("Tinker")
	sm.gui.setInteractionText("", interactKey, "Use")
	sm.gui.setInteractionText("", tinkerKey, "Info")
	
	if character:getCharacterType() == unit_mechanic and not character:isTumbling() then
		return true
	end
	return false
end

-- when the player "tinkers" with the part (U)
function DriverSeatMJM.client_onTinker( self, character, lookAt )
	if lookAt then
		local player = character:getPlayer()
		self.network:sendToServer("sv_getSeatInfo", player)
	end
end

function DriverSeatMJM.cl_openInfoGui( self, infoData )
	if not self.infoGui then self.infoGui = sm.gui.createGuiFromLayout(LAYOUTS_PATH..'SeatInfo.layout') end
	for i = 1, 10 do
		if infoData[i] then
			self.infoGui:setText("Con"..i, infoData[i])
		else
			self.infoGui:setText("Con"..i, "")
		end
	end
	self.infoGui:open()
end

-- when the player "uses" the part (E)
function DriverSeatMJM.client_onInteract( self, character, lookAt )
	if lookAt then
		self:cl_seat()
		if self.shape.interactable:getSeatCharacter() ~= nil then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_OCCUPIED}", 4.0 )
		elseif self.shape.body:isOnLift() then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_ON_LIFT}", 8.0 )
		end
	end
end

function DriverSeatMJM.cl_seat( self )
	if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
		self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
	end
end

function DriverSeatMJM.cl_checkForReSeat( self )
	for k,child in pairs(self.interactable:getChildren()) do
		local cUuid = tostring(sm.shape.getShapeUuid(child:getShape()))
		if cUuid == "229fd8b4-e098-4cb2-bd24-b4c01e470f53" then -- Seat ReExiter Teleporter
			self.reSeatTarget = child
			self.reSeatChar = sm.localPlayer.getPlayer():getCharacter()
		end
	end
end

function DriverSeatMJM.client_onInteractThroughJoint( self, character, state, joint )
	self.cl.bearingGui = sm.gui.createSteeringBearingGui()
	self.cl.bearingGui:open()
	self.cl.bearingGui:setOnCloseCallback( "cl_onGuiClosed" )

	self.cl.currentJoint = joint

	self.cl.bearingGui:setSliderCallback("LeftAngle", "cl_onLeftAngleChanged")
	self.cl.bearingGui:setSliderData("LeftAngle", 120, self.interactable:getSteeringJointLeftAngleLimit( joint ) - 1 )

	self.cl.bearingGui:setSliderCallback("RightAngle", "cl_onRightAngleChanged")
	self.cl.bearingGui:setSliderData("RightAngle", 120, self.interactable:getSteeringJointRightAngleLimit( joint ) - 1 )

	local leftSpeedValue = self.interactable:getSteeringJointLeftAngleSpeed( joint ) / SpeedPerStep
	local rightSpeedValue = self.interactable:getSteeringJointRightAngleSpeed( joint ) / SpeedPerStep

	self.cl.bearingGui:setSliderCallback("LeftSpeed", "cl_onLeftSpeedChanged")
	self.cl.bearingGui:setSliderData("LeftSpeed", 10, leftSpeedValue - 1)

	self.cl.bearingGui:setSliderCallback("RightSpeed", "cl_onRightSpeedChanged")
	self.cl.bearingGui:setSliderData("RightSpeed", 10, rightSpeedValue - 1)

	local unlocked = self.interactable:getSteeringJointUnlocked( joint )

	if unlocked then
		self.cl.bearingGui:setButtonState( "Off", true )
	else
		self.cl.bearingGui:setButtonState( "On", true )
	end

	self.cl.bearingGui:setButtonCallback( "On", "cl_onLockButtonClicked" )
	self.cl.bearingGui:setButtonCallback( "Off", "cl_onLockButtonClicked" )

	--print("Character "..character:getId().." interacted with joint "..joint:getId())
end

function DriverSeatMJM.client_onAction( self, controllerAction, state )
	local consumeAction = true
	if state == true then
		if controllerAction == sm.interactable.actions.forward then
			self.interactable:setSteeringFlag( sm.interactable.steering.forward )
		elseif controllerAction == sm.interactable.actions.backward then
			self.interactable:setSteeringFlag( sm.interactable.steering.backward )
		elseif controllerAction == sm.interactable.actions.left then
			self.interactable:setSteeringFlag( sm.interactable.steering.left )
		elseif controllerAction == sm.interactable.actions.right then
			self.interactable:setSteeringFlag( sm.interactable.steering.right )
		elseif controllerAction == sm.interactable.actions.use then
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
		if controllerAction == sm.interactable.actions.forward then
			self.interactable:unsetSteeringFlag( sm.interactable.steering.forward )
		elseif controllerAction == sm.interactable.actions.backward then
			self.interactable:unsetSteeringFlag( sm.interactable.steering.backward )
		elseif controllerAction == sm.interactable.actions.left then
			self.interactable:unsetSteeringFlag( sm.interactable.steering.left )
		elseif controllerAction == sm.interactable.actions.right then
			self.interactable:unsetSteeringFlag( sm.interactable.steering.right )
		elseif controllerAction == sm.interactable.actions.jump then
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

function DriverSeatMJM.client_onFixedUpdate( self, dt )
	if not self.interactable then return end

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

	if self.cl.updateDelay > 0.0 then
		self.cl.updateDelay = math.max( 0.0, self.cl.updateDelay - dt )

		if self.cl.updateDelay == 0 then
			self:cl_applyBearingSettings()
			self.cl.updateSettings = {}
			self.cl.updateGuiCooldown = 0.2
		end
	else
		if self.cl.updateGuiCooldown then
			self.cl.updateGuiCooldown = self.cl.updateGuiCooldown - dt
			if self.cl.updateGuiCooldown <= 0 then
				self.cl.updateGuiCooldown = nil
			end
		end
		if not self.cl.updateGuiCooldown then
			self:cl_updateBearingGuiValues()
		end
	end
end

function DriverSeatMJM.client_onUpdate( self, dt )
	if not self.interactable then return end

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
			if value and (value:getConnectionInputType() == sm.interactable.connectionType.seated or value:getConnectionInputType() == 9) then
				self.gui:setGridItem( "ButtonGrid", i-1, {
					["itemId"] = tostring(value:getShape():getShapeUuid()),
					["active"] = value:isActive()
				})
			else
				self.gui:setGridItem( "ButtonGrid", i-1, nil)
			end
		end
	end

	local steeringAngle = self.interactable:getSteeringAngle();
	local angle = self.animWeight * 2.0 - 1.0 -- Convert anim weight 0,1 to angle -1,1

	if angle < steeringAngle then
		angle = min( angle + 4.2441*dt, steeringAngle )
	elseif angle > steeringAngle then
		angle = max( angle - 4.2441*dt, steeringAngle )
	end

	self.animWeight = angle * 0.5 + 0.5; -- Convert back to 0,1
	if self.hasAnimation then
		self.interactable:setAnimProgress("steering", self.animWeight)
	end
end

function DriverSeatMJM.cl_onLeftAngleChanged( self, sliderName, sliderPos )
	self.cl.updateSettings.leftAngle = sliderPos + 1
	self.cl.updateDelay = 0.1
end

function DriverSeatMJM.cl_onRightAngleChanged( self, sliderName, sliderPos )
	self.cl.updateSettings.rightAngle = sliderPos + 1
	self.cl.updateDelay = 0.1
end

function DriverSeatMJM.cl_onLeftSpeedChanged( self, sliderName, sliderPos )
	self.cl.updateSettings.leftSpeed = ( sliderPos + 1 ) * SpeedPerStep
	self.cl.updateDelay = 0.1
end

function DriverSeatMJM.cl_onRightSpeedChanged( self, sliderName, sliderPos )
	self.cl.updateSettings.rightSpeed = ( sliderPos + 1 ) * SpeedPerStep
	self.cl.updateDelay = 0.1
end

function DriverSeatMJM.cl_onLockButtonClicked( self, buttonName )
	self.cl.updateSettings.unlocked = buttonName == "Off"
	self.cl.updateDelay = 0.1
end

function DriverSeatMJM.cl_onGuiClosed( self )
	if self.cl.updateDelay > 0.0 then
		self:cl_applyBearingSettings()
		self.cl.updateSettings = {}
		self.cl.updateDelay = 0.0
		self.cl.currentJoint = nil
	end
	self.cl.bearingGui:destroy()
	self.cl.bearingGui = nil
end

function DriverSeatMJM.cl_applyBearingSettings( self )

	assert( self.cl.currentJoint )

	if self.cl.updateSettings.leftAngle then
		self.interactable:setSteeringJointLeftAngleLimit( self.cl.currentJoint, self.cl.updateSettings.leftAngle )
	end

	if self.cl.updateSettings.rightAngle then
		self.interactable:setSteeringJointRightAngleLimit( self.cl.currentJoint, self.cl.updateSettings.rightAngle )
	end

	if self.cl.updateSettings.leftSpeed then
		self.interactable:setSteeringJointLeftAngleSpeed( self.cl.currentJoint, self.cl.updateSettings.leftSpeed )
	end

	if self.cl.updateSettings.rightSpeed then
		self.interactable:setSteeringJointRightAngleSpeed( self.cl.currentJoint, self.cl.updateSettings.rightSpeed )
	end

	if self.cl.updateSettings.unlocked ~= nil then
		self.interactable:setSteeringJointUnlocked( self.cl.currentJoint, self.cl.updateSettings.unlocked )
	end
end

function DriverSeatMJM.cl_updateBearingGuiValues( self )
	if self.cl.bearingGui and self.cl.bearingGui:isActive() then

		local leftSpeed, rightSpeed, leftAngle, rightAngle, unlocked = self.interactable:getSteeringJointSettings( self.cl.currentJoint )

		if leftSpeed and rightSpeed and leftAngle and rightAngle and unlocked ~= nil then
			self.cl.bearingGui:setSliderPosition( "LeftAngle", leftAngle - 1 )
			self.cl.bearingGui:setSliderPosition( "RightAngle", rightAngle - 1 )
			self.cl.bearingGui:setSliderPosition( "LeftSpeed", ( leftSpeed / SpeedPerStep ) - 1 )
			self.cl.bearingGui:setSliderPosition( "RightSpeed", ( rightSpeed / SpeedPerStep ) - 1 )

			if unlocked then
				self.cl.bearingGui:setButtonState( "Off", true )
			else
				self.cl.bearingGui:setButtonState( "On", true )
			end
		end
	end
end

function DriverSeatMJM.cl_setLogicFlags( self )
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