--[[ 
********** ForceField by MJM ********** 
--]]

ForceField = class()
ForceField.maxParentCount = -1
ForceField.maxChildCount = 0
ForceField.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
ForceField.connectionOutput = sm.interactable.connectionType.none
ForceField.colorNormal = sm.color.new( 0xe2db13ff )
ForceField.colorHighlight = sm.color.new( 0xf5f071ff )
ForceField.poseWeightCount = 2

ForceField.radius = 10 -- max 100
ForceField.healthFull = 100
ForceField.lifeTime = 200 -- 5 seconds
ForceField.cooldown = 400 -- 10 seconds

-- ____________________________________ Server ____________________________________
function ForceField.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
	if self.cooldownTimer <= 0 then
		self.interactable:setActive(true)
	else
		self.interactable:setActive(false)
	end
end

-- ____________________________________ Client ____________________________________

function ForceField.client_onCreate( self ) --- Client setup ---
	_G[tostring(self.interactable.id).."isForcefield"] =  true
	--if not _G["forcefields"] then
		_G["forcefields"] = {}
	--end
	self.active = false
	self.lifeTimeTimer = 0
	self.cooldownTimer = 0
	self.health = 100
end
function ForceField.client_onRefresh( self )
	self:client_onCreate()
	print("* * * * * REFRESH ForceField * * * * *")
end

function ForceField.client_onInteract(self, character, lookAt)
    if not lookAt then return end
	self:client_toggleForceField()
end

function ForceField.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------

	local onLift = self.shape.body:isOnLift()
	if not onLift and self.wasOnLift then
		self.interactable:setPoseWeight(0, 0)
		self.active = false
		self.lifeTimeTimer = 0
		self.cooldownTimer = 0
		self.health = 100
	end
	self.wasOnLift = onLift

	for k,parent in pairs(self.interactable:getParents()) do
		local active = parent:isActive()
		if active and not self.prevActive then
			self:client_toggleForceField()
		end
		self.prevActive = active
	end
	
	if self.active then
		--print("ActiveTimer:",self.lifeTimeTimer)
		self.lifeTimeTimer = self.lifeTimeTimer - 1
		if self.lifeTimeTimer <= 0 then
			self:client_disableForceField()
		else
			_G["forcefields"][tostring(self.shape.id)].pos = self.shape.worldPosition
			if _G[tostring(self.shape.id).."hit"] then
				self.health = self.health - _G[tostring(self.shape.id).."hit"]
				_G[tostring(self.shape.id).."hit"] = nil
				
				--print("HIT!!! Health: "..self.health)--DEBUG
				
				if self.health <= 0 then
					self:client_disableForceField()
				end
				
			end
		end
	else
		--print("CoolDown:",self.cooldownTimer)
		if self.cooldownTimer > 0 then
			self.cooldownTimer = self.cooldownTimer - 1
		end
	end
end

function ForceField.client_toggleForceField( self )
	if self.active then
		self.active = false
		self.interactable:setPoseWeight(0, 0)
		self.cooldownTimer = self.cooldown
		_G["forcefields"][tostring(self.shape.id)] = nil
	else
		if self.cooldownTimer <= 0 then
			self.active = true
			self.interactable:setPoseWeight(0, (self.radius / 10))
			self.health = self.healthFull
			self.lifeTimeTimer = self.lifeTime
			_G["forcefields"][tostring(self.shape.id)] = {pos = self.shape.worldPosition, radius = self.radius}
		end
	end
end

function ForceField.client_disableForceField( self )
	self.active = false
	self.interactable:setPoseWeight(0, 0)
	self.cooldownTimer = self.cooldown
	_G["forcefields"][tostring(self.shape.id)] = nil
end