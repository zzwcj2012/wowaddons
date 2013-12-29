--[[
	Copyright (C) 2006-2007 Nymbia
	Copyright (C) 2010 Hendrik "Nevcairiel" Leppkes < h.leppkes@gmail.com >
	Copyright (C) 2011 一区 奥达曼 入戏				< ak48disk@gmail.com  >

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
]]
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")

local MODNAME = "Latency"
local Latency = Quartz3:NewModule(MODNAME, "AceEvent-3.0", "AceHook-3.0")
local Player = Quartz3:GetModule("Player")

local media = LibStub("LibSharedMedia-3.0")
local lsmlist = AceGUIWidgetLSMlists

----------------------------
-- Upvalues
local GetTime = GetTime
local unpack = unpack

local lagbox, lagtext, db, timeDiff, sendTime, alignoutside

local getOptions

local defaults = {
	profile = {
		lagcolor = {1, 0, 0},
		lagalpha = 0.6,
		lagtext = true,
		lagfont = "Friz Quadrata TT",
		lagfontsize = 7,
		lagtextcolor = {0.7, 0.7, 0.7, 0.8},
		lagtextalignment = "center", -- L["Left"], L["Right"]
		lagtextposition = "bottom", --L["Top"], L["Above"], L["Below"]
		
		-- With "embed", the lag indicator is placed on the left hand side of the bar instead of right for normal casting 
		-- and the castbar time is shifted so that the end of the time accounting for lag lines up with the right hand side of the castbar
		-- For channeled spells, the lag indicator is shown on the right, and the cast bar is adjusted down from there 
		-- lagpadding is applied only if lagembed is enabled
		lagembed = false,
		lagpadding = 0.0,
	}
}

function Latency:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile
	
	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Latency"])
end

function Latency:OnEnable()
	self:RawHook(Player, "UNIT_SPELLCAST_START")
	self:RawHook(Player, "UNIT_SPELLCAST_DELAYED")
	
	self:RegisterEvent("UNIT_SPELLCAST_SENT")
	self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
	self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	media.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(mtype, override)
		if mtype == "statusbar" then
			for i=1,15 do 
				lagbox[i]:SetTexture(media:Fetch("statusbar", override))
			end
		end
	end)
	if not lagbox then
		lagbox = {}
		for i=1,15 do
			lagbox[i] = Player.Bar.Bar:CreateTexture(nil, "BACKGROUND")
		end
		lagtext = Player.Bar.Bar:CreateFontString(nil, "OVERLAY")
		self.lagbox = lagbox
		self.lagtext = lagtext
	end
	self:ApplySettings()
end

function Latency:OnDisable()
	media.UnregisterCallback(self, "LibSharedMedia_SetGlobal")
	for i=1,15 do
		lagbox[i]:Hide()
	end
	lagtext:Hide()
end

