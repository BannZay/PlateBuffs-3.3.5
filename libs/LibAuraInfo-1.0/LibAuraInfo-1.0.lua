--[[
Name: LibAuraInfo-1.0
Author(s): Cyprias (cyprias@gmail.com)
Documentation: http://www.wowace.com/addons/libaurainfo-1-0/
SVN: svn://svn.wowace.com/wow/libaurainfo-1-0/mainline/trunk
Description: Database of spellID's duration and debuff type.
Dependencies: LibStub
License: GNU General Public License version 3 (GPLv3)
]]


local MAJOR, MINOR = "LibAuraInfo-1.0", 18
if not LibStub then error(MAJOR .. " requires LibStub.") return end

local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
if not lib.callbacks then	error(MAJOR .. " CallbackHandler-1.0.") return end

lib.confirmedDur = {}

lib.GUIDDurations = {}

local LAI_DB

local debugPrint
do
	local DEBUG = false
	--[===[@debug@
	DEBUG = true
	--@end-debug@]===]
	local print = print
	function debugPrint(...)
		if DEBUG then
			print(...)
		end
	end
	lib.debugPrint = debugPrint
end


--Save debuffType as a number, then return as a string when requested.
lib.debuffTypes = {
	Magic = 1,
	Disease = 2,
	Poison = 3,
	Curse = 4,
	Enrage = 5,
	Invisibility = 6,
	Stealth = 7,
}
for name, id in pairs(lib.debuffTypes) do 
	lib.debuffTypes[id] = name
end


lib.trackAuras = false
lib.callbacksUsed = {}

do
	local table_insert = table.insert
	--~ lib.callbacks:Fire("LibAuraInfo-1.0_xxxx", "blaw")
	function lib.callbacks:OnUsed(target, eventname)
	--~ 	debugPrint("OnUsed", target, eventname)
		
		lib.callbacksUsed[eventname] = lib.callbacksUsed[eventname] or {}
		table_insert(lib.callbacksUsed[eventname], #lib.callbacksUsed[eventname]+1, target)
		lib.trackAuras = true
		lib.frame:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
		
		lib.frame:RegisterEvent('UPDATE_MOUSEOVER_UNIT')
		lib.frame:RegisterEvent('PLAYER_TARGET_CHANGED')
		lib.frame:RegisterEvent('UNIT_TARGET')
		lib.frame:RegisterEvent('UNIT_AURA')
	--~ 	debugPrint("OnUsed", eventName)
	end
end

do
	local table_remove = table.remove
	local pairs = pairs
	function lib.callbacks:OnUnused(target, eventname)
	--~ 	debugPrint("OnUsed", target, eventname)
		if lib.callbacksUsed[eventname] then
			for i= #lib.callbacksUsed[eventname], 1, -1 do 
				if lib.callbacksUsed[eventname][i] == target then
					table_remove(lib.callbacksUsed[eventname], i)
				end
			end
		end
		
		for event, value in pairs(lib.callbacksUsed) do 
			if #value == 0 then
				lib.callbacksUsed[event] = nil
			end
		end
		
		for event in pairs(lib.callbacksUsed) do 
			return
		end
		lib.trackAuras = false
		lib.frame:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
		
		lib.frame:UnregisterEvent('UPDATE_MOUSEOVER_UNIT')
		lib.frame:UnregisterEvent('PLAYER_TARGET_CHANGED')
		lib.frame:UnregisterEvent('UNIT_TARGET')
		lib.frame:UnregisterEvent('UNIT_AURA')
	--~ 	debugPrint("OnUnused", eventName)
	end
end



local Round
do
	local math_floor = math.floor
	function Round(num, zeros)
		return math_floor( num * 10 ^ (zeros or 0) + 0.5 ) / 10 ^ (zeros or 0)
	end
end

local ResetUnitAuras
do
	local dstGUID
	local UnitGUID = UnitGUID
	function ResetUnitAuras(unitID)
		if lib.trackAuras  == true then
			dstGUID = UnitGUID(unitID)
			lib:RemoveAllAurasFromGUID(dstGUID)
		end
	end
end

do
	local GetTime = GetTime
	local table_insert = table.insert
	local currentTime
	function lib:AddAuraFromUnitID(dstGUID, spellID, srcGUID, isDebuff, debuffType, duration, expirationTime, stackCount)
		currentTime = GetTime()
		
		self.GUIDAuras[dstGUID] = self.GUIDAuras[dstGUID] or {}
		
		table_insert(self.GUIDAuras[dstGUID], #self.GUIDAuras[dstGUID]+1, {
			spellID = spellID,
			srcGUID = srcGUID,
			duration = duration,
			debuffType = debuffType,
			isDebuff = isDebuff,
			expirationTime = currentTime + duration,
			startTime = currentTime,
			stackCount = stackCount,--This should only be added if stackCount is over 1, else it'll be nil.
		})
	end
end

