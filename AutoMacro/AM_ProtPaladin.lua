
AM_ProtPaladin = AM_DPSTemplate:Create("AM_ProtPaladin")

function AM_ProtPaladin:Init()
	self.SpellTable = {
		[1] = GetSpellInfo(35395), --Crusader Strike
		[2] = GetSpellInfo(20271), --Judgement
		[3] = GetSpellInfo(31935), --Avenger Shield
		[4] = GetSpellInfo(26573), --Consecration
		[5] = GetSpellInfo(53595), --Hammer of the righteous
		[6] = GetSpellInfo(119072), --Holy Wrath
		[7] = GetSpellInfo(53600), -- Shield of the Righteous
		[8] = GetSpellInfo(20925), -- Sacred Shield
		[9] = GetSpellInfo(24275), -- Hammar
	}
	self.HolyAvenger = GetSpellInfo(105809)
	self.DivinePurpose = GetSpellInfo(90174)
	self.GrandCrusader = GetSpellInfo(85416)
	self.Vengeance = GetSpellInfo(84839)

	self:CreateActionButton()	
	self.lastAttackTime = GetTime()
	self.preserve = false
	self.stuck = false
end

function AM_ProtPaladin:CreateFrame()
	local frame = CreateFrame("Frame")
	local prot = self
	local Vengeance = GetSpellInfo(84839)
	frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	frame:SetScript("OnEvent", --[[function(self, event,...)
		local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg1, arg2, arg3, arg4, arg5, arg6 = select(1, ...)
		local shieldTime = UnitAuraTime("player",prot.SpellTable[7])
		if not shieldTime and UnitName("target") == sourceName and destName == UnitName("player") and sourceName ~= prot.blackList then
			if eventType == "SWING_DAMAGE" then
				prot.lastAttackTime = GetTime()
			end
			if eventType == "SWING_MISSED"  and arg1 == "ABSORB" and arg3 > 100000 then 
				prot.lastAttackTime = GetTime()
			end
			if eventType == "SPELL_DAMAGE" and arg6 == 1 and arg4 > 200000 then
				if not prot.disableSpell then
					prot.lastAttackTime = GetTime()
					print(1)
				end
			end
		end
	end]]nil) 
end

function AM_ProtPaladin:IsRequiredSpell(spell)
	if spell == self.CastSpell then return true else return false end
end

local function Cooldown(spell)
	local CD,Dur = GetSpellCooldown(spell)
	if CD > 0 then return CD + Dur - GetTime() end
	return 0
end

function CanShield()
	local holyPower = UnitPower("player",SPELL_POWER_HOLY_POWER)
	if Cooldown(AM_ProtPaladin.SpellTable[7]) < 0.2 then
		return UnitAuraTime("player",AM_ProtPaladin.DivinePurpose) or (holyPower > 2)
	end
	return false
end

local function HaveSacredShield()
	local _,_,_,_,selected = GetTalentInfo(9)
	return selected
end

function AM_ProtPaladin:Request()
	AM_DPSTemplate.Request(self)

	self.CastSpell = nil
	local shieldTime = UnitAuraTime("player",self.SpellTable[7])
	local vengeanceTime = UnitAuraTime("player", self.Vengeance, true)
	local holyPower = UnitPower("player",SPELL_POWER_HOLY_POWER)
	local spellPower = UnitAuraTime("player",self.HolyAvenger) and 3 or 1
	
	if not shieldTime and CanShield() and BSTStateProvider.state() then
		if UnitName("target") ~= "Rik'kal the Dissector" then
		self.CastSpell = self.SpellTable[7]
		self.stuck = false
		return end
	end

	--if not shieldTime and vengeanceTime and vengeanceTime < 18.7 and vengeanceTime > 18.4 and holyPower > 2 then
		--self.CastSpell = self.SpellTable[7]
		--return
	--end
	
	local tolerance = 0.2
	local crusaderStrikeSpell = self.AOE and self.SpellTable[5] or self.SpellTable[1]
	local crusaderStrikeCD = Cooldown(crusaderStrikeSpell)
	local judgementCD = Cooldown(self.SpellTable[2])
	if UnitAuraTime("player",self.GrandCrusader) and not self.preserve then
		if holyPower + spellPower > 5 and not self.stuck then
			self.CastSpell = self.SpellTable[7]
			return
		end
		self.CastSpell = self.SpellTable[3]
		return
	end
	if crusaderStrikeCD < tolerance then
		if holyPower + spellPower > 5 and not self.stuck then
			self.CastSpell = self.SpellTable[7]
			return
		end
		self.CastSpell = crusaderStrikeCD - judgementCD > 0.2  and self.SpellTable[2] or crusaderStrikeSpell
		return
	end
	if judgementCD < tolerance then
		if holyPower + spellPower > 5 and not self.stuck then
			self.CastSpell = self.SpellTable[7]
			return
		end
		self.CastSpell = self.SpellTable[2]
		return
	end
	if UnitAuraTime("player",self.DivinePurpose) and Cooldown(self.SpellTable[7]) == 0 and not self.stuck then
		self.CastSpell = self.SpellTable[7]
		return
	end
--[[
	if HaveSacredShield() then
		local shieldRemain = UnitAuraTime("player", self.SpellTable[8], true, 20925) or 0
		if shieldRemain < 6 and IsUsableSpell(self.SpellTable[8]) then
			self.CastSpell = self.SpellTable[8]
			return
		end
	end
	]]
	if Cooldown(self.SpellTable[9]) < tolerance and UnitExists("target") and UnitHealthMax("target") > 0 and UnitHealth("target") / UnitHealthMax("target") < 0.2 and not self.AOE then
		self.CastSpell = self.SpellTable[9]
		return
	end

	if Cooldown(self.SpellTable[3]) < tolerance and not self.preserve then
		self.CastSpell = self.SpellTable[3]
		return
	end
	 	
	if Cooldown(self.SpellTable[6]) < tolerance then
		if UnitExists("target") and UnitName("target") == "Embodied Doubt" then 
			self.CastSpell = self.SpellTable[4]
			return
		end
		self.CastSpell = self.SpellTable[6]
		return
	end
 	
	if Cooldown(self.SpellTable[4]) < tolerance then
		self.CastSpell = self.SpellTable[4]
		return
	end 	
end

AM_ProtPaladin:Init()
AM_ProtPaladin:CreateFrame()