function Latency:UNIT_SPELLCAST_SENT(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	sendTime = GetTime()
end

local channelingTicks = {
	-- warlock
	[GetSpellInfo(1120)] = 6, -- drain soul
	[GetSpellInfo(689)] = 6, -- drain life
	[GetSpellInfo(103103)] = 4, -- Malefic Grasp
	[GetSpellInfo(5740)] = 6, -- rain of fire
	[GetSpellInfo(108371)] = 6, -- harvest life
	-- druid
	[GetSpellInfo(740)] = 4, -- Tranquility
	[GetSpellInfo(16914)] = 10, -- Hurricane
	[GetSpellInfo(106996)] = 10, -- Astral Storm
	-- priest
	[GetSpellInfo(15407)] = 3, -- mind flay
	[GetSpellInfo(129197)] = 3, -- mind flay(i)
	[GetSpellInfo(48045)] = 5, -- mind sear
	[GetSpellInfo(47540)] = 2, -- penance
	[GetSpellInfo(64843)] = 4, -- Devine Hymn
	[GetSpellInfo(64904)] = 4, -- Hymn of hope
	
	-- mage
	[GetSpellInfo(5143)] = 5, -- arcane missiles
	[GetSpellInfo(10)] = 8, -- blizzard
	[GetSpellInfo(12051)] = 3, -- evocation

	-- monk
	[GetSpellInfo(125953)] = 9, -- soothing mist
	[GetSpellInfo(117952)] = 6, -- crackling jade lightning
}

local channelingTimeGCDs = {
	[GetSpellInfo(15407)] = 2, -- mind flay
	[GetSpellInfo(48045)] = 5/1.5, -- mind sear
	[GetSpellInfo(1120)] = 12/1.5, -- drain soul
	[GetSpellInfo(689)] = 6/1.5, -- drain life
	[GetSpellInfo(108371)] = 6/1.5, -- harvest life
	[GetSpellInfo(103103)] = 4/1.5, -- Malefic Grasp
	[GetSpellInfo(129197)] = 2, -- mind flay(i)
}

local function GetPlayerChannelTicks()
	local spell = UnitChannelInfo("player")
	--[[
	FIX ME:
	if not Player.db.showticks then
		return 1
	end
	--]]
	return channelingTicks[spell] or 1
end

local function FindDevouringPlagueEndTime()
	local aura = GetSpellInfo(2944)
	for i=1,64 do
		local name,_, _, count, _, _, expires,caster = UnitDebuff("target",i)
		if name and name == aura then
			if caster == "player" then return expires end
		end
	end
end

local function UpdateLagboxColorWithMindFlayInsanityIndicator(bar)
	local r,g,b = unpack(db.lagcolor)
	for i=1,15 do
		lagbox[i]:SetVertexColor(r,g,b)
	end
	if not bar.channelTime then return end
	local spell = UnitChannelInfo("player")
	local startTime, endTime = bar.startTime, bar.endTime
	if spell~= GetSpellInfo(129197) then return end
	local plagueTime = FindDevouringPlagueEndTime()
	for i=1,5 do
		local tickTime = endTime - (i-1)*bar.channelTime/channelingTimeGCDs[spell]/1000
		if not plagueTime or tickTime - plagueTime > -0.2 then
			lagbox[i]:SetVertexColor(r,g,b)
		else
			lagbox[i]:SetVertexColor(0,1,0)
		end
	end
end

local function UpdateLagboxes(bar,ignore)
	local startTime, endTime = bar.startTime, bar.endTime
	if not ignore and (not sendTime or not endTime) then return end

	local castlength = endTime - startTime
	local perc = timeDiff / castlength
	local numTicks
	local delay = bar.delay
	local side
	
	for i=1,15 do
		lagbox[i]:ClearAllPoints()
	end

	UpdateLagboxColorWithMindFlayInsanityIndicator(bar)
	
	if bar.casting then
		side = "RIGHT"
		numTicks = 1
		lagbox[1]:SetTexCoord(1-perc,1,0,1)
	else -- channeling
		side = "LEFT"
		numTicks = GetPlayerChannelTicks()
		for i=1,numTicks do
			lagbox[i]:SetTexCoord(perc,1,0,1)
		end
	end
	local w = Player.Bar.Bar:GetWidth()

    if GetSpellInfo("Mind Blast") then
		local d,e,f=GetSpellCooldown("Mind Blast")
		local mindEndTime
		if d and d~=0 then 
			mindEndTime = d+e
		else 
			mindEndTime = 0 
		end
		
		if mindEndTime > 0 and mindEndTime <= endTime then
			lagbox[15]:SetVertexColor(1,1,0)
			lagbox[15]:SetTexCoord(perc,1,0,1)
			lagbox[15]:SetDrawLayer(side == "LEFT" and "OVERLAY" or "BACKGROUND")
			lagbox[15]:SetPoint(side, Player.Bar.Bar , side , (endTime - mindEndTime) / castlength,0)
			lagbox[15]:SetWidth(w * perc)
			lagbox[15]:Show()
		else
			lagbox[15]:Hide()
		end
	end
	
	if bar.channelTime and castlength * 1000 > bar.channelTime + 10 then 
		local coefficient = castlength / bar.channelTime * 1000
		if delay < 0 then
			delay = 0
		end
		for i=1,numTicks+1 do
			lagbox[i]:SetTexCoord(perc,1,0,1)
			lagbox[i]:SetDrawLayer(side == "LEFT" and "OVERLAY" or "BACKGROUND")
			lagbox[i]:SetPoint(side, Player.Bar.Bar , side , w / numTicks * (i - 1) / coefficient  - w * delay / castlength,0)
			if w / numTicks * (i - 1) / coefficient  - w * delay / castlength >= 0 then
				lagbox[i]:SetWidth(w * perc)
				lagbox[i]:Show()
			else
				lagbox[i]:Hide()
			end
		end
	else
		local coefficient = 1
		if delay < 0 then
			coefficient = (castlength-delay) / castlength
			delay = 0
		end
		for i=1,numTicks do
			lagbox[i]:SetTexCoord(perc,1,0,1)
			lagbox[i]:SetDrawLayer(side == "LEFT" and "OVERLAY" or "BACKGROUND")
			lagbox[i]:SetPoint(side, Player.Bar.Bar , side , w / numTicks * (i - 1) / coefficient - w * delay / castlength ,0)
			lagbox[i]:SetWidth(w * perc)
			lagbox[i]:Show()
		end
	end
end

function Latency:UNIT_SPELLCAST_SUCCEEDED(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	--sendTime = nil
	--not necessary here, because it may cause some latency fail to show
	--due to the latency that UNIT_SPELLCAST_SUCCEEDED may cause UNIT_SPELLCAST_SUCCEEDED of last spell fires after
	--UNIT_SPELLCAST_SENT of the new spell
end

function Latency:UNIT_SPELLCAST_START(object, bar, unit)
	self.hooks[object].UNIT_SPELLCAST_START(object, bar, unit)
	
	local startTime, endTime = bar.startTime, bar.endTime

	for i=1,15 do
		lagbox[i]:Hide()
	end

	if not sendTime or not endTime then return end
	
	timeDiff = GetTime() - sendTime
	local castlength = endTime - startTime
	timeDiff = timeDiff > castlength and castlength or timeDiff
	local perc = timeDiff / castlength
	local numTicks
	
	local spell = UnitChannelInfo("player")

	if spell and channelingTimeGCDs[spell] then
		bar.channelTime = channelingTimeGCDs[spell] * select(7,GetSpellInfo(34914)) --Vampiric Touch
	else
		bar.channelTime = nil
	end

	UpdateLagboxes(bar)
	
	if db.lagtext then
		if alignoutside then
			lagtext:SetJustifyH(side)
			lagtext:ClearAllPoints()
			local lagtextposition = db.lagtextposition
			local point, relpoint
			if lagtextposition == "bottom" then
				point = "BOTTOM"
				relpoint = "BOTTOM"
			elseif lagtextposition == "top" then
				point = "TOP"
				relpoint = "TOP"
			elseif lagtextposition == "above" then
				point = "BOTTOM"
				relpoint = "TOP"
			else --L["Below"]
				point = "TOP"
				relpoint = "BOTTOM"
			end
			if side == "LEFT" then
				lagtext:SetPoint(point.."LEFT", lagbox[1], relpoint.."LEFT", 1, 0)
			else
				lagtext:SetPoint(point.."RIGHT", lagbox[1], relpoint.."RIGHT", -1, 0)
			end
		end
		lagtext:SetFormattedText(L["%dms"], timeDiff*1000)
		lagtext:Show()
	else
		lagtext:Hide()
	end

	-- after using it, clear it, or we might end up with a spell with a much too high latency
	sendTime = nil
end

function Latency:UNIT_SPELLCAST_DELAYED(object, bar, unit)
	self.hooks[object].UNIT_SPELLCAST_DELAYED(object, bar, unit)

	if unit ~= "player" and unit ~= "vehicle" then
		return
	end

	if not bar.casting then
		UpdateLagboxes(bar,1)
	end
	--[[ FIXME: Don't know what "lag embeded" means
	if db.lagembed then
		local startTime = bar.startTime - timeDiff + db.lagpadding
		bar.startTime = startTime
		local endTime = bar.endTime - timeDiff + db.lagpadding
		bar.endTime = endTime
	end
	--]]
end

function Latency:UNIT_SPELLCAST_INTERRUPTED(event, unit)
	if unit ~= "player" and unit ~= "vehicle" then
		return
	end
	for i=1,15 do
		lagbox[i]:Hide()
	end
	lagtext:Hide()
end

function Latency:ApplySettings()
	db = self.db.profile
	if lagbox and self:IsEnabled() then
		for i=1,15 do
			lagbox[i]:SetHeight(Player.Bar.Bar:GetHeight())
			lagbox[i]:SetTexture(media:Fetch("statusbar", Player.db.profile.texture))
			lagbox[i]:SetAlpha(db.lagalpha)
			lagbox[i]:SetVertexColor(unpack(db.lagcolor))
		end
		
		lagtext:SetFont(media:Fetch("font", db.lagfont), db.lagfontsize)
		lagtext:SetShadowColor( 0, 0, 0, 1)
		lagtext:SetShadowOffset( 0.8, -0.8 )
		lagtext:SetTextColor(unpack(db.lagtextcolor))
		lagtext:SetNonSpaceWrap(false)
		
		local lagtextposition = db.lagtextposition
		local point, relpoint
		if lagtextposition == "bottom" then
			point = "BOTTOM"
			relpoint = "BOTTOM"
		elseif lagtextposition == "top" then
			point = "TOP"
			relpoint = "TOP"
		elseif lagtextposition == "above" then
			point = "BOTTOM"
			relpoint = "TOP"
		else --L["Below"]
			point = "TOP"
			relpoint = "BOTTOM"
		end
		local lagtextalignment = db.lagtextalignment
		if lagtextalignment == "center" then
			lagtext:SetJustifyH("CENTER")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point, lagbox[1], relpoint)
			alignoutside = false
		elseif lagtextalignment == "right" then
			lagtext:SetJustifyH("RIGHT")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point.."RIGHT", lagbox[1], relpoint.."RIGHT", -1, 0)
			alignoutside = false
		elseif lagtextalignment == "left" then
			lagtext:SetJustifyH("LEFT")
			lagtext:ClearAllPoints()
			lagtext:SetPoint(point.."LEFT", lagbox[1], relpoint.."LEFT", 1, 0)
			alignoutside = false
		else -- ["Outside"] is set on cast start
			alignoutside = true
		end
	end
