-- Placeholder script for deprecated scripted parts
-- Deletes the part if it exists
DeprecatedDelete = class()
DeprecatedDelete.maxParentCount = -1
DeprecatedDelete.maxChildCount = -1
DeprecatedDelete.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
DeprecatedDelete.connectionOutput = sm.interactable.connectionType.logic
DeprecatedDelete.poseWeightCount = 1

function DeprecatedDelete.server_onFixedUpdate( self, dt )
	self.shape:destroyShape(0)
end
