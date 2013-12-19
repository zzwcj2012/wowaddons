
AM_DPSShadowPriest = AM_DPSTemplate:Create("AM_DPSShadowPriest")

function AM_DPSShadowPriest:Init()
	self.SpellTable = {
		[1] = GetSpellInfo(589), --SW:P
		[2] = GetSpellInfo(8092), --Mind Blast
		[3] = GetSpellInfo(2944), --Devouring Plague
		[4] = GetSpellInfo(34914), -- VT
		[5] = GetSpellInfo(15407), --Mind Flay
		[6] = GetSpellInfo(32379), --Shadow Word: Death
		[7] = GetSpellInfo(73510),-- Mind Spike
	}
	
	self.CastSpell = nil
	
	self.SurgeOfDrakness = GetSpellInfo(87160)

	if not self.Frame then
		self.Frame = CreateFrame("frame")
		self.Frame:RegisterEvent("UNIT_SPELLCAST_START")
		self.Frame:SetScript("OnEvent",function(self,event,unit,spell,...)
			if event ~= "UNIT_SPELLCAST_START" then return end
			if unit == "player" and spell == AM_DPSShadowPriest.SpellTable[4] then
				AM_DPSShadowPriest.LastCastVT = GetTime()
			end
		end )
	end
	
	
	self:CreateActionButton()	
end

function AM_DPSShadowPriest:IsRequiredSpell(spell)
	if spell == self.CastSpell then return true else return false end
end

function AM_DPSShadowPriest:Request()
	AM_DPSTemplate.Request(self)
	
	self.CastSpell = nil
	if not UnitExists("target") then return end
	
	if UnitChannelInfo("player") then return end
	
	local GlobalCooldown = math.max( 1.0 ,  select(7,GetSpellInfo(34914))/1000 )
	local MindFlayCastTime = 2*select(7,GetSpellInfo(34914))/1000
	
	local GCD,GCDDur = GetSpellCooldown(self.SpellTable[1])
	if GCD > 0 then
		GCD = GCD + GCDDur - GetTime()
	end
	
	local Latency = 0.05
	local WaitTolerance = max(0.15,GCD+0.03)
	local DOTTolerance = 0.5
	local MBCD,MBDur = GetSpellCooldown(self.SpellTable[2])
	local SpikeCD,SpikeDur = GetSpellCooldown(self.SpellTable[6])
	
	local shadowOrbs = UnitPower("player", SPELL_POWER_SHADOW_ORBS) or 0

	if MBCD > 0 then
		MBCD = MBCD + MBDur - GetTime()
	end
	if SpikeCD > 0 then
		SpikeCD = SpikeCD + SpikeDur - GetTime()
	end

	if shadowOrbs >= 3 then

	end
	
	if UnitHealth("target")/UnitHealthMax("target") < 0.2 then
		if SpikeCD < WaitTolerance then
			if UnitHealth("player") > 50000 then
				if UnitName("target")~="Chimaeron" then
					if GlobalCooldown  > 0.8 then
						self.CastSpell = self.SpellTable[6]
						if shadowOrbs >= 3 then
							self.CastSpell = self.SpellTable[3]
						end
						return
					end
				end
			end
		end
	end
	
	if UnitHealthMax("target") < 100000 and UnitHealthMax("target") > 20 then --Health less than 10k,it's a mob
		local _,SpikeStacks = UnitAuraTime("target",self.SpellTable[7])
		if MBCD and SpikeStacks and SpikeStacks >= 2 then
			self.CastSpell = self.SpellTable[2]
			return
		else
			self.CastSpell = self.SpellTable[7]
			return
		end
	end
	
	if not UnitAuraTime("target",self.SpellTable[1],true) then 
		self.CastSpell = self.SpellTable[1]
		return
	end
	
	
	

	local IntendedSpell
	if MBCD  == 0 or MBCD < WaitTolerance then
		IntendedSpell = self.SpellTable[2]
		if shadowOrbs >= 3 then
			self.CastSpell = self.SpellTable[3]
		end
	else
		IntendedSpell = self.SpellTable[5]
	end
	
	if IntendedSpell == self.SpellTable[5] then
		local painTime = UnitAuraTime("target",self.SpellTable[1],true)
		
		local VTTime=UnitAuraTime("target",self.SpellTable[4],true)
	
		if not VTTime then
			local k = GetTime()-(self.LastCastVT or 0)
			if (k>2.5) then 
				self.CastSpell = self.SpellTable[4]
				return
			end
		end

		local _,sodStacks = UnitAuraTime("player",self.SurgeOfDrakness)

		sodStacks = sodStacks or 0

		if sodStacks >= 2 then
			self.CastSpell = self.SpellTable[7]
			return
		end


		if MBCD < MindFlayCastTime + Latency then
			DOTTolerance = DOTTolerance + GlobalCooldown
		end
		
		if (not painTime) or painTime < MindFlayCastTime + DOTTolerance then
			self.CastSpell = self.SpellTable[1]
			return
		end
		if VTTime and VTTime < MindFlayCastTime + GlobalCooldown + DOTTolerance then
			local k = GetTime()-(self.LastCastVT or 0)
			if (k>2.5) then 
				self.CastSpell = self.SpellTable[4]
				return
			end
		end
		if shadowOrbs >= 3 then
			self.CastSpell = self.SpellTable[3]
			return
		end
		if sodStacks >= 1 then
			self.CastSpell = self.SpellTable[7]
			return
		end
	else
		if MBCD > 0 then
			return
		end
	end
	
	self.CastSpell = IntendedSpell
end

AM_DPSShadowPriest:Init()
