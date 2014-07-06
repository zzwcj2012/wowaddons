---×÷Õß AK-48 <ak48disk@gmail.com>
---Ò»Çø °Â´ïÂü ÃÎÓêÂä·ç

local function CreateVengeanceBug(BSTStateProvider)


local _,class = UnitClass("player")
if class ~= "PALADIN" then return end

local function CreateFrameWithIcon(icon,x,y,w,h,frameType, template)
	local f
	if not frameType then frameType = "Frame" end
	f=CreateFrame(frameType,nil,UIParent, template) 
	f:SetWidth(w)
	f:SetHeight(h)
	f:SetPoint("CENTER",x,y)
	local t = f:CreateTexture()
	t:SetTexture(icon)
	t:SetAllPoints(f)
	f.texture=t
	return f
end


local function UnitAuraTime(target,aura,ismine,spellid)
	for i=1,64 do
		local filter 
		if ismine then
			local filter = "PLAYER"
		end
		
		local name,_, _, count, _, _, expires,_,_,_,id  = UnitAura(target,i,filter)
			
		if name and name == aura then
			if spellid and id ~= spellid then else
				return expires - GetTime(),count
			end
		end
	end
	for i=1,64 do
		local name,_, _, count, _, _, expires,caster,_,_,id = UnitDebuff(target,i)
		if name and name == aura then
			if spellid and id ~= spellid then else
			if ismine and caster~= "player" then else return expires - GetTime(),count end
		end
		end
	end
end



local name, _ ,icon = GetSpellInfo(53600)
local DivinePurpose = GetSpellInfo(90174)
local Vengeance, _, VengeanceIcon = GetSpellInfo(84839)

local function Cooldown(spell)
	local CD,Dur = GetSpellCooldown(spell)
	if CD > 0 then return CD + Dur - GetTime() end
	return 0
end

local function CanShield()
	local holyPower = UnitPower("player",SPELL_POWER_HOLY_POWER)
	if Cooldown(name) < 0.2 then
		return UnitAuraTime("player",DivinePurpose) or (holyPower > 2)
	end
	return false
end

local executors, stateProvider = {}

local function createCombatLogProvider()
	local lastSwingTime = 0
	local frame = CreateFrame("Frame")

	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:SetScript("OnEvent", function(self, event,...)
		local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg1, arg2, arg3, arg4, arg5, arg6 = select(1, ...)
		local shieldTime = UnitAuraTime("player", name)
		if not shieldTime and UnitName("target") == sourceName and destName == UnitName("player") then
			if eventType == "SWING_DAMAGE" then
				lastSwingTime = GetTime()
			end
			if eventType == "SWING_MISSED"  and arg1 == "ABSORB" and arg3 > 100000 then 
				lastSwingTime = GetTime()
			end
			if eventType == "SPELL_DAMAGE" and arg6 == 1 and arg4 > 300000 then
				lastSwingTime = GetTime()
			end
		end
	end) 
	return function()
		local shieldTime = UnitAuraTime("player",name)
		if not shieldTime and CanShield() and GetTime() - lastSwingTime < 0.35 then
			return true
		else
			return false
		end
	end
end


local function CreateAutoButton()
	
	local function CreateBlockers(prefix,n)
		local i
		for i=1,n do
			local buttonName = prefix .. "B" .. i
			local buttonFrame = CreateFrame("Button",buttonName ,UIParent,"SecureActionButtonTemplate")
			buttonFrame:SetAttribute("type","macro")
			buttonFrame:SetAttribute("macrotext","/clearfocus")
		end
	end

	local function CreateCasters(prefix,n)
		local i
		for i=1,n do
			local buttonName = prefix .. "C" .. i
			local buttonFrame = CreateFrame("Button",buttonName ,UIParent,"SecureActionButtonTemplate")
			buttonFrame:SetAttribute("type","macro")
			buttonFrame:SetAttribute("macrotext","/cast [@focus]" .. name)
		end
	end

	local function RandString(length)
		local dict = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
		local r = ""
		local l = #dict
		local p
		for i = 1, length do
		  p = math.random(l)
		  r = r.. string.sub(dict, p, p)
		end
		return r
	end


	local n = 10000
	local buttonToClick = {}
	local str = ""
	local i,index

	local prefix = RandString(3)
	CreateBlockers(prefix,n)
	CreateCasters(prefix,n)

	index = 0
	for i=1,n do
		index = index + 1
		buttonToClick[index] = prefix .. "B" .. i
		index = index + 1
		buttonToClick[index] = prefix .. "C" .. i
	end

	local generation = 0
	while #buttonToClick > 1 do
		local newButtons = {}
		local parent, parentName
		index = 1
		for i=1,#buttonToClick do
			if not parent then
				parentName = prefix .. generation .. index
				parent = CreateFrame("Button", parentName ,UIParent,"SecureActionButtonTemplate")
				newButtons[index] = parentName
				index = index + 1
				str = ""
			end

			local s = "/click " .. buttonToClick[i] .. "\n"
			if generation > 0 then
				 s = "/click [@focus,harm]" .. buttonToClick[i] .. "\n"
			end

			str = str .. s
			_G[buttonToClick[i]].parent = parent
			parent.num = parent.num and parent.num + 1 or 1

			if str:len() > 500 or i == #buttonToClick then 
				parent:SetAttribute("type","macro")
				parent:SetAttribute("macrotext",str)
				parent = nil
			end
		end
		generation = generation + 1
		buttonToClick = newButtons
	end

	local autoButton = CreateFrame("Button", "VengeanceButton" ,UIParent,"SecureActionButtonTemplate")
	autoButton:SetAttribute("type","macro")
	autoButton:SetAttribute("macrotext","/focus\n/click " .. buttonToClick[1] .. "\n/clearfocus")

	local function stateUpdater(prefix)
		local state = false
		local curr = 1

		local function disable(button)
			button:SetScript("OnClick", nil)
			if button.parent then
				button.parent.num = button.parent.num - 1
				if button.parent.num <= 0 then
					disable(button.parent)
				end
			end
		end

		local function switch()
			local frame
			if not state then
				state = true
				frame = _G[prefix .. "B" .. curr]
				disable(frame)
			else
				state = false
				frame = _G[prefix .. "C" .. curr]
				disable(frame)
				curr =  curr + 1
			end
		end

		return function(newState)
			if state ~= newState then
				switch()
			end
		end
	end

	return stateUpdater(prefix)
end


local autoButtonStateUpdater = CreateAutoButton()
table.insert(executors,autoButtonStateUpdater)

stateProvider = createCombatLogProvider()

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function()
	local state
	if BSTStateProvider and BSTStateProvider.enabled() then
		state = BSTStateProvider.state()
	else
		state = stateProvider()
	end
	
	for _, executor in pairs(executors) do
		executor(state)
	end
end)

end

--To add BST support must implement BSTStateProvider
-- function BSTStateProvider.enabled() (true/false) 
-- function BSTStateProvider.state() give state, true if SoR can be cast
--BSTStateProvider should be the first parameter of CreateVengeanceBug
CreateVengeanceBug(BSTStateProvider)


