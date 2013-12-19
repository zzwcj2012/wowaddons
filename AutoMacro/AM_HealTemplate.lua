AM_HealTemplate = AM_DPSTemplate:Create("AM_HealTemplate")
local log = math.log

function AM_HealTemplate:CreateDefaultTargetTable()

	self.TargetTable = {}
	self.PartyGroup = {}
	self.PartyGroup[1] = {}
	self.RaidGroup = {}
	
	self.TargetTable[1] = "player"
	local i = 2
	local j
	for j=1,4 do
		self.TargetTable[i] = "party" .. j
		self.PartyGroup[1][j] = "party" .. j
		i = i + 1
	end
	self.PartyGroup[1][5] = "player"
	
	for j=1,25 do
		local RaidGroupIndex  = (j - j % 5) / 5 + 1
		self.RaidGroup[RaidGroupIndex] = self.RaidGroup[RaidGroupIndex] or {}
		
		self.TargetTable[i] = "raid" ..  j
		self.RaidGroup[RaidGroupIndex][ (j%5) + 1 ] = "raid" .. j
		
		i = i + 1
	end
	
end

function AM_HealTemplate:CreateEventFrame()
	self.Frame = self.Frame or CreateFrame("Frame")
	self.Frame:RegisterEvent("UNIT_SPELLCAST_SENT")
	self.Frame.AM_Parent = self
	self.Frame:SetScript("OnEvent",function(self,event,unit,spell,rank,target)
		if event ~= "UNIT_SPELLCAST_SENT" then return end
		if unit == "player" then
			 self.AM_Parent.LastCastSpell = spell
			 self.AM_Parent.LastTarget = target
		end
	end )
end

function AM_HealTemplate:GetTargetTable()

	if UnitInRaid("player") then
		return self.RaidGroup
	else
		return self.PartyGroup
	end

end

function AM_HealTemplate:GetEval(unitHealth,unitHealthMax,healAmount,castTime)
	--[[
		We have a function that indicates how "effective" the healing is pre hit point
		That function is e(x) = a^(b-b*x) where a,b are tested constants that is suitable and x is the health precentage of that unit
		To calculate the "effectiveness" of the healing, we need to calculate the average healing effectiveness that is
		E(After,Before) = Integrate(e(x),Before,After)dx / (After - Before) where Before and After are the
		health precentages of these units.
		Here we gave Integration of the function that is -a^(b-bx)/bln(a)
		Now we have the eval that is healAmount * averageHealingEffectiveness
	]]
	local a=2
	local b=3.50 - castTime / 2.50
	if unitHealth + healAmount > unitHealthMax then healAmount = unitHealthMax - unitHealth end
	
	if healAmount <= 0 then return 0 end
	
	local PrecentageBefore = unitHealth / unitHealthMax
	local PrecentageAfter = ( unitHealth  + healAmount) / unitHealthMax
	
	--if PrecentageAfter > 1.0 then PrecentageAfter = 1.0 end
	
	local averageHealEffect = (a^(b-b*PrecentageBefore) ) / ( b* log(a) ) - (a^(b-b*PrecentageAfter) ) / ( b* log(a) )
	
	averageHealEffect = averageHealEffect / (PrecentageAfter - PrecentageBefore)
	
	return healAmount * averageHealEffect
	
end

function AM_HealTemplate:EvalHealSingle(spell,isHot,target,targetGroup,considerLastSpell,isMultiple)
	if not self.HealComm then self.HealComm = LibStub("LibHealComm-4.0-AM") end
	--[[
	HealComm APIs are listed here
		GetHealTargets = function(bitType, guid, healAmount, spellName, hasVariableTicks)
		CalculateHealing = function(guid, spellName, spellRank)
		CalculateHotHealing = function(guid, spellID)
	--]]
	local spellID = spellNameToID(spell)
	if not spellID then return 0 end
	if not UnitExists(target) then return 0 end
	if not SpellCastable(spell,target) then return 0 end
	
	local manaCost = select(4,GetSpellInfo(spellID))
	local spellRank = GetSpellHighestRank(spell)
	local unitGUID = UnitGUID(target)
	local healAmount = 0
	local beforeHealingTime = 0
	local otherHealing = 0
	
	if not self.HealComm.GetHealModifier(unitGUID) then return 0 end
	
	if isHot then
		if UnitAuraTime(target,spell,1) then return 0 end
		_,healAmount = self.HealComm.CalculateHotHealing(unitGUID,spellNameToID(spell)) 
	else
		_,healAmount = self.HealComm.CalculateHealing(unitGUID,spell,spellRank)
	end
	
	healAmount = healAmount * self.HealComm.GetHealModifier(unitGUID)
	
	local castTime = select(7,GetSpellInfo(spellNameToID(spell)))
	beforeHealingTime = castTime - 1
	if castTime == 0 then
		castTime = math.max( 1.0 , 1.5/(1.0+GetCombatRatingBonus(20)/100))*1000.0
	end
	
	if isHot then beforeHealingTime = 2999 end
	
	if beforeHealingTime > 0 then
		otherHealing = self.HealComm.GetOthersHealAmount(unitGUID, self.HealComm.ALL_HEALS , beforeHealingTime ) or 0
	end
	
	if considerLastSpell then
		otherHealing = otherHealing + healAmount
	end
	
	local SingleEval = self:GetEval(UnitHealth(target)+otherHealing ,UnitHealthMax(target),healAmount,castTime/1000.0)/castTime*1000
	if isMultiple and isMultiple > 1 then
		return SingleEval * isMultiple - manaCost *1.2
	elseif isMultiple == 1 then --party heal
		local i = 0
		local v
		SingleEval = 0
		for _,v in pairs(targetGroup) do
			if UnitExists(v) then
				SingleEval = SingleEval + self:GetEval(UnitHealth(v)+otherHealing ,UnitHealthMax(v),healAmount,castTime/1000.0)/castTime*1000
			end
		end
		return SingleEval/1.6 - manaCost*1.5
	end
	
	return SingleEval - manaCost *1.2
end

function AM_HealTemplate:GetHealInfo(considerLastSpell)
	local k,v
	local kk,vv
	local TargetGroupTable = self:GetTargetTable()
	local target
	local EvalMax = {}
	EvalMax.Eval = 0
	local EvalCurrent
	
	for k,v in pairs(self.SpellTable) do
		for kk,vv in pairs(TargetGroupTable) do
			for _,target in pairs(vv) do
			
				EvalCurrent = self:EvalHealSingle(v,self.IsHot[k],target,vv,considerLastSpell,self.IsMultiple[k]);
				
				if EvalCurrent > 0 then print(target,v,EvalCurrent) end
				
				if EvalCurrent > EvalMax.Eval then
					EvalMax.Eval = EvalCurrent
					EvalMax.CastSpell = v
					EvalMax.Target = target
				end
				
			end
		end	
	end
	
	if EvalMax.Eval < 800 then return nil end
	
	if self.LastCastSpell and EvalMax.CastSpell == self.LastCastSpell and EvalMax.Target == self.LastTarget then
		return GetHealInfo(true)
	else
		return EvalMax.CastSpell,EvalMax.Target
	end
end