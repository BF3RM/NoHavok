class 'nohavokShared'



function nohavokShared:__init()
	print("Initializing nohavokShared")
	self:RegisterVars()
	self:RegisterEvents()
end


function nohavokShared:RegisterVars()
	self.m_ToSpawn = {}
	self.m_Index = 2700
end


function nohavokShared:RegisterEvents()
	self.m_PartitionLoadedEvent = Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
   	Events:Subscribe('Engine:Message', self, self.OnEngineMessage)
	self.m_ClientUpdateInputEvent = Events:Subscribe('Client:UpdateInput', self, self.OnUpdateInput)
end

function nohavokShared:OnUpdateInput(p_Delta)
	if InputManager:WentKeyDown(InputDeviceKeys.IDK_C) then

		print(self.m_Index)
		local v = self.m_ToSpawn[self.m_Index]

		print(v.transform)
		local params = EntityCreationParams()
		params.transform = v.transform
		params.variationNameHash = v.variation
		params.networked = false

		if(v.variation == nil) then
			params.variationNameHash = 0
		end

		local s_Entity = EntityManager:CreateEntity(v.mesh, params)
		if(s_Entity ~= nil) then
			s_Entity:Init(Realm.Realm_Client, true)
		else
			print("Failed to spawn object: " .. v.mesh.instanceGuid)
		end
		self.m_Index = self.m_Index + 1
	end
end
function nohavokShared:OnEngineMessage(p_Message)
	if p_Message.type == MessageType.ClientLevelFinalizedMessage then
		self:OnModify(Realm.Realm_Client)
	end
	if p_Message.type == MessageType.ServerLevelLoadedMessage then
		self:OnModify(Realm.Realm_ClientAndServer)
	end
end

function nohavokShared:OnModify(p_Realm)
	for k,v in pairs(self.m_ToSpawn) do

		local params = EntityCreationParams()
		params.transform = v.transform
		params.variationNameHash = v.variation
		params.networked = false

		if(v.variation == nil) then
			params.variationNameHash = 0
		end
		local s_Entity = EntityManager:CreateEntity(v.mesh, params)

		s_Entity:Init(p_Realm, true)
	end
end
function nohavokShared:StringToVec3(linearTransformString)
	local s_LinearTransformRaw = tostring(linearTransformString)
	local s_Split = s_LinearTransformRaw:gsub("%(", ""):gsub("%)", ""):gsub("% ", ","):split(",")
	local s_Vec = Vec3(tonumber(s_Split[1]), tonumber(s_Split[2]), tonumber(s_Split[3]))
	return s_Vec
end
function nohavokShared:StringToVec4(linearTransformString)
	local s_LinearTransformRaw = tostring(linearTransformString)
	local s_Split = s_LinearTransformRaw:gsub("%(", ""):gsub("%)", ""):gsub("% ", ","):split(",")

	local s_Vec = Vec4(tonumber(s_Split[1]), tonumber(s_Split[2]), tonumber(s_Split[3]), tonumber(s_Split[4]))

	return s_Vec
end

function nohavokShared:OnPartitionLoaded(p_Partition)
	if p_Partition == nil then
		return
	end
	
	local s_Instances = p_Partition.instances

	local s_Originals = {}
	local s_Clones = {}

	for _, l_Instance in ipairs(s_Instances) do
		if l_Instance == nil then
			print('Instance is null?')
			break
		end
		if(l_Instance.typeInfo.name == "StaticModelGroupEntityData") then
			local s_Original = StaticModelGroupEntityData(l_Instance)
			local s_Instance = StaticModelGroupEntityData(l_Instance:Clone(l_Instance.instanceGuid))
			table.insert(s_Originals, l_Instance)
			table.insert(s_Clones, s_Instance)

			local s_PhysicsName = GroupHavokAsset(PhysicsEntityData(s_Instance.physicsData).asset).name
			print(s_PhysicsName)
			local s_AssetName = "__shared/havok/" .. s_PhysicsName
			local s_HavokData = require (s_AssetName)
			s_Havok = json.decode(s_HavokData)

			local s_Index = 1
			for k,s_MemberData in pairs(s_Instance.memberDatas) do
				for i = 1, s_MemberData.instanceCount, 1 do

					local s_Transform = nil
					local s_Scale = 1
					if(s_MemberData.instanceScale:get(i) ~= nil) then
						-- Comment this to always have the scale at 1
						--s_Scale = s_Original.memberDatas:get(k).instanceScale:get(i)
					end

					if(s_MemberData.instanceTransforms:get(i) == nil) then
						s_Transform = QuatToLineartransform(self:StringToVec4(s_Havok[s_Index].Rotation), self:StringToVec3(s_Havok[s_Index].Position), s_Scale)
					else
						s_Transform = s_Original.memberDatas:get(k).instanceTransforms:get(i)
					end

					table.insert(self.m_ToSpawn, {
						mesh = s_MemberData.memberType,
						transform = s_Transform,
						variation = s_MemberData.instanceObjectVariation:get(i)
						})
					s_Index = s_Index + 1
				end
			end

			s_Instance.memberDatas:clear()
		end
	end

	for k,v in pairs(s_Originals) do
		p_Partition:ReplaceInstance(s_Originals[k], s_Clones[k], true)
	end
end

function QuatToLineartransform( quat, pos, scale )
	local res = LinearTransform()
	res.left = VecMultiply(quat, Vec3(scale,0,0))
	res.up = VecMultiply(quat, Vec3(0,scale,0))
	res.forward = VecMultiply(quat, Vec3(0,0,scale))

	
	-- TODO: Scale?!

	res.trans = pos

	return res

end

function VecMultiply(quat, vec)
	local num = quat.x * 2.0
	local num2 = quat.y * 2.0
	local num3 = quat.z * 2.0
	local num4 = quat.x * num
	local num5 = quat.y * num2
	local num6 = quat.z * num3
	local num7 = quat.x * num2
	local num8 = quat.x * num3
	local num9 = quat.y * num3
	local num10 = quat.w * num
	local num11 = quat.w * num2
	local num12 = quat.w * num3
	local result = Vec3()

	result.x = (1.0 - (num5 + num6)) * vec.x + (num7 - num12) * vec.y + (num8 + num11) * vec.z;
	result.y = (num7 + num12) * vec.x + (1.0 - (num4 + num6)) * vec.y + (num9 - num10) * vec.z;
	result.z = (num8 - num11) * vec.x + (num9 + num10) * vec.y + (1.0 - (num4 + num5)) * vec.z;
	return result;
 end


function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end


g_nohavokShared = nohavokShared()

