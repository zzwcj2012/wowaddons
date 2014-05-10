-- Author      : AK-48
-- Create Date : 10/2/2013 10:15:03 PM

local _,class = UnitClass("player")
if class ~= "PRIEST" then return end

local MapFiles = LibStub("LibMapData-1.0")

local Spells = {
	CoH = {
		SpellId = 34861,
		SpellName = GetSpellInfo(34861),
		Base = (4599 + 5082) / 2,
		Coff = 0.467,
		Range = 30 ^ 2,
		Icon = "Interface\\Icons\\Spell_Holy_CircleOfRenewal",
	},
	PoH = {
		SpellId = 596,
		SpellName = GetSpellInfo(596),
		Base = (6766 + 7148) / 2,
		Coff = 0.671,
		Range = 30 ^ 2,
		Icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
	},
	SpiritShell = {
		SpellId = 109964,
		SpellName = GetSpellInfo(109964)
	},
	Chakra = {
		SpellId = 81206,
	},
	DivineAegis = {
		SpellId = 47753,
		Icon = "Interface\\Icons\\Spell_Holy_DevineAegis",
		Name = GetSpellInfo(47753),
	},
}

local HealingIncrements = {
	[123254] = 0.15, --Twist of fate
	[109147] = 0.25, --Archangel
	[81206] = 0.25, --Chakara
	[144364] = 0.15, --Power of the titans
}

local UnitGUID = UnitGUID
local GetPlayerMapPosition = GetPlayerMapPosition
local SetMapToCurrentZone = SetMapToCurrentZone
local GetSpellCooldown = GetSpellCooldown
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsVisible = UnitIsVisible
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitIsEnemy = UnitIsEnemy
local UnitIsCharmed = UnitIsCharmed
local UnitIsUnit = UnitIsUnit
local UnitInRange = UnitInRange
local UnitBuff = UnitBuff
local UnitGetIncomingHeals = UnitGetIncomingHeals
local GetSpellCritChance = GetSpellCritChance
local GetSpellBonusHealing = GetSpellBonusHealing
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local tinsert = table.insert
local tsort = table.sort
local select = select
local pairs = pairs
local wipe = wipe
local tostring = tostring
local abs = math.abs

local WorldMapFrame = WorldMapFrame


local map_width = 0
local map_height = 0
local player_x = 0
local player_y = 0
local playerHealingIncrement = 0
local lastRefresh = 0

local groups = {
	[0] = {},
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {},
}
--local unitData = {}
local currentActive = 0
local unitDataActual = {}

local unitData = {
	__index = function(t,val)
		if unitDataActual[val] and unitDataActual[val].currentActive == currentActive then
			return unitDataActual[val]
		else
			return nil
		end
	end
}

setmetatable(unitData,unitData)

local function UpdateRoster()
	groups = {
		[0] = {},
		[1] = {},
		[2] = {},
		[3] = {},
		[4] = {},
	}
	if not IsInRaid() then
		tinsert(groups[0], "player")
		for i = 1, 4 do
			local unitid = "party" .. i
			if UnitExists(unitid) then
				tinsert(groups[0], unitid)
			end
		end
	else
		for i=1,25 do
			local _, _, party = GetRaidRosterInfo(i)
			local unitid = "raid" .. i
			if UnitExists(unitid) and party <= 5 then
				tinsert(groups[party-1], unitid)
			end
		end
	end
end



local function DistanceSq(x1, y1, x2, y2)
	local xx = x2 - x1
	local yy = y2 - y1

	return xx*xx + yy*yy
end

local function IsValidTarget(unitid)
	return not UnitIsDeadOrGhost(unitid) and
				UnitIsConnected(unitid) and
				UnitIsVisible(unitid) and
				not (UnitIsCharmed(unitid) and UnitIsEnemy("player", unitid))
end

local function IsUnitInRange(unitid)
	if UnitIsUnit(unitid, "player") then
		return true
	else
		return UnitInRange(unitid)
	end
end


local function UpdateMapData(map, floor, w, h)
	map_width = w
	map_height = h

	if w == 0 and h == 0 then
		--print("No map data available, status will be disabled. Installing the latest version of LibMapData-1.0 may fix this problem.")
	end
