local folder, core = ...

if not core.LibNameplate or not core.LibNameplateRegistry then
	return
end

--Globals
local _G = _G
local pairs = pairs
local table_insert	= table.insert
local table_sort	= table.sort
local table_getn	= table.getn
local Debug = core.Debug
local tonumber = tonumber
local GetSpellInfo = GetSpellInfo
local select = select


core.tooltip = core.tooltip or CreateFrame("GameTooltip", folder.."Tooltip", UIParent, "GameTooltipTemplate")
local tooltip = core.tooltip
tooltip:Show()
tooltip:SetOwner(UIParent, "ANCHOR_NONE")


-- Isolate the environment
--~ setfenv(1, core)
-- local
local spellIDs = {}

local defaultSettings = core.defaultSettings
local L = core.L or LibStub("AceLocale-3.0"):GetLocale(folder, true)

local P = {}
local prev_OnEnable = core.OnEnable;
function core:OnEnable()
	prev_OnEnable(self);

--~ 	self:Debug("OnEnable", "options", self.db.profile)
	P = self.db.profile
	
	if P.addSpellDescriptions == true then
		spellIDs = self:GetAllSpellIDs()
	end
	
	self:BuildSpellUI()
end

local minIconSize = 8
local maxIconSize = 80
local minTextSize = 6
local maxTextSize = 20
local minInterval = 2
local maxInterval = 80

--1=all, 2=mine, 3=none
defaultSettings.profile.defaultBuffShow			= 3
defaultSettings.profile.defaultDebuffShow			= 2

defaultSettings.profile.unknownSpellDataIcon	= false
--~ defaultSettings.profile.showAura				= false
defaultSettings.profile.saveNameToGUID			= true
defaultSettings.profile.watchCombatlog			= true
defaultSettings.profile.addSpellDescriptions = false

defaultSettings.profile.watchUnitIDAuras = true

defaultSettings.profile.abovePlayers		= true
defaultSettings.profile.aboveNPC		    = true
defaultSettings.profile.aboveFriendly		= true
defaultSettings.profile.aboveNeutral		= true
defaultSettings.profile.aboveHostile		= true
defaultSettings.profile.aboveTapped 		= true

defaultSettings.profile.textureSize			= 0.1

defaultSettings.profile.barAnchorPoint		= "BOTTOM"
defaultSettings.profile.plateAnchorPoint		= "TOP"
defaultSettings.profile.barOffsetX		= 0
defaultSettings.profile.barOffsetY		= 8 --bit north incase user's running Threat plates.
defaultSettings.profile.iconsPerBar		= 6
defaultSettings.profile.barGrowth		= 1
defaultSettings.profile.numBars		= 2
defaultSettings.profile.iconSize		= 24
defaultSettings.profile.iconSize2		= 24
defaultSettings.profile.increase		= 1
defaultSettings.profile.biggerSelfSpells		= true
defaultSettings.profile.showCooldown		= true
defaultSettings.profile.shrinkBar		= true
defaultSettings.profile.showBarBackground		= false
defaultSettings.profile.frameLevel		= 0

defaultSettings.profile.cooldownSize		= 10
defaultSettings.profile.stackSize		= 10
defaultSettings.profile.intervalX		= 12
defaultSettings.profile.intervalY		= 12
defaultSettings.profile.defaultLib		= 1


defaultSettings.profile.namePlateFont = "Friz Quadrata TT"

defaultSettings.profile.digitsnumber		= 1

defaultSettings.profile.showCooldownTexture		= true

defaultSettings.profile.borderTexture		= "Interface\\Addons\\PlateBuffs\\texture\\border.tga"

defaultSettings.profile.colorByType = true

defaultSettings.profile.color1		= {0.80,0,0}
defaultSettings.profile.color2		= {0.20,0.60,1.00}
defaultSettings.profile.color3		= {0.60,0.00,1.00 }
defaultSettings.profile.color4		= {0.60,0.40, 0 }
defaultSettings.profile.color5		= {0.00,0.60,0 }
defaultSettings.profile.color6		= {0.00,1.00,0 }

defaultSettings.profile.blinkTimeleft		= 0.2 --20%
defaultSettings.profile.showTotems = false
defaultSettings.profile.npcCombatWithOnly = true
defaultSettings.profile.playerCombatWithOnly = false



