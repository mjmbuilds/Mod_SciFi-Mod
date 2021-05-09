--[[ 
********** Tank Track Friction by MJM ********** 

This part acts as a friction componenet of 'Tank Track 1'
and is spawned in palce as needed. 
Not inteded for use as a normal building part. 
Deletes itself is placed loose.

--]]

TankTrackFriction = class()
TankTrackFriction.maxParentCount = 0
TankTrackFriction.maxChildCount = 0
TankTrackFriction.connectionInput = sm.interactable.connectionType.none
TankTrackFriction.connectionOutput = sm.interactable.connectionType.none

-- ____________________________________ Server ____________________________________

function TankTrackFriction.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
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
end