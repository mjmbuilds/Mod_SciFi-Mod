dofile "Utility.lua"

ThrusterScifi = class()
ThrusterScifi.maxParentCount = -1
ThrusterScifi.maxChildCount = 0
ThrusterScifi.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
ThrusterScifi.connectionOutput = sm.interactable.connectionType.none
ThrusterScifi.colorNormal = sm.color.new( 0x20c5c9ff )
ThrusterScifi.colorHighlight = sm.color.new( 0x2cebf3ff )
ThrusterScifi.poseWeightCount = 1

ThrusterScifi.logicInputs = {
	"THRUSTER"
}

function ThrusterScifi.server_onCreate( self ) --- Server setup ---
	self.publicData = {}
	self.publicData.logicInputs = self.logicInputs
	self.interactable:setPublicData(self.publicData)
	self.thrust = 0
	self.defaultThrust = 1000
end
function ThrusterScifi.server_onRefresh( self )
	print("* * * * * REFRESH ThrusterScifi * * * * *")
	self:server_onCreate()
end

function ThrusterScifi.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
	if self.thrust ~= 0 then
		sm.physics.applyImpulse(self.shape, sm.vec3.new(0,0,(self.thrust * -1)), false, nil)
	end
end

-- ____________________________________ Client ____________________________________

function ThrusterScifi.client_onCreate( self ) --- Client setup ---
	self.thrusterEffect = sm.effect.createEffect( "MJM_ThrusterScifi_01", self.interactable )
	self.thrusterEffect:setOffsetPosition(sm.vec3.new(0,0,-0.5))
end
function ThrusterScifi.client_onRefresh( self )
	self:client_onCreate()
end

function ThrusterScifi.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------
	local thrust = 0
	local active = true
	local hasSwitch = false
	local hasNum = false
	-- check for logic gating the signal
	for _,input in pairs(self.interactable:getParents()) do
		if input.type == "scripted" and input:getPublicData() then
			hasSwitch = true
			for inputKey,inputValue in pairs(input:getPublicData()) do
				active = inputValue
			end
		else
			if input:hasOutputType(sm.interactable.connectionType.logic) then
				hasSwitch = true
				if not input:isActive() then
					active = false
					break
				end
			else
				hasNum = true
				thrust = thrust + input:getPower()
			end
		end
	end
	if active then
		if hasSwitch and not hasNum then
			thrust = self.defaultThrust
		end
		if thrust ~= 0 then
			if not (self.thrusterEffect:isPlaying()) then
				self.thrusterEffect:start()
			end
			self.interactable:setPoseWeight(0,1)
		else
			if self.thrusterEffect:isPlaying() then
				self.thrusterEffect:stop()
			end
			self.interactable:setPoseWeight(0,0)
		end
	else
		if self.thrusterEffect:isPlaying() then
			self.thrusterEffect:stop()
		end
		self.interactable:setPoseWeight(0,0)
		thrust = 0
	end
	self.thrust = thrust
end
