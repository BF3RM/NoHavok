-- This is a global table that will be populated on-demand by
-- the server via NetEvents on the client-side, or overriden
-- with the real data on the server-side.
HavokTransforms = {}
local objectVariations = {}
local pendingVariations = {}
local foundObjects = {}
local staticModelGroupNumber = 1

local customRegistry = nil
local CUSTOMREF_GUID = "ED170123"

local blacklistedBlueprintNames = {
	["Levels/XP4_Parliament/Objects/ME_StoreFront_GlassDoor_BigBackdoor_TwoWindows_01_main"] = true,
	["Objects/Ashtray_01/Ashtray_01"] = true,
	["Objects/Phonebooth_02/Phonebooth_02"] = true,
	["Objects/MetroSigns/MetroSign_14"] = true,
	["Objects/MetroSigns/MetroSign_25"] = true,
	["Objects/MetroSigns/MetroSign_32"] = true,
	["Objects/MetroSigns/MetroSign_57"] = true,
	["Objects/SignsBorder_01/Sign_LED_Wait_01"] = true,
	["Levels/XP5_002/Objects/ConveyorLine_01_XP5_002/ConveyorLine_01b_XP5_002"] = true,
	["Levels/XP5_002/Objects/ConveyorLine_01_XP5_002/ConveyorLine_01c_XP5_002"] = true
}

-- Generates a guid based on a given number. Used for vanilla objects.
function PadAndCreateGuid(p_Base, p_Index1, p_Index2)
	local hash = MathUtils:FNVHash(p_Base)
	hash = string.format("%08x", hash)
	hash = string.sub(hash, -8)
	
	local index1 = string.format("%04x", p_Index1)
	index1 = string.sub(index1, -4)
	
	local index2 = string.format("%012x", p_Index2)
	index2 = string.sub(index2, -12)
	
	local guid = hash .. "-0000-0000-".. index1 .."-".. index2
	return Guid(guid)
end

function processMemberData(transformIndex, index, member, worldPartData, havokAsset, partition, havokTransforms)
	-- For every static model we'll create an object blueprint
	-- and set its object to the static model entity. We will
	-- also add it to our custom registry for replication support.
	local blueprint = ObjectBlueprint()
	customRegistry.blueprintRegistry:add(blueprint)

	for i = 1, member.instanceCount do
		-- We will create one new referenceobject with our previously
		-- created blueprint for all instances of this static model.
		-- We'll also give it a blueprint index that's above any other
		-- blueprint index currently in-use by the engine (this is
		-- currently hardcoded but could be improved). This will allow
		-- for proper network replication.
		local referenceObjectData = ReferenceObjectData(PadAndCreateGuid(havokAsset.name, index, i))
		partition:AddInstance(referenceObjectData)

		transformIndex = handleBlueprint(blueprint, transformIndex, i, member, worldPartData, havokTransforms, referenceObjectData)
	end

	return transformIndex
end

