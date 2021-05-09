InputFunction = class()
InputFunction.maxParentCount = 255
InputFunction.maxChildCount = 255
InputFunction.connectionInput = sm.interactable.connectionType.logic
InputFunction.connectionOutput = sm.interactable.connectionType.logic
InputFunction.colorNormal = sm.color.new( 0x808080ff )
InputFunction.colorHighlight = sm.color.new( 0xc0c0c0ff )

function InputFunction.server_onCreate( self )
	self.data = self.storage:load() or {}
	self.data.modeIndex = self.data.modeIndex or 1
end

function InputFunction.server_onFixedUpdate( self )
	local newActive = false
	for _,parent in pairs(self.interactable:getParents()) do
		if parent:isActive() then
			newActive = true
			break
		end
	end
	self.interactable:setActive(newActive)
end

function InputFunction.sv_requestMode(self)
	self.network:sendToClients("cl_setMode", self.data.modeIndex)
end

function InputFunction.sv_changeMode( self, newIndex )
	self.data.modeIndex = newIndex
	self.storage:save(self.data)
	self.network:sendToClients("cl_setMode", newIndex)
end

-- ____________________________________ Client ____________________________________

function InputFunction.client_onCreate( self )
	self.cl_modeIndex = 1
	self.network:sendToServer("sv_requestMode")
end

function InputFunction.client_onInteract( self, character, lookAt ) 
    if not lookAt then return end
	self.availableModes = nil
	for _,child in pairs(self.interactable:getChildren()) do
		self.availableModes = child:getPublicData().availableModes -- sandbox violation
		print(self.availableModes)
		if self.availableModes then
			self.childUUID = child:getShape():getShapeUuid()
		end
	end	
	if self.availableModes then
		if self.gui == nil then
			self.gui = sm.gui.createEngineGui()
			self.gui:setSliderCallback( "Setting", "cl_onSliderChange")
			self.gui:setText("Name", "Input Function")
			self.gui:setText("Interaction", "Select Mode")		
			self.gui:setVisible("FuelContainer", false )
		end
		self.gui:setIconImage("Icon", self.childUUID)
		self.gui:setSliderData("Setting", #self.availableModes, self.cl_modeIndex-1)
		self.gui:setText("SubTitle", "Mode: "..self.availableModes[self.cl_modeIndex])
		self.gui:open()
	end
end

function InputFunction.cl_setMode( self, modeIndex )
	self.cl_modeIndex = modeIndex
end

function InputFunction.cl_onSliderChange( self, sliderName, sliderPos )
	local newIndex = sliderPos + 1
	self.cl_modeIndex = newIndex
	if self.gui ~= nil then
		self.gui:setText("SubTitle", "Mode: "..self.availableModes[newIndex])
	end
	self.network:sendToServer("sv_changeMode", newIndex)
	--sm.audio.play("Button on", self.shape.worldPosition)
end
