class 'NoHavokServer'

NoHavokCommon = NoHavokCommon(Realm.Realm_Server)

function NoHavokServer:__init()
    print("Initializing NoHavokServer")
    self:RegisterVars()
    self:RegisterEvents()
end


function NoHavokServer:RegisterVars()
    self.m_StaticModelGroups = {}
    self.m_PhysicsAssets = {}
end


function NoHavokServer:RegisterEvents()
    self.m_PartitionLoadedEvent = Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
    self.m_PlayerJoinedEvent = Events:Subscribe('Player:Authenticated', self, self.OnPlayerAuthenticated)
    Events:Subscribe('Level:Destroy', self, self.OnLevelDestroy)
    Events:Subscribe('Server:LevelLoaded', self, self.OnLevelLoaded)
end

function NoHavokServer:OnLevelDestroy()
    self:RegisterVars()
    NoHavokCommon:RegisterVars()
end
function NoHavokServer:OnLevelLoaded()
    print(NoHavokCommon:GetUnresolved())
    print(NoHavokCommon:GetUnresolvedVariations())
end

function NoHavokServer:OnPlayerAuthenticated(p_Player)
    for k,v in pairs(self.m_PhysicsAssets) do
        NetEvents:SendTo("NoHavok:PhysicsDataLoaded", p_Player, k, v)
    end
end

function NoHavokServer:OnPartitionLoaded(p_Partition)
    if p_Partition == nil then
        return
    end

    local s_Instances = p_Partition.instances
    for _, l_Instance in ipairs(s_Instances) do
        if l_Instance == nil then
            print('Instance is null?')
            break
        end

        if(l_Instance.typeInfo.name == "StaticModelGroupEntityData") then
            local s_Instance = StaticModelGroupEntityData(l_Instance)
            local s_PhysicsName = GroupHavokAsset(PhysicsEntityData(s_Instance.physicsData).asset).name

            local s_AssetName = "havok/" .. s_PhysicsName
            local s_HavokData = require (s_AssetName)
            self.m_PhysicsAssets[s_PhysicsName] = s_HavokData
            NoHavokCommon:RegisterStaticModelGroupAsset(s_PhysicsName, s_HavokData)
        end
    end
    NoHavokCommon:OnPartitionLoaded(p_Partition)
end



g_NoHavokServer = NoHavokServer()