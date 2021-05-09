SettingsSlider = class( nil )
SettingsSlider.maxChildCount = -1
SettingsSlider.maxParentCount = -1
SettingsSlider.connectionInput = sm.interactable.connectionType.logic
SettingsSlider.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power
SettingsSlider.colorNormal = sm.color.new( 0x7d0388ff )
SettingsSlider.colorHighlight = sm.color.new( 0x9e0caaff )
SettingsSlider.poseWeightCount = 2

-- ____________________________________ Server ____________________________________

function SettingsSlider.server_onCreate( self )
	self.data = {}
	self.saved = self.storage:load()
	if self.saved then
		self.data.modeIndex = self.saved.modeIndex or 0
	else
		self.data.modeIndex = 0
	end
	self.svChildCount = nil
	if self.interactable then
		_G[tostring(self.interactable.id) .. "modeIndex"] = nil --might not have interactable yet?
	end
end

function SettingsSlider.sv_getMode(self)
	self.network:sendToClients("cl_setMode", self.data.modeIndex)
end

function SettingsSlider.sv_setMode( self, modeIndex )
	self.data.modeIndex = modeIndex
	self.storage:save(self.data)
	self.network:sendToClients("cl_setMode", modeIndex)
end

function SettingsSlider.server_onFixedUpdate( self, dt )

--[[----------------------------this is for input part, not slider part...
	local active = false
	local children = self.interactable:getChildren()
	-- only need to continue if there is a child connection
	if children[1] then
		local parents = self.interactable:getParents()
		-- check for input signals
		for k,parent in pairs(self.interactable:getParents()) do
			-- default orange = input1, other color = input 2
		end	
	end

	-- apply active
	if active ~= self.interactable:isActive() then
		self.interactable:setActive(active)
	end
--]]
	
end

-- ____________________________________ Client ____________________________________

function SettingsSlider.client_onCreate(self)
	self.cl_modeIndex = 0
	self.network:sendToServer("server_requestMode")
end
function SettingsSlider.client_setMode( self, modeIndex )
	self.cl_modeIndex = modeIndex
	self.interactable:setUvFrameIndex(modeIndex)
end

function SettingsSlider.client_onInteract(self, character, lookAt)
    if not lookAt then return end
	if self.gui == nil then
		self.gui = sm.gui.createEngineGui()
		self.gui:setSliderCallback( "Setting", "cl_onSliderChange")
		self.gui:setText("Name", "Settings Slider")
		self.gui:setText("Interaction", "Value")		
		self.gui:setIconImage("Icon", sm.uuid.new("6f64d36d-5e23-4f6b-bcb5-e0057ba43fce")) --TODO udpate uuid
		self.gui:setVisible("FuelContainer", false )
	end
	self.gui:setSliderData("Setting", #self.modes, self.cl_modeIndex)
	self.gui:setText("SubTitle", self.modes[self.cl_modeIndex])
	self.gui:open()
	--sm.audio.play("Button on", self.shape.worldPosition)
end

function SettingsSlider.cl_onSliderChange( self, sliderName, sliderPos )
	self.cl_modeIndex = sliderPos
	if self.gui ~= nil then
		self.gui:setText("SubTitle", "Mode: "..self.modes[sliderPos])
	end
	self.network:sendToServer("server_changeMode", sliderPos)
end

function SettingsSlider.client_onFixedUpdate( self, dt )
	if self.interactable:isActive() then
		self.interactable:setPoseWeight(0, 1)
	else
		self.interactable:setPoseWeight(0, 0)
	end
end
