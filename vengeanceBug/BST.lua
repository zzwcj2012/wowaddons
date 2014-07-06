
if not BossSwingTimer then return end

local defaults = {
	profile = {
		enableBST = false,
		swingTimeOffset = 50,
		swingTimeRange = 350,
	},
}

local addon = LibStub("AceAddon-3.0"):NewAddon("VengeanceBug", "AceConsole-3.0")

function addon:GetOptions()
	if not BossSwingTimer then
	end
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

local function CreateBSTStateProvider(db)
	local swings = BossSwingTimer.swings
	return {
		enabled = function ()
			return db.enableBST
		end,
		state = function ()
			local guid  = UnitGUID("target")
			local swing = swings[guid]
			local time, readyTime = GetTime()
			if not swing then return false end
			if db.swingTimeOffset < 0 then
				readyTime = swing.time - db.swingTimeOffset / 1000.0
			else
				readyTime = swing.next - db.swingTimeOffset / 1000.0
			end
			return time >= readyTime and time < readyTime + db.swingTimeRange / 1000.0
		end,
	}
end

local BSTRangeIndicatorFactory = function(self)
	if not self.bar.range then
		self.bar.range = self.bar:CreateTexture(nil, "BACKGROUND")
		self.bar.reage:SetPoint("TOPLEFT", self.bar, "TOPLEFT", 0, 0)
		self.bar.range:SetPoint("BOTTOMLEFT", self.bar, "BOTTOMLEFT", 0, 0)
	end
	self.bar.range:SetWidth(1)
	self.bar.range:SetVertexColor(0.0, 0.6, 0.0)
	self.bar.range:SetAlpha(self.db.profile.frame.alpha)
	return function (self)
		local db = self.db
		local offset = db.swingTimeOffset / 1000 / self.db.profile.frame.length * self.db.profile.frame.width
		local length = db.swingTimeRange / 1000 / self.db.profile.frame.length * self.db.profile.frame.width
		self.bar.reage:SetPoint("TOPLEFT", self.bar, "TOPLEFT", offset, 0)
		self.bar.range:SetPoint("BOTTOMLEFT", self.bar, "BOTTOMLEFT", offset, 0)
		self.bar.range:SetWidth(length)
	end
end

function addon:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("VengeanceBugDB", defaults, true)
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable("VengeanceBug", self:GetOptions())
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("VengeanceBug", "VengeanceBug卡复仇")

	self.UpdateBSTRangeIndicator = BSTRangeIndicatorFactory(BossSwingTimer)
	self:UpdateBSTRangeIndicator()

	BSTStateProvider = CreateBSTStateProvider(self.db)
end