local CheckUnitAuras
do
	local UnitGUID = UnitGUID
	local table_remove = table.remove
	local UnitAura = UnitAura
	local _ --find globals nagging me.
	local UnitName = UnitName
	local i
	local name, rank, dispelType, duration, isStealable, spellID, unitCaster, expirationTime, stackCount, shouldConsolidate
	local dstGUID, srcGUID
	function CheckUnitAuras(unitID, filterType)
	--~ 	name, rank, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId  = UnitAura("unit", index or "name"[, "rank"[, "filter"]]) 
		i = 1;
		dstGUID = UnitGUID(unitID)
		--Since we have a unitID, lets clear our aura table and use 100% accurate aura info.
		if lib.trackAuras == true and lib.GUIDAuras[dstGUID] then
			for i=#lib.GUIDAuras[dstGUID], 1, -1 do 
				table_remove(lib.GUIDAuras[dstGUID], i)
			end
		end
	
		while true do 
			name, rank, _, stackCount, dispelType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellID = UnitAura(unitID, i, filterType)
			if not name then break end
	
			duration = Round(duration)
	
			if not lib.auraInfo[spellID] then
	
				lib.auraInfo[spellID] = (duration or 0) .. ";" .. (dispelType and lib.debuffTypes[dispelType] or 0)--add it temporarily.
				
				--[===[@debug@
				if not LAI_DB.new[spellID] then
					--Save the spell info to a saved variable to add it later. End users won't execute this code.
					LAI_DB.new[spellID] = lib.auraInfo[spellID]    .."  --"..name .. (rank and rank ~= "" and " ("..rank..")" or "") .."*"
					debugPrint("1 Missing info on", name, rank, spellID, dispelType, duration)
				end
				--@end-debug@]===]
			end
			
			if lib.trackAuras == true and unitCaster then
	--~ 			srcGUID = UnitGUID(unitCaster)
				lib:AddAuraFromUnitID(
					dstGUID, 
					spellID, 
					srcGUID, 
					filterType == "HARMFUL", 
					dispelType, 
					duration, 
					expirationTime, 
					stackCount and stackCount > 1 and stackCount or nil
				)
			end
			
			i = i + 1
		end
	end
end
	
lib.frame = lib.frame or CreateFrame("Frame")
local function OnEvent(self, event, ...)
	if self[event] then
		self[event](self, event, ...)
	end
end

function lib.frame:UPDATE_MOUSEOVER_UNIT()
	ResetUnitAuras("mouseover")
	CheckUnitAuras("mouseover", "HELPFUL")
	CheckUnitAuras("mouseover", "HARMFUL")
end

function lib.frame:PLAYER_TARGET_CHANGED()
	ResetUnitAuras("target")
	CheckUnitAuras("target", "HELPFUL")
	CheckUnitAuras("target", "HARMFUL")
end

do
	local UnitIsUnit = UnitIsUnit
	local targetID
	function lib.frame:UNIT_TARGET(unitID)
		if not UnitIsUnit(unitID, "player") then
			targetID = unitID.."target"
			ResetUnitAuras(targetID)
			CheckUnitAuras(targetID, "HELPFUL")
			CheckUnitAuras(targetID, "HARMFUL")
		end
	end
end

function lib.frame:UNIT_AURA(unitID)
	ResetUnitAuras(unitID)
	CheckUnitAuras(unitID, "HELPFUL")
	CheckUnitAuras(unitID, "HARMFUL")
end

do
	local _G = _G
	function lib.frame:PLAYER_LOGOUT(unitID)
		--[===[@debug@
		_G.LAI_DB = LAI_DB
		--@end-debug@]===]
	end
end

do
	local _G = _G
	function lib.frame:ADDON_LOADED()
		--[===[@debug@
		LAI_DB = _G.LAI_DB or {needConfirm = {}, new = {}}
		self:RegisterEvent('PLAYER_LOGOUT')
		--@end-debug@]===]
	end
end

function lib.frame:PLAYER_LOGIN()
	self:ADDON_LOADED()
end

lib.frame:SetScript("OnEvent", OnEvent)
lib.frame:RegisterEvent('ADDON_LOADED')
lib.frame:RegisterEvent('PLAYER_LOGIN')

------------------------------------------------------------------------------------------------------
--~ Dimminshing Returns
------------------------------------------------------------------------------------------------------

lib.resetDRTime = 18 --Time it tacks for DR to reset.

