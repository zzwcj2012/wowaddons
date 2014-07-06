---作者 AK-48 <ak48disk@gmail.com>
---一区 奥达曼 梦雨落风

if not BossSwingTimer then return end

local BossSwingTimer = BossSwingTimer

BSTStateProvider = {
	enabled = function() return false end
}

local defaults = {
	profile = {
		enableBST = false,
		swingTimeOffset = 50,
		swingTimeRange = 150,
	},
}

local addon = LibStub("AceAddon-3.0"):NewAddon("VengeanceBug", "AceConsole-3.0")

function addon:GetOptions()
	self.Options = self.Options or {
		type = "group",
		name = "VengeanceBug卡复仇",
		handler = self,
		args = {
			enableBST = {
				name = "从BST获取信息",
				desc = "启用BossSwingTimer作为预测攻击的数据源（适用于高延迟）",
				order = 0,
				type = "toggle",
				set = function(info,val)
						self.db.profile[info[1]] = val
					end,
				get = function(info) return self.db.profile[info[1]] end
			},
			swingTimeOffset = {
				name = "盾击时间提前量(毫秒)",
				desc = "打出盾击与BST预测BOSS攻击时间的提前量，正值表示提前于BOSS攻击打出盾击",
				order = 1,
				type = "range",
				min = -100,
				max = 500,
				step = 1,
				set = function(info, val)
					self.db.profile[info[1]] = val
					self:UpdateBSTRangeIndicator()
				end,
				get = function(info) return self.db.profile[info[1]] end
			},
			swingTimeRange = {
				name = "卡复仇时间范围(毫秒)",
				desc = "打出盾击的时间范围，单位毫秒",
				order = 1,
				type = "range",
				min = 0,
				max = 500,
				step = 1,
				set = function(info, val)
					self.db.profile[info[1]] = val
					self:UpdateBSTRangeIndicator()
				end,
				get = function(info) return self.db.profile[info[1]] end
			},
		},
	}
	return self.Options
end

function addon:CreateBSTStateProvider()
	local swings = BossSwingTimer.swings
	local db = self.db.profile
	local updatedIndicator = false
	
	BSTStateProvider.enabled = function ()
		return db.enableBST
	end
	
	BSTStateProvider.state = function ()
		if not updatedIndicator then
			updatedIndicator = self:UpdateBSTRangeIndicator()
		end
		if UnitExists("target") then
			local guid  = UnitGUID("target")
			local swing = swings[guid]
			local time, readyTime = GetTime()
			if not swing then return false end
			if db.swingTimeOffset < 0 then
				readyTime = swing.time - db.swingTimeOffset / 1000.0
			else
				if not swing.next then return false end
				readyTime = swing.next - db.swingTimeOffset / 1000.0
				if time < readyTime and db.swingTimeOffset < db.swingTimeRange then
					readyTime = swing.time - db.swingTimeOffset / 1000.0
				end
			end
			return time >= readyTime and time < readyTime + db.swingTimeRange / 1000.0
		end
	end
end

function addon:UpdateBSTRangeIndicator()
	if not BossSwingTimer.bar then return false end
	if not BossSwingTimer.bar.range then
		BossSwingTimer.bar.range = BossSwingTimer.bar:CreateTexture(nil, "OVERLAY")
		BossSwingTimer.bar.range:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
		BossSwingTimer.bar.range:SetPoint("TOPRIGHT", BossSwingTimer.bar, "TOPLEFT", 0, 0)
		BossSwingTimer.bar.range:SetPoint("BOTTOMRIGHT", BossSwingTimer.bar, "BOTTOMLEFT", 0, 0)
		BossSwingTimer.bar.range:SetWidth(1)
		BossSwingTimer.bar.range:SetHeight(BossSwingTimer.db.profile.frame.height)
		BossSwingTimer.bar.range:SetVertexColor(0.0, 0.6, 0.0)
		BossSwingTimer.bar.range:SetAlpha(BossSwingTimer.db.profile.frame.alpha * 0.3)
	end
	
	local db = self.db.profile
	local offset = db.swingTimeOffset / 1000.0 / BossSwingTimer.db.profile.frame.length * BossSwingTimer.db.profile.frame.width
	local length = db.swingTimeRange / 1000.0 / BossSwingTimer.db.profile.frame.length * BossSwingTimer.db.profile.frame.width
	BossSwingTimer.bar.range:ClearAllPoints()
	BossSwingTimer.bar.range:SetPoint("TOPRIGHT", BossSwingTimer.bar, "TOPLEFT", offset, 0)
	BossSwingTimer.bar.range:SetPoint("BOTTOMRIGHT", BossSwingTimer.bar, "BOTTOMLEFT", offset, 0)
	BossSwingTimer.bar.range:SetWidth(length)
	if length == 0 then 
		BossSwingTimer.bar.range:Hide()
	else
		BossSwingTimer.bar.range:Show()
	end
	return true
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("VengeanceBugDB", defaults, true)
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable("VengeanceBug", self:GetOptions())
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("VengeanceBug", "VengeanceBug卡复仇")

	self:UpdateBSTRangeIndicator()

	self:CreateBSTStateProvider()
end