end

do
	local function hidelagtextoptions()
		return not db.lagtext
	end

	local function setOpt(info, value)
		db[info[#info]] = value
		Latency:ApplySettings()
	end

	local function getOpt(info)
		return db[info[#info]]
	end

	local function getColor(info)
		return unpack(getOpt(info))
	end

	local function setColor(info, r, g, b, a)
		setOpt(info, {r, g, b, a})
	end

	local options
	function getOptions()
		if not options then
			options = {
				type = "group",
				name = L["Latency"],
				order = 600,
				get = getOpt,
				set = setOpt,
				args = {
					toggle = {
						type = "toggle",
						name = L["Enable"],
						desc = L["Enable"],
						get = function()
							return Quartz3:GetModuleEnabled(MODNAME)
						end,
						set = function(info, v)
							Quartz3:SetModuleEnabled(MODNAME, v)
						end,
						order = 100,
					},
					lagembed = {
						type = "toggle",
						name = L["Embed"],
						desc = L["Include Latency time in the displayed cast bar."],
						order = 101,
					},
					lagalpha ={
						type = "range",
						name = L["Alpha"],
						desc = L["Set the alpha of the latency bar"],
						min = 0.05, max = 1, bigStep = 0.05,
						isPercent = true,
						order = 102,
					},
					lagpadding = {
						type = "range",
						name = L["Embed Safety Margin"],
						desc = L["Embed mode will decrease it's lag estimates by this amount.  Ideally, set it to the difference between your highest and lowest ping amounts.  (ie, if your ping varies from 200ms to 400ms, set it to 0.2)"],
						min = 0, max = 1, bigStep = 0.05,
						disabled = function()
							return not db.lagembed
						end,
						order = 103,
					},
					lagcolor = {
						type = "color",
						name = L["Bar Color"],
						desc = L["Set the color of the %s"]:format(L["Latency Bar"]),
						get = getColor,
						set = setColor,
						order = 111,
					},
					header = {
						type = "header",
						name = L["Font and Text"],
						order = 113,
					},
					lagtext = {
						type = "toggle",
						name = L["Show Text"],
						desc = L["Display the latency time as a number on the latency bar"],
						order = 114,
					},
					lagtextcolor = {
						type = "color",
						name = L["Text Color"],
						desc = L["Set the color of the latency text"],
						get = getColor,
						set = setColor,
						disabled = hidelagtextoptions,
						hasAlpha = true,
						order = 115,
					},
					lagfont = {
						type = "select",
						dialogControl = "LSM30_Font",
						name = L["Font"],
						desc = L["Set the font used for the latency text"],
						values = lsmlist.font,
						disabled = hidelagtextoptions,
						order = 116,
					},
					lagfontsize = {
						type = "range",
						name = L["Font Size"],
						desc = L["Set the size of the latency text"],
						min = 3, max = 15, step = 1,
						disabled = hidelagtextoptions,
						order = 117,
					},
					lagtextalignment = {
						type = "select",
						name = L["Text Alignment"],
						desc = L["Set the position of the latency text"],
						values = {["center"] = L["Center"], ["left"] = L["Left"], ["right"] = L["Right"], ["outside"] = L["Outside"]},
						disabled = hidelagtextoptions,
						order = 118,
					},
					lagtextposition = {
						type = "select",
						name = L["Text Position"],
						desc = L["Set the vertical position of the latency text"],
						values = {["above"] = L["Above"], ["top"] = L["Top"], ["bottom"] = L["Bottom"], ["below"] = L["Below"]},
						disabled = hidelagtextoptions,
						order = 119,
					},
				},
			}
		end
		return options
	end
end
