local timerFrame
local eventFrame
local strgsub = string.gsub
local select = select

local function Initialize()
	local total = nil
	timerFrame = CreateFrame("Frame")
	timerFrame:SetScript("OnUpdate", function(self,elapsed)
		if not total then total = GetTime() elapsed = 0 end
		total = total + elapsed
		local x = self.timers
		while x and x.time <= total do
			SendChatMessage(x.msg, "SAY")
			x = x.next
		end
		self.timers = x
	end)
	timerFrame.queueChat = function(self,time,msg)
		local realTime = time + GetTime()
		local x = self.timers
		local last = x
		local t = {time = realTime, msg = msg}
		total = GetTime()
		if not x then self.timers = t return end
		while x and x.time <= realTime do
			last = x
			x = x.next
		end
		t.next = last.next
		last.next = t
	end
	eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	eventFrame.playerName = UnitName("player")
	eventFrame:SetScript("OnEvent",function(self, event, ...)
		local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId = select(1, ...)
		if not self[spellId] then return end
		if type(self[spellId]) ~= "table" then return end
		local x = self[spellId][eventType]
		if x and sourceName == self.playerName then 
			local str = strgsub(x.msg,"player", sourceName or "")
			str = strgsub(str,"target", destName or "") 
			SendChatMessage(str,"SAY") 
			if x.w then SendChatMessage(x.w,"WHISPER",nil,x.wt)  end
			if x.queue then 
				local str = strgsub(x.qmsg,"player", sourceName or "")
				str = strgsub(str,"target", destName or "") 
				timerFrame:queueChat(x.queue,str)
			end
		end
	end)
end

local function RegisterSpell(spellId,castMsg,applicationMsg,fadeMsg,queueTime,queueMsg,requireMine,whisper,whisperTarget,start)
	eventFrame[spellId] = eventFrame[spellId] or {}
	if castMsg then eventFrame[spellId]["SPELL_CAST_SUCCESS"] = {msg = castMsg,queue = queueTime, qmsg = queueMsg,r = requireMine, w =whisper,wt = whisperTarget  } end
	if applicationMsg then eventFrame[spellId]["SPELL_AURA_APPLIED"] = {msg = applicationMsg, queue = queueTime, qmsg = queueMsg, r = requireMine } end
	if fadeMsg then eventFrame[spellId]["SPELL_AURA_REMOVED"] = {msg = fadeMsg, queue = queueTime, qmsg = queueMsg, r = requireMine } end
	if start then eventFrame[spellId]["SPELL_CAST_START"] = {msg = castMsg,queue = queueTime, qmsg = queueMsg,r = requireMine, w =whisper,wt = whisperTarget  } end
end

Initialize()

local tFrame = CreateFrame("Frame")
tFrame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
local lastTime = GetTime()
tFrame:SetScript("OnEvent",function(self, event, unit, spell, rank, lineID, spellId)

end)
--使用方法
--RegiserSpell(技能ID,"施放成功的喊话","效果开始的时候的喊话","效果结束时候的喊话",延时,"延时结束时的喊话",true)
--如果不需要则用nil代替

RegisterSpell(62618,"<player> 真言术：障 已放，持续10秒",nil,nil,10,"<player> 真言术：障已消失", true)
RegisterSpell(64843,"<player> 神圣赞美诗",nil,"<player> 神圣赞美诗 结束",nil,nil, true)
RegisterSpell(64901,"<player> 希望圣歌",nil,"<player> 希望圣歌 结束",nil,nil, true)

RegisterSpell(33206,nil,"痛苦压制=> <target>，持续8秒","<target> 痛苦压制 已消失",nil,nil, true)
RegisterSpell(47788,nil,"守护之魂=> <target>，持续10秒","<target> 守护之魂 已消失",nil,nil, true)
RegisterSpell(108968,"<player> 已与 <target> 换血 有人受伤了？",nil,nil,nil,nil, true)
RegisterSpell(142723,"<player> 已与 <target> 换血 有人受伤了？",nil,nil,nil,nil, true)
RegisterSpell(32375,"已施放群体驱散，下个宠爱 宠爱 宠爱",nil,nil,nil,nil, true,"YOU NEXT","陌颜丶")
RegisterSpell(142723,"<player> 已与 <target> 换血 有人受伤了？",nil,nil,nil,nil, true)
RegisterSpell(56222,"嘲讽 <target>， 治疗注意加好",nil,nil,nil,nil, true)
RegisterSpell(49576,"嘲讽 <target>， 治疗注意加好",nil,nil,nil,nil, true)
RegisterSpell(62124,"嘲讽 <target>， 治疗注意加好",nil,nil,nil,nil, true)
--RegisterSpell(62618,"<player> 真言术：障 已放，持续10秒",nil,nil,10,"<player> 真言术：障已消失", true)

