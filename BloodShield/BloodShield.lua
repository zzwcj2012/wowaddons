local _,class = UnitClass("player")
if class ~= "DEATHKNIGHT" then return end

local eventFrame = CreateFrame("Frame")
local playerGUID = UnitGUID("player")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

local damageInWindow = 0
local damages = {}

local function ClearOutdatedDamage()
	local currentTime = GetTime()
	local newDamages = {}
	for k,v in pairs(damages) do
		if currentTime - k > 5 then
			damageInWindow = damageInWindow - v
		else
			newDamages[k] = v
		end
	end
	damages = newDamages
end

local function AddDamage(time, amount)
	damages[time] = (damages[time] or 0) + amount
	damageInWindow = damageInWindow + amount
end

eventFrame:SetScript("OnEvent",function(self, event, 
	timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, ...)
	local currentTime = GetTime()
	if destGUID == playerGUID then
		if  eventType == "SPELL_DAMAGE" or 
			eventType == "SPELL_PERIODIC_DAMAGE" or
			eventType == "SPELL_BUILDING_DAMAGE" or
			eventType == "RANGE_DAMAGE" then
			local spellId, spellName, spellSchool, amount = ...
			AddDamage(currentTime, amount)
		elseif eventType == "SWING_DAMAGE" then
			local amount = ...
			AddDamage(currentTime, amount)
		end
	end
end)


local function CreateFrameWithIcon(icon,x,y,w,h)
	local f
	f=CreateFrame("Frame",nil,UIParent) 
	f:SetWidth(w)
	f:SetHeight(h)
	f:SetPoint("CENTER",x,y)
	local t = f:CreateTexture()
	t:SetTexture(icon)
	t:SetAllPoints(f)
	f.texture=t
	return f
end

local _,_,tex = GetSpellInfo(49998)
local icon = CreateFrameWithIcon(tex,-70 ,-30 ,48,48,0.7)
local buffName = GetSpellInfo(49509)
local vampName = GetSpellInfo(55233)


local function GetBloodShieldAmount()
	ClearOutdatedDamage()
	local mastery = GetMasteryEffect() / 100.0
	local _, _ , _ , buffStacks = UnitBuff("player",buffName)
	local healingBonus = 1.0
	if UnitBuff("player",vampName) then
		healingBonus = 1.25
	end
	buffStacks = buffStacks or 0
	local healing  = math.max(damageInWindow * 0.2, 0.07 * UnitHealthMax("player")) * healingBonus  * (1.0 + buffStacks * 0.2) 
	local hole = UnitHealthMax("player") - UnitHealth("player")
	local effectiveHealing = math.min(hole, healing)
	return healing * mastery + effectiveHealing
end

local function sortArray(arr, count)
	local i,j
	for i=0,count -1 do
		for j=i,count -1 do
			if arr[i] > arr[j] then
				local t = arr[i]
				arr[i] = arr[j]
				arr[j] = t
			end
		end
	end
end


local deathTime = {}
local frostTime = {}
local unholyTime = {}
local cooldownTimes = {}
	
local function GetDeathStrikeCooldown()
	local deathCount = 0
	local frostCount = 0
	local unholyCount = 0
	local i
	for i=1,6 do 
		local runeType = GetRuneType(i)
		local start, duration = GetRuneCooldown(i)
		local t
		if start == nil or start == 0 then
			t = 0
		else
			t = start + duration - GetTime()
		end
		if runeType == 2 then
			unholyTime[unholyCount] = t
			unholyCount = unholyCount + 1
		elseif runeType == 3 then
			frostTime[frostCount] = t
			frostCount = frostCount + 1
		elseif runeType == 4 then
			deathTime[deathCount] = t
			deathCount = deathCount + 1
		end
	end
	sortArray(unholyTime, unholyCount)
	sortArray(frostTime, frostCount)
	sortArray(deathTime, deathCount)
	
	local frostIndex = 0
	local unholyIndex = 0
	local deathIndex = 0
	for i=1,2 do
		local frostRequired,unholyRequired,deathRequired,time
		local optTime, optFrost, optUnholy, optDeath
		for frostDeath = 0,1 do
			for unholyDeath = 0,1 do
				frostRequired = frostDeath > 0 and 0 or 1
				unholyRequired = unholyDeath > 0 and 0 or 1
				deathRequired = 2 - frostRequired - unholyRequired
				time = 0
				if frostCount < frostRequired or unholyCount < unholyRequired or deathCount < deathRequired then else
					if frostRequired > 0 then time = math.max(frostTime[frostIndex],time) end
					if unholyRequired > 0 then time = math.max(unholyTime[unholyIndex],time) end
					if deathRequired > 0 then time = math.max(deathTime[deathIndex],time) end
					if deathRequired > 1 then time = math.max(deathTime[deathIndex + 1],time) end
					if not optTime or time < optTime then
						optTime = time
						optFrost = frostRequired
						optUnholy = unholyRequired
						optDeath = deathRequired
					end
				end
			end
		end
		
		frostCount = frostCount - optFrost
		unholyCount = unholyCount - optUnholy
		deathCount = deathCount - optDeath
		frostIndex = frostIndex + optFrost
		unholyIndex = unholyIndex + optUnholy
		deathIndex = deathIndex + optDeath
		cooldownTimes[i] = optTime

	end

	return cooldownTimes
end

local text = icon:CreateFontString(nil, "OVERLAY")
text:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
text:ClearAllPoints()
text:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
text:SetSize(48, 24)
text:SetText("0")

local textCount = icon:CreateFontString(nil, "OVERLAY")
textCount:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
textCount:ClearAllPoints(true)
textCount:SetPoint("TOPLEFT", icon, "TOPLEFT", 5 , -5)

local textCooldown = icon:CreateFontString(nil, "OVERLAY")
textCooldown:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
textCooldown:SetAllPoints(true)
textCooldown:SetSize(48, 24)

local counter = 5

icon:SetScript("OnUpdate", function()
--threshold updating to save CPU
	counter = counter + 1 
	if counter > 5 then counter = 0 end
	if counter > 0 then return end

	local amount = GetBloodShieldAmount()
	text:SetFormattedText("%.2fw", amount / 10000)
	local cooldowns = GetDeathStrikeCooldown()
	local cd
	local count = 0
	for i=1,2 do
		if cooldowns[i] == 0 then 
			count = count + 1 
		else
			if not cd then cd = cooldowns[i] else if cd > cooldowns[i] then cd = cooldowns[i] end end
		end
	end
	if count == 0 then
		icon:SetAlpha(0.5)
		textCount:Hide()
	else
		icon:SetAlpha(0.8)
		textCount:Show()
		textCount:SetFormattedText("%d", count)
	end
	if cd then
		textCooldown:Show()
		textCooldown:SetFormattedText("%.1f", cd)
	else
		textCooldown:Hide()
	end
end)

icon:Show()