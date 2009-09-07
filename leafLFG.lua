local locale = GetLocale()
local L = setmetatable(locale == 'zhCN' and {
	['LFG-Channel enabled by leafLFG'] = '组队频道由leafLFG自动启用',
	['When join automatically?'] = '何时自动加入',
	['LFG Comment:'] = '注释:',
	['Solo'] = '未组队',
	['Party'] = '小队',
	['Raid'] = '团队',
} or locale == 'zhTW' and {
	['LFG-Channel enabled by leafLFG'] = '組隊頻道由leafLFG自動啟用',
	['When join automatically?'] = '何時自動加入',
	['LFG Comment:'] = '注釋:',
	['Solo'] = '未組隊',
	['Party'] = '小隊',
	['Raid'] = '團隊',
} or {}, {__index=function(t,i) return i end})


local addon = CreateFrame('Frame', 'leafLFG', UIParent)
local playerDisable = ''
local debugf, debug
local debugf = tekDebug and tekDebug:GetFrame('leafLFG')
if debugf then
	debug = function(...) debugf:AddMessage(strjoin(', ', tostringall(...))) end
else
	debug = function() end
end

local open_eye = 'Interface\\AddOns\\leafLFG\\icon.tga'
local closed_eye = 'Interface\\AddOns\\leafLFG\\icon2.tga'
local obj = LibStub('LibDataBroker-1.1'):NewDataObject('leafLFG', {
	type = 'launcher',
	icon = closed_eye,
	label = L["LFG"],
	text = '...',
})

function addon:GetGroupStatus()
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

function addon:GetLFGStatus()
 	local _, _, _, _, _, _, _, _, _, _, lfg, lfm = GetLookingForGroup()
	return lfg or lfm, lfg, lfm
end

function addon:Join()
	local typ, can = addon:GetGroupStatus()
	debug('join GroupStatus', typ, can)
	if not can then return end

	addon:Leave()
	if typ == 'Solo' then
		SetLookingForGroup(3,5,1)
	else
		SetLookingForMore(5,1)
	end
	debug'Joined'
end

function addon:Leave()
	ClearLookingForGroup()
	ClearLookingForMore()
end

function addon:OnEvent(event)
	debug('\n\n\nOnEvent', event)
	local looking = addon:GetLFGStatus()
	obj.text = looking and L['|cff00ff00On|r'] or L['|cffff0000Off|r']
	obj.icon = looking and open_eye or closed_eye
	if event == 'LFG_UPDATE' then return end
	local typ, can = addon:GetGroupStatus()
	debug('GroupStatus', typ, can)

	if playerDisable == typ then return end
	playerDisable = ''

	local status, lfg, lfm = addon:GetLFGStatus()
	debug('LFGStatus', status, lfg, lfm)

	if (not status) and leafLFGDB[typ] and can then
		debug'Auto join!'
		addon:Join()
	end
end

local frame = CreateFrame('Frame', nil, InterfaceOptionsFramePanelContainer)
frame:Hide()
frame.name = 'leafLFG'
addon.option = frame
InterfaceOptions_AddCategory(frame)

function obj.OnClick(self, button)
	if IsModifiedClick() then
		if addon:GetLFGStatus() then
			playerDisable = addon:GetGroupStatus()
			addon:Leave()
		else
			playerDisable = ''
			addon:Join()
		end
	else
		InterfaceOptionsFrame_OpenToCategory(frame)
	end
end

addon:RegisterEvent'VARIABLES_LOADED'
addon:SetScript('OnEvent', function()
	debug'OnLoad'

	local leader, tank, healer, damage = GetLFGRoles()
	if not (leader or tank or healer or damage) then
		SetLFGRoles(false, false, false, true)
	end

	leafLFGDB = setmetatable(leafLFGDB or {}, {__index = {comment = L['LFG-Channel enabled by leafLFG'], Solo = true}})

	addon:OnEvent()
	addon:SetScript('OnEvent', addon.OnEvent)
	addon:RegisterEvent'CHAT_MSG_CHANNEL_NOTICE'
	addon:RegisterEvent'PARTY_MEMBERS_CHANGED'
	addon:RegisterEvent'RAID_ROSTER_UPDATE'
	addon:RegisterEvent'ZONE_CHANGED_NEW_AREA'
	addon:RegisterEvent'LFG_UPDATE'
	SetLFGComment(leafLFGDB.comment)
end)

frame:SetScript("OnShow", function()
	local title = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
	title:SetPoint('TOPLEFT', 16, -16)
	title:SetText('leafLFG')

	local about = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
	about:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -8)
	about:SetPoint('RIGHT', frame, -32, 0)
	about:SetHeight(32)
	about:SetJustifyH('LEFT')
	about:SetJustifyV('TOP')
	about:SetText(GetAddOnMetadata(frame.name, "Notes"))

	local last
	local checkboxes = {}
	for dummy, typ in pairs{'Solo', 'Party', 'Raid'} do
		local check = CreateFrame('CheckButton', nil, frame, 'OptionsCheckButtonTemplate')
		check:SetPoint('TOPLEFT', last or about, 'BOTTOMLEFT', last and 0 or -2, last and 0 or -8)
		check.tooltipText = L["Automatically join the LFG system when "..(typ == "Solo" and "" or L["in "])..L[typ:lower()]]

		local label = check:CreateFontString(nil, 'BACKGROUND', 'GameFontHighlight')
		label:SetPoint('LEFT', check, 'RIGHT', 3, 2)
		label:SetText(L[typ])
		check.label = label

		check:SetChecked(leafLFGDB[typ])
		check.typ = typ

		check:SetScript('OnClick', function(self)

			local joined = addon:GetLFGStatus()
			local status = addon:GetGroupStatus()
			if self:GetChecked() then
				leafLFGDB[self.typ] = true
				if (status == self.typ) and (not joined) then
					playerDisable = ''
					addon:Join()
				end
			else
				leafLFGDB[self.typ] = nil
				if (status == self.typ) and joined then
					playerDisable = ''
					addon:Leave()
				end
			end
		end)

		last = check
		checkboxes[typ] = check
	end

	local commentinputabout = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
	commentinputabout:SetPoint('TOP', last, 'BOTTOM', 0, -8)
	commentinputabout:SetPoint('LEFT', 16, 0)
	commentinputabout:SetText(L['LFG Comment:'])

	local commentinput = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
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

	frame.default = function()
		for i in pairs(leafLFGDB) do leafLFGDB[i] = nil end
		for typ,cb in pairs(checkboxes) do cb:SetChecked(leafLFGDB[typ]) end
		commentinput:ClearFocus()
		commentinput:SetText(leafLFGDB.comment)
		SetLFGComment(leafLFGDB.comment)
	end

	frame:SetScript("OnShow", nil)
end)
