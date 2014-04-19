local GetSpellCooldown = GetSpellCooldown
local GetTime = GetTime

local tFrames = {}
local mainFrame

local function Initialize()
	local currentCount = 0
	local f = CreateFrame("frame")
	f:SetScript("OnUpdate",function(self,elapsed) 
		local x
		if elapsed > 0.5 then
			for i=0,4 do
				x = tFrames[currentCount]
				while x do
					if x.criteria() then if not x.t then x.t = GetTime() end if x.t - GetTime() < 3 and x.s then x.f:SetAlpha(1) else x.f:SetAlpha(x.opacity) end else x.f:SetAlpha(0) x.t = nil end
					x = x.next
				end
			end
			return
		end
		x = tFrames[currentCount]
		while x do
			if x.criteria() then x.f:SetAlpha(x.opacity) else x.f:SetAlpha(0) end
			x = x.next
		end
		currentCount = currentCount + 1
		if currentCount > 4 then currentCount = 0 end
	end)
	f:SetScript("OnEvent",function(self,event,...)
		local x = tFrames[event]
		while x do
			if x.criteria(...) then x.f:SetAlpha(x.opacity) else x.f:SetAlpha(0) end
			x = x.next
		end
	end)
	mainFrame = f
end

local roundRobin = 0

local function Register(f,c,o,events)
	local tt = {}
	local k,v
	tt.f = f
	tt.criteria = c
	tt.opacity = o
	if not events then
		tt.next = tFrames[roundRobin]
		tFrames[roundRobin] = tt
		roundRobin = roundRobin + 1
		if roundRobin > 4 then roundRobin = 0 end
	else
		for k,v in pairs(events) do
			if not tFrames[v] then mainFrame:RegisterEvent(v) end
			tt.next = tFrames[v]
			tFrames[v] = tt
		end
	end
end

local cd=function(a) local d,e,f=GetSpellCooldown(a)if d and  d~=0 then return GetTime()-d+e else return 0 end end

local gcd=GetSpellInfo(2096)

local function CreateFrameWithIcon(icon,x,y,w,h,frameType)
	local f
	if not frameType then frameType = "Frame" end
	f=CreateFrame(frameType,nil,UIParent) 
	f:SetWidth(w)
	f:SetHeight(h)
	f:SetPoint("CENTER",x,y)
	local t = f:CreateTexture()
	t:SetTexture(icon)
	t:SetAllPoints(f)
	f.texture=t
	local text = f:CreateFontString(nil, "OVERLAY")
	text:SetFont(STANDARD_TEXT_FONT, 15, "OUTLINE")
	text:SetAllPoints(true)
	text:Hide()
	f.text = text
	return f
end


function CreateCD(spell,x,y,w,h,o,additionalCriteriaString,s, sound)
	local c,_,z=GetSpellInfo(spell)
	local f = CreateFrameWithIcon(z,x,y,w,h)
	f.s = s	
	f.t = true
	local criteriaString = "IsSpellKnown(spell) and cd(c)<=cd(k)"
	if additionalCriteriaString then
		criteriaString = criteriaString .. " and " .. additionalCriteriaString
	end
	local criteriaActual = "if " .. criteriaString .. " then if not f.t then f:Show() if sound then PlaySound(sound) end end f.t = true return true else f.t = nil f:Hide() return false end"
	local criteria = loadstring(criteriaActual)
	setfenv(criteria,{f = f,spell=spell, cd = cd, c=c, k=gcd, IsSpellKnown = IsSpellKnown, UnitHealth = UnitHealth, UnitHealthMax = UnitHealthMax, UnitIsEnemy = UnitIsEnemy, sound = sound, PlaySound = PlaySound})
	Register(f,criteria,o)
end

