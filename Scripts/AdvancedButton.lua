dofile("ModPaths.lua")
dofile("KeyboardGui.lua")
dofile("SelectFunctionGui.lua")

AdvancedButton = class()
AdvancedButton.maxParentCount = -1
AdvancedButton.maxChildCount = -1
AdvancedButton.connectionInput = sm.interactable.connectionType.logic + sm.interactable.connectionType.seated
AdvancedButton.connectionOutput = sm.interactable.connectionType.logic
AdvancedButton.colorNormal = sm.color.new( 0xee2a7bff )
AdvancedButton.colorHighlight = sm.color.new( 0xff4394ff )
AdvancedButton.poseWeightCount = 1

AdvancedButton.modes = { -- map of supported modes
	[1] = "BUTTON",
	[2] = "BUTTON INVERTED",
	[3] = "SINGLE TICK",
	[4] = "SINGLE TICK INVERTED",
	[5] = "SWITCH",
	[6] = "SWITCH INVERTED",
	[7] = "SWITCH MEMORY"
}

-- set up the server data
function AdvancedButton.server_onCreate( self )
	self.sv_data = self.storage:load() or {}
	self.sv_data.modeIndex = self.sv_data.modeIndex or (self.data and self.data.modeIndex or 1)
	self.sv_data.name = self.sv_data.name or self.modes[self.sv_data.modeIndex]
	self.sv_data.hasBeenRenamed = self.sv_data.hasBeenRenamed or false
	self.sv_data.hideTinkerHint = self.sv_data.hideTinkerHint or false
	self.sv_data.hideAllHints = self.sv_data.hideAllHints or false
	self.sv_data.savedState = self.sv_data.savedState or false
	self.publicData = {name = self.sv_data.name}
	self.interactable:setPublicData(self.publicData)
end
function AdvancedButton.server_onRefresh( self )
	print("* * * * * REFRESH AdvancedButton * * * * *")
	self:server_onCreate()
end

function AdvancedButton.server_onFixedUpdate( self, dt )
	-- apply override if changing modes
	if self.overrideActive ~= nil then
		self.interactable:setActive(self.overrideActive)
		self.overrideActive = nil
		return
	end
	
	-- check for interaction or active inputs
	local hasInteraction = self.sv_interacting or false
	if not hasInteraction then
		for _,input in pairs(self.interactable:getParents()) do
			if input:isActive() and not input:hasOutputType(sm.interactable.connectionType.seated) then
				hasInteraction = true
				break
			end
		end
	end
	-- update based upon mode behavior
	local newActive = false
	if self.sv_data.modeIndex == 1 then -- button
		newActive = hasInteraction
	elseif self.sv_data.modeIndex == 2 then -- button inverted
		newActive = not hasInteraction
	elseif self.sv_data.modeIndex == 3 then -- single tick
		newActive = hasInteraction and not self.prevInteraction
	elseif self.sv_data.modeIndex == 4 then -- single tick inverted
		newActive = self.prevInteraction and not hasInteraction
	elseif self.sv_data.modeIndex > 4 then -- switch, switch inverted, switch memory
		if hasInteraction and not self.prevInteraction then
			newActive = not self.interactable:isActive()
		else
			newActive = self.interactable:isActive()
		end
	end
	self.prevInteraction = hasInteraction
	
	-- if memory switch, save state if changed
	if self.sv_data.modeIndex == 7 then
		if newActive ~= self.interactable:isActive() then
			self.sv_data.savedState = newActive
			self.storage:save(self.sv_data)
		end
	-- if not a memeory switch, reset state when on lift	
	else
		local isOnLift = self.shape.body:isOnLift()
		if isOnLift and not self.prevOnLift then
			--if normal switch, set inactive
			if self.sv_data.modeIndex == 5 then
				newActive = false
			--if inverted switch, set active
			elseif self.sv_data.modeIndex == 6 then
				newActive = true
			end
		end
		self.prevOnLift = isOnLift
	end
	self.interactable:setActive(newActive or false) -- "or false" because "nil" got in there somehow
end

-- function for the client to tell the server if they are interacting with the part
function AdvancedButton.sv_setInteracting( self, data )
	self.sv_interacting = data.interacting
	if data.player then
		self.publicData.player = data.player
		self.interactable:setPublicData(self.publicData)
	end
end

-- function returns the state of its data to the clients
function AdvancedButton.sv_getData( self )
	self.network:sendToClients("cl_setData", self.sv_data)
