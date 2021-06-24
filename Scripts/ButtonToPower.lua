ButtonToPower = class()
ButtonToPower.maxParentCount = -1
ButtonToPower.maxChildCount = -1
ButtonToPower.connectionInput = sm.interactable.connectionType.logic
ButtonToPower.connectionOutput = sm.interactable.connectionType.logic + sm.interactable.connectionType.power + sm.interactable.connectionType.piston
ButtonToPower.colorNormal = sm.color.new( 0x7d0388ff )
ButtonToPower.colorHighlight = sm.color.new( 0x9e0caaff )

ButtonToPower.rampStep = 0.05
ButtonToPower.targetVelocity = 10
ButtonToPower.maxImpulse = 10000000
ButtonToPower.reverseColors = {"222222ff", "323000ff", "375000ff", "064023ff", "0a4444ff", "0a1d5aff", "35086cff", "520653ff", "560202ff", "472800ff"}

ButtonToPower.logicInputs = {
	"INPUT 1",
	"INPUT 2"
}

function ButtonToPower.server_onCreate( self ) --- Server setup ---
	self.publicData = {}
	self.publicData.logicInputs = self.logicInputs
	self.interactable:setPublicData(self.publicData)
	self.rampedInput = 0
end

function ButtonToPower.server_onFixedUpdate( self, dt ) --- Server Fixed Update ------------
	
	local targetValue = nil
	local pistonStrength = self.maxImpulse
	local pistonSpeed = self.targetVelocity
	
	-- get inputs
	local targetInput = 0
	
	----- get inputs from advanced buttons
	for _, input in pairs(self.interactable:getParents()) do
		if input.type == "scripted" and input:getPublicData() then
			for inputKey,inputValue in pairs(input:getPublicData()) do
				if inputKey == "INPUT 1" and inputValue == true then
					targetInput = targetInput + 1
				elseif inputKey == "INPUT 2" and inputValue == true then
					targetInput = targetInput - 1
				end
			end
		else
			local color = tostring(input.shape.color)
			if input:hasOutputType(sm.interactable.connectionType.logic) then
				if input:isActive() then
					local inputVal = 1
					local color = tostring(input.shape.color)
					for k,revColor in pairs(self.reverseColors) do
						if color == revColor then
							inputVal = -1
							break
						end
					end
					targetInput = targetInput + inputVal
				end
			else -- numbers
				if color == "eeaf5cff" then -- target value (orange 1)
					targetValue = input:getPower()
				elseif color == "df7f00ff" then -- piston speed (orange 2)
					pistonSpeed = input:getPower()
				elseif color == "673b00ff" then -- piston strength (orange 3)
					pistonStrength = input:getPower()
				end
			end
		end
	end
	targetInput = sm.util.clamp(targetInput, -1, 1)
	
	-- ramping
	if targetInput ~= 0 then
		if self.rampedInput < targetInput then
			self.rampedInput = self.rampedInput + self.rampStep
		else--self.rampedInput > targetInput then
			self.rampedInput = self.rampedInput - self.rampStep
		end
	else
		self.rampedInput = 0
	end
	
	-- set power for motors
	self.interactable:setPower(self.rampedInput)
	
	-- set pistons
	for k,piston in pairs(self.interactable:getPistons()) do
		local currentLength = tonumber(string.format("%4.2f",piston.length - 1))
		local targetLength = sm.util.clamp(currentLength + self.rampedInput ,0, 15)
		if targetValue then
			targetLength = targetValue
		end
		piston:setTargetLength(targetLength, pistonSpeed, pistonStrength)
	end
	
end
