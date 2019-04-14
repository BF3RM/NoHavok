class 'NoHavokCommon'


function NoHavokCommon:__init(p_Realm)
	print("Initializing NoHavokCommon: " .. p_Realm)
	self:RegisterVars(p_Realm)
end


function NoHavokCommon:RegisterVars(p_Realm)
	self.m_ToSpawn = {}
	self.m_Index = 2700

	self.m_Patched = 0
	self.m_Done = false

	self.m_Primary = {}
	self.m_Variations = {}
	self.m_KeepAlive = {}

	self.m_HighestIndex = 0
	self.m_Registry = nil

	self.m_Realm = p_Realm

	self.m_WorldPartReferences = {}
	self.m_PhysicsAssets = {}
	self.m_Unresolved = {}
	self.m_UnresolvedVariation = {}
end

function NoHavokCommon:RegisterStaticModelGroupAsset(p_AssetName, p_Data)
	self.m_PhysicsAssets[p_AssetName] = p_Data
	print("Registered PhysicsData: " .. p_AssetName)
end

function NoHavokCommon:GetUnresolved()
	return self.m_Unresolved
end
function NoHavokCommon:GetUnresolvedVariations()
	return self.m_UnresolvedVariation
end

function NoHavokCommon:OnPartitionLoaded(p_Partition)
	if p_Partition == nil then
		return
	end

	local s_Instances = p_Partition.instances

	local s_Originals = {}
	local s_Clones = {}
	local s_Blueprint = nil

	for _, l_Instance in ipairs(s_Instances) do
		if l_Instance == nil then
			print('Instance is null?')
			break
		end
		if l_Instance.typeInfo == LevelData.typeInfo then
			self.m_LevelData = LevelData(l_Instance)
			self.m_LevelData:MakeWritable()
			self.m_Registry = self.m_LevelData.registryContainer
   			self.m_Registry:MakeWritable()
		end

		if l_Instance.typeInfo == ObjectVariation.typeInfo then
		    local s_Instance = ObjectVariation(l_Instance)
		    self.m_Variations[s_Instance.nameHash] = s_Instance
			if(self.m_UnresolvedVariation[s_Instance.nameHash] ~= nil) then
				self:ResolveVariation(s_Instance.nameHash)
			end
		end

		if(l_Instance:Is("Blueprint")) then
			s_Blueprint = Blueprint(l_Instance)
		end

		if(s_Blueprint ~= nil) then
			self.m_Primary[tostring(l_Instance.instanceGuid)] = s_Blueprint.name
		end

		if(self.m_Unresolved[tostring(l_Instance.instanceGuid)] ~= nil) then
			self:ResolveBlueprint(tostring(l_Instance.instanceGuid))
		end
		if(self.m_Unresolved[IncreasedGuid(tostring(l_Instance.instanceGuid))] ~= nil) then
			self:ResolveBlueprint(tostring(l_Instance.instanceGuid), true)

		end

		if(l_Instance.typeInfo.name == "StaticModelGroupEntityData") then
			local s_Original = StaticModelGroupEntityData(l_Instance)
			local s_Instance = StaticModelGroupEntityData(l_Instance:Clone(l_Instance.instanceGuid))
			table.insert(s_Originals, l_Instance)
			table.insert(s_Clones, s_Instance)

			local s_PhysicsName = GroupHavokAsset(PhysicsEntityData(s_Instance.physicsData).asset).name

			if(self.m_PhysicsAssets[s_PhysicsName] == nil) then
				error("Failed to find PhysicsAsset: " .. s_PhysicsName)
				return
			end
			local s_Havok = json.decode(self.m_PhysicsAssets[s_PhysicsName])


			local s_Index = 1
			local s_ToSpawn = {}
			for k,s_MemberData in pairs(s_Instance.memberDatas) do
				for i = 1, s_MemberData.instanceCount, 1 do

					local s_Transform = nil
					local s_Scale = 1
					if(s_MemberData.instanceScale:get(i) ~= nil) then
						-- Comment this to always have the scale at 1
						--s_Scale = s_Original.memberDatas:get(k).instanceScale:get(i)
					end

					if(s_MemberData.instanceTransforms:get(i) == nil) then
						s_Transform = QuatToLineartransform(StringToVec4(s_Havok[s_Index].Rotation), StringToVec3(s_Havok[s_Index].Position), s_Scale)
					else
						s_Transform = s_Original.memberDatas:get(k).instanceTransforms:get(i)
					end

					table.insert(s_ToSpawn, {
						mesh = s_MemberData.memberType,
						transform = s_Transform,
						variation = s_MemberData.instanceObjectVariation:get(i)
						})
					s_Index = s_Index + 1
				end
			end
			s_Instance.memberDatas:clear()
			self:PatchLevel(s_PhysicsName, s_ToSpawn)
		end
	end

	for k,v in pairs(s_Originals) do
		p_Partition:ReplaceInstance(s_Originals[k], s_Clones[k], true)
	end
