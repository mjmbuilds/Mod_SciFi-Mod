dofile("ModPaths.lua")

SelectFunction = class()
--SelectFunction.open arguments:
--"_" is the "self" of this class and not used
--"self" is the "self" from the class importing this one
--"callback" is a function to be called when this GUI closes
--"data" should contain a "inputList" table of the accepted input names and a "partName" name of the part accepting the inputs
function SelectFunction.open( _, self, callback, data )
	if self == nil or callback == nil or data == nil or data.inputsLayout == nil then return end
	local returnMessage = nil --messsage to send to the callback

	-- when GUI is closed, send the return message to the callback
	self.selectFunction_onGuiClose = function( self ) -- when closed, return the message (can be null)
		callback(self, returnMessage)
	end
	
	-- when a buttons is clicked, set the return message and close thie GUI
	self.selectFunction_onButtonClick = function( self, buttonName ) -- if any other key clicked, append key's value to current message
		returnMessage = buttonName
		self.selectFunction_gui:close()
	end
	
	-- initialize the GUI with values and callbacks
	if not self.selectFunction_gui then
		self.selectFunction_gui = sm.gui.createGuiFromLayout(LAYOUTS_PATH..data.inputsLayout)
	end
	self.selectFunction_gui:setOnCloseCallback("selectFunction_onGuiClose")
	for i = 1, #data.logicInputs do
		self.selectFunction_gui:setButtonCallback(data.logicInputs[i], "selectFunction_onButtonClick")
	end
	self.selectFunction_gui:open()
end
