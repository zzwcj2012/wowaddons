local AM_DispelTable = {
	[4] = { --Fully CC Buffs
		[1] = GetSpellInfo(118), -- Polymorph
		[2] = GetSpellInfo(5782), --Fear
		[3] = GetSpellInfo(8122), --Psychic Scream
		[4] = GetSpellInfo(6358), --Seduction
		[5] = GetSpellInfo(6789), --Death Coil
		[6] = GetSpellInfo(64044), --Psychic Horror
		[7] = GetSpellInfo(44572), --Deep Freeze
		[8] = GetSpellInfo(853), --Hammer of Justice
		[9] = GetSpellInfo(20066), --Repentance
		[10] = GetSpellInfo(1499), --Frozen Trap
		[11] = GetSpellInfo(44572),  --Deep Freeze
		[12] = GetSpellInfo(30752), --30752
	},
	[3] = { --Silence and Immobilize Buffs
		[1] = GetSpellInfo(15487), --Silence
		[2] = GetSpellInfo(19647), --Spell Lock
		[3] = GetSpellInfo(12598), --Improved Counterspell
		[4] = GetSpellInfo(122),   --Frost Nova
		[5] = GetSpellInfo(54787), 
		[6] = GetSpellInfo(40875), 
		[7] = GetSpellInfo(339),   --Entangling Roots
		[8] = GetSpellInfo(47476), --Strangulate
		[9] = GetSpellInfo(50245), --Pin
		[10] = GetSpellInfo(4167), --Web
		[11] = GetSpellInfo(12497), -- Frostbite
	},
	[2] = { --Less critical but worthy of dispeling
		[1] = GetSpellInfo(770), --Faerie Fire
		[2] = GetSpellInfo(348), --Immolate
		[3] = GetSpellInfo(8050),--Flame Shock
		[4] = GetSpellInfo(116), --Frost Blot
	},
	[1] = {}, --腐蚀啥的 就不写了
}

local AM_DispelTableEnemy = {
    [2] = {
			[1] = GetSpellInfo(1044), -- Hand of Freedom
			[2] = GetSpellInfo(1022), -- Hand of Protection
			[3] = GetSpellInfo(17),   -- Power Word: Sheild
			[4] = GetSpellInfo(29166),-- Innervate
			[5] = GetSpellInfo(12472),-- Icy Veins
			[6] = GetSpellInfo(12042),-- Arcane Power
			[7] = GetSpellInfo(10060),-- Power Infusion
			[8] = GetSpellInfo(6346), -- Fear Ward
			
	},
	[1] = {
			[1] = GetSpellInfo(11426),-- Ice Barrier
			[2] = GetSpellInfo(44543),-- Fingers of Frost
			[3] = GetSpellInfo(47258),-- 
			[4] = GetSpellInfo(54370),-- Nether Protection
			[5] = GetSpellInfo(33076),--POM
	},

	[-100] = {
			[1] = GetSpellInfo(642),  -- Divine Sheild
			[2] = GetSpellInfo(45438),-- Ice Block
			[3] = GetSpellInfo(33206),-- Pain Suppression
	},
			
}
local DispelSpell = nil
local DispelUnit = nil

local function _strcontains(str,find)
	if not str then return false end
	str=strlower(str);
	find=strlower(find)
	if str==find then
		return 1
	end
	return strfind(str,find,1,true)
end

local function DispelProbability(debuffnum)
	if debuffnum <=2 then return 1.0 end
	return 2.0 / debuffnum / (debuffnum-1)
end

local function EvalSingleUnit(unit)
	local EvalMax = 0
	local EvalCurrent = 0
	local i,debuffCount
	debuffCount = 0
	local k,v,vv
	local DispelTable
	local BuffFunction

	if not UnitExists(unit) then return 0 end
	if not SpellCastable(DispelSpell,unit) then return -1 end

	if UnitIsEnemy(unit,"player") then 
		DispelTable = AM_DispelTableEnemy
		BuffFunction = UnitBuff
	else 
		DispelTable = AM_DispelTable
		BuffFunction = UnitDebuff
	end

	for i=1,64 do
		local name,_, _, _, debuffType , _, expires = BuffFunction(unit,i)
		if name and _strcontains(debuffType,"magic") then
			debuffCount = debuffCount + 1
		end
	end
	
	for i=1,64 do
		local name,_, _, _, debuffType , _, expires = BuffFunction(unit,i)
		if _strcontains(debuffType,"magic") then
			for k,v in pairs(DispelTable) do
				for _,vv in pairs(v) do
					if name and _strcontains(name,vv) then
						EvalCurrent = k*1000 + DispelProbability(debuffCount) * (expires - GetTime())
						if EvalCurrent > EvalMax then EvalMax = EvalCurrent end
					end
				end
			end
		end
	end
	
	if EvalMax > 0 then return EvalMax else return debuffCount end
	
end

function AutoDispel_Init(unitlist,dispelspell)
	local v
	local EvalMax = 0
	
	DispelUnit = nil
	DispelSpell = dispelspell or ""
	local AM_UnitList = AM_AutoSel_GetList()
	if not AM_UnitList[unitlist] then return false end
	
	for _,v in pairs(AM_UnitList[unitlist]) do
		local EvalCurrent = EvalSingleUnit(v)
		if EvalCurrent > EvalMax then
			DispelUnit = v
			EvalMax = EvalCurrent
		end
	end
	
	return DispelUnit
end

function AutoDispel_IsUnit(unit)
	if not DispelUnit then return false end
	return UnitIsUnit(unit,DispelUnit)
end

function AutoDispel_CreateMacroButton()
	local AM_UnitList = AM_AutoSel_GetList()
	local PlayerClass = select(2,UnitClass("player"))
	local _DispelSpell

	if PlayerClass == "PRIEST" then
		_DispelSpell = GetSpellInfo(527)
	elseif PlayerClass == "PALADIN" then
		_DispelSpell = GetSpellInfo(4987)
	elseif PlayerClass == "SHAMAN" then
		_DispelSpell = GetSpellInfo(370)
	else
		return
	end

	local k,v
	for k,v in pairs(AM_UnitList) do
		local str = '/if AutoDispel_Init("%s","%s")\n/run AutoSelInit("%s",AutoDispel_IsUnit)\n'
		.. '/click AutoSel%s\n/if AutoSelOK()\n/cast %s\n/if AutoSelNeedTarget()\n' ..
		'/targetlasttarget\n/end\n/end\n/end'

		local macroText = string.format(str,k,_DispelSpell,k,k,_DispelSpell)

		local frameName = "AutoDispel" .. k .. "Button"

		local macrobutton = CreateFrame("Button",frameName,UIParent,"SecureActionButtonTemplate")

		macrobutton:SetAttribute("type","macro")
		macrobutton:SetAttribute("macrotext",macroText)
	end

end

AutoDispel_CreateMacroButton()