
local nameTable = {}
local tooltip = nil

function SpellCastable(spellName,target)
	if IsUsableSpell(spellName) and IsSpellInRange(spellName,target)==1 then
		if GetSpellCooldown(spellName) == 0 then
			return true
		end
	end
end

function UnitIsCastingClass(target)
	local _,Class = UnitClass(target)
	return Class == "MAGE" or Class == "PRIEST" or Class == "WARLOCK"
end

function Interruptable(target,blacklist)
	local notInterruptible
	local spellName
	if UnitChannelInfo(target) then
		notInterruptible = select(8,UnitChannelInfo(target))
		spellName = UnitChannelInfo(target)
	else
		if UnitCastingInfo(target) then
			notInterruptible = select(9,UnitCastingInfo(target))
			spellName = UnitCastingInfo(target)
		else
			return false
		end
	end
	
	if not notInterruptible then 
		if blacklist then
			for k,v in pairs(blacklist) do
				local blackSpell = GetSpellInfo(v)
				if blackSpell == spellName then
					return false
				end
			end
		end
		return true 
	end
	
end

function UnitAuraTime(target,aura,ismine)
	for i=1,64 do
		local filter 
		if ismine then
			local filter = "PLAYER"
		end
		
		local name,_, _, count, _, _, expires = UnitAura(target,i,filter)
			
		if name and name == aura then
			return expires - GetTime(),count
		end
	end
	for i=1,64 do
		local name,_, _, count, _, _, expires,caster = UnitDebuff(target,i)
		if name and name == aura then
			if ismine and caster~= "player" then else return expires - GetTime(),count end
		end
	end
end

function GetSpellHighestRank(spellName)
	local hRank = select(2,GetSpellInfo(spellName))
	return hRank
end

function spellNameToID(spellName)
	if nameTable[spellName] then return nameTable[spellName] end
	local id
	local spellRank = GetSpellHighestRank(spellName)
	
	local offset, numSpells = select(3, GetSpellTabInfo(GetNumSpellTabs()))
	for id=1, (offset + numSpells) do
		-- Match, yay!
		local _spellName, _spellRank = GetSpellName(id, BOOKTYPE_SPELL)

		if( _spellName == spellName and
			_spellRank == spellRank) then
			
			if not tooltip then
				tooltip = CreateFrame("GameTooltip")
				tooltip:SetOwner(UIParent, "ANCHOR_NONE")
				tooltip.TextLeft1 = tooltip:CreateFontString()
				tooltip.TextRight1 = tooltip:CreateFontString()
				tooltip:AddFontStrings(tooltip.TextLeft1, tooltip.TextRight1)
			end
			
			tooltip:SetSpell(id, BOOKTYPE_SPELL)
			local spellID = select(3, tooltip:GetSpell())
			
			if( spellID ) then
				nameTable[spellName] = spellID
				return spellID
			end
			
		end
	end
	
	nameTable[spellName] = false
end

function InterruptList(spell,list,target)
	local k,v
	if SpellCastable(spell,target) then
		if not list then return true end
		local CastInfo,ChannelInfo = UnitCastingInfo(target) or "" ,UnitChannelInfo(target) or ""
		for k,v in pairs(list) do
			if strfind(CastInfo,v) or strfind(ChannelInfo,v) then
				return true
			end
		end	
	end
	return false
end