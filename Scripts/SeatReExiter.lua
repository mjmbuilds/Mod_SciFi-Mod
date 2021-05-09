-- SeatReExiter.lua --
SeatReExiter = class()
SeatReExiter.maxChildCount = 1
SeatReExiter.maxParentCount = 1
SeatReExiter.connectionInput = sm.interactable.connectionType.power
SeatReExiter.connectionOutput = sm.interactable.connectionType.power
SeatReExiter.colorNormal = sm.color.new( 0x00ff80ff )
SeatReExiter.colorHighlight = sm.color.new( 0x6affb6ff )

function SeatReExiter.server_onFixedUpdate( self )
	if self.reSeatTarget then
		self.reSeatTarget:setSeatCharacter( self.reSeatChar )
		self.reSeatTarget = nil
		self.reSeatChar = nil
	end
	local seatedCharacter = self.interactable:getSeatCharacter()
	if seatedCharacter then
		for k,child in pairs(self.interactable:getChildren()) do
			local cUuid = tostring(sm.shape.getShapeUuid(child:getShape()))
			if cUuid == "229fd8b4-e098-4cb2-bd24-b4c01e470f53" then
				self.reSeatTarget = child
				self.reSeatChar = seatedCharacter
			end
		end
		self.interactable:setSeatCharacter( seatedCharacter ) -- exit seat
	end
end

-- ____________________________________ Client ____________________________________

function SeatReExiter.client_onInteract( self, character, state )
	if state then
		self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
	end
end