--[[
	List of spellID's copied from DRData-1.0 by Shadowed.
	http://www.wowace.com/addons/drdata-1-0/
	http://www.wowace.com/profiles/Shadowed/
]]
lib.drSpells = {
	--[[ TAUNT ]]--
	-- Death Knight
	[ 56222] = "taunt", -- Dark Command
	[ 57603] = "taunt", -- Death Grip
	-- I have also seen these two spellIDs used for the Death Grip debuff in MoP.
	-- I have not seen the first one here in any of my MoP testing, but it may still be valid.
	[ 49560] = "taunt", -- Death Grip
	[ 51399] = "taunt", -- Death Grip
	-- Druid
	[  6795] = "taunt", -- Growl
	-- Hunter
	[ 20736] = "taunt", -- Distracting Shot
	-- Monk
	[116189] = "taunt", -- Provoke
	-- Paladin
	[ 62124] = "taunt", -- Reckoning
	-- Warlock
	[ 17735] = "taunt", -- Suffering (Voidwalker)
	-- Warrior
	[   355] = "taunt", -- Taunt
	-- ???
	[ 36213] = "taunt", -- Angered Earth -- FIXME: NPC ability ?
	

	--[[ DISORIENTS ]]--
	-- Druid
	[  2637] = "disorient", -- Hibernate
	[    99] = "disorient", -- Disorienting Roar (talent)
    -- Hunter
	[  3355] = "disorient", -- Freezing Trap
	[ 19386] = "disorient", -- Wyvern Sting
    -- Mage
	[   118] = "disorient", -- Polymorph
	[ 28272] = "disorient", -- Polymorph (pig)
	[ 28271] = "disorient", -- Polymorph (turtle)
	[ 61305] = "disorient", -- Polymorph (black cat)
	[ 61025] = "disorient", -- Polymorph (serpent) -- FIXME: gone ?
	[ 61721] = "disorient", -- Polymorph (rabbit)
	[ 61780] = "disorient", -- Polymorph (turkey)
	[ 82691] = "disorient", -- Ring of Frost
    -- Monk
	[115078] = "disorient", -- Paralysis
    -- Paladin
	[105421] = "disorient", -- Blinding Light
	[ 20066] = "disorient", -- Repentance
    -- Priest
	[  9484] = "disorient", -- Shackle Undead
    -- Rogue
	[  1776] = "disorient", -- Gouge
	[  6770] = "disorient", -- Sap
    -- Shaman
	[ 51514] = "disorient", -- Hex
    -- Pandaren
	[107079] = "disorient", -- Quaking Palm

	--[[ SILENCES ]]--
	-- Death Knight
	[ 47476] = "silence", -- Strangulate
    -- Druid
	[ 78675] = "silence", -- Solar Beam -- FIXME: check id
	[ 81261] = "silence", -- Solar Beam -- Definitely correct
    -- Hunter
	[ 34490] = "silence", -- Silencing Shot
    -- Mage
	[ 55021] = "silence", -- Improved Counterspell
	[102051] = "silence", -- Frostjaw (talent)
    -- Monk
	[116709] = "silence", -- Spear Hand Strike
    -- Paladin
	[ 31935] = "silence", -- Avenger's Shield
    -- Priest
	[ 15487] = "silence", -- Silence
    -- Rogue
	[  1330] = "silence", -- Garrote
    -- Warlock
	[ 24259] = "silence", -- Spell Lock (Felhunter)
	[115782] = "silence", -- Optical Blast (Observer)
    -- Warrior
	[ 18498] = "silence", -- Glyph of Gag Order
    -- Blood Elf
	[ 25046] = "silence", -- Arcane Torrent (Energy version)
	[ 28730] = "silence", -- Arcane Torrent (Mana version)
	[ 50613] = "silence", -- Arcane Torrent (Runic power version)
	[ 69179] = "silence", -- Arcane Torrent (Rage version)
	[ 80483] = "silence", -- Arcane Torrent (Focus version)

	--[[ DISARMS ]]--
	-- Hunter
	[ 91644] = "disarm", -- Snatch (Bird of Prey)
	[ 50541] = "disarm", -- Clench (Scorpid)
    -- Monk
	[117368] = "disarm", -- Grapple Weapon
	-- Priest
	[ 64058] = "disarm", -- Psychic Horror (Disarm effect)
    -- Rogue
	[ 51722] = "disarm", -- Dismantle
    -- Warlock
	[118093] = "disarm", -- Disarm (Voidwalker/Voidlord)
    -- Warrior
	[   676] = "disarm", -- Disarm

	--[[ FEARS ]]--
	-- Hunter
	[  1513] = "fear", -- Scare Beast
    -- Paladin
	[ 10326] = "fear", -- Turn Evil
    -- Priest
	[  8122] = "fear", -- Psychic Scream
	[113792] = "fear", -- Psychic Terror (Psyfiend)
    -- Rogue
	[  2094] = "fear", -- Blind
    -- Warlock
	[118699] = "fear", -- Fear -- new SpellID in MoP, Blood Fear uses same ID
	[  5484] = "fear", -- Howl of Terror
	[  6358] = "fear", -- Seduction (Succubus)
	[115268] = "fear", -- Mesmerize (Shivarra) -- FIXME: verify this is the correct category
    -- Warrior
	[  5246] = "fear", -- Intimidating Shout (main target)
	[ 20511] = "fear", -- Intimidating Shout (secondary targets)

	--[[ CONTROL STUNS ]]--
	-- Death Knight
	[108194] = "ctrlstun", -- Asphyxiate (talent)
	[ 91800] = "ctrlstun", -- Gnaw (Ghoul)
	[ 91797] = "ctrlstun", -- Monstrous Blow (Dark Transformation Ghoul)
    -- Druid
	[ 22570] = "ctrlstun", -- Maim
	[  9005] = "ctrlstun", -- Pounce
	[  5211] = "ctrlstun", -- Mighty Bash (talent)
	[102795] = "ctrlstun", -- Bear Hug
	[113801] = "ctrlstun", -- Bash (treants in feral spec) (Bugged by blizzard - it instantly applies all 3 levels of DR right now, making any target instantly immune to ctrlstuns)
    -- Hunter
	[ 24394] = "ctrlstun", -- Intimidation
	[ 90337] = "ctrlstun", -- Bad Manner (Monkey)
	[ 50519] = "ctrlstun", -- Sonic Blast (Bat)
	-- [ 56626] = "ctrlstun", -- Sting (Wasp) --FIXME: this doesn't share with ctrlstun anymore. Unknown what it is right now, so watch for it on www.arenajunkies.com/topic/227748-mop-diminishing-returns-updating-the-list
	[117526] = "ctrlstun", -- Binding Shot (talent)
    -- Mage
	[ 44572] = "ctrlstun", -- Deep Freeze
	[118271] = "ctrlstun", -- Combustion Impact (Combustion; Fire)
    -- Monk
	[119392] = "ctrlstun", -- Charging Ox Wave (talent)
	[119381] = "ctrlstun", -- Leg Sweep (talent)
	[122242] = "ctrlstun", -- Clash (Brewmaster)
	[120086] = "ctrlstun", -- Fists of Fury (Windwalker)
    -- Paladin
	[   853] = "ctrlstun", -- Hammer of Justice
	[119072] = "ctrlstun", -- Holy Wrath (Protection)
	[105593] = "ctrlstun", -- Fist of Justice (talent)
    -- Priest
	-- [ 88625] = "ctrlstun", -- Holy Word: Chastise --FIXME: this doesn't share with ctrlstun anymore. Unknown what it is right now, so watch for it on www.arenajunkies.com/topic/227748-mop-diminishing-returns-updating-the-list
    -- Rogue
	[  1833] = "ctrlstun", -- Cheap Shot
	[   408] = "ctrlstun", -- Kidney Shot
    -- Shaman
	[118905] = "ctrlstun", -- Static Charge (Capacitor Totem)
	-- Warlock
	[ 30283] = "ctrlstun", -- Shadowfury
	[ 89766] = "ctrlstun", -- Axe Toss (Felguard)
	[ 22703] = "ctrlstun", -- Infernal Awakening (Infernal)
    -- Warrior
	[132168] = "ctrlstun", -- Shockwave
	[105771] = "ctrlstun", -- Warbringer (talent)
    -- Tauren
	[ 20549] = "ctrlstun", -- War Stomp

	--[[ RANDOM STUNS ]]--
	-- Rogue
	[113953] = "rndstun", -- Paralysis (Paralytic Poison five stack stun)
    -- Warrior
	[118895] = "rndstun", -- Dragon Roar (talent)

	--[[ ROOTS ]]--
	-- Death Knight
	[ 96294] = "ctrlroot", -- Chains of Ice (Chilblains Root)
	-- Druid
	[   339] = "ctrlroot", -- Entangling Roots
	[ 19975] = "ctrlroot", -- Nature's Grasp (Uses different spellIDs than Entangling Roots for the same spell)
	[102359] = "ctrlroot", -- Mass Entanglement (talent)
    -- Hunter
	[ 50245] = "ctrlroot", -- Pin (Crab)
	[  4167] = "ctrlroot", -- Web (Spider)
	[ 54706] = "ctrlroot", -- Venom Web Spray (Silithid)
	[ 90327] = "ctrlroot", -- Lock Jaw (Dog)
	[128405] = "ctrlroot", -- Narrow Escape (talent)
    -- Mage
	[   122] = "ctrlroot", -- Frost Nova
	[ 33395] = "ctrlroot", -- Freeze (Water Elemental)
    -- Monk
	[116706] = "ctrlroot", -- Disable
    -- Priest
	[114404] = "ctrlroot", -- Void Tendrils
    -- Shaman
	[ 64695] = "ctrlroot", -- Earthgrab
	[ 63685] = "ctrlroot", -- Freeze (Frozen Power talent)
    -- Warrior
	[107566] = "ctrlroot", -- Staggering Shout (talent)

	--[[ HORROR ]]--
	-- Priest
	[ 64044] = "horror", -- Psychic Horror (Horrify effect)
	-- Warlock
	[  6789] = "horror", -- Mortal Coil

	--[[ MISC ]]--
	-- Druid
	[ 33786] = "cyclone",       -- Cyclone
	-- Hunter
	[ 19503] = "scatters",      -- Scatter Shot
	[ 64803] = "entrapment",    -- Entrapment
	-- Mage
	[ 31661] = "dragons",       -- Dragon's Breath
	[111340] = "iceward",       -- Ice Ward
	-- Priest
	[   605] = "mc",            -- Dominate Mind
	-- Shaman
	[ 76780] = "bindelemental", -- Bind Elemental
	-- Warlock
	[   710] = "banish",        -- Banish
	-- Warrior
	[  7922] = "charge",        -- Charge
}