end

local function RefreshMapData()
	if map_width == 0 and map_height == 0 then
		return false
	end

	-- check player position
	player_x, player_y = GetPlayerMapPosition("player")

	-- continue only if map supported
	if (player_x > 0 or player_y > 0) then
		return true
	end

	return false
end

local function GetHealingAmount(spell,unit)
	local slot
	if unit == "player" then
		slot = UnitHealthMax("player") - UnitHealth("player")
	else
		if type(unitData[unit]) ~= "table" then return 0,0 end
		slot = unitData[unit].slot
	end
	local avgAmount = (spell.Base + GetSpellBonusHealing() * spell.Coff) * (1 + playerHealingIncrement)
	local critChance = GetSpellCritChance(2) / 100.0
	local mastery = GetMasteryEffect() / 100.0
	local e,o = 0,0
	if GetSpecialization() == 1 then --Disc
		avgAmount = avgAmount * (1 + mastery / 2)
		e = math_min(slot,avgAmount)
		o = avgAmount - e
		e = e + avgAmount * critChance * (1 + mastery)
		if UnitBuff("player",Spells.SpiritShell.SpellName) then 
			e = avgAmount * ( 1 + critChance * ( 1 + mastery) )
			o = 0
		end
		return e,o
	elseif GetSpecialization() == 2 then --Holy
		e = math_min(slot,avgAmount)
		o = avgAmount - e
		return e,o 
	else return 0,0 end
end



local function RefreshForUnitId(unitid)
	local cx, cy = GetPlayerMapPosition(unitid)
	local health = UnitHealth(unitid) or 1
	local healthMax = UnitHealthMax(unitid) or 1
	if (cx ~= 0 or cy ~= 0) and IsValidTarget(unitid) then
		if not unitDataActual[unitid] then unitDataActual[unitid] = {} end
		unitDataActual[unitid].guid = UnitGUID(unitid)
		unitDataActual[unitid].x = cx * map_width
		unitDataActual[unitid].y = cy * map_height
		unitDataActual[unitid].health = health
		unitDataActual[unitid].healthMax = healthMax
		unitDataActual[unitid].percent = health / healthMax
		unitDataActual[unitid].slot = healthMax - health
		unitDataActual[unitid].currentActive = currentActive
	end
end

local function RefreshPlayerData()
	local k,unitid,v
	--unitData = {}
	currentActive = currentActive + 1
	for i=0,4 do
		for k,unitid in pairs(groups[i]) do
			RefreshForUnitId(unitid)
		end
	end
	playerHealingIncrement = 0
	for k,v in pairs(HealingIncrements) do
		local spellName = GetSpellInfo(k)
		if UnitBuff("player",spellName) then
			playerHealingIncrement = (1 + playerHealingIncrement) * (1 + v) - 1
		end
	end
end

local function RefreshPlayerDataWhenNecessary()
	if GetTime() - lastRefresh  > 0.1 then
		lastRefresh = GetTime()
		RefreshPlayerData()
		return 1
	end
end
local diffThreshold = 0.08

local oldPohTarget = {
	[0] = {},
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {}
}

