dofile("ModPaths.lua")

KeyboardGui = class()
--KeyboardGui.open arguments:
--"private" is the "self" of this class
--"self" is the "self" from the class importing this one
--"callback" is a function to be called when this GUI closes
--"initialMessage" is the initial text to start with for the message
function KeyboardGui.open( private, self, callback, initialMessage )
	private.messageBuffer = initialMessage --current message while GUI is open
	private.returnMessage = nil --messsage to send to the callback
	self.keyboard_onOkButtonClick = function( self ) --if OK clicked, set the return message
		private.returnMessage = private.messageBuffer
		self.keyboard_gui:close()
	end
	self.keyboard_onCancelButtonClick = function( self ) -- if CANCEL clicked, close with no message
		self.keyboard_gui:close()
	end
	self.keyboard_onGuiClose = function( self ) -- when closed, return the message (can be null)
		callback(self, private.returnMessage)
	end
	self.keyboard_onClearButtonClick = function( self ) -- if CLEAR clicked, current message is empty string
		private.messageBuffer = ""
		self.keyboard_gui:setText("MessageText", "\""..private.messageBuffer.."\"")
	end
	self.keyboard_onDelButtonClick = function( self ) -- if DEL clicked, remove last character from current message
		if private.messageBuffer and #private.messageBuffer > 0 then
			private.messageBuffer = private.messageBuffer:sub(1, -2)
			self.keyboard_gui:setText("MessageText", "\""..private.messageBuffer.."\"")
		end
	end
	self.keyboard_onSpaceButtonClick = function( self ) -- is SPACE clicked, append a space to current message
		private.messageBuffer = private.messageBuffer.." "
		self.keyboard_gui:setText("MessageText", "\""..private.messageBuffer.."\"")
	end
	
	self.keyboard_onKeyButtonClick = function( self, buttonName ) -- if any other key clicked, append key's value to current message
		local keyValue = string.sub(buttonName, 7) -- the key's value is a substring of the button name such that "Button3" has the value "3"
		private.messageBuffer = private.messageBuffer..keyValue
		self.keyboard_gui:setText("MessageText", "\""..private.messageBuffer.."\"")
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
