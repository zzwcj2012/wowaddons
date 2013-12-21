local size
local energy
if select(2,UnitClass("player")) == "PRIEST" then
	size = 3
	energy = SPELL_POWER_SHADOW_ORBS
elseif  select(2,UnitClass("player")) == "PALADIN" then
	size = 5
	energy = SPELL_POWER_HOLY_POWER
else
	return  
end

-- 設置
local barsize = {200,15}											-- 大小
local barpoint = {"center", UIParent, 0, -200}						-- 描点
local statusbartexture = "Interface\\AddOns\\spball\\statusbar"		-- statusbar材质
local bballcolor = {151/255, 86/255, 168/255}						-- 黑球颜色

local crateshadow = function(parent)
	local shadow = CreateFrame("Frame", nil, parent)
	shadow:SetPoint("TOPLEFT", -5, 5)
	shadow:SetPoint("BOTTOMRIGHT", 5, -5)
	shadow:SetFrameStrata(parent:GetFrameStrata())
	shadow:SetFrameLevel(0)
	shadow:SetBackdrop({edgeFile = "Interface\\addons\\spball\\glow", edgeSize = 5,})
	shadow:SetBackdropBorderColor(0,0,0)
end

local bar = CreateFrame("Frame", "spbar", UIParent)
bar:SetSize(unpack(barsize))
bar:SetPoint(unpack(barpoint))
bar:SetFrameStrata("MEDIUM")
bar:SetFrameLevel(2)
bar:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1,})
bar:SetBackdropColor( .1, .1, .1, .6)
bar:SetBackdropBorderColor(0, 0, 0)
crateshadow(bar)

local bbar = CreateFrame("Frame", nil, bar)
for i = 1, size do
	bbar[i] = CreateFrame("StatusBar", nil, bbar)
	bbar[i]:SetSize((bar:GetWidth()-4)/size, bar:GetHeight()-2)
	bbar[i]:SetStatusBarTexture(statusbartexture)
	bbar[i]:SetStatusBarColor(unpack(bballcolor))
	bbar[i]:SetAlpha(.15)

	if i == 1 then
		bbar[i]:SetPoint("TOPLEFT", bar, 1, -1)
	else
		bbar[i]:SetPoint("LEFT", bbar[i-1], "RIGHT", 1, 0)
	end
end

local function OnEvent(self,event)
	-- 黑球部份
	local numOrbs = UnitPower("player", energy)
	if numOrbs ~= 0 then
		for i = 1, size do
			bbar[i]:SetAlpha(.15)
		end
		for i = 1, numOrbs do
			bbar[i]:SetAlpha(1)
		end
	else
		for i = 1, size do
			bbar[i]:SetAlpha(.15)
		end
	end
end

bar:RegisterEvent("PLAYER_ENTERING_WORLD")
bar:RegisterEvent("PLAYER_REGEN_DISABLED")
bar:RegisterEvent("PLAYER_REGEN_ENABLED")
bar:RegisterEvent("UNIT_POWER")
bar:SetScript("OnEvent", OnEvent)
