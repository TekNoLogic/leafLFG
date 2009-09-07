local locale = GetLocale()
local L = setmetatable(locale == 'zhCN' and {
	['LFG-Channel enabled by leafLFG'] = '组队频道由leafLFG自动启用',
	['When join automatically?'] = '何时自动加入',
	['LFG Comment:'] = '注释:',
	['solo'] = '未组队',
	['party'] = '小队',
	['raid'] = '团队',
} or locale == 'zhTW' and {
	['LFG-Channel enabled by leafLFG'] = '組隊頻道由leafLFG自動啟用',
	['When join automatically?'] = '何時自動加入',
	['LFG Comment:'] = '注釋:',
	['solo'] = '未組隊',
	['party'] = '小隊',
	['raid'] = '團隊',
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

local obj = LibStub('LibDataBroker-1.1'):NewDataObject('leafLFG', {
	type = 'data source',
	icon = 'Interface\\Icons\\spell_shadow_curseofmannoroth',
	label = L["LFG"],
	text = '...',
})

function addon:GetGroupStatus()
	local raidnum = GetRealNumRaidMembers()
	local partynum = GetRealNumPartyMembers()
	if raidnum > 0 then
		return 'raid', (raidnum ~= 40) and IsRaidLeader()
	elseif partynum > 0 then
		return 'party', (partynum ~= 5) and IsPartyLeader'player'
	else
		return 'solo', true
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
	if typ == 'solo' then
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
	obj.text = addon:GetLFGStatus() and L['|cff00ff00On|r'] or L['|cffff0000Off|r']
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
frame.name = 'leafLFG'
addon.option = frame
InterfaceOptions_AddCategory(frame)

function obj.OnClick(self, button)
	if button == 'LeftButton' then
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

	leafLFGDB = setmetatable(leafLFGDB or {}, {__index = {comment = L['LFG-Channel enabled by leafLFG']}})

	addon:OnEvent()
	addon:SetScript('OnEvent', addon.OnEvent)
	addon:RegisterEvent'CHAT_MSG_CHANNEL_NOTICE'
	addon:RegisterEvent'PARTY_MEMBERS_CHANGED'
	addon:RegisterEvent'RAID_ROSTER_UPDATE'
	addon:RegisterEvent'ZONE_CHANGED_NEW_AREA'
	addon:RegisterEvent'LFG_UPDATE'
	SetLFGComment(leafLFGDB.comment)


	local title = frame:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
	title:SetPoint('TOPLEFT', 16, -16)
	title:SetText('leafLFG')

	local about = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
	about:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -5)
	about:SetPoint('RIGHT', frame, -20, 0)
	about:SetHeight(40)
	about:SetJustifyH('LEFT')
	about:SetJustifyV('TOP')
	about:SetText(L['A simple addon helps you join LFG Channel easily'])

	local checkboxabout = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
	checkboxabout:SetPoint('TOPLEFT', about, 'BOTTOMLEFT', 0, -30)
	checkboxabout:SetText(L['When join automatically?'])

	local last
	addon.checkboxes = {}
	for dummy, typ in pairs{'solo', 'party', 'raid'} do
		local check = CreateFrame('CheckButton', nil, frame, 'OptionsCheckButtonTemplate')
		check:SetPoint('TOPLEFT', last or checkboxabout, 'BOTTOMLEFT', last and 0 or 20, last and 0 or -10)

		local label = check:CreateFontString(nil, 'BACKGROUND', 'GameFontNormal')
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
		addon.checkboxes[typ] = check
	end

	local commentinputabout = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall')
	commentinputabout:SetPoint('TOPLEFT', last, 'BOTTOMLEFT', -20, -25)
	commentinputabout:SetText(L['LFG Comment:'])

	local commentinput = CreateFrame('EditBox', nil, frame, 'InputBoxTemplate')
	commentinput:SetHeight(25)
	commentinput:SetWidth(300)
	commentinput:SetAutoFocus(false)
	commentinput:SetPoint('TOPLEFT', commentinputabout, 'BOTTOMLEFT', 5, -5)
	commentinput:SetText(leafLFGDB.comment)
	commentinput:SetScript('OnEscapePressed', commentinput.ClearFocus)
	commentinput:SetScript('OnEnterPressed', commentinput.ClearFocus)
	commentinput:SetScript('OnEditFocusLost', function(self)
		leafLFGDB.comment = self:GetText()
		SetLFGComment(leafLFGDB.comment)
	end)

	frame.default = function()
		for i in pairs(leafLFGDB) do leafLFGDB[i] = nil end
		commentinput:ClearFocus()
		commentinput:SetText(leafLFGDB.comment)
		SetLFGComment(leafLFGDB.comment)
		for dummy, cb in pairs(addon.checkboxes) do
			cb:SetChecked(false)
		end
	end
end)