function handleBlueprint(blueprint, transformIndex, i, member, worldPartData, havokTransforms, referenceObjectData)
	-- Set the relevant flag if this entity needs a network ID,
	-- which is when the range value is not uint32::max.
	if member.networkIdRange.first ~= 0xffffffff then
		blueprint.needNetworkId = true
	end
	referenceObjectData.blueprint = blueprint
	referenceObjectData.indexInBlueprint = #worldPartData.objects + 30001
	referenceObjectData.isEventConnectionTarget = Realm.Realm_None
	referenceObjectData.isPropertyConnectionTarget = Realm.Realm_None

	customRegistry.referenceObjectRegistry:add(referenceObjectData)

	-- If the entity data is lazy loaded then we'll need to come
	-- back and hotpatch it once it is loaded.
	if member.memberType.isLazyLoaded then
		member.memberType:RegisterLoadHandlerOnce(function(ctr)
			blueprint.object = GameObjectData(ctr)
		end)
	else
		blueprint.object = member.memberType
	end

	if #member.instanceTransforms > 0 and member.instanceTransforms[i] ~= nil then
		-- If this member contains its own transforms then we get the
		-- transform from there.
		referenceObjectData.blueprintTransform = member.instanceTransforms[i]
	else
		-- Otherwise, we'll need to calculate the transform using the
		-- extracted havok data.
		local scale = 1.0

		-- FIXME: Any scale other than 1.0 currently crashes the server.
		--[[if i <= #member.instanceScale then
			scale = member.instanceScale[i]
		end]]

		local transform = havokTransforms[transformIndex]

		if not transform then
			print('Transform not found, index: ' .. transformIndex)
			return
		end

		-- At index 1 we have the rotation and at index 2 we have the position.
		local quatTransform = QuatTransform(
			Quat(transform[1][1], transform[1][2], transform[1][3], transform[1][4]),
			Vec4(transform[2][1], transform[2][2], transform[2][3], scale)
		)

		referenceObjectData.blueprintTransform = quatTransform:ToLinearTransform()

		transformIndex = transformIndex + 1
	end

	referenceObjectData.castSunShadowEnable = true

	if i <= #member.instanceCastSunShadow then
		referenceObjectData.castSunShadowEnable = true --member.instanceCastSunShadow[i]
	end

	if i <= #member.instanceObjectVariation and member.instanceObjectVariation[i] ~= 0 then
		local variationHash = member.instanceObjectVariation[i]
		local variation = objectVariations[variationHash]

		-- If we don't have this variation loaded yet we'll set this
		-- aside and we'll hotpatch it when the variation gets loaded.
		if variation == nil then
			if pendingVariations[variationHash] == nil then
				pendingVariations[variationHash] = {}
			end

			table.insert(pendingVariations[variationHash], referenceObjectData)
		else
			referenceObjectData.objectVariation = variation
		end
	end

	local objectName = referenceObjectData.blueprint.name
	-- if foundObjects[objectName] == nil then
	-- 	foundObjects[objectName] = 1
	-- 	-- print(objectName)
	-- else
	-- 	foundObjects[objectName] = foundObjects[objectName] + 1
	-- end

	if blacklistedBlueprintNames[referenceObjectData.blueprint.name] then
		print("Found a blacklisted blueprint, ignoring. Name: " .. referenceObjectData.blueprint.name)
	else
		worldPartData.objects:add(referenceObjectData)
	end

	return transformIndex
end

function processStaticGroup(instance, partition)
	--print("processStaticGroup")
	local smgeData = StaticModelGroupEntityData(instance)
	smgeData:MakeWritable()
	
	if not smgeData or not smgeData.physicsData then
		print('StaticModelGroupEntityData was nil. Partition guid: ' .. tostring(partition.guid) .. ", name:" .. tostring(instance.guid))
	end
	
	local havokAsset = GroupHavokAsset(smgeData.physicsData.asset)
	local worldPartReferenceObjectData = WorldPartReferenceObjectData(PadAndCreateGuid(havokAsset.name, MathUtils:FNVHash(havokAsset.name), MathUtils:FNVHash(havokAsset.name)))
	smgeData.physicsData = nil
	local havokTransforms = HavokTransforms[havokAsset.name:lower()]

	-- If we don't have any transform data for this asset then skip.
	if havokTransforms == nil then
		print('No havok transforms found for "' .. havokAsset.name .. '".')
		return nil
	end

	-- Create some WorldPartData. This will hold all of the entities
	-- we'll extract from the static group.
	local worldPartData = WorldPartData(smgeData.instanceGuid)
	worldPartData.name = havokAsset.name
	partition:AddInstance(worldPartData)
	worldPartData.enabled = true

	-- Also add it to our registry for proper replication support.
	customRegistry.blueprintRegistry:add(worldPartData)

	-- local transformIndexes = {
	-- 	index = 1
	-- }
	local transformIndex = 1
	for j, member in ipairs(smgeData.memberDatas) do
		-- If the entity data is lazy loaded then we'll need to come
		-- back and hotpatch it once it is loaded.
		transformIndex = processMemberData(transformIndex, j, member, worldPartData, havokAsset, partition, havokTransforms)
		--print(tostring(staticModelGroupNumber) .. " - TransformIndex: " .. tostring(transformIndex))
	end
	-- local counter = 0
	-- for objectName, amount in pairs(foundObjects) do
	-- 	--print(objectName .. " - " .. tostring(amount))
	-- 	counter = counter + 1
	-- end
	-- print("Unique objects: " .. counter)
	smgeData.memberDatas:clear()
	
	-- Finally, we'll create a worldpart reference which we'll use
	-- to replace the original static model group.
	partition:AddInstance(worldPartReferenceObjectData)
	worldPartReferenceObjectData.blueprint = worldPartData
	worldPartReferenceObjectData.indexInBlueprint = smgeData.indexInBlueprint + 3000
	worldPartReferenceObjectData.isEventConnectionTarget = Realm.Realm_None
	worldPartReferenceObjectData.isPropertyConnectionTarget = Realm.Realm_None

	customRegistry.referenceObjectRegistry:add(worldPartReferenceObjectData)
	return worldPartReferenceObjectData