end

function NoHavokCommon:ResolveBlueprint(p_InstanceGuid, p_IncreasedGuid)
	local s_Guid = p_InstanceGuid
	if(p_IncreasedGuid == true) then
		s_Guid = IncreasedGuid(p_InstanceGuid)
	end
	if(self.m_Unresolved[s_Guid] ~= nil) then
		for l_WorldPartName, l_Entry in pairs(self.m_Unresolved[s_Guid]) do
			if(self.m_WorldPartReferences[l_WorldPartName] == nil) then
				print("Failed to get worldpart: " .. l_WorldPartName)
				return
			end
			local s_WorldPartReference = self.m_WorldPartReferences[l_WorldPartName]
			local s_WorldPart = WorldPartData(s_WorldPartReference.blueprint);

			for _, l_Index in pairs(self.m_Unresolved[s_Guid][l_WorldPartName]) do
				local s_Reference = ReferenceObjectData(s_WorldPart.objects:get(l_Index))
				local s_Blueprint = self:GetBlueprintFromInstance(p_InstanceGuid)
				if(s_Blueprint == nil) then
					print("Failed to fetch blueprint: " .. p_InstanceGuid .. " | " .. s_Guid)
				end
				s_Blueprint = Blueprint(s_Blueprint)
				s_Reference.blueprint = Blueprint(s_Blueprint)
				print("Replaced blueprint: " .. s_Blueprint.name)
			end
			self.m_Unresolved[s_Guid][l_WorldPartName] = nil
		end
		self.m_Unresolved[s_Guid] = nil
	else
		print("Attempted to update an instance that's already resolved?")
	end
end

function NoHavokCommon:ResolveVariation(p_Variation)
	print("Resolving variation: " .. p_Variation)

	if(self.m_UnresolvedVariation[p_Variation] ~= nil) then
		for l_WorldPartName, l_Entry in pairs(self.m_UnresolvedVariation[p_Variation]) do
			if(self.m_WorldPartReferences[l_WorldPartName] == nil) then
				print("Failed to get worldpart: " .. l_WorldPartName)
				return
			end
			local s_WorldPartReference = self.m_WorldPartReferences[l_WorldPartName]
			local s_WorldPart = WorldPartData(s_WorldPartReference.blueprint);

			for _, l_Index in pairs(self.m_UnresolvedVariation[p_Variation][l_WorldPartName]) do
				local s_Reference = ReferenceObjectData(s_WorldPart.objects:get(l_Index))
				local s_Variation = self.m_Variations[p_Variation]
				s_Reference.objectVariation = s_Variation
			end
			self.m_UnresolvedVariation[p_Variation][l_WorldPartName] = nil
		end
		self.m_UnresolvedVariation[p_Variation] = nil
	else
		print("Attempted to update an instance that's already resolved?")
	end
end

function NoHavokCommon:GetBlueprintFromInstance( p_Guid )
	if self.m_Primary[p_Guid] ~= nil then
		return ResourceManager:LookupDataContainer(ResourceCompartment.ResourceCompartment_Game,self.m_Primary[p_Guid])
	end
end

function NoHavokCommon:CreateData(p_Name, p_ToSpawn)

 
    -- Create our world part data.
    local worldPart = WorldPartData()
    worldPart.name = p_Name .. "_WorldData"
    worldPart.enabled = true

 	for k,v in ipairs(p_ToSpawn) do
	    -- Create our reference object data.
		local s_Blueprint = self:GetBlueprintFromInstance(tostring(v.mesh.instanceGuid))
		if(s_Blueprint == nil) then
			local s_Guid = tostring(v.mesh.instanceGuid)

			if(self.m_Unresolved[s_Guid] == nil) then
				self.m_Unresolved[s_Guid] = {}
			end
			if(self.m_Unresolved[s_Guid][p_Name] == nil) then
				self.m_Unresolved[s_Guid][p_Name] = {}
			end
			table.insert(self.m_Unresolved[s_Guid][p_Name], k)
		else
			s_Blueprint = Blueprint(s_Blueprint)
		end

	    local s_Variation = nil
	    if(v.variation ~= nil and v.variation ~= 0) then
			if self.m_Variations[v.variation] == nil then
				if(self.m_UnresolvedVariation[v.variation] == nil) then
					self.m_UnresolvedVariation[v.variation] = {}
				end
				if(self.m_UnresolvedVariation[v.variation][p_Name] == nil) then
					self.m_UnresolvedVariation[v.variation][p_Name] = {}
				end
				table.insert(self.m_UnresolvedVariation[v.variation][p_Name], k)

			else
				s_Variation = self.m_Variations[v.variation]
			end
	    end

		local referenceObject = ReferenceObjectData()
		referenceObject.isEventConnectionTarget = 3
		referenceObject.isPropertyConnectionTarget = 3
		referenceObject.indexInBlueprint = -1
		referenceObject.blueprintTransform = v.transform
		--referenceObject.blueprint = s_Blueprint
		--referenceObject.objectVariation = s_Variation
		referenceObject.streamRealm = StreamRealm.StreamRealm_None
		referenceObject.castSunShadowEnable = true
		referenceObject.excluded = false
		if(s_Blueprint == nil or s_Variation == nil ) then
			referenceObject.excluded = false
		end
		worldPart.objects:add(referenceObject)

	    ::continue::
	end

	-- Create our world part reference object data.
	local worldPartReference = WorldPartReferenceObjectData()
	worldPartReference.isEventConnectionTarget = 3
	worldPartReference.isPropertyConnectionTarget = 3
	worldPartReference.indexInBlueprint = -1
	worldPartReference.blueprintTransform = LinearTransform()
	worldPartReference.blueprint = worldPart
	worldPartReference.streamRealm = StreamRealm.StreamRealm_None
	worldPartReference.castSunShadowEnable = true
	worldPartReference.excluded = false

	return worldPartReference
