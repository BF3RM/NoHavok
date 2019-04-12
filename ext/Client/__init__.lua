class 'NoHavokClient'

NoHavokCommon = NoHavokCommon(Realm.Realm_Client)

function NoHavokClient:__init()
    print("Initializing NoHavokClient")
    self:RegisterVars()
    self:RegisterEvents()
end


function NoHavokClient:RegisterVars()
end


function NoHavokClient:RegisterEvents()
    self.m_PartitionLoadedEvent = Events:Subscribe('Partition:Loaded', self, self.OnPartitionLoaded)
    self.m_PhysicsDataLoadedEvent = Events:Subscribe('NoHavok:PhysicsDataLoaded', self, self.onPhysicsDataLoaded)
end

function NoHavokClient:onPhysicsDataLoaded(p_AssetName, p_Data)
    NoHavokCommon:RegisterStaticModelGroupAsset(p_AssetName, p_Data)
end

function NoHavokClient:OnPartitionLoaded(p_Partition)
    NoHavokCommon:OnPartitionLoaded(p_Partition)
end



g_NoHavokClient = NoHavokClient()