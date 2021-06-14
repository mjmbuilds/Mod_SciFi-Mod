AutoLift = class()
AutoLift.maxParentCount = -1
AutoLift.maxChildCount = 0
AutoLift.connectionInput = sm.interactable.connectionType.logic
AutoLift.connectionOutput = sm.interactable.connectionType.none
AutoLift.colorNormal = sm.color.new( 0x505050ff )
AutoLift.colorHighlight = sm.color.new( 0x707070ff )
AutoLift.poseWeightCount = 1

function AutoLift.server_onRefresh( self )
	print("* * * * * REFRESH Auto Lift * * * * *")
end

function AutoLift.server_onFixedUpdate( self, dt )
	local isOnLift = self.shape.body:isOnLift()
	if isOnLift and not self.prevOnLift then
		local bodyDir = 0
		local bodyRot = sm.body.getWorldRotation(self.shape.body)
		if bodyRot.w > 0.8 then
			bodyDir = 0
		elseif bodyRot.w < 0.5 then
			bodyDir = 2
		elseif bodyRot.z < 0 then
			bodyDir = 1
		else
			bodyDir = 3
		end
		local seatDir = 0
		for _,shape in pairs(self.shape.body:getCreationShapes()) do
			local interactable = shape:getInteractable()
			if interactable and interactable:hasSeat() then
				local front = shape:getUp()
				if front.x < -0.707107 then
					seatDir = 3
				elseif front.y < -0.707107 then
					seatDir = 2
				elseif front.x > 0.707107 then
					seatDir = 1
				end
				break
			end
		end
		self.bodySeatRotOffset = (bodyDir - seatDir) % 4
	end
	self.prevOnLift = isOnLift
	
	if self.liftPlayer and isOnLift then
		self.interactable:setActive(true)
	else
		self.interactable:setActive(false)
		self.liftPlayer = nil
	end

	-- check for active input
	local hasInput = false
	for _,input in pairs(self.interactable:getParents()) do
		if input:isActive() then
			hasInput = true
			break
		end
	end
	-- check if active input is a new activation
	if hasInput and not self.hadInput then
		-- check if need to use lift or remove it
		if isOnLift then
			self.removeLift = true
		else
			self.useLift = true
		end
	end
	self.hadInput = hasInput
	-- if need to use the lift...
	if self.useLift then
		-- do a raycast to see if lift can be used
		local bodyWorldPosition_corner1,bodyWorldPosition_corner2 = self.shape.body:getWorldAabb()
		local crrectBodyWorldPosition = (bodyWorldPosition_corner1 + bodyWorldPosition_corner2) / 2
		local raycastStart = sm.vec3.new(crrectBodyWorldPosition.x,crrectBodyWorldPosition.y,math.min(bodyWorldPosition_corner1.z,bodyWorldPosition_corner2.z))
		local castLen = 6
		local raycastEnd = sm.vec3.new(raycastStart.x,raycastStart.y,(raycastStart.z - castLen))
		local success, result = sm.physics.raycast(raycastStart, raycastEnd, self.shape.body)
		if success then
			-- get position to place the lift
			local liftPos = result.pointWorld
			local liftHeight = 10
			local heightSuccess, heightResult = sm.physics.raycast(liftPos + sm.vec3.new(0,0,0.25), liftPos + sm.vec3.new(0,0,castLen))
			if heightSuccess then
				liftHeight = math.floor(heightResult.fraction * castLen * 4 - 0.5)
			end
			-- check for a seat to use as rotation reference
			local liftRotation = 0
			for _,shape in pairs(self.shape.body:getCreationShapes()) do
				local interactable = shape:getInteractable()
				if interactable and interactable:hasSeat() then
					local front = shape:getUp()
					if front.x < -0.707107 then
						liftRotation = 1
					elseif front.y < -0.707107 then
						liftRotation = 2
					elseif front.x > 0.707107 then
						liftRotation = 3
					end
					liftRotation = (liftRotation - (self.bodySeatRotOffset or 0)) % 4
					break
				end
			end
			if liftRotation == 1 then
				-- ok the way it is
			elseif liftRotation == 2 then
				liftPos = sm.vec3.new(liftPos.x, liftPos.y + 0.25, liftPos.z)
			elseif liftRotation == 3 then
				liftPos = sm.vec3.new(liftPos.x - 0.25, liftPos.y + 0.25, liftPos.z)
			else --liftRotation == 0
				liftPos = sm.vec3.new(liftPos.x - 0.25, liftPos.y, liftPos.z)
			end
			-- get the closest player
			local closestPlayer = nil
			local closestDistance = nil
			for _,player in pairs(sm.player.getAllPlayers()) do
				local playerDistance = (player:getCharacter():getWorldPosition() - self.shape:getWorldPosition()):length()
				if closestPlayer then
					if playerDistance < closestDistance then
						closestPlayer = player
						closestDistance = playerDistance
					end
				else
					closestPlayer = player
					closestDistance = playerDistance
				end
			end
			
			-- use lift
			closestPlayer:placeLift({self.shape.body}, liftPos * 4, liftHeight, liftRotation)
			self.liftPlayer = closestPlayer
			self.useLift = nil
			self.interactable:setActive(true)
		else
			self.useLift = nil
		end
	-- if need to remove the lift...
	elseif self.removeLift then
		-- if still on a lift, try next removal method (no way to get direct reference to the actual lift we are on)
		if isOnLift then
			-- first try removing the liftPlayer's lift (but it might have been manually deleted and replaced!)
			if self.liftPlayer then
				self.liftPlayer:removeLift()
				self.liftPlayer = nil
			-- otherwise try removing lifts of each player ()
			else
				if not self.triedPlayers then self.triedPlayers = {} end
				for _,player in pairs(sm.player.getAllPlayers()) do
					if not self.triedPlayers[player:getId()] then
						self.triedPlayers[player:getId()] = true
						player:removeLift()
						break
					end
				end
			end
		-- if no longer on a lift, clear related flags
		else
			self.removeLift = nil
			self.triedPlayers = nil
		end
	end
end

function AutoLift.client_onFixedUpdate( self, dt )
	self.interactable:setPoseWeight(0, self.interactable:isActive() and 1 or 0)
end





















