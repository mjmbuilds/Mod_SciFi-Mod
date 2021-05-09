-- ******************* My Functions **********************

-- Lightly formatted printing of tables.
function printT( table, tableName )
	local name = tableName or ""
	print("- - - - Print Table: "..name.." - - - -")
	if table == nil then
		print("nil")
	else
		local hasData = false
		for k,v in pairs(table) do
			hasData = true
			print("key: "..tostring(k))
			print(v)
		end
		if not hasData then
			print("empty")
		end
	end
end

-- Prints the length of the largest impulse it has seen
function printLargestImpulse( impulse )
	local impLen = impulse:length()
	if impLen > (largestImpulse or 0) then
		largestImpulse = impLen
	end
	print(largestImpulse)
end

-- Returns size of table or -1 if table is nil.
function sizeOf( table )
	if table == nil then
		return -1
	end
	local size = 0
	for k,v in pairs(table) do
		size = size + 1
	end
	return size
end