function CreateBuff(spell,x,y,w,h,o,target,ismine,duration,sound)
	local c,_,z = GetSpellInfo(spell)
	local f
	local filter = nil
	local cooldownFrame
	if duration then
		f = CreateFrameWithIcon(z,x,y,w,h,"Cooldown")
	else
		f = CreateFrameWithIcon(z,x,y,w,h)
	end
	if ismine then filter = "PLAYER" end
	local criteriaString = "if UnitBuff(target,spell,filter) then if not f.t then f:Show() if sound then PlaySound(sound) end end f.t = true return true else f.t = nil f:Hide() return false end"
	if duration then
		--cooldownFrame = CreateFrame("Cooldown",nil ,UIParent)
		--cooldownFrame:SetAllPoints(f)
		f:SetReverse(false)
		criteriaString = "if UnitBuff(target,spell,filter) then if not f.t then f:Show() if sound then PlaySound(sound) end f:SetCooldown(GetTime(), duration) end f.t = true return true else f.t = nil f:Hide() return false end"
		f:SetScript("OnUpdate", function(self, ...) 
			local dur = select(7,UnitBuff(target,c,filter))
			if dur then
				f.text:SetFormattedText("%.1f", dur - GetTime())
				f.text:Show()
			else
				f.text:Hide()
			end
		end)
	end
	f:SetAlpha(0)

	local criteria = loadstring(criteriaString)
	setfenv(criteria,{UnitBuff = UnitBuff, target = target, spell = c, filter = filter,f = f,duration = duration,GetTime = GetTime, sound = sound, PlaySound = PlaySound})
	Register(f,criteria,o, {UNIT_AURA = "UNIT_AURA"})
end

function CreateRapture(x,y,w,h,o)
	local _, class = UnitClass("player")
	if class ~= "PRIEST" then return end
	local c,_,z = GetSpellInfo(17)
	local f = CreateFrameWithIcon(z,x,y,w,h)
	local eventFrame = CreateFrame("Frame")
	local soundPlayed = true
	eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	eventFrame.lastTime = 0
	eventFrame:SetScript("OnEvent",function(self, event, ...)
		local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId = select(1, ...)
		if eventType == "SPELL_ENERGIZE" then
			local player_name = UnitName("player")
			if destName == player_name and sourceName == player_name and spellId == 47755 then
				self.lastTime = GetTime()
				soundPlayed = false
			end
		end
		if GetTime() - self.lastTime > 12  and not soundPlayed then
				soundPlayed =  true
				PlaySound("QUESTADDED")
		end
		if GetTime() - self.lastTime < 12 then
			f.text:SetFormattedText("%.1f", 12 - GetTime() + self.lastTime)
			f.text:Show()
		else
			f.text:Hide()
		end
	end)
	eventFrame.lastTime = 0
	local criteriaString = "return GetSpecialization() == 1"
	local criteria = loadstring(criteriaString)
	setfenv(criteria,{f = eventFrame,GetTime = GetTime, GetSpecialization = GetSpecialization})
	Register(f,criteria,o)
end

Initialize()
CreateCD(32379,0,0,128,128,0.5,[[IsSpellKnown(8092) and UnitHealth("target") > 0 and UnitHealth("target") / UnitHealthMax("target") < 0.2 and UnitIsEnemy("target","player")]]) --Death
--CreateCD(8092,0,-120,48,48,0.5) --Mind Blast

CreateBuff(31821,-160,-100,48,48,0.8,"player",nil) --Shadow Fiend
CreateCD(10060,80,-120,48,48,0.5) --Power Infusion

CreateBuff(137247,-190,-120,48,48,0.8,"player",nil, 4, "AuctionWindowOpen") --Lucidity

CreateCD(34433,-170,-140,48,48,0.5,nil,nil,"AuctionWindowClose") --Shadow Fiend
CreateRapture(-150,-120,48,48,0.5)
CreateBuff(48517,-150,-120,48,48,0.8,"player",nil)
CreateBuff(48518,-150,-120,48,48,0.8,"player",nil) 
