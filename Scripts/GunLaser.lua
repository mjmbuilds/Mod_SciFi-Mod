dofile "Utility.lua"
--[[ 
********** GunLaser by MJM ********** 
--]]

GunLaser = class()
GunLaser.maxParentCount = -1
GunLaser.maxChildCount = -1
GunLaser.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
GunLaser.connectionOutput = sm.interactable.connectionType.logic
GunLaser.colorNormal = sm.color.new( 0xcb0a00ff )
GunLaser.colorHighlight = sm.color.new( 0xee0a00ff )
GunLaser.poseWeightCount = 1

GunLaser.ammoEffectName = "MJM_BulletLaser"
GunLaser.explosionEffectName = "MJM_ExplosionSmall"
GunLaser.targetSpeed = 3.0
GunLaser.destructionLevel = 6
GunLaser.destructionRadius = 0.25
GunLaser.impulseRadius = 2.0
GunLaser.impulseMagnitude = 5.0
GunLaser.fuze = 1 -- delay before raycast starts looking for collision
GunLaser.shotLifespan = 3000 -- ticks until destroys self
GunLaser.explodesWhenExpires = false -- shot explodes if lifespan runs out?
GunLaser.singleFire = false -- require pressing button for every shot?
GunLaser.reloadTime = 16
GunLaser.barrelOffset = 0.0 -- distance forward from center of gun to spawn projectile

-- ____________________________________ Server ____________________________________

function GunLaser.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
	--this sends an active tick that is offset by half the reload cooldown when firing
	--its purpose if for chaning togethere two guns to alternate fire with a single button
	if #self.interactable:getChildren() > 0 then
		if self.reloadCountdown == math.floor(self.reloadTime / 2) +1 then
			local hasActiveLogicInput = false
			for k,parent in pairs(self.interactable:getParents()) do
				if parent:isActive() and not parent:hasSeat() then
					hasActiveLogicInput = true
					break
				end
			end
			self.interactable:setActive(hasActiveLogicInput)
		else
			self.interactable:setActive(false)
		end
	end
end

function GunLaser.explode( self, loc )
	sm.physics.explode( loc, self.destructionLevel, self.destructionRadius, self.impulseRadius, self.impulseMagnitude, self.explosionEffectName)
end

function GunLaser.server_updateClientTargetVec( self, targetVec )
	self.network:sendToClients('client_setTargetVec', targetVec)
end

-- ____________________________________ Client ____________________________________

function GunLaser.client_onCreate( self ) --- Client setup ---
	print("* * * * * INIT GunLaser * * * * *")
	self.shotsInFlight = {}
	self.reloadCountdown = -1
	self.shotSound1 = sm.effect.createEffect("MJM_GunDrum2", self.shape.interactable) --SW Rifle
	self.shotSound1:setParameter( "pitch", 0.4 )
	self.shotSound2 = sm.effect.createEffect("MJM_GunDrum2", self.shape.interactable) --SW ATAT 
	self.shotSound2:setParameter( "pitch", 0.85 )
	self.targetVec = nil
end
function GunLaser.client_onRefresh( self )
	self:client_onCreate()
end

function GunLaser.client_setTargetVec( self, targetVec )
	if not self.isCameraOwner then
		self.targetVec = targetVec
	end
end

function GunLaser.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------

	local currentPosition = self.shape.worldPosition
	if not self.prevPosition then
		self.prevPosition = currentPosition
	end
	
	-- check if using camera control
	self.isCameraOwner = false
	for k,parent in pairs(self.interactable:getParents()) do
		local seatedPlayer = parent:getSeatCharacter()
		if seatedPlayer and sm.localPlayer.getId() == seatedPlayer.id then
			self.isCameraOwner = true
			break
		end
	end
	
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
			
			local newPos = v.pos + (v.fwd * (self.targetSpeed + v.initVel))
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

	-- check if trying to / can fire
	local fire = false
	if self.reloadCountdown > 0 then
		self.reloadCountdown = self.reloadCountdown - 1
		local poseWeight = self.interactable:getPoseWeight(0)
		if poseWeight > 0 then
			self.interactable:setPoseWeight(0, poseWeight - 0.1)
		end
	else
		if self.reloadCountdown == 0 then
			self.reloadCountdown = -1
			self.interactable:setPoseWeight(0, 0)
		end
		for k,parent in pairs(self.interactable:getParents()) do
			if parent:isActive() and not parent:hasSeat() then
				fire = true
				self.reloadCountdown = self.reloadTime
				break
			end
		end
	end
	
	-- if firing
	if fire then
		self.interactable:setPoseWeight(0, 1)
		if not self.shotSound1 then
			self.shotSound1 = sm.effect.createEffect("MJM_GunDrum2", self.shape.interactable) --SW Rifle
			self.shotSound1:setParameter( "pitch", 0.4 )
		end
		if not self.shotSound2 then
			self.shotSound2 = sm.effect.createEffect("MJM_GunDrum2", self.shape.interactable) --SW ATAT 
			self.shotSound2:setParameter( "pitch", 0.85 )
		end		
		self.shotSound1:start()
		self.shotSound2:start()
		
		local newShot = sm.effect.createEffect(self.ammoEffectName)
		newShot:start()
		local shotPos = self.shape.worldPosition + (self.shape.at * self.barrelOffset)
		
		local predictPos = currentPosition - self.prevPosition
		shotPos = shotPos + (predictPos * 1)
		
		newShot:setPosition(shotPos)
		newShot:setRotation(self.shape.worldRotation)
		
		-- if using seat camera control, calc shot target vector
		if self.isCameraOwner then
			if sm.localPlayer.isInFirstPersonView() then
				local hitTarget = nil
				local start = sm.camera.getPosition() + sm.camera.getDirection() * 5
				local dir = sm.camera.getDirection() * 1000
				local hit,num = sm.physics.distanceRaycast( start, dir )
				if hit then
					hitTarget = start + (dir * num)
				else
					hitTarget = start + dir 
				end
				local rawVec = toLocal(self.shape,(hitTarget - self.shape.worldPosition):normalize())
				local limit1 = -0.12
				local limit2 = 0.12
				local limit3 = 0.5
				self.targetVec = toGlobal(self.shape, sm.vec3.new(sm.util.clamp(rawVec.x,limit1,limit2),sm.util.clamp(rawVec.y,limit3,1),sm.util.clamp(rawVec.z,limit1,limit2)):normalize())
				self.network:sendToServer('server_updateClientTargetVec', self.targetVec)
			elseif self.targetVec then
				self.targetVec = nil
				self.network:sendToServer('server_updateClientTargetVec', self.targetVec)
			end
		end
		
		local aimFwd = self.shape.at
		local shotRot = self.shape.worldRotation
		
		-- if there is a target vector, turn towards it
		if self.targetVec then
			aimFwd = self.targetVec
			shotRot = sm.vec3.getRotation( sm.vec3.new(0,1,0), aimFwd )
		end
		
		newShot:setRotation(shotRot)
		
		local barrelVel = math.max(0,((toLocal(self.shape,(currentPosition - self.prevPosition))).y / 1))		
		
		self.shotsInFlight[tostring(newShot.id)] = {shot = newShot, pos = shotPos, fwd = aimFwd, fuze = self.fuze, life = self.shotLifespan, initVel = barrelVel}
	end
	
	self.prevPosition = currentPosition
end
