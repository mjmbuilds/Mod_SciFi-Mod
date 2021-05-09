dofile "Utility.lua"
--[[ 
********** RadarSmall by MJM ********** 
--]]

RadarSmall = class()
RadarSmall.maxParentCount = 0
RadarSmall.maxChildCount = 0
RadarSmall.connectionInput = sm.interactable.connectionType.none
RadarSmall.connectionOutput = sm.interactable.connectionType.none
RadarSmall.colorNormal = sm.color.new( 0x808080ff )
RadarSmall.colorHighlight = sm.color.new( 0xc0c0c0ff )
RadarSmall.poseWeightCount = 2

-- ____________________________________ Client ____________________________________

function RadarSmall.client_onCreate( self ) --- Client setup ---
	self.target = 0
end
function RadarSmall.client_onRefresh( self )
	self:client_onCreate()
	print("* * * * * REFRESH Radar * * * * *")
end

function RadarSmall.client_onInteract(self, character, lookAt)
    if not lookAt then return end
	sm.audio.play("Button on", self.shape.worldPosition)
	players = sm.player.getAllPlayers()
	self.target = self.target + 1
	if self.target > #sm.player.getAllPlayers() then
		self.target = 0
	end
	if self.target == 0 then
		sm.gui.displayAlertText("Tracking OFF")
	else
		sm.gui.displayAlertText("Tracking "..players[self.target]:getName())
	end
end

function RadarSmall.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------
	if self.target == 0 then
		self.interactable:setPoseWeight(0, 0.5)
		self.interactable:setPoseWeight(1, 0.5)--0.85
	else
		local x = 0.5
		local y = 0.5
		local targetPos sm.vec3.zero()
		for playerIndex,player in pairs(sm.player.getAllPlayers()) do
			if playerIndex == self.target then
				targetPos = player:getCharacter().worldPosition
				break
			end
		end
		local targetVec = toLocal(self.shape, (targetPos - self.shape.worldPosition):normalize())
		y = (targetVec.y / 2) + 0.5
		if targetVec.z >= 0 then
			if targetVec.x < 0 then
				x = 0
			else
				x = 1
			end
		else
			if x > 0.75 or x < -0.75 then
				y = y * (1 - (((1 - math.abs(x))/0.25) * 0.15))
			end
			x = (targetVec.x / 2) + 0.5
		end
		self.interactable:setPoseWeight(0, x)
		self.interactable:setPoseWeight(1, y)
	end
end
