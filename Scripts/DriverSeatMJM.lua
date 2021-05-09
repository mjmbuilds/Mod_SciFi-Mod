-- DriverSeatMJM.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("SeatMJM.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")

DriverSeatMJM = class( SeatMJM )
DriverSeatMJM.maxChildCount = 255
DriverSeatMJM.connectionOutput = sm.interactable.connectionType.seated + sm.interactable.connectionType.power + sm.interactable.connectionType.bearing
DriverSeatMJM.colorNormal = sm.color.new( 0x80ff00ff )
DriverSeatMJM.colorHighlight = sm.color.new( 0xb4ff68ff )

DriverSeatMJM.maxConnections = 255 --game max is 255

local SpeedPerStep = 1 / math.rad( 27 ) / 3

function DriverSeatMJM.server_onCreate( self )
	SeatMJM:server_onCreate( self )
end

function DriverSeatMJM.server_onFixedUpdate( self )
	SeatMJM.server_onFixedUpdate( self )
	if self.interactable:isActive() then
		self.interactable:setPower( self.interactable:getSteeringPower() )
	else
		self.interactable:setPower( 0 )
		self.interactable:setSteeringFlag( 0 )
	end
end

function DriverSeatMJM.client_onInteract( self, character, state )
	if state then
		self:cl_seat()
		if self.shape.interactable:getSeatCharacter() ~= nil then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_OCCUPIED}", 4.0 )
		elseif self.shape.body:isOnLift() then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_ON_LIFT}", 8.0 )
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

	local stateName = state and "Down" or "Up"
	--print("Action: ", controllerAction, " : ", stateName )

	if state == true then
		if controllerAction == sm.interactable.actions.forward then
			self.interactable:setSteeringFlag( sm.interactable.steering.forward )
		elseif controllerAction == sm.interactable.actions.backward then
			self.interactable:setSteeringFlag( sm.interactable.steering.backward )
		elseif controllerAction == sm.interactable.actions.left then
			self.interactable:setSteeringFlag( sm.interactable.steering.left )
		elseif controllerAction == sm.interactable.actions.right then
			self.interactable:setSteeringFlag( sm.interactable.steering.right )
		else
			return SeatMJM.client_onAction( self, controllerAction, state )
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
		else
			return SeatMJM.client_onAction( self, controllerAction, state )
		end
	end
	return true
end

function DriverSeatMJM.client_getAvailableChildConnectionCount( self, connectionType )
	local filter = sm.interactable.connectionType.seated + sm.interactable.connectionType.bearing + sm.interactable.connectionType.power
	local currentConnectionCount = #self.interactable:getChildren( filter )

	if bit.band( connectionType, filter ) then
		local availableChildCount = DriverSeatMJM.maxConnections
		return availableChildCount - currentConnectionCount
	end
	return 0
end

function DriverSeatMJM.client_onCreate( self )
	SeatMJM.client_onCreate( self )
	self.animWeight = 0.5
	if self.interactable:hasAnim("steering") then
		self.hasAnimation = true
		self.interactable:setAnimEnabled("steering", true)
	end

	self.cl = {}
	self.cl.updateDelay = 0.0
	self.cl.updateSettings = {}
end


function DriverSeatMJM.client_onFixedUpdate( self, dt )
	SeatMJM.client_onFixedUpdate( self, dt )
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
	SeatMJM.client_onUpdate( self, dt )

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