lib.pveDR = {
	["ctrlstun"] = true,
	["rndstun"] = true,
	["taunt"] = true,
	["cyclone"] = true,
}

--~ lib.guidDREffects = {}

--
lib.GUIDDrEffects_reset = {}
lib.GUIDDrEffects_diminished = {}

do
	local drType, key, reset
	local GetTime = GetTime
	function lib:GUIDGainedDRAura(dstGUID, spellID, dstIsPlayer)
		drType = self.drSpells[spellID]
		
		if dstIsPlayer or self.pveDR[drType] then
			key = dstGUID..drType
			reset = self.GUIDDrEffects_reset[key]
			if reset and reset <= GetTime() then
				self.GUIDDrEffects_diminished[key] = 1
			end
	--~ 		debugPrint("GUIDGainedDRAura", dstGUID, drType, self.GUIDDrEffects_diminished[key])
		end
	end
end
	
local function NextDR(diminished)
	if( diminished == 1 ) then
		return 0.50
	elseif( diminished == 0.50 ) then
		return 0.25
	end
	
	return 0
end

do
	local key
	local GetTime = GetTime
	local drType
	function lib:GUIDRemovedDRAura(dstGUID, spellID, dstIsPlayer)
		drType = self.drSpells[spellID]
		if dstIsPlayer or self.pveDR[drType] then
			key = dstGUID..drType
			self.GUIDDrEffects_reset[key] = GetTime() + self.resetDRTime
			self.GUIDDrEffects_diminished[key] = NextDR( self.GUIDDrEffects_diminished[key] or 1.0 )
		end
	end
end
	
do
	local GetTime = GetTime
	local duration, drType, key, reset
	function lib:GetDRDuration(dstGUID, spellID, duration)
		duration = duration or self:GetDuration(spellID, nil, dstGUID)
		drType = self.drSpells[spellID]
		if drType then
			key = dstGUID..drType
			reset = self.GUIDDrEffects_reset[key]
			if reset and GetTime() < reset then
				return duration * (self.GUIDDrEffects_diminished[key] or 1)
			end
		end
		
		return duration
	end
