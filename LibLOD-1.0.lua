--[[
THIS IS ONLY A PoC. It's ugly, deal with it.

does NOT play nice with Gemini:Addon and modules!

	Gemini:Addon expects all modules to be there when calling OnLoad (which starts initializequeue and enablequeue for the addon and modules)
	workaround: call addon:OnLoad(), addon:Disable(), addon:Enable() on the addon you are injecting




required toc.xml structure:

<?xml version="1.0" encoding="UTF-8"?>
<Addon Author="Some Author" APIVersion="9" Name="Some Name" Description="Some Description">
	<Script Name="SomeLoadOnStartScript.lua"/>
	<LoadOnDemandSet name="someSetName1">
		<Meta key="someKey1" value="someValue1" />
		<Meta key="someKey2" value="someValue2" />
	    <Script Name="SomeLoadOnStartScript1.lua"/>
		...
	    <Script Name="SomeLoadOnStartScriptN.lua"/>
	</LoadOnDemandSet>
	...
	<LoadOnDemandSet name="someSetNameN">
	...
	</LoadOnDemandSet>
</Addon>

tSetList:

{
[AddonName] = {
	[SetName] = {
		metadata = {
			[keyName1] = value1,
			...
			[keyNameN] = valueN,
		}
		scripts = {
			"fileName1",
			...
			"fileNameN",
		}
	}
}


tSetListFlat:

{
[AddonName_SetName] = {
	metadata = {
		[keyName1] = value1,
		...
		[keyNameN] = valueN,
	}
	scripts = {
		"fileName1",
		...
		"fileNameN",
	}
}

--]]

local MAJOR, MINOR = "LibLOD-1.0", 1
-- Get a reference to the package information if any
local APkg = Apollo.GetPackage(MAJOR)
-- If there was an older version loaded we need to see if this is newer
if APkg and (APkg.nVersion or 0) >= MINOR then
    return -- no upgrade needed
end
-- Set a reference to the actual package or create an empty table
local Lib = APkg and APkg.tPackage or {}

-------------------------------------------------------------------------------
--- Upvalues
-------------------------------------------------------------------------------
local strmatch, next = string.match, next
local Apollo, XmlDoc = Apollo, XmlDoc

-------------------------------------------------------------------------------
--- Local Variables
-------------------------------------------------------------------------------

local tSetList = {}
local tSetListFlat = {}

local tLibError = Apollo.GetPackage("Gemini:LibError-1.0")
local fnErrorHandler = tLibError and tLibError.tPackage and tLibError.tPackage.Error or Print

-------------------------------------------------------------------------------
--- Local Functions
-------------------------------------------------------------------------------

local function buildSetList()
	-- addon folder & toc grabbing stolen from LibApolloFixes
	local strWildstarDir = strmatch(Apollo.GetAssetFolder(), "(.-)[\\/][Aa][Dd][Dd][Oo][Nn][Ss]")
	local tAddonXML = XmlDoc.CreateFromFile(strWildstarDir.."\\Addons.xml"):ToTable()
	for _,v in next, tAddonXML do
		if v.__XmlNode == "Addon" then
			if v.Carbine ~= "1" then
				local xmlTOC = XmlDoc.CreateFromFile(strWildstarDir.."\\Addons\\"..v.Folder.."\\toc.xml")
				if xmlTOC then
					local tTocTable = xmlTOC:ToTable()
					local addonName = tTocTable.Name
					for i = 1, #tTocTable do -- child nodes have numeric keys
						local set = tTocTable[i]
						if set.__XmlNode == 'LoadOnDemandSet' then
							if not tSetList[addonName] then	tSetList[addonName] = {} end
							tSetList[addonName][set.name] = { meta = {}, scripts = {} } -- we assume each set in an addon has a unique name
							for j = 1, #set do
								local child = set[j]
								if child.__XmlNode == 'Meta' then
									tSetList[addonName][set.name].meta[child.key] = child.value
								elseif child.__XmlNode == 'Script' then
									tSetList[addonName][set.name].scripts[#tSetList[addonName][set.name].scripts + 1] = strWildstarDir.."\\Addons\\"..v.Folder.."\\"..child.Name
								end
							end
						end
					end
				end
			end
		end
	end
	
	for addonName, sets in next, tSetList do
		for setName, setData in next, sets do
			tSetListFlat[addonName .. "_" .. setName] = setData
		end
	end
	
	buildSetList = nil
end

function Lib:GetSets(strAddon, bFlat)
	if buildSetList then buildSetList() end
	
	if strAddon then
		return tSetList[strAddon]
	else 
		return bFlat and tSetListFlat or tSetList
	end
end

function Lib:GetSetMetadataFlat(strSet, strMetaKey)
	if not strSet then return end
	if buildSetList then buildSetList() end
	
	if not tSetListFlat[strSet] then return end
	
	if strMetaKey then
		return tSetListFlat[strSet].meta[strMetaKey]
	else
		return tSetListFlat[strSet].meta
	end
end

function Lib:GetSetMetadata(strAddon, strSet, strMetaKey)
	if not strAddon or not strSet then return end
	
	return self:GetSetMetadataFlat(strAddon .. "_" .. strSet, strMetaKey)
end

function Lib:LoadSetFlat(strSet)
	if not strSet then return end
	if buildSetList then buildSetList() end
	
	local tSet = tSetListFlat[strSet]
	if not tSet or tSet.isLoaded then return end
	
	for _, v in next, tSet.scripts do
		local func = assert(loadfile(v))
		if func then xpcall(func, fnErrorHandler) end
	end
	
	tSet.isLoaded = true
	return true
end

function Lib:LoadSet(strAddon, strSet)
	if not strAddon or not strSet then return end
	
	return self:LoadSetFlat(strAddon .. "_" .. strSet)
end

function Lib:IsSetLoadedFlat(strSet)
	return tSetListFlat[strSet] and tSetListFlat[strSet].isLoaded or false
end

function Lib:IsSetLoaded(strAddon, strSet)
	if not strAddon or not strSet then return end
	return self:IsSetLoadedFlat(strAddon .. "_" .. strSet)
end

Apollo.RegisterPackage(Lib, MAJOR, MINOR, {})
