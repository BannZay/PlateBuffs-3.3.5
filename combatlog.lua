--[[
	Here I do the combatlog stuff. 
	
	Todo: 
		SPELL_AURA_REMOVED_DOSE
		SPELL_DISPEL
		SPELL_STOLEN
]]
local folder, core = ...

local nametoGUIDs = core.nametoGUIDs
local P
local playerGUID
local Debug = core.Debug
local guidBuffs = core.guidBuffs
--~ local _ --underscore so GetGlobals doesn't nag me.

local LibAI = LibStub("LibAuraInfo-1.0", true)
if not LibAI then	error(folder .. " requires LibAuraInfo-1.0.") return end

do
	local UnitGUID = UnitGUID
	local prev_OnEnable = core.OnEnable
	function core:OnEnable()
		prev_OnEnable(self)
		P = self.db.profile
		playerGUID = UnitGUID("player")
		core:RegisterLibAuraInfo()
	end
end

do
	local CombatLogClearEntries = CombatLogClearEntries
	function core:RegisterLibAuraInfo()
		LibAI.UnregisterAllCallbacks(self) 
		if P.watchCombatlog == true then
	--~ 		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			LibAI.RegisterCallback(self, "LibAuraInfo_AURA_APPLIED")
			LibAI.RegisterCallback(self, "LibAuraInfo_AURA_REMOVED")
			LibAI.RegisterCallback(self, "LibAuraInfo_AURA_REFRESH")
			LibAI.RegisterCallback(self, "LibAuraInfo_AURA_APPLIED_DOSE")
			LibAI.RegisterCallback(self, "LibAuraInfo_AURA_CLEAR")
			
			CombatLogClearEntries()
		end
	end
end

local prev_OnDisable = core.OnDisable
function core:OnDisable(...)
	if prev_OnDisable then prev_OnDisable(self, ...) end
	
	LibAI.UnregisterAllCallbacks(self) 
end

do
	local bit_band = bit.band
	local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
	function core:FlagIsPlayer(flags)
		if bit_band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER then
			return true
		end
		return nil
	end
end

do
	local bit_band = bit.band
	local COMBATLOG_OBJECT_REACTION_FRIENDLY = COMBATLOG_OBJECT_REACTION_FRIENDLY
	function core:FlagIsFriendly(flags)
		if bit_band(flags, COMBATLOG_OBJECT_REACTION_FRIENDLY) == COMBATLOG_OBJECT_REACTION_FRIENDLY then
			return true
		end
		return nil
	end
end

do
	local bit_band = bit.band
	local COMBATLOG_OBJECT_REACTION_HOSTILE = COMBATLOG_OBJECT_REACTION_HOSTILE
	local COMBATLOG_OBJECT_REACTION_NEUTRAL = COMBATLOG_OBJECT_REACTION_NEUTRAL
	function core:FlagIsHostle(flags)
		if bit_band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE) == COMBATLOG_OBJECT_REACTION_HOSTILE then
			return true
		end
		return nil
	end
end



--[[]]
do
	local dstName, dstFlags, shortName
	function core:ForceNameplateUpdate(dstGUID)
		if not self:UpdatePlateByGUID(dstGUID) then
			--We can't find a nameplate that matches that GUID.
			--Lets check if the GUID is a player, if so find a nameplate that matches the player's name.
	
			dstName, dstFlags = LibAI:GetGUIDInfo(dstGUID)
			if dstFlags and self:FlagIsPlayer(dstFlags) then
				shortName = self:RemoveServerName(dstName) --Nameplates don't have server names.
				nametoGUIDs[shortName] = dstGUID
				self:UpdatePlateByName(shortName)
			end
		end
	end
end

