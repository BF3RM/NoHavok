local TIMEOUT = 50

local clientSettingsGuids = {
	partitionGuid = Guid('C4DCACFF-ED8F-BC87-F647-0BC8ACE0D9B4'),
	instanceGuid = Guid('B479A8FA-67FF-8825-9421-B31DE95B551A'),
}

local serverSettingsGuids = {
	partitionGuid = Guid('C4DCACFF-ED8F-BC87-F647-0BC8ACE0D9B4'),
	instanceGuid = Guid('818334B3-CEA6-FC3F-B524-4A0FED28CA35'),
}

ResourceManager:RegisterInstanceLoadHandler(clientSettingsGuids.partitionGuid, clientSettingsGuids.instanceGuid, function(instance)
	instance = ClientSettings(instance)
	instance:MakeWritable()
	instance.loadedTimeout = TIMEOUT
	instance.loadingTimeout = TIMEOUT
	instance.ingameTimeout = TIMEOUT
	print("Changed ClientSettings")
end)

ResourceManager:RegisterInstanceLoadHandler(serverSettingsGuids.partitionGuid, serverSettingsGuids.instanceGuid, function(instance)
	instance = ServerSettings(instance)
	instance:MakeWritable()
	instance.loadingTimeout = TIMEOUT
	instance.ingameTimeout = TIMEOUT
	instance.timeoutTime = TIMEOUT
	print("Changed ServerSettings")
end)