end

function NoHavokCommon:PatchLevel(p_Name, p_ToSpawn)
    print('Patching level with custom spawn data.')
 
    -- Create our data if it doesn't exist.
    local s_WorldPartReference = self:CreateData(p_Name, p_ToSpawn)
	self.m_WorldPartReferences[p_Name] = s_WorldPartReference
 
    -- Calculate the highest blueprint index.
    -- This is just to do things "properly". You can probably
    -- get away with just using a very high number.
    if(self.m_HighestIndex == 0) then
	    self.m_HighestIndex = self:CalculateIndexInBlueprint(self.m_LevelData) + 1
	end
    print('Highest blueprint index: ' .. tostring(self.m_HighestIndex))
 
    -- Patch our data.
    --s_WorldPartReference.indexInBlueprint = self.m_HighestIndex
    local s_WorldPart = WorldPartData(s_WorldPartReference.blueprint)

    self.m_Registry.referenceObjectRegistry:add(s_WorldPartReference)
    self.m_Registry.blueprintRegistry:add(s_WorldPart)

	self:PatchRegistry(self.m_Registry, s_WorldPart)
    print(#s_WorldPart.objects)
    

    print(self.m_HighestIndex)
 
    -- Add necessary instance to the registry.
    
 
    -- Add WPROD to the level.
    self.m_LevelData.objects:add(s_WorldPartReference)
 
    print('Finished patching level!')
    self.m_LevelData = s_WorldPart
end

function NoHavokCommon:PatchRegistry(p_Registry, p_WorldPart)

	local s_BlueprintRegistryInstances = {}
	local s_ReferenceObjectRegistry = {}

	for k,v in pairs(p_Registry.blueprintRegistry) do
		s_BlueprintRegistryInstances[tostring(v.instanceGuid)] = true
	end
	for k,v in pairs(p_Registry.referenceObjectRegistry) do
		s_ReferenceObjectRegistry[tostring(v.instanceGuid)] = true
	end

	for k,v in pairs(p_WorldPart.objects) do
		local s_Ref = ReferenceObjectData(v)
		if(s_Ref.blueprint ~= nil) then
			if(s_BlueprintRegistryInstances[tostring(v.instanceGuid)] == nil) then
				self.m_Registry.blueprintRegistry:add(Blueprint(s_Ref.blueprint))
				print("Added blueprint to BP registry")
			end
			if(s_ReferenceObjectRegistry[tostring(v.instanceGuid)] == nil) then
				self.m_Registry.referenceObjectRegistry:add(s_Ref)
				print("Added Ref to REF registry")
			end

		end
		--s_Ref.indexInBlueprint = k
	end
end

function NoHavokCommon:CalculateIndexInBlueprint(data)
    local finalIndex = 0
 
    for _, object in pairs(data.objects) do
        if object.typeInfo == WorldPartReferenceObjectData.typeInfo then
            local referenceObjectData = WorldPartReferenceObjectData(object)
           
            if referenceObjectData.blueprint ~= nil then
                local index = self:GetWPDHighestIndex(referenceObjectData.blueprint)
       
                if index > finalIndex then
                    finalIndex = index
                end
            else
                print('Encountered WPROD with null blueprint: ' .. referenceObjectData.name)
            end
        else
            print('Encountered unknown object in data: ' .. object.typeInfo.name)
        end
    end

    return finalIndex
end

function NoHavokCommon:GetWPDHighestIndex(object)
    if object.isLazyLoaded then
        return 0
    end
 
    local data = PrefabBlueprint(object)
    local highestIndex = 0
 
    for _, object in pairs(data.objects) do
        if object:Is('GameObjectData') then
            local gameObject = GameObjectData(object)
 
            if gameObject.indexInBlueprint > highestIndex then
                highestIndex = gameObject.indexInBlueprint
            end
        else
            print('Found unknown object in prefab: ' .. object.typeInfo.name)
        end
    end
 
    return highestIndex
end

return NoHavokCommon
