local locale = GetLocale()
local L = setmetatable(locale == 'zhCN' and {
	['LFG-Channel enabled by leafLFG'] = '组队频道由leafLFG自动启用',
	['LFG Comment:'] = '注释:',
	['Solo'] = '未组队',
	['Party'] = '小队',
	['Raid'] = '团队',
} or locale == 'zhTW' and {
	['LFG-Channel enabled by leafLFG'] = '組隊頻道由leafLFG自動啟用',
	['LFG Comment:'] = '注釋:',
	['Solo'] = '未組隊',
	['Party'] = '小隊',
	['Raid'] = '團隊',
} or {}, {__index=function(t,i) return i end})


local playerDisable, config = ''
local debugf = tekDebug and tekDebug:GetFrame('leafLFG')
local debug = debugf and function(...) debugf:AddMessage(strjoin(', ', tostringall(...))) end or function() end


local open_eye = 'Interface\\AddOns\\leafLFG\\icon.tga'
local closed_eye = 'Interface\\AddOns\\leafLFG\\icon2.tga'
local obj = LibStub('LibDataBroker-1.1'):NewDataObject('leafLFG', {
	type = 'launcher',
	icon = closed_eye,
	label = L["LFG"],
	text = '...',
})


local function GetGroupStatus()
	local raidnum = GetRealNumRaidMembers()
	local partynum = GetRealNumPartyMembers()
	if raidnum > 0 then
		return 'Raid', (raidnum ~= 40) and IsRaidLeader()
	elseif partynum > 0 then
		return 'Party', (partynum ~= 5) and IsPartyLeader'player'
	else
		return 'Solo', true
	end
end


local function GetLFGStatus()
 	local _, _, _, _, _, _, _, _, _, _, lfg, lfm = GetLookingForGroup()
	return lfg or lfm, lfg, lfm
end


local function Leave()
	ClearLookingForGroup()
	ClearLookingForMore()
end


local function Join()
	local typ, can = GetGroupStatus()
	debug('join GroupStatus', typ, can)
	if not can then return end

	Leave()
	if typ == 'Solo' then
		SetLookingForGroup(3,5,1)
	else
		SetLookingForMore(5,1)
	end
	debug'Joined'
end


local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")


function f:ADDON_LOADED(event, addon)
	if addon:lower() ~= "leaflfg" then return end

	leafLFGDB = setmetatable(leafLFGDB or {}, {__index = {comment = L['LFG-Channel enabled by leafLFG'], Solo = true}})

	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil

	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end


function f:PLAYER_LOGIN()
	self:RegisterEvent('CHAT_MSG_CHANNEL_NOTICE')
	self:RegisterEvent('PARTY_MEMBERS_CHANGED')
	self:RegisterEvent('RAID_ROSTER_UPDATE')
	self:RegisterEvent('ZONE_CHANGED_NEW_AREA')
	self:RegisterEvent('LFG_UPDATE')

	local leader, tank, healer, damage = GetLFGRoles()
	if not (leader or tank or healer or damage) then SetLFGRoles(false, false, false, true) end
	f:CHAT_MSG_CHANNEL_NOTICE(event)
	SetLFGComment(leafLFGDB.comment)

	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
end


function f:LFG_UPDATE(event)
	local looking = GetLFGStatus()
	obj.text = looking and L['|cff00ff00On|r'] or L['|cffff0000Off|r']
	obj.icon = looking and open_eye or closed_eye
end


function f:CHAT_MSG_CHANNEL_NOTICE()
	self:LFG_UPDATE()

	local typ, can = GetGroupStatus()
	debug('GroupStatus', typ, can)

	if playerDisable == typ then return end
	playerDisable = ''

	local status, lfg, lfm = GetLFGStatus()
	debug('LFGStatus', status, lfg, lfm)

	if (not status) and leafLFGDB[typ] and can then
		debug'Auto join!'
		Join()
	end
end
f.PARTY_MEMBERS_CHANGED = f.CHAT_MSG_CHANNEL_NOTICE
f.RAID_ROSTER_UPDATE = f.CHAT_MSG_CHANNEL_NOTICE
f.ZONE_CHANGED_NEW_AREA = f.CHAT_MSG_CHANNEL_NOTICE


function obj.OnClick(self, button)
	if IsModifiedClick() then
		if GetLFGStatus() then
			playerDisable = GetGroupStatus()
			Leave()
		else
			playerDisable = ''
			Join()
		end
	else
		InterfaceOptionsFrame_OpenToCategory(config)
	end
end


config = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
config:Hide()
config.name = 'leafLFG'
InterfaceOptions_AddCategory(config)

config:SetScript("OnShow", function()
	local title = config:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
	title:SetPoint('TOPLEFT', 16, -16)
	title:SetText('leafLFG')

	local about = config:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
	about:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
	about:SetPoint('RIGHT', config, -32, 0)
	about:SetHeight(32)
	about:SetJustifyH('LEFT')
	about:SetJustifyV('TOP')
	about:SetText(GetAddOnMetadata(config.name, "Notes"))

	local last
	local checkboxes = {}
	for dummy, typ in pairs{'Solo', 'Party', 'Raid'} do
		local check = CreateFrame('CheckButton', nil, config, 'OptionsCheckButtonTemplate')
		check:SetPoint('TOPLEFT', last or about, 'BOTTOMLEFT', last and 0 or -2, last and 0 or -8)
		check.tooltipText = L["Automatically join the LFG system when "..(typ == "Solo" and "" or L["in "])..L[typ:lower()]]

		local label = check:CreateFontString(nil, 'BACKGROUND', 'GameFontHighlight')
		label:SetPoint('LEFT', check, 'RIGHT', 3, 2)
		label:SetText(L[typ])
		check.label = label

		check:SetChecked(leafLFGDB[typ])
		check.typ = typ

		check:SetScript('OnClick', function(self)

			local joined = GetLFGStatus()
			local status = GetGroupStatus()
			if self:GetChecked() then
				leafLFGDB[self.typ] = true
				if (status == self.typ) and (not joined) then
					playerDisable = ''
					Join()
				end
			else
				leafLFGDB[self.typ] = nil
				if (status == self.typ) and joined then
					playerDisable = ''
					Leave()
				end
			end
		end)

		last = check
		checkboxes[typ] = check
	end

	local commentinputabout = config:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
	commentinputabout:SetPoint('TOP', last, 'BOTTOM', 0, -8)
	commentinputabout:SetPoint('LEFT', 16, 0)
	commentinputabout:SetText(L['LFG Comment:'])

	local commentinput = CreateFrame('EditBox', nil, config, 'InputBoxTemplate')
	commentinput:SetHeight(25)
	commentinput:SetWidth(300)
	commentinput:SetAutoFocus(false)
	commentinput:SetPoint('TOPLEFT', commentinputabout, 'BOTTOMLEFT', 8, -2)
	commentinput:SetText(leafLFGDB.comment)
	commentinput:SetScript('OnEscapePressed', commentinput.ClearFocus)
	commentinput:SetScript('OnEnterPressed', commentinput.ClearFocus)
	commentinput:SetScript('OnEditFocusLost', function(self)
		leafLFGDB.comment = self:GetText()
		SetLFGComment(leafLFGDB.comment)
	end)

	config.default = function()
		for i in pairs(leafLFGDB) do leafLFGDB[i] = nil end
		for typ,cb in pairs(checkboxes) do cb:SetChecked(leafLFGDB[typ]) end
		commentinput:ClearFocus()
		commentinput:SetText(leafLFGDB.comment)
		SetLFGComment(leafLFGDB.comment)
	end

	config:SetScript("OnShow", nil)
end)