do
	local GetTime = GetTime
	local dstName, dstFlags, getTime, count, i
	local table_insert = table.insert
	
	function core:AddSpellToGUID(dstGUID, spellID, srcName, spellName, spellTexture, duration, srcGUID, isDebuff, debuffType, expires, stackCount)
		guidBuffs[dstGUID] = guidBuffs[dstGUID] or {}
		if #guidBuffs[dstGUID] > 0 then
			self:RemoveOldSpells(dstGUID)
		end
		
	--~ 	if spellName == "Lacerate" then
	--~ 		Debug("AddSpellToGUID", spellName, count)
	--~ 	end
		dstName, dstFlags = LibAI:GetGUIDInfo(dstGUID)
	--~ 	if stackCount > 0 then
	--~ 		Debug("AddSpellToGUID", dstName, spellName, stackCount)
	--~ 	end
		
		
		getTime = GetTime()
		count = #guidBuffs[dstGUID]
		if count == 0 then
			i = 0
			table_insert(guidBuffs[dstGUID], i+1, {
				name		= spellName,
				icon		= spellTexture,
				duration	= (duration or 0),
				playerCast	= srcGUID == playerGUID and 1,
				stackCount	= stackCount or 0,
				startTime	= getTime,
				expirationTime = expires or 0 - 0.1,
				sID = spellID,
				caster = srcName,
			})
			
			if isDebuff then
				guidBuffs[dstGUID][i+1].isDebuff = true
				guidBuffs[dstGUID][i+1].debuffType = debuffType or "none"
			end
			
	--~ 		local dstName, dstFlags = LibAI:GetGUIDInfo(dstGUID)
	--~ 		Debug("AddSpellToGUID 1", spellName, dstName)
			return true
		
		else
			for i=1, count do 
				if guidBuffs[dstGUID][i].sID == spellID and (not guidBuffs[dstGUID][i].caster or guidBuffs[dstGUID][i].caster == srcName) then
					--I know 2 of the same buff can be on someone, but how do I confirm that?
					-- unitCaster returns a unitID and combatlog has names. =/
					
					guidBuffs[dstGUID][i].expirationTime = expires or 0 - 0.1
					guidBuffs[dstGUID][i].startTime = getTime
					
					
	--~ 				Debug("AddSpellToGUID", spellName.." already on "..dstName)
					return true
				elseif i == count then
					table_insert(guidBuffs[dstGUID], i+1, {
						name		= spellName,
						icon		= spellTexture,
						duration	= (duration or 0),
						playerCast	= srcGUID == playerGUID and 1,
						stackCount	= stackCount or 0,
						startTime	= getTime,
						expirationTime = expires or 0 - 0.1,
						sID = spellID,
						caster = srcName,
					})
					
					if isDebuff then
						guidBuffs[dstGUID][i+1].isDebuff = true
						guidBuffs[dstGUID][i+1].debuffType = debuffType or "none"
					end
					
	--~ 				local dstName, dstFlags = LibAI:GetGUIDInfo(dstGUID)
	--~ 				Debug("AddSpellToGUID 2", spellName, dstName)
					return true
				end
			end
		end
		return false
	end
end

local function CheckFilter(tip, spelllist)
	
	if tip == "BUFF" then		
		if spelllist and P.defaultBuffShow == 4 then return false end
		return true
	elseif tip == "DEBUFF" then
		if spelllist and P.defaultDebuffShow == 4 then return false end		
		return true
	end	
	return nil
end