end

-- function updates and saves the server's data
function AdvancedButton.sv_setData( self, data )
	self.sv_data.modeIndex = data.modeIndex or self.sv_data.modeIndex
	self.sv_data.name = data.name or self.sv_data.name
	if data.hasBeenRenamed then
		self.sv_data.hasBeenRenamed = true
	end
	self.publicData.name = self.sv_data.name
	self.interactable:setPublicData(self.publicData)
	if data.hideTinkerHint ~= nil then
		self.sv_data.hideTinkerHint = data.hideTinkerHint
	end
	if data.hideAllHints ~= nil then
		self.sv_data.hideAllHints = data.hideAllHints
	end
	self.storage:save(self.sv_data)
	if data.modeIndex then
		-- apply overrides when changing modes (using setActive() here wasn't reliable)
		if data.modeIndex == 1 or data.modeIndex == 3 or data.modeIndex == 5 then -- default off
			self.overrideActive = false
		elseif data.modeIndex == 2 or data.modeIndex == 4 or data.modeIndex == 6 then -- default on
			self.overrideActive = true
		end
	end
	self.network:sendToClients("cl_setData", data)
end

-- function checks child connections for recognized input names
function AdvancedButton.sv_getRecognizedInputs( self, player )
	local data = {}
	for _, child in pairs (self.interactable:getChildren()) do
		if child.type == "scripted" then
			local publicData = child:getPublicData()
			if publicData then
					data.inputList = publicData.inputList
					data.partName = publicData.partName
				break
			end
		end
	end
	-- if part of the data was nil, return nil, otherwise return data
	if data.inputList == nil or data.partName == nil then data = nil end	
	self.network:sendToClient(player, "cl_setRecognizedInputs", data)
end

-- ____________________________________ Client ____________________________________

-- set up the client data
function AdvancedButton.client_onCreate( self )
	self.actionLocks = {}
	self.cl_data = {}
	self.cl_data.modeIndex = 1
	self.cl_data.name = "unset"
	self.cl_data.hasBeenRenamed = false
	self.cl_data.hideTinkerHint = false
	self.cl_data.hideAllHints = false
	self.network:sendToServer("sv_getData")
end
function AdvancedButton.client_onRefresh( self )
	self:client_onCreate()
end

function AdvancedButton.client_onFixedUpdate( self, dt )
	-- reset interaction of switches and single tick buttons (so they were only for 1 tick)
	if self.cl_interacting and (self.cl_data.modeIndex == 3 or self.cl_data.modeIndex > 4 ) then
		self:cl_release()
	end
	-- update pose
	self.interactable:setPoseWeight(0, self.interactable:isActive() and 1 or 0)
end

-- client_onAction will allow us to minitor some keys when the character is locked to the interactable
function AdvancedButton.client_onAction( self, controllerAction, isKeyDown )
	if self.actionLocks.button then
		-- If the action was false, the player just released that key.
		if isKeyDown == false and controllerAction == sm.interactable.actions.use and self.lockedCharacter then
			self:cl_release()
		end
		return false
	end
end

-- cleanup on destroy
function AdvancedButton.client_onDestroy( self )
	if self.gui then -- if the advanced button GUI exists, destroy it
		self.gui:destroy()
		self.gui = nil
	end
	if self.keyboard_gui then -- if the keyboard GUI exists, destroy it
		self.keyboard_gui:destroy()
		self.keyboard_gui = nil
	end
	if self.lockedCharacter then -- if the character was locked to the interactable, clear them
		self.lockedCharacter:setLockingInteractable(nil)
		self.lockedCharacter = nil
	end
end

-- use client_canInteract to override the messages shown when looking at the part
function AdvancedButton.client_canInteract( self )
	local interactKey = sm.gui.getKeyBinding("Use")
	local tinkerKey = sm.gui.getKeyBinding("Tinker")
	if self.cl_data.hideAllHints then
		sm.gui.setInteractionText("")
		sm.gui.setInteractionText("")
	elseif self.cl_data.hideTinkerHint then
		sm.gui.setInteractionText("", interactKey, self.cl_data.name)
		sm.gui.setInteractionText("")
	else
		sm.gui.setInteractionText("", interactKey, self.cl_data.name)
		sm.gui.setInteractionText("", tinkerKey, "Edit")
	end
	return true
end

-- when the player "uses" the part (E)
function AdvancedButton.client_onInteract( self, character, lookAt )
	if lookAt == true then
		self:cl_press(character)
	elseif self.cl_interacting then
		self:cl_release()
	end
end

-- when the player "tinkers" with the part (U)
function AdvancedButton.client_onTinker( self, character, lookAt )
	if lookAt then
		self:cl_release()
		-- if there's a child connection, see if it has recognized inputs before opening GUI
		if #self.interactable:getChildren() > 0 then
			self.network:sendToServer("sv_getRecognizedInputs", character:getPlayer())
		else
			self.recognizedData = nil
			self:cl_openMainGui()
		end
	end
end

-- for the server to set data about child part's recognized input names
function AdvancedButton.cl_setRecognizedInputs( self, data )
	self.recognizedData = data
	self:cl_openMainGui()
end

-- initialize the GUI with values and callbacks
function AdvancedButton.cl_openMainGui( self )
	self.newModeIndex = nil
	self.newName = nil
	self.newHideTinkerHint = nil
	self.newHideAllHints = nil
	if not self.gui then self.gui = sm.gui.createGuiFromLayout(LAYOUTS_PATH..'AdvancedButton.layout') end
	self.gui:setOnCloseCallback("cl_onGuiClose")
	self.gui:setButtonCallback("RenameButton", "cl_onRenameButtonClick")
	self.gui:setButtonCallback("SelectFunctionButton", "cl_onSelectFunctionButtonClick")
	self.gui:setButtonCallback("TinkerHintButton", "cl_onTinkerHintButtonClick")
	self.gui:setButtonCallback("TinkerHintTextButton", "cl_onTinkerHintButtonClick")
	self.gui:setButtonCallback("AllHintsButton", "cl_onAllHintsButtonClick")
	self.gui:setButtonCallback("AllHintsTextButton", "cl_onAllHintsButtonClick")
	for i = 1, 7 do -- the mode buttons have their index stored like "Button1" is mode index 1
		self.gui:setButtonCallback("ModeButton"..tostring(i), "cl_onModeButtonClick")
	end
	self:cl_drawGui()	
	self.gui:open()
end

-- updates the GUI text and button states
function AdvancedButton.cl_drawGui( self )
	local description = ""..
		"\"Inverted\" button and switch default to ON position.\n"..
		"\"Inverted\" single tick sends a tick when released.\n"..
		"\"Switch Memory\" keeps the last state instead of resetting on the lift.\n\n"..
		"Note: If a vanilla part doesn't recogniz the scripted logic output, you can use a logic gate in between."
	self.gui:setText("DescriptionText", description)
	local name = self.newName or self.cl_data.name
	self.gui:setText("NameText", "\""..name.."\"")
	local hideTinkerHint = self.newHideTinkerHint or self.cl_data.hideTinkerHint
	self.gui:setButtonState("TinkerHintButton", hideTinkerHint)
	local hideAllHints = self.newHideAllHints or self.cl_data.hideAllHints
	self.gui:setButtonState("AllHintsButton", hideAllHints)
	local modeIndex = self.newModeIndex or self.cl_data.modeIndex
	for i = 1, 7 do
		self.gui:setButtonState("ModeButton"..tostring(i), i == modeIndex)
	end
	if self.recognizedData then
		self.gui:setVisible("SelectFunctionButton", true)
		self.gui:setVisible("RenameButton", false)
		self.gui:setText("Title", self.recognizedData.partName)
	else
		self.gui:setVisible("RenameButton", true)
		self.gui:setVisible("SelectFunctionButton", false)
		self.gui:setText("Title", "Advanced Button")
	end
end

-- when the GUI closes, send the server the updates if anything has changed
function AdvancedButton.cl_onGuiClose( self, buttonName )
	if (self.newName == nil and self.newModeIndex == nil and self.newHideTinkerHint == nil and self.newHideAllHints == nil) then return end
	local data = {} -- members can be nil (sv_setData allows missing values)
	if self.newName == nil then
		if self.newModeIndex and not self.cl_data.hasBeenRenamed and not self.recognizedData then
			data.name = self.modes[self.newModeIndex]
		end
	else
		data.hasBeenRenamed = true
		if self.newName == "" then -- endcode empty string as false beucase sending empty string logs an error
			data.name = false
		else
			data.name = self.newName
		end
	end
	data.modeIndex = self.newModeIndex
	data.hideTinkerHint = self.newHideTinkerHint
	data.hideAllHints = self.newHideAllHints
	self.network:sendToServer("sv_setData", data)
end

-- if the REANAME button clicked, open the keyboard GUI
function AdvancedButton.cl_onRenameButtonClick( self, buttonName )
	self.gui:close()
	-- arguments for KeyboardGui:open( {self}, {callback for when keyboard GUI closes}, {intial text for keyboard's message} )
	KeyboardGui:open( self, self.cl_onKeyboardGuiClose, self.newName or self.cl_data.name )
end

-- will get called from the callback of the keyboard GUI
function AdvancedButton.cl_onKeyboardGuiClose( self, newName )
	if newName ~= nil then
		self.newName = newName
		self:cl_onGuiClose()
	end
end

-- if the SELECT FUNCTION button clicked, open the select function GUI
function AdvancedButton.cl_onSelectFunctionButtonClick( self, buttonName )
	self.gui:close()
	-- arguments for SelectFunction:open( {self}, {callback for when SelectFunction GUI closes}, {data for recognized inputs} )
	SelectFunction:open( self, self.cl_onKeyboardGuiClose, self.recognizedData )
end

-- handle toggling the hiding of the "Edit" hint text when looking at the part
function AdvancedButton.cl_onTinkerHintButtonClick( self, buttonName )
	self.gui:close()
	if self.newHideTinkerHint ~= nil then
		self.newHideTinkerHint = not self.newHideTinkerHint
	else
		self.newHideTinkerHint = not self.cl_data.hideTinkerHint
	end
	self.gui:setButtonState("TinkerHintButton", self.newHideTinkerHint)
end

-- handle toggling the hiding of all the text when looking at the part
function AdvancedButton.cl_onAllHintsButtonClick( self, buttonName )
	self.gui:close()
	if self.newHideAllHints ~= nil then
		self.newHideAllHints = not self.newHideAllHints
	else
		self.newHideAllHints = not self.cl_data.hideAllHints
	end
	self.gui:setButtonState("AllHintsButton", self.newHideAllHints)
end

-- handle clicking on a new mode
function AdvancedButton.cl_onModeButtonClick( self, buttonName )
	self.gui:close()
	local buttonString = string.sub(buttonName, 11)
	self.newModeIndex = tonumber(buttonString)
	for i = 1, 7 do
		self.gui:setButtonState("ModeButton"..tostring(i), i == self.newModeIndex)
	end
end

-- for the server to update the client's data
function AdvancedButton.cl_setData( self, data )
	self.cl_data.modeIndex = data.modeIndex or self.cl_data.modeIndex
	if data.name == false then 
		data.name = ""
	end
	if data.hasBeenRenamed then
		self.cl_data.hasBeenRenamed = true
	end
	self.cl_data.name = data.name or self.cl_data.name
	if data.hideTinkerHint ~= nil then
		self.cl_data.hideTinkerHint = data.hideTinkerHint
	end
	if data.hideAllHints ~= nil then
		self.cl_data.hideAllHints = data.hideAllHints
	end
end

-- for updating interactable lock and notifying the server when the player starts interacting
function AdvancedButton.cl_press( self, character )
	self.cl_interacting = true
	self.actionLocks.button = true
	self:cl_lockCharacter(character)
	self.network:sendToServer( 'sv_setInteracting', {interacting = true, player = character:getPlayer()} )
	if self.cl_data.modeIndex ~= 4 then -- don't make press noise for inverted single tick
		sm.audio.play("Button on", self.shape.worldPosition)
	end
end

-- for updating interactable lock and notifying the server when the player stops interacting
function AdvancedButton.cl_release( self )
	self.cl_interacting = false
	self.actionLocks.button = false
	self:cl_unlockCharacter()
	self.network:sendToServer( 'sv_setInteracting', {interacting = false} )
	sm.audio.play("Button off", self.shape.worldPosition)
end

-- locks the character to the interactable
function AdvancedButton.cl_lockCharacter( self, character )
	if not character:getLockingInteractable() then
		character:setLockingInteractable(self.interactable)
		self.lockedCharacter = character
	end
end

-- unlocks the character from the interactable
function AdvancedButton.cl_unlockCharacter( self )
	if self.lockedCharacter then
		self.lockedCharacter:setLockingInteractable(nil)
		self.lockedCharacter = nil
	end
end