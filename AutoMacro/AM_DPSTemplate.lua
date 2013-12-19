AM_DPSTemplate = {}

function AM_DPSTemplate:Create(name)
	local newobject = {}
	setmetatable(newobject,self)
	self.__index = self
	newobject.name = name
	newobject.SpellTable = {}
	newobject.TargetTable = nil
	return newobject
end

function AM_DPSTemplate:CreateActionButton()
	local str = ""
	local str2 = ""
	local k,v
	if self.TargetTable then --Need change target,maybe a healer
		for _,v in pairs(self.TargetTable) do
			--str = str .. "/if " .. self.name .. ":IsRequiredTarget(\"" .. v .. "\")\n" .. "/target " .. v .. "\n/end\n"
			if str:len() < 800 then
				str = str .. "/if " .. "_aM" .. ":R(\"" .. v .. "\")\n/tar " .. v .. "\n/end\n"
			else
				str2 = str2 .. "/if " .. "_aM" .. ":R(\"" .. v .. "\")\n/tar " .. v .. "\n/end\n"
			end
		end
		
		local macrobutton1 = CreateFrame("Button",self.name .. "Button1" ,UIParent,"SecureActionButtonTemplate")
		macrobutton1:SetAttribute("type","macro")
		macrobutton1:SetAttribute("macrotext",str)
		
		local macrobutton2 = CreateFrame("Button",self.name .. "Button2" ,UIParent,"SecureActionButtonTemplate")
		macrobutton2:SetAttribute("type","macro")
		macrobutton2:SetAttribute("macrotext",str2)
		
		str = "/run " .. self.name .. ":Request()\n" .. "/click " .. self.name .. "Button1\n" .. "/click " .. self.name .. "Button2\n"
	else
		str = "/run " .. self.name .. ":Request()\n/if _aM:F()\n/click " .. self.name .. "ButtonF\n/else \n"
	end
	
	str2 = ""
	for _,v in pairs(self.SpellTable) do
		str2 = str2 .. "/if " .. "_aM" .. ":iRs(\"" .. v .. "\")\n/cast [@focus]" .. v .. "\n/end\n"
	end
	local macrobuttonfocus = CreateFrame("Button",self.name .. "ButtonF" ,UIParent,"SecureActionButtonTemplate")
	macrobuttonfocus:SetAttribute("type","macro")
	macrobuttonfocus:SetAttribute("macrotext",str2)
	
	for _,v in pairs(self.SpellTable) do
		str = str .. "/if " .. "_aM" .. ":iRs(\"" .. v .. "\")\n/cast " .. v .. "\n/end\n"
	end
	
	str = str .. "/end\n"
	
	local macrobutton = CreateFrame("Button",self.name .. "Button" ,UIParent,"SecureActionButtonTemplate")
	macrobutton:SetAttribute("type","macro")
	macrobutton:SetAttribute("macrotext",str)
end

function AM_DPSTemplate:IsRequiredTarget(unit)
	if not self.TargetTable then return true end
	return false --need modification by module
end

function AM_DPSTemplate:IsRequiredSpell(spell)
	return false
end

function AM_DPSTemplate:IsFocus()
	return false
end

function AM_DPSTemplate:R(...) return self:IsRequiredTarget(...) end
function AM_DPSTemplate:iRs(...) return self:IsRequiredSpell(...) end
function AM_DPSTemplate:F(...) return self:IsFocus(...) end

function AM_DPSTemplate:Request()
	_aM=self
end