local function GetPohTargets()
	local spell = Spells.PoH
	local targets = {}
	local healingAmount
	local effectiveHeal,overHeal = GetHealingAmount(spell,"player")
	local averagePohHeal = (effectiveHeal + overHeal) * 5
	local k,unitId
	local bestUnit,bestHealing
	local oldHealing
	local unitHealed
	local bestUnitHealed
	local oldUnitHealed
	for i=0,4 do
		for k,unitId in pairs(groups[i]) do
			if unitData[unitId] then
				effectiveHeal,overHeal = GetHealingAmount(spell,unitId)
				unitData[unitId].POHEffective = effectiveHeal
			end
		end
		bestUnitHealed = 0
		bestUnit = nil
		bestHealing = 0
		oldHealing = nil
		oldUnitHealed = nil
		for k,unitId in pairs(groups[i]) do
			healingAmount = 0
			unitHealed = 0
			if unitData[unitId] then
				local x,y = unitData[unitId].x,unitData[unitId].y
				for _,unitId2 in pairs(groups[i]) do
					if unitData[unitId2] then
						local dist = DistanceSq(x,y,unitData[unitId2].x,unitData[unitId2].y)
						if dist < spell.Range then 
							healingAmount = healingAmount + unitData[unitId2].POHEffective
							unitHealed = unitHealed + 1
						end
					end
				end
				if healingAmount > bestHealing and IsUnitInRange(unitId) then
					bestHealing = healingAmount
					bestUnit = unitId
					bestUnitHealed = unitHealed
				end
				if oldPohTarget[i].unitId and unitId == oldPohTarget[i].unitId then
					oldHealing = healingAmount
					oldUnitHealed = unitHealed
				end
			end
		end
		if bestUnit then 
			if oldPohTarget[i].unitId and IsUnitInRange(oldPohTarget[i].unitId) and 
			abs(bestHealing / averagePohHeal - oldPohTarget[i].healing / averagePohHeal) < diffThreshold then
				bestUnit =  oldPohTarget[i].unitId 
				bestHealing = oldHealing or oldPohTarget[i].healing
				bestUnitHealed = oldUnitHealed or oldPohTarget[i].unitHealed
			end
			oldPohTarget[i].unitId  = bestUnit
			oldPohTarget[i].healing = bestHealing
			oldPohTarget[i].unitHealed = bestUnitHealed
			targets[bestUnit] = { amount = bestHealing / averagePohHeal, unitHealed = bestUnitHealed }
		end
	end
	return targets
end

local function HasGlyph(gid)
	for i = 1, 9 do
		local _, _, _, id = GetGlyphSocketInfo(i)
		if id and gid == id then
			return true
		end
	end
	return false
end

local function CohSortTargets(x, y)
	return x.percent < y.percent
end

local oldCoHTarget = {}

