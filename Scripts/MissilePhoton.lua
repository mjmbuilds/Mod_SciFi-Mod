dofile "Utility.lua"
--[[ 
********** MissilePhoton by MJM ********** 
--]]

MissilePhoton = class()
MissilePhoton.maxParentCount = -1
MissilePhoton.maxChildCount = -1
MissilePhoton.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
MissilePhoton.connectionOutput = sm.interactable.connectionType.logic
MissilePhoton.colorNormal = sm.color.new( 0xcb0a00ff )
MissilePhoton.colorHighlight = sm.color.new( 0xee0a00ff )
MissilePhoton.poseWeightCount = 1

MissilePhoton.ammoEffectName = "MJM_Missile_Photon"
MissilePhoton.explosionEffectName = "MJM_ExplosionSmall"
MissilePhoton.targetSpeed = 2.0
MissilePhoton.targetSpeedCam = 0.75
MissilePhoton.destructionLevel = 6
MissilePhoton.destructionRadius = 2.0
MissilePhoton.impulseRadius = 12.0
MissilePhoton.impulseMagnitude = 40.0
MissilePhoton.fuze = 1 -- delay before raycast starts looking for collision
MissilePhoton.shotLifespan = 3000 -- ticks until destroys self
MissilePhoton.explodesWhenExpires = true -- shot explodes if lifespan runs out?
MissilePhoton.singleFire = true -- require pressing button for every shot?
MissilePhoton.reloadTime = 120
MissilePhoton.barrelOffset = 0.75 -- distance forward from center of gun to spawn projectile
MissilePhoton.groupDelay = 12 -- delay between firing a group of linked missiles

-- ____________________________________ Server ____________________________________
function MissilePhoton.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
	if self.reloadCountdown < 0 then
		self.interactable:setActive(true)
	else
		self.interactable:setActive(false)
	end
end

function MissilePhoton.explode( self, loc )
	sm.physics.explode( loc, self.destructionLevel, self.destructionRadius, self.impulseRadius, self.impulseMagnitude, self.explosionEffectName)
end

function MissilePhoton.server_updateClientTargetPos( self, targetPos )
	self.network:sendToClients('client_setTargetPos', targetPos)
end

-- ____________________________________ Client ____________________________________

function MissilePhoton.client_onCreate( self ) --- Client setup ---
	print("* * * * * INIT MissilePhoton * * * * *")
	_G[tostring(self.interactable.id).."isMissile"] =  true
	_G[tostring(self.interactable.id).."ready"] = true
	self.shotsInFlight = {}
	self.reloadCountdown = -1
	self.groupReloadCountdown = 0
	self.fireIndex = 0
	self.isCameraOwner = false
	self.targetPos = nil
	self.target = nil
end
function MissilePhoton.client_onRefresh( self )
	self:client_onCreate()
end

function MissilePhoton.client_setTargetPos( self, targetPos )
	if not self.isCameraOwner then
		self.targetPos = targetPos
	end
end