end

-------------------------------------------------------------------------------------------------------
--~ Combatlog
-------------------------------------------------------------------------------------------------------
lib.GUIDAuras = lib.GUIDAuras or {}

lib.GUIDData_name = {}
lib.GUIDData_flags = {}
local function SaveGUIDInfo(guid, name, flags)
	lib.GUIDData_name[guid] = name
	lib.GUIDData_flags[guid] = flags
end

do 
	local tonumber = tonumber
	local GetBuildInfo = GetBuildInfo
	local select = select
	
	local timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2
	local dstFlags2, srcFlags2 --4.2 
	local eventVars=10
	function lib.frame:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
		--timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags
		
		if tonumber((select(4, GetBuildInfo()))) >= 40200 then
			timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2 = ...
			eventVars = 12
		else
			timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags  = ...-- ***
		end
		
		if srcGUID and not lib.GUIDData_name[srcGUID] then
			SaveGUIDInfo(srcGUID, srcName, srcFlags)
		end
		if dstGUID and not lib.GUIDData_name[dstGUID] then
			SaveGUIDInfo(dstGUID, dstName, dstFlags)
		end

		if self[eventType] then
			self[eventType](self, eventType, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, select(eventVars, ...)) -- ...
		elseif eventType:find("AURA") then
			debugPrint("Missing eventType", eventType)
		end
	end
end
	
do
	local data, getTime
	local GetTime = GetTime
	local table_remove = table.remove
	----------------------------------------------
	function lib:RemoveExpiredAuras(dstGUID)	--
	-- Remove expired auras from a GUID. 		--
	----------------------------------------------
		if self.GUIDAuras[dstGUID] then
			getTime = GetTime()
			for i = #self.GUIDAuras[dstGUID], 1, -1 do 
				data = self.GUIDAuras[dstGUID][i]
				if getTime > data.expirationTime then
					table_remove(self.GUIDAuras[dstGUID], i)
				end
			end
		end
	end
end
	
do
	local data, spellName, newName, oldName
	local GetSpellInfo = GetSpellInfo
	local tostring = tostring
	local spellName
	----------------------------------------------------------------------
	function lib:checkIfAuraAlreadyOnGUID(dstGUID, spellID, srcGUID)	--
	-- Used for debuging and learning the combatlog. 					--
	----------------------------------------------------------------------
		spellName = GetSpellInfo(spellID)
		for i= #self.GUIDAuras[dstGUID], 1, -1  do 
			data = self.GUIDAuras[dstGUID][i]
			if data.spellID == spellID  then --and srcGUID ~= data.srcGUID
				if srcGUID ~= data.srcGUID then
					newName = self:GetGUIDInfo(srcGUID)
					oldName = self:GetGUIDInfo(data.srcGUID)
					if newName == oldName then
						debugPrint("checkIfAuraAlreadyOnGUID", spellID, spellName, "new:"..tostring(srcGUID), "old:"..tostring(data.srcGUID))
					else
						debugPrint("checkIfAuraAlreadyOnGUID", spellID, spellName, "new:"..tostring(newName), "old:"..tostring(oldName))
					end
				end
			end
		
		end
	end
end
	
do
	local duration, debuffType, currentTime
	local table_insert = table.insert
	local GetTime = GetTime
	------------------------------------------------------------------
	function lib:AddAuraToGUID(dstGUID, spellID, srcGUID, isDebuff)	--
	-- Add a auraID to our GUID list.								--
	------------------------------------------------------------------
		duration = self:GetDuration(spellID, srcGUID, dstGUID)
		debuffType = self:GetDebuffType(spellID)
		currentTime = GetTime()
	
		self.GUIDAuras[dstGUID] = self.GUIDAuras[dstGUID] or {}
	
		--[===[@debug@
	--~ 	self:checkIfAuraAlreadyOnGUID(dstGUID, spellID, srcGUID)
		--@end-debug@]===]
		
		--[[
			I didn't want to use tables this way when I started the project but due to multiple instnces of a spellID being on a GUID I couldn't do a hash table lookup.
			I wanted do something like
			GUIDAuras_Duration[dstGUID..spellID..srcGUID] = 30
			but because UnitAura() sometimes doesn't return a unitID to get srcGUID, I had to do a index table. meh
			
		]]
	
		table_insert(self.GUIDAuras[dstGUID], #self.GUIDAuras[dstGUID]+1, {
			spellID = spellID,
			srcGUID = srcGUID,
			duration = duration,
			debuffType = debuffType,
			isDebuff = isDebuff,
			expirationTime = currentTime + duration,
			startTime = currentTime,
		})
		
		
	--~ 	table.sort(self.GUIDAuras[dstGUID], function(a,b) 
	--~ 		return a.expirationTime < b.expirationTime 
	--~ 	end)
	end
end
	
do
	local GetTime = GetTime
	local data
	------------------------------------------------------
	function lib:AddAuraDose(dstGUID, spellID, srcGUID)	--
	-- Increase stack count of a aura.					--
	------------------------------------------------------
	
		if self.GUIDAuras[dstGUID] then
			
			if srcGUID then
				for i=1, #self.GUIDAuras[dstGUID] do 
					data = self.GUIDAuras[dstGUID][i]
					if data.spellID == spellID and data.srcGUID == srcGUID then
						
						data.stackCount = (data.stackCount or 1) + 1
						
						data.startTime = GetTime()
						data.expirationTime = data.duration + data.startTime
						
						return true, data.stackCount, data.expirationTime
					end
				end
			end
			
			for i=1, #self.GUIDAuras[dstGUID] do 
				data = self.GUIDAuras[dstGUID][i]
				if data.spellID == spellID then
					
					data.stackCount = (data.stackCount or 1) + 1
					
					data.startTime = GetTime()
					data.expirationTime = data.duration + data.startTime
					
					return true, data.stackCount, data.expirationTime
				end
			end
	
		end
		return false
	end