end

function patchWorldData(instance, groupsToReplace)
	local data = SubWorldData(instance)
	data:MakeWritable()

	if data.registryContainer ~= nil then
		data.registryContainer:MakeWritable()
	end

	for group, replacement in pairs(groupsToReplace) do
		local groupIndex = data.objects:index_of(group)

		if groupIndex ~= -1 then
			-- We found the static group. Replace it with our world part reference.
			data.objects[groupIndex] = replacement
		end
	end
end

Events:Subscribe('Partition:Loaded', function(partition)
	local groupsToReplace = {}
	local hasToReplace = false

	-- Resources haven't loaded yet, so we don't care about the partition (it's about persitence/sound/description) 
	if not SharedUtils:GetLevelName() then
		return
	end

	for _, instance in pairs(partition.instances) do
		-- We look for all static model groups to convert them into separate entities.
		if instance:Is('StaticModelGroupEntityData') then
			-- Ignore if it's from a sideloaded bundle
			if string.find(partition.name:lower(), SharedUtils:GetLevelName():lower()) then
				--print("staticModelGroupNumber: " .. tostring(staticModelGroupNumber))
				--print("partition guid: " .. tostring(partition.guid))
				--print("instance guid: " .. tostring(instance.instanceGuid))
				local replacement = processStaticGroup(instance, partition)
				staticModelGroupNumber = staticModelGroupNumber + 1

				if replacement ~= nil then
					hasToReplace = true
					groupsToReplace[StaticModelGroupEntityData(instance)] = replacement
				end
			end
		elseif instance:Is('ObjectVariation') then
			-- Store all variations in a map.
			local variation = ObjectVariation(instance)
			objectVariations[variation.nameHash] = variation

			if pendingVariations[variation.nameHash] ~= nil then
				for _, object in pairs(pendingVariations[variation.nameHash]) do
					object.objectVariation = variation
				end
				pendingVariations[variation.nameHash] = nil
			end
		end
	end

	-- If we found a group we'll go through the instances once more so we can
	-- patch the level / subworld data. These should always be within the same
	-- partition.
	if hasToReplace then
		for _, instance in pairs(partition.instances) do
			if instance:Is('SubWorldData') then
				patchWorldData(instance, groupsToReplace)
			end
		end
	end
end)

Events:Subscribe('Level:Destroy', function()
	objectVariations = {}
	pendingVariations = {}
	customRegistry = nil
end)

Events:Subscribe('Level:LoadResources', function()
	objectVariations = {}
	pendingVariations = {}
	customRegistry = RegistryContainer()
end)

Events:Subscribe('Level:RegisterEntityResources', function(levelData)
	ResourceManager:AddRegistry(customRegistry, ResourceCompartment.ResourceCompartment_Game)
end)