function MissilePhoton.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------
	
	-- check if using camera control
	self.isCameraOwner = false
	for k,parent in pairs(self.interactable:getParents()) do
		local seatedPlayer = parent:getSeatCharacter()
		if seatedPlayer and sm.localPlayer.getId() == seatedPlayer.id then
			self.isCameraOwner = true
			break
		end
	end
	
	local onLift = self.shape.body:isOnLift()
	if not onLift and self.wasOnLift then
		self.interactable:setPoseWeight(0, 0)
		self.reloadCountdown = -1
		self.groupReloadCountdown = 0
		self.fireIndex = 0
	end
	self.wasOnLift = onLift
	
	-- update shots in air
	for k,v in pairs(self.shotsInFlight) do
		if v.life <= 0 then
			v.shot:setPosition(sm.vec3.new(0,0,-1000))
			v.shot:stop()
			if sm.isHost and self.explodesWhenExpires then
				self.network:sendToServer('explode', v.pos)
			end
			self.shotsInFlight[k] = nil
		else
			v.lfe = v.life - 1
		
			-- if using seat camera control, calc missile target vector
			if self.isCameraOwner then
				if sm.localPlayer.isInFirstPersonView() then
					
					local body = self.shape.body
					if self.seat then
						body = self.seat.shape.body
					end
					local rcStart = sm.camera.getPosition() + sm.camera.getDirection() * 5
					local rcEnd = rcStart + sm.camera.getDirection() * 1000
					local hit,result = sm.physics.raycast( rcStart, rcEnd, body )
					if hit then
						if result.type == "body" then
							self.target = result:getShape()
							self.targetPos = self.target.worldPosition
						elseif result.type == "character" then
							self.target = result:getCharacter()
							self.targetPos = self.target.worldPosition
						else
							self.target = nil
							self.targetPos = result.pointWorld
						end
					else
						self.target = nil
						self.targetPos = rcEnd
					end
					self.network:sendToServer('server_updateClientTargetPos', self.targetPos)
					
				elseif self.target and sm.exists(self.target) then
					self.targetPos = self.target.worldPosition
					self.network:sendToServer('server_updateClientTargetPos', self.targetPos)
				elseif self.targetPos then
					self.targetPos = nil
					self.network:sendToServer('server_updateClientTargetPos', self.targetPos)
				end
			end
			
			-- if there is a target location, turn towards it
			if self.targetPos then
				v.targetPos = self.targetPos
			end
			if v.targetPos then
				local targetVec = (v.targetPos - v.pos):normalize()
				local lerpSpeed = 0.05 -- 0 = no change, 1 = immediate full change
				v.fwd = sm.vec3.lerp( v.fwd, targetVec, lerpSpeed )
				local rot = sm.vec3.getRotation( sm.vec3.new(0,1,0), v.fwd )
				v.shot:setRotation(rot)
			end
			
			local speed = self.targetSpeed
			if self.targetPos then
				speed = self.targetSpeedCam
			end
			local newPos = v.pos + (v.fwd * speed)
			if v.initVel then
				if v.initVel:length2() > 0.0001 then
					newPos = newPos + v.initVel
					v.initVel = v.initVel * 0.975
				else
					v.initVel = nil
				end
			end
			if v.fuze <= 0 then
				local hit,result = sm.physics.raycast( (v.pos - (v.fwd * 0.25)), newPos, self.shape.body )
				if hit and result:getBody() ~= self.shape.body then
					v.shot:setPosition(sm.vec3.new(0,0,-1000))
					v.shot:stop()
					if sm.isHost then
						self.network:sendToServer('explode', result.pointWorld)
					end
					self.shotsInFlight[k] = nil
				else
					v.shot:setPosition(newPos)
					v.pos = newPos
				end
			else
				v.fuze = v.fuze - 1
				v.shot:setPosition(newPos)
				v.pos = newPos
			end
		end
	end
	
	-- check reload status
	if self.reloadCountdown > 0 then
		self.reloadCountdown = self.reloadCountdown - 1
	elseif self.reloadCountdown == 0 then
		-- check if able to relead
		local canReload = false
		for k,parent in pairs(self.interactable:getParents()) do
			if self.shape.body:isOnLift() or _G[tostring(parent.id).."canReload"] or (tostring(parent.shape.color) == "eeeeeeff" and parent:isActive()) then
				canReload = true
				self.reloadCountdown = -1
				_G[tostring(self.interactable.id).."ready"] = true
				sm.audio.play("SequenceController change rotation", self.shape.worldPosition)
				self.interactable:setPoseWeight(0, 0)
				break
			end
		end
		_G[tostring(self.interactable.id).."canReload"] = canReload
	end
	if self.groupReloadCountdown > 0 then
		self.groupReloadCountdown = self.groupReloadCountdown - 1
	end
	
	-- see if fire button is pressed
	local tryFire = false
	if _G[tostring(self.interactable.id).."fire"] then
		_G[tostring(self.interactable.id).."fire"] = nil
		tryFire = true
	else
		local active = false
		for k,parent in pairs(self.interactable:getParents()) do
			if tostring(parent.shape.color) ~= "eeeeeeff" and not _G[tostring(parent.id).."isMissile"] then
				if parent:isActive() and not parent:hasSeat() then
					active = true
					if not self.prevActive then
						tryFire = true
						break
					end
				end
			end
		end
		self.prevActive = active
	end
	
	if tryFire then
		-- see if has any children missiles to manage
		local missileGroup = {}
		local missileGroupCount = 0
		for k,child in pairs(self.interactable:getChildren()) do
			if _G[tostring(child.id).."isMissile"] then
				missileGroupCount = missileGroupCount + 1
				missileGroup[#missileGroup + 1] = child
			end
		end
		
		if missileGroupCount > 0 then
			if self.groupReloadCountdown > 0 then
				self.prevActive = false
			else
				local volleyFail = true
				if self.fireIndex > missileGroupCount then
					self.fireIndex = 0
				end
				local tryIndex = self.fireIndex
				for i=0,missileGroupCount do
					if tryIndex == 0 then
						if self.reloadCountdown < 0 then
							self:client_fire()
							self.prevActive = false
							self.groupReloadCountdown = self.groupDelay
							volleyFail = false
							break
						end
					else
						if _G[tostring(missileGroup[tryIndex].id).."ready"] then
							_G[tostring(missileGroup[tryIndex].id).."fire"] = true
							self.prevActive = false
							self.groupReloadCountdown = self.groupDelay
							volleyFail = false
							break
						end
					end
					tryIndex = tryIndex + 1
					if tryIndex > missileGroupCount then
						tryIndex = 0
					end
				end
				if not volleyFail then
					self.fireIndex = self.fireIndex + 1
				end
			end
		else
			if self.reloadCountdown < 0 then
				self:client_fire()
			else
				self.prevActive = false
			end
		end
	end
end

function MissilePhoton.client_fire( self )
	_G[tostring(self.interactable.id).."ready"] = false
	self.reloadCountdown = self.reloadTime
	self.interactable:setPoseWeight(0, 1)
	sm.audio.play("PotatoRifle - NoAmmo", self.shape.worldPosition)
	local newShot = sm.effect.createEffect(self.ammoEffectName)
	newShot:start()
	local shotPos = self.shape.worldPosition + (self.shape.at * self.barrelOffset)
	newShot:setPosition(shotPos)
	newShot:setRotation(self.shape.worldRotation)
	
	local barrelVel = toLocal(self.shape, (self.shape.velocity / 4))
	local speed = self.targetSpeed
	if self.targetPos then
		speed = self.targetSpeedCam
	end
	local velDiff = barrelVel.y - speed
	if velDiff > 0 then
		barrelVel.y = (velDiff / 10) + 0.2 -- temporary extra forward speed if barrel faster than projectile
	else
		barrelVel.y = 0
	end
	local adjInitVel = toGlobal(self.shape, sm.vec3.new(barrelVel.x / 10, barrelVel.y, barrelVel.z / 10))
	
	self.shotsInFlight[tostring(newShot.id)] = {shot = newShot, pos = shotPos, fwd = self.shape.at, fuze = self.fuze, life = self.shotLifespan, initVel = adjInitVel}
end

function MissilePhoton.client_onDestroy( self ) --- Cleanup ---
	_G[tostring(self.interactable.id).."isMissile"] = nil
	_G[tostring(self.interactable.id).."ready"] = nil
end
