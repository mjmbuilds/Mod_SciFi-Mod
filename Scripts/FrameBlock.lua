--[[ 
********** FrameBlock by MJM ********** 
--]]

FrameBlock = class()
FrameBlock.maxParentCount = 0
FrameBlock.maxChildCount = 0
FrameBlock.connectionInput = sm.interactable.connectionType.none
FrameBlock.connectionOutput = sm.interactable.connectionType.none
FrameBlock.poseWeightCount = 1

FrameBlock.openColor = sm.color.new("222221ff")

-- ____________________________________ Client ____________________________________

function FrameBlock.client_onCreate( self ) --- Client setup ---
	self.open = true
end

function FrameBlock.client_onFixedUpdate( self, dt ) --- Client Fixed Update ------------
	if self.shape.color == self.openColor then
		if not self.open then
			self.open = true
			self.interactable:setPoseWeight(0, 0)
		end
	else
		if self.open then
			self.open = false
			self.interactable:setPoseWeight(0, 1)
		end
	end
end
