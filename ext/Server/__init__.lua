require('havok')

local currentLevel = nil
-- We are sending the required havok transforms to clients when the level
-- changes or when someone joins for the first time.

-- NOTE: This may not work over high latency connections, as the client
-- might already be loading the level by the time they receive the event.
function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
 end

Events:Subscribe('Level:LoadResources', function(levelName)
	local lowerName = levelName:lower()
	local s_Path = lowerName:split("/")
	currentLevel = s_Path[2]
	for assetName, transforms in pairs(HavokTransforms) do
		if assetName:lower():find(currentLevel) then
			print('Sending transforms for "' .. assetName .. '" to all clients.')
			NetEvents:Broadcast('nohavok:transforms', assetName, transforms)
		end
	end
end)

Events:Subscribe('Player:Authenticated', function(player)
	if currentLevel == nil then
		return
	end
	for assetName, transforms in pairs(HavokTransforms) do
		if assetName:lower():find(currentLevel) then
			print('Sending transforms for "' .. assetName .. '" to "' .. player.name .. '".')
			NetEvents:Broadcast('nohavok:transforms', assetName, transforms)
		end
	end
end)