do
	local found, stackCount, debuffType, duration, expires, isDebuff, casterGUID, spellName, _, spellTexture, dstName, dstFlags, updateBars, srcName, srcFlags
	local GetSpellInfo = GetSpellInfo
	function core:LibAuraInfo_AURA_APPLIED(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
		found, stackCount, debuffType, duration, expires, isDebuff, casterGUID = LibAI:GUIDAuraID(dstGUID, spellID)
		
		spellName, _, spellTexture = GetSpellInfo(spellID)
		dstName, dstFlags = LibAI:GetGUIDInfo(dstGUID)
		
	
		
	--~ 	if not found then
	--~ 		Debug("LibAuraInfo_AURA_APPLIED", found, dstName, spellName, expires and expires - GetTime())
	--~ 	end
		
		
		if found then
--~ 			spellTexture = spellTexture:gsub("Interface\\Icons\\", "")
			spellTexture = spellTexture:upper():gsub("INTERFACE\\ICONS\\", "")
			
			if spellTexture:find("\\") then
				Debug("spellTexture", spellTexture)
			end
			
	--~ 		Debug("LibAuraInfo_AURA_APPLIED 1", dstGUID, spellName, spellID, "+", count, debuffType, duration, expires, isDebuff)
	
			updateBars = false
			
			local spellOpts = core:HaveSpellOpts(spellName, spellID)
			
			if spellOpts and spellOpts.show and CheckFilter(auraType, true) then
				if P.spellOpts[spellName].show == 1 
				or (P.spellOpts[spellName].show == 2 and srcGUID == playerGUID) 
				or (P.spellOpts[spellName].show == 4 and core:FlagIsFriendly(dstFlags)) --fix this
				or (P.spellOpts[spellName].show == 5 and core:FlagIsHostle(dstFlags)) --fix this
				then --fix this

					srcName, srcFlags = LibAI:GetGUIDInfo(srcGUID)
					updateBars = self:AddSpellToGUID(dstGUID, spellID, srcName, spellName, spellTexture, duration, srcGUID, isDebuff, debuffType, expires, stackCount)
				end
			else
				if auraType == "BUFF" and P.defaultBuffShow == 1 or ( (P.defaultBuffShow == 2 and srcGUID == playerGUID) or (P.defaultBuffShow == 4 and srcGUID == playerGUID) )
				or auraType == "DEBUFF" and P.defaultDebuffShow == 1 or ( (P.defaultDebuffShow == 2 and srcGUID == playerGUID)  or (P.defaultDebuffShow == 4 and srcGUID == playerGUID) ) then
					srcName, srcFlags = LibAI:GetGUIDInfo(srcGUID)
					updateBars = self:AddSpellToGUID(dstGUID, spellID, srcName, spellName, spellTexture, duration, srcGUID, isDebuff, debuffType, expires, stackCount)
				end
			end
	
			if updateBars then
				core:ForceNameplateUpdate(dstGUID)
			end
	
		end
		
	end
end

do
	local table_remove = table.remove
	local srcName, srcFlags
	function core:LibAuraInfo_AURA_REMOVED(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
	--~ 	Debug("LibAuraInfo_AURA_REMOVED 1", GetSpellInfo(spellID))
		if guidBuffs[dstGUID] then
	--~ 		Debug("LibAuraInfo_AURA_REMOVED 2", GetSpellInfo(spellID))
			srcName, srcFlags = LibAI:GetGUIDInfo(srcGUID)
			for i = #guidBuffs[dstGUID], 1, -1 do 
	--~ 			Debug("LibAuraInfo_AURA_REMOVED 3", GetSpellInfo(spellID))
				if guidBuffs[dstGUID][i].sID == spellID and (not guidBuffs[dstGUID][i].caster or guidBuffs[dstGUID][i].caster == srcName) then
					table_remove(guidBuffs[dstGUID], i)
					
					--Remove the spell from nameplates on screen.
					self:ForceNameplateUpdate(dstGUID)
	--~ 				Debug("LibAuraInfo_AURA_REMOVED 4", GetSpellInfo(spellID))
					
					return
				end
			end
		end
		
	end
end
	
do
	local spellName, srcName, srcFlags, getTime, dstName
	local GetTime = GetTime
	local GetSpellInfo = GetSpellInfo
	function core:LibAuraInfo_AURA_REFRESH(event, dstGUID, spellID, srcGUID, spellSchool, auraType, expirationTime)
		spellName = GetSpellInfo(spellID)
		
	--~ 	if srcGUID == playerGUID then
	--~ 		local _, count = LibAI:GUIDAuraID(dstGUID, spellID)
	--~ 		
	--~ 		Debug("AURA_REFRESH", spellName, count)
	--~ 	end
		
		
		if guidBuffs[dstGUID] then
			srcName, srcFlags = LibAI:GetGUIDInfo(srcGUID)
			for i = #guidBuffs[dstGUID], 1, -1 do 
				if guidBuffs[dstGUID][i].sID == spellID and (not guidBuffs[dstGUID][i].caster or guidBuffs[dstGUID][i].caster == srcName) then
					getTime = GetTime()
					guidBuffs[dstGUID][i].startTime = getTime
					guidBuffs[dstGUID][i].expirationTime = expirationTime
					
					self:ForceNameplateUpdate(dstGUID)
					return
				end
			end
		end
	
		
		dstName = LibAI:GetGUIDInfo(dstGUID)
		if not LibAI:GUIDAuraID(dstGUID, spellID) then
			Debug("SPELL_AURA_REFRESH",LibAI:GUIDAuraID(dstGUID, spellID), dstName, spellName, "passing to SPELL_AURA_APPLIED")
		end
		self:LibAuraInfo_AURA_APPLIED(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
	end
end

do
	local spellName, srcName, srcFlags, dstName
	local GetSpellInfo = GetSpellInfo
	local GetTime = GetTime
	--DOSE = spell stacking
	function core:LibAuraInfo_AURA_APPLIED_DOSE(event, dstGUID, spellID, srcGUID, spellSchool, auraType, stackCount, expirationTime)
		spellName = GetSpellInfo(spellID)
	--~ 	local _, stackCount1 = LibAI:GUIDAuraID(dstGUID, spellID)
	--~ 	if srcGUID == playerGUID then
	--~ 		
	--~ 		Debug("AURA_APPLIED_DOSE", spellName, count, stackCount)
	--~ 	end
		
		if guidBuffs[dstGUID] then
			srcName, srcFlags = LibAI:GetGUIDInfo(srcGUID)
			for i = #guidBuffs[dstGUID], 1, -1 do 
				if guidBuffs[dstGUID][i].sID == spellID and (not guidBuffs[dstGUID][i].caster or guidBuffs[dstGUID][i].caster == srcName) then
					guidBuffs[dstGUID][i].stackCount = stackCount
				
					guidBuffs[dstGUID][i].startTime = GetTime()
					guidBuffs[dstGUID][i].expirationTime = expirationTime
				
	--~ 				if srcGUID == playerGUID then
	--~ 					Debug("AURA_APPLIED_DOSE 2", spellName, stackCount1, stackCount)
	--~ 				end
					
					self:ForceNameplateUpdate(dstGUID)
					return
				end
			end
		end
		
		
		dstName = LibAI:GetGUIDInfo(dstGUID)
		if not LibAI:GUIDAuraID(dstGUID, spellID) then
			Debug("LAURA_APPLIED_DOSE", dstName, spellName, "passing to SPELL_AURA_APPLIED")
		end
		self:LibAuraInfo_AURA_APPLIED(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
	end
end
	
do
	local table_getn = table.getn
	local table_remove = table.remove
	function core:LibAuraInfo_AURA_CLEAR(event, dstGUID)
		if guidBuffs[dstGUID] then
			--Remove all known buffs for that person. Maybe we're in a BG and don't need their old buffs on our plates.
			for i=table_getn(guidBuffs[dstGUID]), 1, -1 do 
				table_remove(guidBuffs[dstGUID], i)
			end
			self:ForceNameplateUpdate(dstGUID)
		end
	end
end