core.CoreOptionsTable = {
	name = core.titleFull,
	type = "group",
	childGroups = "tab",

    get = function(info)
		local key = info[#info]
        return P[key]
    end,
    set = function(info, v)
        local key = info[#info] -- backup_enabled, etc...
        P[key] = v
    end,

	
	args = {
	
		enable = {
			type = "toggle",	order	= 1,
			name	= L["Enable"],
			desc	= L["Enables / Disables the addon"],
			set = function(info,val) 
				if val == true then
					core:Enable()
				else
					core:Disable()
				end
			end,
			get = function(info) return core:IsEnabled() end
		},
		
		defaultLib = {
			type = "select", order = 2,
			name = "Nameplate library.",
			desc = "An embeddable library providing an abstraction layer for tracking and querying Blizzard's Nameplate frames with ease and efficiency. \nDefault - LibNameplate-1.0",

			values = function()
				return {
					"LibNameplate-1.0",
					"LibNameplateRegistry-1.0", 
				}
			end,
			get = function(info)
				local key = info[#info]
				return P[key]
			end,
			set = function(info, v)
				local key = info[#info] -- backup_enabled, etc...
				P[key] = v
				
				print("Do change", v)
				ReloadUI()
			end,
		},
		
		unknownSpellDataIcon = {
			type = "toggle", order	= 10,
			name = L["Show question mark"],
			desc = L["Display a question mark above plates we don't know spells for. Target or mouseover those plates."],
		},
		
		defaultBuffShow = {
			type = "select", order = 11,
			name = L["Show Buffs"],
			desc = L["Show buffs above nameplate."],

			values = function()
				return {
					L["All"], 
					"Mine + SpellList", --L["Mine Only"],
					"Only SpellList", --L["None"],
					"Only mine",
				}
			end,
		},
		
		defaultDebuffShow = {
			type = "select", order = 12,
			name = L["Show Debuffs"],
			desc = L["Show debuffs above nameplate."],

			values = function()
				return {
					L["All"], 
					"Mine + SpellList", --L["Mine Only"],
					"Only SpellList", --L["None"],
					"Only mine",
				}
			end,
		},

		saveNameToGUID = {
			type = "toggle", order	= 15,
			name = L["Save player GUID"],
			desc = L["Remember player GUID's so target/mouseover isn't needed every time nameplate appears.\nKeep this enabled"],

			set = function(info,val) 
				P.saveNameToGUID = val
			end,
			get = function(info) return P.saveNameToGUID end
		},
		
		watchCombatlog = {
			type = "toggle", order	= 16,
			name = L["Watch Combatlog"],
			desc = L["Watch combatlog for people gaining/losing spells.\nDisable this if you're having performance issues."],
			set = function(info,val) 
				P.watchCombatlog = val
				core:RegisterLibAuraInfo()
			end,
		},
		
		addSpellDescriptions = {
			type = "toggle", order	= 17,
			name = L["Add Spell Description"],
			desc = L["Add spell descriptions to the specific spell's list.\nDisabling this will lower memory usage and login time."],

			set = function(info,val) 
				P.addSpellDescriptions = val
				
				if val then
					spellIDs = core:GetAllSpellIDs()
					core:BuildSpellUI()
				end
			end,
		},
		
		borderTexture = {
			name = L["Border Texture"],
			order = 17,
			desc = L["Set border texture."],
			type = "select",
			
			values = function()
				return {
					[""]= NO, 
					["Interface\\Addons\\PlateBuffs\\texture\\border.tga"] = "Default",
					["Masque"] = ( LibStub("LibButtonFacade", true) and "Masque" or nil),
				}
			end,
			set = function(info,val) 
				P.borderTexture = val
				core:ResetAllPlateIcons()				
			end,

		},
		
		namePlateFont = {
			name = "Nameplate Font",
			order = 17.1,
			desc = "Set nameplate font.",
			type = "select",
			dialogControl = 'LSM30_Font',
			values = core.LSM:HashTable("font"),
			set = function(info,val) 
				P.namePlateFont = val
				core:UpdateNameplateFont()
			end,

		},
		
		textureSize = {
			name = L["Texture size"],
			desc = L["increase texture size.\nDefaul=0.1"],
			type = "range",
			order	= 18,
			min		= 0,
			max		= 0.3,
			step	= 0.01,
			set = function(info,val) 
				P.textureSize = val
				core:ResetAllPlateIcons()
			end,
		},
		
		colorHeader = {
			name	= L["Border colors"],
			order	= 19,
			type = "header",
		},
		
		colorbyType = {
				type = "toggle", order	= 20,
				name = L["Color by type"],
				desc = L["If not set Physical color used for all debuffs"],

				set = function(info,val) 
					P.colorByType = val
				end,
				get = function(info) return P.colorByType end
			},
		color1 = {
				order = 21,name = L["Physical"],type = "color",
				set = function(info,r,g,b) P.color1={r,g,b} end,
				get = function(info) return P.color1[1],P.color1[2],P.color1[3],1 end
			},
		color2 = {
				order = 22,name = L["Magic"],type = "color",
				set = function(info,r,g,b) P.color2={r,g,b} end,
				get = function(info) return P.color2[1],P.color2[2],P.color2[3],1 end
			},
		color3 = {
				order = 23, name = L["Curse"],type = "color",
				set = function(info,r,g,b) P.color3={r,g,b} end,
				get = function(info) return P.color3[1],P.color3[2],P.color3[3],1 end
			},
		color4 = {
				order = 24,name = L["Disease"],type = "color",
				set = function(info,r,g,b) P.color4={r,g,b} end,
				get = function(info) return P.color4[1],P.color4[2],P.color4[3],1 end
			},
		color5 = {
				order = 25,name = L["Poison"],type = "color",
				set = function(info,r,g,b) P.color5={r,g,b} end,
				get = function(info) return P.color5[1],P.color5[2],P.color5[3],1 end
			},
		color6 = {
				order = 26,name = L["Buff"],type = "color",
				set = function(info,r,g,b) P.color6={r,g,b} end,
				get = function(info) return P.color6[1],P.color6[2],P.color6[3],1 end
			},
		--[===[@debug@
		watchUnitIDAuras = {
			type = "toggle", order	= 90,
			name = "Watch unitID auras",
			desc = "Option to help me test out combatlog tracking.",

		},
		--@end-debug@]===]
		
	},
}



core.WhoOptionsTable = {
	name = core.titleFull,
	type = "group",
	childGroups = "tab",

    get = function(info)
		local key = info[#info]
        return P[key]
    end,
    set = function(info, v)
        local key = info[#info] -- backup_enabled, etc...
        P[key] = v
    end,
	
	args = {
		typeHeader = {
			name	= L["Type"],
			order	= 10,
			type = "header",
		},

		abovePlayers = {
			name = L["Players"],
			desc = L["Add buffs above players"],
			type = "toggle",
			order	= 11,
		},
	
		aboveNPC = {
			name = L["NPC"],
			desc = L["Add buffs above NPCs"],
			type = "toggle",
			order	= 12,
		},
	
		reactionHeader = {
			name	= L["Reaction"],
			order	= 15,
			type = "header",
		},

		aboveFriendly = {
			name = L["Friendly"],
			desc = L["Add buffs above friendly plates"],
			type = "toggle",
			order	= 16,
		},

		aboveNeutral = {
			name = L["Neutral"],
			desc = L["Add buffs above neutral plates"],
			type = "toggle",
			order	= 17,
		},
		
		aboveHostile = {
			name = L["Hostile"],
			desc = L["Add buffs above hostile plates"],
			type = "toggle",
			order	= 18,
		},

		aboveTapped = {
			name = L["Tapped"],
			desc = L["Add buffs above tapped plates"],
			type = "toggle",
			order	= 19,
		},
		
		
		otherHeader = {
			name	= L["Other"],
			order	= 20,
			type = "header",
		},

		showTotems = {
			name = L["Show Totems"],
			desc = L["Show spell icons on totems"],
			type = "toggle",
			order	= 21,
		},
		
		
		npcCombatWithOnly = {
			name = L["NPC combat only"],
			desc = L["Only show spells above nameplates that are in combat."],
			type = "toggle",
			order	= 22,
			set = function(info,val) 
				P.npcCombatWithOnly = val
				core:Disable()
				core:Enable()
			end,
		},
		
		playerCombatWithOnly = {
			name = L["Player combat only"],
			desc = L["Only show spells above nameplates that are in combat."],
			type = "toggle",
			order	= 23,
			set = function(info,val) 
				P.playerCombatWithOnly = val
				core:Disable()
				core:Enable()
			end,
		},
		
		
		
	},
}

core.BarOptionsTable = {
	name = core.titleFull,
	type = "group",
	childGroups = "tab",

    get = function(info)
		local key = info[#info]
        return P[key]
    end,
    set = function(info, v)
        local key = info[#info] -- backup_enabled, etc...
        P[key] = v
    end,
	
	args = {
		barAnchorPoint = {
			name = L["Row Anchor Point"],
			order = 1,
			desc = L["Point of the buff frame that gets anchored to the nameplate.\ndefault = Bottom"],
			type = "select",
			
			values = function()
				return {
					["TOP"]=L["Top"], 
					["BOTTOM"]=L["Bottom"], 
--~ 					["LEFT"]=L["Left"], --NOTE! Using these values may break bar anchors to other bars.
--~ 					["RIGHT"]=L["Right"], 
--~ 					["CENTER"]=L["Center"], 
					["TOPLEFT"]=L["Top Left"], 
					["BOTTOMLEFT"]=L["Bottom Left"], 
					["TOPRIGHT"]=L["Top Right"], 
					["BOTTOMRIGHT"]=L["Bottom Right"], 
				}
			end,
			set = function(info,val) 
				P.barAnchorPoint = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.barAnchorPoint end
		},

		plateAnchorPoint = {
			name = L["Plate Anchor Point"],
			order = 2,
			desc = L["Point of the nameplate our buff frame gets anchored to.\ndefault = Top"],
			type = "select",
			
			values = function()
				return {
					["TOP"]=L["Top"], 
					["BOTTOM"]=L["Bottom"], 
--~ 					["LEFT"]=L["Left"],   --NOTE! Using these values may break bar anchors to other bars.
--~ 					["RIGHT"]=L["Right"], 
--~ 					["CENTER"]=L["Center"], 
					["TOPLEFT"]=L["Top Left"], 
					["BOTTOMLEFT"]=L["Bottom Left"], 
					["TOPRIGHT"]=L["Top Right"], 
					["BOTTOMRIGHT"]=L["Bottom Right"], 
				}
			end,
			set = function(info,val) 
				P.plateAnchorPoint = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.plateAnchorPoint end
		},
		
		barOffsetX = {
			name = L["Row X Offset"],
			desc = L["Left to right offset."],
			type = "range",
			order	= 5,
			min		= -256,
			max		= 256,
			step	= 1,
			set = function(info,val) 
				P.barOffsetX = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.barOffsetX end
		},

		
		barOffsetY = {
			name = L["Row Y Offset"],
			desc = L["Up to down offset."],
			type = "range",
			order	= 6,
			min		= -256,
			max		= 256,
			step	= 1,
			set = function(info,val) 
				P.barOffsetY = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.barOffsetY end
		},
		
		iconsPerBar = {
			name = L["Icons per bar"],
			desc = L["Number of icons to display per bar."],
			type = "range",
			order	= 7,
			min		= 1,
			max		= 16,
			step	= 1,
			set = function(info,val) 
				P.iconsPerBar = val
				core:ResetAllPlateIcons()
		--~ 		core:UpdateBarsSize()
				core:ShowAllKnownSpells()
			end,
--~ 			get = function(info) return P.iconsPerBar end
		},
		
		barGrowth = {
			type = "select",	order = 8,
			name = L["Row Growth"],
			desc = L["Which way do the bars grow, up or down."],

			values = function()
				return {
					L["Up"],
					L["Down"],
				}
			end,
			set = function(info,val) 
				P.barGrowth = val
				core:ResetAllBarPoints()
			end,
--~ 			get = function(info) return P.barGrowth end
		},
		
		numBars = {
			name = L["Max bars"],
			desc = L["Max number of bars to show."],
			type = "range",
			order	= 9,
			min		= 1,
			max		= 4,
			step	= 1,
			set = function(info,val) 
				P.numBars = val
				core:ResetAllPlateIcons()
		--~ 		core:UpdateBarsSize()
				core:UpdateBarsBackground()
				core:ShowAllKnownSpells()
			end,
--~ 			get = function(info) return P.numBars end
		},
		
		
		
		
		
		biggerSelfSpells = {
			name = L["Larger self spells"],
			desc = L["Make your spells 20% bigger then other's."],
			type = "toggle",
			order	= 11,
		},
		
		

		

		shrinkBar = {
			name = L["Shrink Bar"],
			desc = L["Shrink the bar horizontally when spells frames are hidden."],
			type = "toggle",
			order	= 20,
			set = function(info,val) 
				P.shrinkBar = val
				core:UpdateAllPlateBarSizes()
			end,
		},
		
		--[[
		frameLevel = {
			name = "Frame Level",
			desc = "xxx",
			type = "range",
			
			order	= 21,
			min		= 0,
			max		= 20,
			step	= 1,
			
			set = function(info,val) 
				P.frameLevel = val
				core:UpdateAllFrameLevel()
			end,
		},]]
		
		
		
		showBarBackground = {
			name = L["Show bar background"],
			desc = L["Show the area where spell icons will be. This is to help you configure the bars."],
			type = "toggle",
			order	= 99,
			set = function(info,val) 
				P.showBarBackground = val
				core:UpdateBarsBackground()
			end,
		},

		iconTestMode = {
			name = L["Test Mode"],
			desc = L["For each spell on someone, multiply it by the number of icons per bar.\nThis option won't be saved at logout."],
			type = "toggle",
			order	= 100,
		},
		
	},
}

--~ defaultSettings.profile.spellOpts = {}

-- END OF BAR

local tmpNewName = ""
local tmpNewID = ""

core.SpellOptionsTable = {
	name = core.titleFull,
	type = "group",
	

	
	args = {
--~ 				whatThisDo = {
--~ 					type = "description",	order = 5,
--~ 					name = "Specific spell options.",
--~ 				},

		
		
		
		inputName = {
			type = "input",	order	= 2,
			name = L["Spell name"],
			desc = L["Input a spell name. (case sensitive)\nOr spellID"],
			set = function(info,val) 
				local num = tonumber(val)
				if num then
					local spellName = GetSpellInfo(num)
--~ 					Debug("num 1", num, spellName)
					if spellName then
						tmpNewName = spellName
						tmpNewID = num
						return
					end
				end
--~ 				Debug(val, type(val))
				tmpNewName = val
				tmpNewID = "No spellID"
			end,
			get = function(info) return tmpNewName, tmpNewID end
		},

		addName = {
			type = "execute",	order	= 3,
			name	= L["Add spell"],
			desc	= L["Add spell to list."],
			func = function(info) 
				if tmpNewName ~= "" then
					if tmpNewID ~= "" then
						core:AddNewSpell(tmpNewName, tmpNewID)
					else
						core:AddNewSpell(tmpNewName)
					end
					tmpNewName = ""
				end
			end
		},

		spellList = {
			type = "group",	order	= 5,
			name	= L["Specific Spells"],
			
			args={}, --done later
		},
		
--~ 		defaultSpellOpt = {
--~ 			type = "group",	order	= 6,
--~ 			name	= "Default",

--~ 		},



		
		
		
	},
}

core.DefaultSpellOptionsTable = {
	name = core.titleFull,
	type = "group",
	
	get = function(info)
		local key = info[#info]
		return P[key]
	end,
	set = function(info, v)
		local key = info[#info] -- backup_enabled, etc...
		P[key] = v
	end,
	
	args = {
		spellDesc = {
			type = "description",
			name = L["Spells not in the Specific Spells list will use these options."],
			order = 1,
		},

		iconSize = {
			name = L["Icon width"],
			desc = L["Size of the icons."],
			type = "range",
			order	= 10,
			min		= minIconSize,
			max		= maxIconSize,
			step	= 1,
			set = function(info,val) 
				P.iconSize = val
				core:ResetIconSizes()
		--~ 		core:UpdateBarsSize()
			end,
		},	
		iconSize2 = {
			name = L["Icon height"],
			desc = L["Size of the icons."],
			type = "range",
			order	= 11,
			min		= minIconSize,
			max		= maxIconSize,
			step	= 1,
			set = function(info,val) 
				P.iconSize2 = val
				core:ResetIconSizes()
		--~ 		core:UpdateBarsSize()
			end,
			
			
		},
		
		digitsnumber = {
			name = L["Digits number"],
			desc = L["Digits number after the decimal point."],
			type = "range",
			order	= 10,
			min		= 0,
			max		= 2,
			step	= 1,
			set = function(info,val) 
				P.digitsnumber = val
			end,
		},
		
		
		intervalX = {
			name = L["Interval Y"],
			desc = L["Change interval between icons."],
			type = "range",
			order	= 12,
			min		= minInterval,
			max		= maxInterval,
			step	= 1,
			set = function(info,val) 
				P.intervalX = val
				core:ResetIconSizes()
		--~ 		core:UpdateBarsSize()
			end,
		},
		
		intervalY = {
			name = L["Interval X"],
			desc = L["Change interval between icons."],
			type = "range",
			order	= 13,
			min		= minInterval,
			max		= maxInterval,
			step	= 1,
			set = function(info,val) 
				P.intervalY = val
				core:ResetIconSizes()
		--~ 		core:UpdateBarsSize()
			end,
		},
		
		cooldownSize = {
			name = L["Cooldown Text Size"],
			desc = L["Text size"],
			type = "range",
			order	= 14,
			min		= minTextSize,
			max		= maxTextSize,
			step	= 1,
			set = function(info,val) 
				P.cooldownSize = val
				
				core:ResetCooldownSize()
				core:ResetAllPlateIcons()
				core:ResetIconSizes()--Adjust the frame height with the new Cooldown Text Size
		--~ 		core:UpdateBarsSize()
				core:ShowAllKnownSpells()
			end,
		},

		stackSize = {
			name = L["Stack Text Size"],
			desc = L["Text size"],
			type = "range",
			order	= 15,
			min		= minTextSize,
			max		= maxTextSize,
			step	= 1,
			set = function(info,val) 
				P.stackSize = val
				core:ResetStackSizes()
			end,
		},
	
		blinkTimeleft = {
			name = L["Blink Timeleft"],
			desc = L["Blink spell if below x% timeleft, (only if it's below 60 seconds)"],
			type = "range",
			order	= 16,
			min		= 0,
			max		= 1,
			step	= 0.05,
			isPercent = true,
		},

		showCooldown = {
			name = L["Show cooldown"],
			desc = L["Show cooldown text under the spell icon."],
			type = "toggle",
			order	= 17,
			set = function(info,val) 
				P.showCooldown = val
		--~ 		core:ResetCooldownSize()
		--~ 		core:ResetAllPlateIcons()
				core:ResetIconSizes()--Adjust the frame height with the new Cooldown Text Size
		--~ 		core:UpdateBarsSize()
				core:ShowAllKnownSpells()
			end,
		},
		
		showCooldownTexture = {
			name = L["Show cooldown overlay"],
			desc = L["Show a clock overlay over spell textures showing the time remaining."].."\n"..L["This overlay tends to disappear when the frame's moving."],
			type = "toggle",
			order	= 18,
			set = function(info,val)
				P.showCooldownTexture = val
			end,
		},
		
		
	},
}


local _spelliconcache = {}
local function SpellString(spellID,size)
		if not size then size = 12 end
		if not _spelliconcache[spellID..size] then
			if spellID and tonumber(spellID) then
			
				local name, rank, icon = GetSpellInfo(spellID)

				_spelliconcache[spellID..size] = "\124T"..icon..":"..size.."\124t"
				
				return _spelliconcache[spellID..size]
			else
				return "\124TInterface\\Icons\\"..core.unknownIcon..":"..size.."\124t"
			end
		else
			return _spelliconcache[spellID..size]
		end
	end
	
function core:BuildSpellUI()
	--P.addSpellDescriptions

	local SpellOptionsTable = core.SpellOptionsTable
	SpellOptionsTable.args.spellList.args = {} --reset

	local list = {}
	for name, data in pairs(P.spellOpts) do 
		if not P.ignoreDefaultSpell[name] then
			table_insert(list, name)
		end
	end
	
	table_sort(list, function(a,b) 
		if(a and b) then 
--~ 			if P.spellOpts[a].iconSize and P.spellOpts[b].iconSize and P.spellOpts[a].iconSize ~= P.spellOpts[b].iconSize then
--~ 				return P.spellOpts[a].iconSize > P.spellOpts[b].iconSize
--~ 			else
				return a < b
--~ 			end
		end 
	end)
	
	
	local testDone = false
	local spellName, data, spellID
	local spellDesc, spellTexture
	local iconSize
	local nameColour
	local iconTexture
	
	for i=1, table_getn(list) do 
		spellName = list[i]
		data = P.spellOpts[spellName]
		spellID = P.spellOpts[spellName].spellID or "No spellID"
		iconSize = data.increase or P.increase
		iconTexture = SpellString(spellID)
	
		if data.show == 1 then
			nameColour = "|cff00ff00%s|r" --green
		elseif data.show == 3 then 
			nameColour = "|cffff0000%s|r" --red
		elseif data.show == 5 then
			nameColour = "|cffcd00cd%s|r" --purple
		elseif data.show == 4 then
			nameColour = "|cffb9ffff%s|r" --birizoviy
		else
			nameColour = "|cffffff00%s|r"--yellow
		end
		
		
		spellDesc = "??"
		spellTexture = "Interface\\Icons\\"..core.unknownIcon
		
		
		if spellIDs[spellName] or (spellID and type(spellID) == "number") then
			
			spellIDs[spellName] = spellIDs[spellName] or spellID
			tooltip:SetHyperlink("spell:"..spellIDs[spellName])
			
			spellTexture = select(3, GetSpellInfo( spellIDs[spellName] ))
			
			local lines = tooltip:NumLines()
			if lines > 0 then
				spellDesc = _G[folder.."TooltipTextLeft"..lines] and _G[folder.."TooltipTextLeft"..lines]:GetText() or "??"
			end
		end
		
	--	print(spellName, spellID, spellTexture, spellIDs[spellName])
		
		--add spell to table.
		SpellOptionsTable.args.spellList.args[spellName] = {
			type	= "group",
			name	= iconTexture.." "..nameColour:format(spellName.." ("..iconSize..") #"..spellID),
			desc	= spellDesc, --L["Spell name"],
			order = i,
			args={}
		}
		if P.addSpellDescriptions == true then
			SpellOptionsTable.args.spellList.args[spellName].args.spellDesc = {
				type = "description",
				name = spellDesc,
				order = 1,
				image = spellTexture, 
				imageWidth = 32,
				imageHeight = 32,
			}
		end
		--UI elements
		SpellOptionsTable.args.spellList.args[spellName].args.showOpt = {
			type = "select",	order = 2,
			name = L["Show"],
			desc = L["Always show spell, only show your spell, never show spell"],

			values = {
				L["Always"],
				L["Mine only"],
				L["Never"],
				L["Only Friend"],
				L["Only Enemy"],
			},
			set = function(info,val) 
				P.spellOpts[info[2]].show = val
				core:BuildSpellUI()
			end,
			get = function(info) return P.spellOpts[info[2]].show or 1 end
		}
		
		SpellOptionsTable.args.spellList.args[spellName].args.spellID = {
			type = "input",	order	= 3,
			name = "Spell ID",
			desc = "Change spellID",
			set = function(info,val) 
				local num = tonumber(val)
				if num then
					P.spellOpts[info[2]].spellID = num
				else
					P.spellOpts[info[2]].spellID = "No SpellID"
				end
			end,
			get = function(info) return tostring(P.spellOpts[info[2]].spellID or "Spell ID not set") end
			
	--	data = P.spellOpts[spellName]
	--	spellID = P.spellOpts[spellName].spellID or "No spellID"
	
		}	
		SpellOptionsTable.args.spellList.args[spellName].args.iconSize = {
			name = L["Icon multiplication"],
			desc = L["Size of the icons."],
			type = "range",
			order	= 4,
			min		= 1,
			max		= 3,
			step	= 0.1,
			set = function(info,val) 
				P.spellOpts[info[2]].increase = val
				
				core:ResetIconSizes()
				core:BuildSpellUI()
			end,
			get = function(info) return P.spellOpts[info[2]].increase or P.increase end
		}
		
	--	SpellOptionsTable.args.spellList.args[spellName].args.iconSize2 = {
	--		name = "Icon Size2",
	--		desc = "Size of the icons.2",
	--		type = "range",
	--		order	= 4,
	--		min		= minIconSize,
	--		max		= maxIconSize,
	--		step	= 4,
	--		set = function(info,val) 
	--			P.spellOpts[info[2]].iconSize2 = val
				
	--			core:ResetIconSizes()
	--			core:BuildSpellUI()
	--		end,
	--		get = function(info) return P.spellOpts[info[2]].iconSize2 or P.iconSize2 end
	--	}
		
		SpellOptionsTable.args.spellList.args[spellName].args.cooldownSize = {
			name = L["Cooldown Text Size"],
			desc = L["Text size"],
			type = "range",
			order	= 5,
			min		= minTextSize,
			max		= maxTextSize,
			step	= 1,
			set = function(info,val) 
				P.spellOpts[info[2]].cooldownSize = val
				
				core:ResetCooldownSize()
				core:ResetAllPlateIcons()
				core:ResetIconSizes()--Adjust the frame height with the new Cooldown Text Size
		--~ 		core:UpdateBarsSize()
				core:ShowAllKnownSpells()
				core:BuildSpellUI()
			end,
			get = function(info) return P.spellOpts[info[2]].cooldownSize or P.cooldownSize end
		}
		
		SpellOptionsTable.args.spellList.args[spellName].args.stackSize = {
			name = L["Stack Text Size"],
			desc = L["Text size"],
			type = "range",
			order	= 14,
			min		= minTextSize,
			max		= maxTextSize,
			step	= 1,
			set = function(info,val) 
				P.spellOpts[info[2]].stackSize = val
				core:ResetStackSizes()
				core:BuildSpellUI()
			end,
			get = function(info) return P.spellOpts[info[2]].stackSize or P.stackSize end
		}
		
		
		--last
		
		if data.when then
			SpellOptionsTable.args.spellList.args[spellName].args.addedWhen = {
				type = "description",	order = 90,
				name = L["Added: "]..data.when,
			}
		end
		
		SpellOptionsTable.args.spellList.args[spellName].args.removeSpell = {
			type = "execute",	order	= 91,
			name	= L["Remove Spell"],
			desc	= L["Remove spell from list"],
			func = function(info) 
				core:RemoveSpell(info[2])
			end
		}
		
		SpellOptionsTable.args.spellList.args[spellName].args.grabID = {
				type = "toggle", order	= 20,
				name = L["Check SpellID"],
				desc = L["Check SpellID"],

				set = function(info,val) 
					P.spellOpts[info[2]].grabid = not P.spellOpts[info[2]].grabid
				end,
				get = function(info) return P.spellOpts[info[2]].grabid end
		}
			
	end
	
	
end

do
	core.AboutOptionsTable = {
		name = core.titleFull,
		type = "group",
		childGroups = "tab",
	
		get = function(info)
			local key = info[#info]
			return P[key]
		end,
		set = function(info, v)
			local key = info[#info] -- backup_enabled, etc...
			P[key] = v
		end,
		args = {},
	}

	local tostring = tostring
	local GetAddOnMetadata = GetAddOnMetadata
	local pairs = pairs
	local fields = {"Author", "X-Category", "X-License", "X-Email", "Email", "eMail", "X-Website", "X-Credits", "X-Localizations", "X-Donate", "X-Bitcoin"}
	local haseditbox = {["X-Website"] = true, ["X-Email"] = true, ["X-Donate"] = true, ["Email"] = true, ["eMail"] = true, ["X-Bitcoin"] = true}
	local fNames = {
		["Author"] = L.author,
		["X-License"] = L.license,
		["X-Website"] = L.website,
		["X-Donate"] = L.donate,
		["X-Email"] = L.email,
		["X-Bitcoin"] = L.bitcoinAddress,
	}
	local yellow = "|cffffd100%s|r"
	
	local val
	local options
	function core:BuildAboutMenu()
		options = self.options
		
		self.AboutOptionsTable.args.about = {
			type = "group",
			name = L.about,
			order = 99,
			args = {}
		}

		
		self.AboutOptionsTable.args.about.args.title = {
			type = "description",
			name = yellow:format(L.title..": ")..self.title,
			order = 1,
		}
		self.AboutOptionsTable.args.about.args.version = {
			type = "description",
			name = yellow:format(L.version..": ")..self.version,
			order = 2,
		}
		self.AboutOptionsTable.args.about.args.notes = {
			type = "description",
			name = yellow:format(L.notes..": ")..tostring(GetAddOnMetadata(folder, "Notes")),
			order = 3,
		}
	
		for i,field in pairs(fields) do
			val = GetAddOnMetadata(folder, field)
			if val then
				
				if haseditbox[field] then
					self.AboutOptionsTable.args.about.args[field] = {
						type = "input",
						name = fNames[field] or field,
						order = i+10,
						desc = L.clickCopy,
						width = "full",
						get = function(info)
							local key = info[#info]
							return GetAddOnMetadata(folder, key)
						end,	
					}
				else
					self.AboutOptionsTable.args.about.args[field] = {
						type = "description",
						name = yellow:format((fNames[field] or field)..": ")..val,
						width = "full",
						order = i+10,
					}
				end
		
			end
		end
	
		LibStub("AceConfig-3.0"):RegisterOptionsTable(self.title, self.AboutOptionsTable ) --
		LibStub("AceConfigDialog-3.0"):SetDefaultSize(self.title, 600, 500) --680
	end
end