end
	
do
	local data
	----------------------------------------------------------
	function lib:RemoveAuraDose(dstGUID, spellID, srcGUID)	--
	-- Remove 1 stack from a aura.							--
	----------------------------------------------------------
		if self.GUIDAuras[dstGUID] then
			
			if srcGUID then
				for i=1, #self.GUIDAuras[dstGUID] do 
					data = self.GUIDAuras[dstGUID][i]
					if data.spellID == spellID and data.srcGUID == srcGUID then
						data.stackCount = (data.stackCount or 1) - 1
	--~ 					data.startTime = GetTime()
	--~ 					data.expirationTime = data.duration + data.startTime
						return true, data.stackCount, data.expirationTime
					end
				end
			end
			
			for i=1, #self.GUIDAuras[dstGUID] do 
				data = self.GUIDAuras[dstGUID][i]
				if data.spellID == spellID then
					data.stackCount = (data.stackCount or 1) - 1
	--~ 				data.startTime = GetTime()
	--~ 				data.expirationTime = data.duration + data.startTime
					return true, data.stackCount, data.expirationTime
				end
			end
	
		end
		return false
	end
end

do
	local GetTime = GetTime
	local data
	------------------------------------------------------
	function lib:RefreshAura(dstGUID, spellID, srcGUID)	--
	-- Refresh the start and expiration time of a aura.	--
	------------------------------------------------------
		if self.GUIDAuras[dstGUID] then
			
			if srcGUID then
				for i=1, #self.GUIDAuras[dstGUID] do 
					data = self.GUIDAuras[dstGUID][i]
					if data.spellID == spellID and data.srcGUID == srcGUID then
						data.startTime = GetTime()
						data.expirationTime = data.duration + data.startTime
						return true, data.expirationTime
					end
				end
			end
			
			for i=1, #self.GUIDAuras[dstGUID] do 
				data = self.GUIDAuras[dstGUID][i]
				if data.spellID == spellID then
					data.startTime = GetTime()
					data.expirationTime = data.duration + data.startTime
					return true, data.expirationTime
				end
			end
	
		end
		return false
	end
end
	
local RemoveAuraFromGUID
do
	local data, spellName
	local table_remove = table.remove
	local GetSpellInfo = GetSpellInfo
	local tostring = tostring
	local newName, oldName
	------------------------------------------------------------------
	function RemoveAuraFromGUID(dstGUID, spellID, srcGUID)	--
	-- Remove a aura from a GUID.									--
	------------------------------------------------------------------
		if lib.GUIDAuras[dstGUID] then
			spellName  = GetSpellInfo(spellID)
			
			if srcGUID then
				for i= #lib.GUIDAuras[dstGUID],1, -1 do 
					data = lib.GUIDAuras[dstGUID][i]
					if data.spellID == spellID and srcGUID == data.srcGUID then
	--~ 					debugPrint("RemoveAuraFromGUID", spellName, srcGUID, data.srcGUID, "match:"..tostring(srcGUID == data.srcGUID))
						table_remove(lib.GUIDAuras[dstGUID], i)
						return
					end
				end
			end
			
			for i= #lib.GUIDAuras[dstGUID],1, -1 do 
				data = lib.GUIDAuras[dstGUID][i]
				if data.spellID == spellID  then
					table_remove(lib.GUIDAuras[dstGUID], i)
					
					--[===[@debug@
					newName = lib:GetGUIDInfo(srcGUID)
					oldName = lib:GetGUIDInfo(data.srcGUID)
					if newName == oldName then
						debugPrint("RemoveAuraFromGUID", spellName, "new:"..tostring(newName), "old:"..tostring(data.srcGUID))
	--~ 				else
	--~ 					debugPrint("RemoveAuraFromGUID", spellName, "new:"..tostring(newName), "old:"..tostring(oldName))
					end
					--@end-debug@]===]
					return
				end
			end
			
		end
	end
end
	
do
	local table_remove = table.remove
	------------------------------------------------------
	function lib:RemoveAllAurasFromGUID(dstGUID)		--
	-- Remove all auras on a GUID. They must have died.	--
	------------------------------------------------------
		if self.GUIDAuras[dstGUID] then
			for i=#self.GUIDAuras[dstGUID], 1, -1 do 
				table_remove(self.GUIDAuras[dstGUID], i)
			end
		end
	end
end

--[[
local function AuraAlreadyOnGUID(dstGUID, spellID, srcGUID)
	if lib.GUIDAuras[dstGUID] then
		local data
		if srcGUID then
			for i=1, lib.GUIDAuras[dstGUID] do 
				data = lib.GUIDAuras[dstGUID][i]
				if data.spellID == spellID and data.srcGUID == srcGUID then
					return true
				end
			end
		end
		
		for i=1, lib.GUIDAuras[dstGUID] do 
			data = lib.GUIDAuras[dstGUID][i]
			if data.spellID == spellID then
				return true
			end
		end
	end
	return false
end
]]

