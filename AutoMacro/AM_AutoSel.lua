local AM_AutoSel_Success = false
local AM_AutoSel_Target = nil
local AM_IsCurrentTarget = false
local AM_AutoSel_List = {}

function AM_AutoSel_Init()
	local i
	local k,v,vv
	
	AM_AutoSel_List.party = {}
	for i=1,4 do
		AM_AutoSel_List.party[i] = "party" .. i
	end
	AM_AutoSel_List.party[5] = "player"
	
	AM_AutoSel_List.raid = {}
	for i=1,40 do
		AM_AutoSel_List.raid[i] = "raid" .. i
	end
	AM_AutoSel_List.raid[41] = "player"
	
	AM_AutoSel_List.arena = {}
	for i=1,5 do
		AM_AutoSel_List.arena[i] = "arena" .. i
	end
	
	for k,v in pairs(AM_AutoSel_List) do
		local macrobutton = CreateFrame("Button","AutoSel" .. k ,UIParent,"SecureActionButtonTemplate")
		local str = ""
		for _,vv in pairs(AM_AutoSel_List[k]) do
			str = str .. "/if _A_Is(\"" .. vv .. "\")\n/target " .. vv .. "\n/end\n"
		end
		--print(str)
		macrobutton:SetAttribute("type","macro")
		macrobutton:SetAttribute("macrotext",str)
	end
	
end

function AM_AutoSel_GetList()
	return AM_AutoSel_List
end

function _A_Is(unit)
	if unit == AM_AutoSel_Target then return true else return false end
end

function AutoSelOK()
	return AM_AutoSel_Success
end

function AutoSelInit(targetlist,criteria)
	local v
	AM_AutoSel_Target = nil
	AM_AutoSel_Success = false
	if not AM_AutoSel_List[targetlist] then return false end
	for _,v in pairs(AM_AutoSel_List[targetlist]) do
		if UnitExists(v) and criteria(v) then
			AM_AutoSel_Target = v
			AM_AutoSel_Success = true
			if UnitIsUnit("target",AM_AutoSel_Target) then
				AM_IsCurrentTarget = false
			else
				AM_IsCurrentTarget = true
			end
			return true 
		end
	end
	return false
end

function AutoSelNeedTarget()
	return AM_IsCurrentTarget
end

local lastunit

function AutoSelDisc()
	local unit,minhealth
	local weak = GetSpellInfo(6788)
	local shield = GetSpellInfo(17)
	for i=1,40 do
		if UnitExists(AM_AutoSel_List.raid[i]) and not UnitIsDeadOrGhost(AM_AutoSel_List.raid[i]) and UnitHealthMax(AM_AutoSel_List.raid[i]) 
		and UnitHealthMax(AM_AutoSel_List.raid[i])>0 then
			if not minhealth or UnitHealth(AM_AutoSel_List.raid[i]) / UnitHealthMax(AM_AutoSel_List.raid[i]) < minhealth then
				if not UnitAuraTime(AM_AutoSel_List.raid[i],weak) then
					if IsSpellInRange(shield,AM_AutoSel_List.raid[i])==1 then
					if lastunit~= AM_AutoSel_List.raid[i] then
						unit = AM_AutoSel_List.raid[i]
						minhealth = UnitHealth(AM_AutoSel_List.raid[i]) / UnitHealthMax(AM_AutoSel_List.raid[i])
					end end
				end
			end
		end
	end
	lastunit = unit
	return unit
end

function AutoSelDisc_IsUnit(u)
	if UnitIsUnit(u,lastunit) then return true else return false end
end

function AutoSelDisc2()
	local unit,minhealth
	local shield = GetSpellInfo(17)
	for i=1,40 do
		if UnitExists(AM_AutoSel_List.raid[i]) and not UnitIsDeadOrGhost(AM_AutoSel_List.raid[i]) and UnitHealthMax(AM_AutoSel_List.raid[i]) 
		and UnitHealthMax(AM_AutoSel_List.raid[i])>0 then
			if not minhealth or UnitHealth(AM_AutoSel_List.raid[i]) / UnitHealthMax(AM_AutoSel_List.raid[i]) < minhealth then
				--if not UnitAuraTime(AM_AutoSel_List.raid[i],weak) then
					if IsSpellInRange(shield,AM_AutoSel_List.raid[i])==1 then
					if lastunit~= AM_AutoSel_List.raid[i] then
						unit = AM_AutoSel_List.raid[i]
						minhealth = UnitHealth(AM_AutoSel_List.raid[i]) / UnitHealthMax(AM_AutoSel_List.raid[i])
					end end
				--end
			end
		end
	end
	lastunit2 = unit
	return unit
end

function AutoSelDisc_IsUnit2(u)
	if UnitIsUnit(u,lastunit2) then return true else return false end
end

AM_AutoSel_Init()