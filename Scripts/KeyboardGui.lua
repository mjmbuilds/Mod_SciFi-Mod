dofile("ModPaths.lua")

KeyboardGui = class()
--KeyboardGui.open arguments:
--"_" is the "self" of this class and not used
--"self" is the "self" from the class importing this one
--"callback" is a function to be called when this GUI closes
--"initialMessage" is the initial text to start with for the message
function KeyboardGui.open( _, self, callback, initialMessage )
	if self == nil or callback == nil then return end
	local messageBuffer = initialMessage or "" --current message while GUI is open
	local returnMessage = nil --messsage to send to the callback
	self.keyboard_onOkButtonClick = function( self ) --if OK clicked, set the return message
		returnMessage = messageBuffer
		self.keyboard_gui:close()
	end
	self.keyboard_onCancelButtonClick = function( self ) -- if CANCEL clicked, close with no message
		self.keyboard_gui:close()
	end
	self.keyboard_onGuiClose = function( self ) -- when closed, return the message (can be null)
		callback(self, returnMessage)
	end
	self.keyboard_onClearButtonClick = function( self ) -- if CLEAR clicked, current message is empty string
		messageBuffer = ""
		self.keyboard_gui:setText("MessageText", "\""..messageBuffer.."\"")
	end
	self.keyboard_onDelButtonClick = function( self ) -- if DEL clicked, remove last character from current message
		if messageBuffer and #messageBuffer > 0 then
			messageBuffer = messageBuffer:sub(1, -2)
			self.keyboard_gui:setText("MessageText", "\""..messageBuffer.."\"")
		end
	end
	self.keyboard_onSpaceButtonClick = function( self ) -- is SPACE clicked, append a space to current message
		messageBuffer = messageBuffer.." "
		self.keyboard_gui:setText("MessageText", "\""..messageBuffer.."\"")
	end
	
	self.keyboard_onKeyButtonClick = function( self, buttonName ) -- if any other key clicked, append key's value to current message
		local keyValue = string.sub(buttonName, 7) -- the key's value is a substring of the button name such that "Button3" has the value "3"
		messageBuffer = messageBuffer..keyValue
		self.keyboard_gui:setText("MessageText", "\""..messageBuffer.."\"")
	end
	
	-- initialize the GUI with values and callbacks
	if not self.keyboard_gui then self.keyboard_gui = sm.gui.createGuiFromLayout(LAYOUTS_PATH..'Keyboard.layout') end
	self.keyboard_gui:setOnCloseCallback("keyboard_onGuiClose")
	self.keyboard_gui:setButtonCallback("ButtonOk", "keyboard_onOkButtonClick")
	self.keyboard_gui:setButtonCallback("ButtonCancel", "keyboard_onCancelButtonClick")
	self.keyboard_gui:setButtonCallback("ButtonClear", "keyboard_onClearButtonClick")
	self.keyboard_gui:setButtonCallback("ButtonDel", "keyboard_onDelButtonClick")
	self.keyboard_gui:setButtonCallback("ButtonSpace", "keyboard_onSpaceButtonClick")
	local keys = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	for i = 1, 36 do -- index through the list of keys to assign callbacks to the buttons which have been named "Button{key}"
		self.keyboard_gui:setButtonCallback("Button"..keys:sub(i,i), "keyboard_onKeyButtonClick")
	end
	self.keyboard_gui:setText("MessageText", "\""..initialMessage.."\"")
	self.keyboard_gui:open()
end