do
	local spellID, spellName, spellSchool, auraType
	function lib.frame:SPELL_AURA_REMOVED(event, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, ...)	--
		spellID, spellName, spellSchool, auraType  = ...
		RemoveAuraFromGUID(dstGUID, spellID, srcGUID)
	--~ 	debugPrint(event, dstName, spellName)
		
		if lib.drSpells[spellID] then
			lib:GUIDRemovedDRAura(dstGUID, spellID, lib:FlagIsPlayer(dstFlags))
		end
		
	--~ 	(event, dstGUID, spellID, srcGUID, spellSchool, auraType)
		if lib.GUIDAuras[dstGUID] then
			lib.callbacks:Fire("LibAuraInfo_AURA_REMOVED", dstGUID, spellID, srcGUID, spellSchool, auraType)
		end
	end
end

do
	local spellID, spellName, spellSchool, auraType, amount
	function lib.frame:SPELL_AURA_APPLIED(event, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, ...)	--
		spellID, spellName, spellSchool, auraType, amount  = ...

		--[[
		ChatFrame7:AddMessage("LibAuraInfo:():SPELL_AURA_APPLIED(LibAuraInfo): "
			.. tostring(self) .. "/" .. tostring(event) .. "/" .. tostring(timestamp) .. "/" .. tostring(eventType)
			.. "/" .. tostring(srcGUID) .. "/" .. tostring(srcName) .. "/" .. tostring(srcFlags) .. "/" .. tostring(srcFlags2)
			.. "/" .. tostring(dstGUID) .. "/" .. tostring(dstName) .. "/" .. tostring(dstFlags) .. "/" .. tostring(dstFlags2))
		]]

		if lib.drSpells[spellID] then
			lib:GUIDGainedDRAura(dstGUID, spellID, lib:FlagIsPlayer(dstFlags))
		end
		
		if lib.auraInfo[spellID] then
			lib:RemoveExpiredAuras(dstGUID)
			
			lib:AddAuraToGUID(dstGUID, spellID, srcGUID, auraType == "DEBUFF")
			lib.callbacks:Fire("LibAuraInfo_AURA_APPLIED", dstGUID, spellID, srcGUID, spellSchool, auraType)
			
		--[===[@debug@
		elseif not LAI_DB.new[spellID] then
			LAI_DB.new[spellID] = "*;*  --"..spellName .. "*"
			--These I manually check the web for.
			debugPrint("2 Missing info on", dstName, spellName, spellID)
		--@end-debug@]===]
		end
	end
end
	
do
	local spellID, spellName, spellSchool, auraType
	local refreshed, expirationTime
	function lib.frame:SPELL_AURA_REFRESH(event, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, ...)
		spellID, spellName, spellSchool, auraType  = ...
		
		if lib.drSpells[spellID] then
			lib:GUIDRemovedDRAura(dstGUID, spellID, lib:FlagIsPlayer(dstFlags))
			lib:GUIDGainedDRAura(dstGUID, spellID, lib:FlagIsPlayer(dstFlags))
		end
	
		refreshed, expirationTime = lib:RefreshAura(dstGUID, spellID, srcGUID)
	
		if refreshed then
			lib.callbacks:Fire("LibAuraInfo_AURA_REFRESH", dstGUID, spellID, srcGUID, spellSchool, auraType, expirationTime)
			return
		end
	
		self:SPELL_AURA_APPLIED(event, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, ...)
	end
end
	
do
	local spellID, spellName, spellSchool, auraType
	local dosed, stackCount, expirationTime
	--DOSE = spell stacking
	function lib.frame:SPELL_AURA_APPLIED_DOSE(event, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, ...)
		spellID, spellName, spellSchool, auraType  = ...
	
		dosed, stackCount, expirationTime = lib:AddAuraDose(dstGUID, spellID, srcGUID)
		
		if dosed then
			lib.callbacks:Fire("LibAuraInfo_AURA_APPLIED_DOSE", dstGUID, spellID, srcGUID, spellSchool, auraType, stackCount, expirationTime)
			return
		end
	
		--Spell isn't in our list, let's add it.
		--Note this event could have fired on the 5th stack but our spell frame will only show it applied once. 
		self:SPELL_AURA_APPLIED(event, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, ...)
	end
end

do
	local spellID, spellName, spellSchool, auraType
	local dosed, stackCount, expirationTime
	--~ function lib.frame:SPELL_AURA_APPLIED_REMOVED_DOSE(event, timestamp, eventType, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
	function lib.frame:SPELL_AURA_REMOVED_DOSE(event, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, ...)
		spellID, spellName, spellSchool, auraType  = ...
		dosed, stackCount, expirationTime = lib:RemoveAuraDose(dstGUID, spellID, srcGUID)
		if dosed then
			lib.callbacks:Fire("LibAuraInfo_AURA_APPLIED_DOSE", dstGUID, spellID, srcGUID, spellSchool, auraType, stackCount, expirationTime)
			return
		end
	end
end

function lib.frame:SPELL_AURA_BROKEN_SPELL(...)
--~ 	local spellID, spellName, spellSchool, auraType  = ...
	self:SPELL_AURA_REMOVED(...)
end

function lib.frame:SPELL_AURA_BROKEN(...)
--~ 	local spellID, spellName, spellSchool, auraType  = ...
	self:SPELL_AURA_REMOVED(...)
end


function lib.frame:UNIT_DIED(event, timestamp, eventType, hideCaster, srcGUID, srcName, srcFlags, srcFlags2, dstGUID, dstName, dstFlags, dstFlags2, ...)
	if lib.GUIDAuras[dstGUID] then
		lib:RemoveAllAurasFromGUID(dstGUID)
		lib.callbacks:Fire("LibAuraInfo_AURA_CLEAR", dstGUID)
	end
end

function lib.frame:UNIT_DESTROYED(...)
	self:UNIT_DIED(...)
end

function lib.frame:UNIT_DISSIPATES(...)
	self:UNIT_DIED(...)
end

function lib.frame:PARTY_KILL(...)
	self:UNIT_DIED(...)
end

do
	local bit_band = bit.band
	local COMBATLOG_OBJECT_TYPE_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER
	function lib:FlagIsPlayer(flags)
		if bit_band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) == COMBATLOG_OBJECT_TYPE_PLAYER then
			return true
		end
		return nil
	end
