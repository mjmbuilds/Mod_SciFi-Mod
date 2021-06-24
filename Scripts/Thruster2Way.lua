dofile "Utility.lua"
--[[ 
********** Thruster2Way by MJM ********** 
--]]

Thruster2Way = class()
Thruster2Way.maxParentCount = -1
Thruster2Way.maxChildCount = 0
Thruster2Way.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
Thruster2Way.connectionOutput = sm.interactable.connectionType.none
Thruster2Way.colorNormal = sm.color.new( 0x20c5c9ff )
Thruster2Way.colorHighlight = sm.color.new( 0x2cebf3ff )
Thruster2Way.poseWeightCount = 1

Thruster2Way.logicInputs = {
	"THRUSTER",
	"REVERSE THRUSTER"
}
function Thruster2Way.server_onCreate( self ) --- Server setup ---
	self.publicData = {}
	self.publicData.logicInputs = self.logicInputs
	self.interactable:setPublicData(self.publicData)
	self.thrust = 0
	self.defaultThrust = 1000
end
function Thruster2Way.server_onRefresh( self )
	print("* * * * * REFRESH Thruster2Way * * * * *")
	self:server_onCreate()
end

function Thruster2Way.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
	if self.thrust ~= 0 then
		sm.physics.applyImpulse(self.shape, sm.vec3.new(0,0,self.thrust), false, nil)
	end
end

-- ____________________________________ Client ____________________________________

function Thruster2Way.client_onCreate( self ) --- Client setup ---
	self.animState = 0
end
function Thruster2Way.client_onRefresh( self )
	self:client_onCreate()
end

function Thruster2Way.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------
	local thrust = 0
	local active = true
	local hasSwitch = false
	local hasNum = false
	local revinput = false
	-- check for logic gating the signal
	for _,input in pairs(self.interactable:getParents()) do
		if input.type == "scripted" and input:getPublicData() then
			for inputKey,inputValue in pairs(input:getPublicData()) do
				if inputKey == "REVERSE THRUSTER" then
					revinput = inputValue
				else
					active = inputValue
				end
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
			if self.animstate == 1 then
				self.animstate = 0
			else
				self.animstate = 1
			end
			self.interactable:setPoseWeight(0, self.animstate)
		end
	else
		thrust = 0
	end
	self.thrust = thrust
end
