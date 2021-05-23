--[[ 
This part is now deprected since the game now has replaceShape().
This part was a friction componenet of 'Tank Track 1' and was 
spawned on top of the tracks when high friction was needed. 
--]]
TankTrackFriction = class()
TankTrackFriction.connectionInput = sm.interactable.connectionType.none
TankTrackFriction.connectionOutput = sm.interactable.connectionType.none

function TankTrackFriction.server_onFixedUpdate( self, dt )
	
	-- this part is deprecated and should never exist
	self.shape:destroyShape(0)
	
	-- old code
	--[[
	local trackPart = _G[self.shape.id.."track"]
	-- remove if not referenced by a track
	if not trackPart or not sm.exists(trackPart) then
		self.shape:destroyShape(0)
	-- remove if by itself
	elseif #self.shape.body:getShapes() <= 1 then
		_G[trackPart.id.."friction"] = nil
		self.shape:destroyShape(0)
	-- if for some reason it's out of sync check for global message
	elseif _G[trackPart.id.."destroy"] then
		self.shape:destroyShape(0)
	end
	--]]
end