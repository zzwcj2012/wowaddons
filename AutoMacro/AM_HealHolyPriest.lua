
local _,class = UnitClass("player")
if class ~= "PRIEST" then return end

AM_HealHolyPriest = AM_HealTemplate:Create("AM_HealHolyPriest")

function AM_HealHolyPriest:Init()
	self.SpellTable = {
		[1] = GetSpellInfo(34861), --Circle of Healing
		[2] = GetSpellInfo(2061), --Flash Heal
		--[3] = GetSpellInfo(2060), --Greater Heal
		[4] = GetSpellInfo(139), --Renew
		[5] = GetSpellInfo(33076), --Prayer of Mending
		[6] = GetSpellInfo(596), --Preyer of Healing
		[7] = GetSpellInfo(19236), -- Desperate Prayer
		[8] = GetSpellInfo(23455), -- Holy Nova
		[9] = GetSpellInfo(32546),	--Binding Heal
		}
	self.IsHot = {
		[4] = 1,
	}
	self.IsMultiple = {
		[1] = 6,
		[6] = 1,
		[8] = 1,
	}
	
	self.CastSpell = nil
	self.Target = nil
	
	self:CreateDefaultTargetTable()
	self:CreateEventFrame()
	self:CreateActionButton()
end

function AM_HealHolyPriest:IsRequiredTarget(unit)
	if not self.Target then return false end
	if unit and UnitIsUnit(unit,self.Target) then return true else return false end
end

function AM_HealHolyPriest:IsRequiredSpell(spell)
	if spell == self.CastSpell then return true else return false end
end

function AM_HealHolyPriest:Request()
	AM_DPSTemplate.Request(self)
	
	-- Figure out who is MT ( the one has largest hit points
	local v
	local mt 
	local mtHealth = 0
	for _,v in pairs(self.TargetTable) do
		if UnitExists(v) and UnitHealthMax(v) > mtHealth then
			mtHealth = UnitHealthMax(v) 
			mt = v
		end
	end
	
	-- Check Prayer of Mending first
	if SpellCastable(self.SpellTable[5],mt) then
		self.CastSpell = self.SpellTable[5]
		self.Target = mt
		return 
	end
	
	self.CastSpell , self.Target = self:GetHealInfo()
	
	if self.CastSpell == self.SpellTable[6] and SpellCastable(self.SpellTable[1],self.Target) then self.CastSpell = self.SpellTable[1] end
end

function AM_HealHolyPriest:EvalHealSingle(spell,isHot,target,targetGroup,considerLastSpell,isMultiple)
	if spell == self.SpellTable[7] and (not UnitIsUnit(target,"player")) then return 0 end --Desperate Prayer cannot be cast on other players
	local currentEval = AM_HealTemplate.EvalHealSingle(self,spell,isHot,target,targetGroup,considerLastSpell,isMultiple)
	
	if spell == self.SpellTable[9] and (not UnitIsUnit(target,"player")) then -- Binding Heal consider the player 
		currentEval = currentEval + AM_HealTemplate.EvalHealSingle(self,spell,isHot,"player",targetGroup,considerLastSpell,isMultiple)
		currentEval = currentEval / 1.5
	end
	
	if spell == self.SpellTable[2] then
		local hy_s = select(2,UnitAuraTime("player","Serendipity")) or 0
		if hy_s < 3 then 
			currentEval = currentEval + 600
		end
	end
	return currentEval
end

AM_HealHolyPriest:Init()