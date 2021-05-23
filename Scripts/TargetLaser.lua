TargetLaser = class()
TargetLaser.maxParentCount = -1
TargetLaser.maxChildCount = -1
TargetLaser.connectionInput = sm.interactable.connectionType.logic
TargetLaser.connectionOutput = sm.interactable.connectionType.logic
TargetLaser.colorNormal = sm.color.new( 0xf6e46aff )
TargetLaser.colorHighlight = sm.color.new( 0xf7eb99ff )
TargetLaser.poseWeightCount = 1

TargetLaser.laserLen = 1000

function TargetLaser.server_onFixedUpdate( self, dt )
	local laserHit = false
	for _,input in pairs(self.interactable:getParents()) do
		if input:isActive() then
			local laserDir = self.shape:getUp() * 0.25
			local castStart = self.shape:getWorldPosition() + (laserDir * 0.4)
			local castDir = laserDir * self.laserLen
			local hit,hitLen = sm.physics.distanceRaycast(castStart, castDir)
			if hit then
				laserHit = true
			end
			break
		end
	end
	self.interactable:setActive(laserHit)
end

function TargetLaser.client_onFixedUpdate( self, dt )
	local laserActive = false
	for _,input in pairs(self.interactable:getParents()) do
		if input:isActive() then
			laserActive = true
			break
		end
	end
	if laserActive then
		local laserDir = self.shape:getUp() * 0.25
		local castStart = self.shape:getWorldPosition() + (laserDir * 0.4)
		local castDir = laserDir * self.laserLen
		local hit,hitLen = sm.physics.distanceRaycast(castStart, castDir)
		if hit then
			laserHit = true
			self.interactable:setPoseWeight(0, hitLen)
		else
			self.interactable:setPoseWeight(0, 1)
		end
	else
		self.interactable:setPoseWeight(0, 0)
	end
end






