local function GetCohTargets()
	if GetSpecialization() ~= 2 then return end
	local spell = Spells.CoH
	local numCoh = 5
	local healAmount 
	local bestUnit,bestHealing = nil,0
	local effectiveHeal,overHeal = GetHealingAmount(spell,"player")
	local bestDist = 99999999
	local oldHealing

	if HasGlyph(55675) then numCoh = 6 end

	local averageCohHeal = (effectiveHeal + overHeal) * numCoh

	for unitId,p1 in pairs(unitDataActual) do
		if p1.currentActive == currentActive then
			p1.CoHAmount = GetHealingAmount(spell,unitId)
		end
	end
	for unitId,p1 in pairs(unitDataActual) do
		if p1.currentActive == currentActive then
			local candidates = {}
			local x,y = p1.x, p1.y
			healAmount = 0
			for unitId2,p2 in pairs(unitDataActual) do
				if p2.currentActive == currentActive then
					local dist = DistanceSq(x,y,p2.x,p2.y)
					if dist < spell.Range then
						p2.dist = dist
						tinsert(candidates,p2)
					end
				end
			end
			if #candidates > numCoh then 
				tsort(candidates, CohSortTargets)
			end
			local curDist = 0
			for ti = 1, math_min(numCoh, #candidates) do
				healAmount = healAmount + candidates[ti].CoHAmount
				curDist = math_max(curDist,candidates[ti].dist)
			end
			if oldCoHTarget.unitId and unitId == oldCoHTarget.unitId then
				oldHealing = healAmount
			end
			if IsUnitInRange(unitId) then
				if (healAmount > bestHealing) or (healAmount == bestHealing and curDist < bestDist) then
					bestHealing = healAmount
					bestUnit = unitId
					bestDist = curDist
				end
			end
		end
	end
	if oldHealing then oldCoHTarget.healing = oldHealing end
	if oldCoHTarget.unitId and IsUnitInRange(oldCoHTarget.unitId) and 
		(bestHealing / averageCohHeal - oldCoHTarget.healing / averageCohHeal) < diffThreshold then
		bestUnit =  oldCoHTarget.unitId 
		bestHealing = oldCoHTarget.healing
	end
	oldCoHTarget.unitId = bestUnit
	oldCoHTarget.healing = bestHealing

	return bestUnit,bestHealing / averageCohHeal
end

local unitFrameTable = {}
local frameIconTable = {}


local function CreateIcon(parent,icon,x,withText)
	local f
	f=CreateFrame("Frame",nil,parent) 
	f:SetWidth(20)
	f:SetHeight(20)
	f:SetPoint("TOP",x,5,"TOP")
	local t = f:CreateTexture()
	t:SetTexture(icon)
	t:SetAllPoints(f)
	f.texture=t
	f:Hide()
	if withText then
		local text = f:CreateFontString(nil, "OVERLAY")
		text:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
		text:SetAllPoints(true)
		text:Hide()
		f.text = text
	end
	return f
end

local function ShowIcon(unit,poh,o)
	local frame = unitFrameTable[unit]
	if frame then
		if not frameIconTable[frame] then
			frameIconTable[frame] = {
				CoHIcon = CreateIcon(frame,Spells.CoH.Icon,0),
				PoHIcon = CreateIcon(frame,Spells.PoH.Icon,25, true),
				DAIcon = CreateIcon(frame,Spells.DivineAegis.Icon,-25),
			}
		end
	else
		return
	end
	if poh then 
		frame = frameIconTable[frame].PoHIcon 
		frame.text:SetFormattedText("%d", poh)
		frame.text:Show()
	else
		frame = frameIconTable[frame].CoHIcon 
	end
	frame:Show()
	frame:SetAlpha(o)
end

local cd=function(a) local d,e,f=GetSpellCooldown(a)if d and  d~=0 then return d+e-GetTime() else return 0 end end

local gcd=GetSpellInfo(2096)

function CoHCooldown()
	return cd(Spells.CoH.SpellName) <= cd(gcd)
end



local function Update()
	if not RefreshPlayerDataWhenNecessary() then return end
	local DAMaxAmount = 0.6 * UnitHealthMax("player")
	for unit,frame in pairs(unitFrameTable) do
		if frameIconTable[frame] then
			frameIconTable[frame].CoHIcon:Hide()
			frameIconTable[frame].PoHIcon:Hide()
			frameIconTable[frame].DAIcon:Hide()
		end
		if GetSpecialization() == 1 and frameIconTable[frame] then
		local name,_, _, count, _, _, expires,_ , _, _, _, _, _,_,amount = UnitBuff(unit,Spells.DivineAegis.Name,nil,"PLAYER")
		if name and amount then
			frameIconTable[frame].DAIcon:Show()
			frameIconTable[frame].DAIcon:SetAlpha(math_min(1.0,0.3 + amount / DAMaxAmount))
		else
			frameIconTable[frame].DAIcon:Hide()
		end
	end
	end
	local o
	local PoHTargets = GetPohTargets()
	for k,v in pairs(PoHTargets) do
		o = math_min(1.0,v.amount + 0.2)
		ShowIcon(k,v.unitHealed,o)
	end
	if GetSpecialization() == 2 and CoHCooldown() then
		local CoHTarget
		CoHTarget, o = GetCohTargets()
		o = o or 0
		o = math_min(1.0,o + 0.2)
		if CoHTarget then
			ShowIcon(CoHTarget,nil,o)
		end
	end
end


local function Initialize()
	UpdateRoster()
	MapFiles:RegisterCallback("MapChanged", function(event, map, floor, w, h) UpdateMapData(map, floor, w, h) end)

	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	eventFrame:SetScript("OnEvent",function(self,event,...)
		UpdateRoster()
	end)
	hooksecurefunc("CompactUnitFrame_SetUnit",function(frame,unit)
		local oldUnit 
		for k,v in pairs(unitFrameTable) do
			if v == frame then oldUnit = k end
		end
		if oldUnit then unitFrameTable[oldUnit] = nil end
		if unit then 
			unitFrameTable[unit] = frame
		end
	end)
	local timerFrame = CreateFrame("Frame")
	timerFrame:SetScript("OnUpdate", function(self,elapsed)
		Update()
	end)
end

Initialize()

BlzPriestAoeAPI = {
	GetCohTargets = GetCohTargets,
	GetPohTargets = GetPohTargets,
	GetHealingAmount = GetHealingAmount,
	RefreshPlayerData = RefreshPlayerData,
}

