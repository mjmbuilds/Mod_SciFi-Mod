--[[ 
This part acts as a friction componenet of 'Tank Track 1'
and is spawned in palce as needed. 
Not inteded for use as a normal building part. 
Deletes itself if placed loose.
--]]
TankTrackFriction = class()
TankTrackFriction.connectionInput = sm.interactable.connectionType.none
TankTrackFriction.connectionOutput = sm.interactable.connectionType.none

function TankTrackFriction.server_onFixedUpdate( self, dt )
	local trackPart = _G[self.shape.id.."track"]
	-- remove if not referenced by a track
	if not trackPart or not sm.exists(trackPart) then
		self.shape:destroyShape(0)
	end
end