end

--------------------------------------------------------------
--~ API
--------------------------------------------------------------
local GUIDIsPlayer
do
	local B, maskedB
	local tonumber = tonumber
	function GUIDIsPlayer(guid)
		B = tonumber(guid:sub(5,5), 16);
		maskedB = B % 8; -- x % 8 has the same effect as x & 0x7 on numbers <= 0xf
	--~ 	local knownTypes = {[0]="player", [3]="NPC", [4]="pet", [5]="vehicle"};
	--~ 	print("Your target is a " .. (knownTypes[maskedB] or " unknown entity!"));
		if maskedB == 0 then
			return true
		end
		return false
	end
end

do
	local tonumber = tonumber
	local strsplit = strsplit
	local dstIsPlayer, spellStr, duration, dur, debuffType
	--Return the duration of a spell.
	function lib:GetDuration(spellID, srcGUID, dstGUID, dstIsPlayer)
		dstIsPlayer = dstIsPlayer or dstGUID and GUIDIsPlayer(dstGUID) or false
		spellStr = ""
		if dstIsPlayer and lib.auraInfoPvP[spellID] then
			--Receiver is a player and the spell has a PvP duration. Return the pvp duration.
			duration = lib.auraInfoPvP[spellID]
			if dstGUID and duration then
				--Check if there's dimminshing returns on the spell.
				duration = self:GetDRDuration(dstGUID, spellID, duration)
			end

			return tonumber(duration or 0)
		elseif self.auraInfo[spellID] then
			--Check caster GUID was given.
			if srcGUID then
				--Check if we've seen that caster cast a spell with a duration that doesn't match our own (spec/glphed into something?)
				if self.GUIDDurations[srcGUID.."-"..spellID] then
					dur = self.GUIDDurations[srcGUID.."-"..spellID]
					
					--Check if receiver GUID was given.
					if dstGUID then
						--Check if there's dimminshing returns on the spell.
						dur = self:GetDRDuration(dstGUID, spellID, dur)
					end
					return dur
				end
			end
		
			duration, debuffType = strsplit(";", self.auraInfo[spellID])
			return tonumber(duration or 0)
		end
	end
end

do
	local duration, debuffType
	local tonumber = tonumber
	local strsplit = strsplit
	--Return the debuff type of a spell.
	function lib:GetDebuffType(spellID)
		if self.auraInfo[spellID] then
			duration, debuffType = strsplit(";", self.auraInfo[spellID])
			if debuffType then
				debuffType = tonumber(debuffType)
				if debuffType == 0 then
					return "none" --Lowercase because DebuffTypeColor["none"] is lowercase.
				else
					return self.debuffTypes[debuffType] or "unknown"
				end
			end
			return "none"--Lowercase because DebuffTypeColor["none"] is lowercase.
		end
		return nil
	end
end
	
function lib:GetNumGUIDAuras(dstGUID)
	self:RemoveExpiredAuras(dstGUID)
	
	if self.GUIDAuras[dstGUID] then
		return #self.GUIDAuras[dstGUID]
	end

	return 0
end

do
	local data
	function lib:GUIDAura(dstGUID, i)
		if self.GUIDAuras[dstGUID] and self.GUIDAuras[dstGUID][i] then
			data = self.GUIDAuras[dstGUID][i]
			return true, data.count or 0, data.debuffType, data.duration, data.expirationTime, data.isDebuff, data.srcGUID
		end
		return false
	end
end

do
	local data
	function lib:GUIDAuraID(dstGUID, spellID, srcGUID)
		if self.GUIDAuras[dstGUID] then
			if srcGUID then
				for i=1, #self.GUIDAuras[dstGUID] do 
					data = self.GUIDAuras[dstGUID][i]
					if data.spellID == spellID and data.srcGUID == srcGUID then
						return true, data.count or 0, data.debuffType, data.duration, data.expirationTime, data.isDebuff, data.srcGUID
					end
				end
			end
			for i=1, #self.GUIDAuras[dstGUID] do 
				data = self.GUIDAuras[dstGUID][i]
				if data.spellID == spellID then
					return true, data.count or 0, data.debuffType, data.duration, data.expirationTime, data.isDebuff, data.srcGUID
				end
			end
		end
		return false
	end
end
--[[
old function no longer used.
function lib:GetGUIDAuras(GUID)
	if self.GUIDAuras[GUID] then
		return unpack(self.GUIDAuras[GUID])
	end
	return nil
end
]]

do
	local drType, key, reset
	local GetTime = GetTime
	function lib:HasDREffect(dstGUID, spellID)
		drType = self.drSpells[spellID]
		if drType then
			key = dstGUID..drType
			reset = self.GUIDDrEffects_reset[key]
			if reset and GetTime() < reset then
				return true, (self.GUIDDrEffects_diminished[key] or 1)
			end
		end
		return false
	end
end
	
function lib:GetGUIDInfo(GUID)
	return self.GUIDData_name[GUID], self.GUIDData_flags[GUID]
end

