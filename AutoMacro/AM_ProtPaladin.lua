
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
	}
	self.HolyAvenger = GetSpellInfo(105809)
	self.DivinePurpose = GetSpellInfo(90174)
	self.GrandCrusader = GetSpellInfo(85416)

	self:CreateActionButton()	
end

function AM_ProtPaladin:IsRequiredSpell(spell)
	if spell == self.CastSpell then return true else return false end
end

local function Cooldown(spell)
	local CD,Dur = GetSpellCooldown(spell)
	if CD > 0 then return CD + Dur - GetTime() end
	return 0
end

function AM_ProtPaladin:Request()
	AM_DPSTemplate.Request(self)

	self.CastSpell = nil
	local holyPower = UnitPower("player",SPELL_POWER_HOLY_POWER)
	local spellPower = UnitAuraTime("player",self.HolyAvenger) and 3 or 1
	if holyPower + spellPower > 5 then
		self.CastSpell = self.SpellTable[7]
		return
	end
	
	local tolerance = 0.2
	local crusaderStrikeSpell = self.AOE and self.SpellTable[5] or self.SpellTable[1]
	local crusaderStrikeCD = Cooldown(crusaderStrikeSpell)
	local judgementCD = Cooldown(self.SpellTable[2])
	if UnitAuraTime("player",self.GrandCrusader) then
		self.CastSpell = self.SpellTable[3]
		return
	end
	if crusaderStrikeCD < tolerance then
		self.CastSpell = crusaderStrikeCD - judgementCD > 0.2  and self.SpellTable[2] or crusaderStrikeSpell
		return
	end
	if judgementCD < tolerance then
		self.CastSpell = self.SpellTable[2]
		return
	end
	if UnitAuraTime("player",self.DivinePurpose) and Cooldown(self.SpellTable[7]) == 0 then
		self.CastSpell = self.SpellTable[7]
		return
	end

	local shieldRemain = UnitAuraTime("player", self.SpellTable[8], true, 20925) or 0
	if shieldRemain < 6 and IsUsableSpell(self.SpellTable[8]) then
		self.CastSpell = self.SpellTable[8]
		return
	end

	if Cooldown(self.SpellTable[3]) < tolerance then
		self.CastSpell = self.SpellTable[3]
		return
	end
	 	
	if Cooldown(self.SpellTable[6]) < tolerance then
		self.CastSpell = self.SpellTable[6]
		return
	end
 	
	if Cooldown(self.SpellTable[4]) < tolerance then
		self.CastSpell = self.SpellTable[4]
		return
	end 	
end

AM_ProtPaladin:Init()

