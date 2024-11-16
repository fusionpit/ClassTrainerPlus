local _, ctp = ...
local ignoreStore = LibStub:GetLibrary("FusionIgnoreStore-1.0")
--- KNOWN ISSUES:
-- - When ignoring things at the very bottom, it will shift around weird

local CreateFrame = CreateFrame
local GetMoney = GetMoney
local PlaySound = PlaySound
local UnitClass = UnitClass
local UnitName = UnitName
local UnitLevel = UnitLevel
local BuyTrainerService = BuyTrainerService
local SelectTrainerService = SelectTrainerService
local GetTrainerServiceSkillLine = GetTrainerServiceSkillLine
local GetTrainerSelectionIndex = GetTrainerSelectionIndex
local GetTrainerGreetingText = GetTrainerGreetingText
local GetTrainerServiceCost = GetTrainerServiceCost
local GetTrainerServiceIcon = GetTrainerServiceIcon
local GetTrainerServiceLevelReq = GetTrainerServiceLevelReq
local GetTrainerServiceTypeFilter = GetTrainerServiceTypeFilter
local GetTrainerServiceSkillReq = GetTrainerServiceSkillReq
local GetTrainerServiceNumAbilityReq = GetTrainerServiceNumAbilityReq
local GetTrainerServiceAbilityReq = GetTrainerServiceAbilityReq
local SetTrainerServiceTypeFilter = SetTrainerServiceTypeFilter
local GetTrainerServiceInfo = GetTrainerServiceInfo
local GetTrainerServiceDescription = GetTrainerServiceDescription
local GetCoinTextureString = GetCoinTextureString
local IsShiftKeyDown = IsShiftKeyDown
local SetPortraitTexture = SetPortraitTexture
local SetMoneyFrameColor = SetMoneyFrameColor
local CloseTrainer = CloseTrainer
local CloseDropDownMenus = CloseDropDownMenus
local IsTradeskillTrainer = IsTradeskillTrainer
local IsTrainerServiceLearnSpell = IsTrainerServiceLearnSpell
local CollapseTrainerSkillLine = CollapseTrainerSkillLine
local ExpandTrainerSkillLine = ExpandTrainerSkillLine
local EasyMenu = EasyMenu
local UpdateMicroButtons = UpdateMicroButtons
local GetNumPrimaryProfessions = GetNumPrimaryProfessions
local FauxScrollFrame_SetOffset = FauxScrollFrame_SetOffset
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_Update = FauxScrollFrame_Update
local MoneyFrame_Update = MoneyFrame_Update
local StaticPopup_Show = StaticPopup_Show
local StaticPopup_Visible = StaticPopup_Visible
local StaticPopup_Hide = StaticPopup_Hide
local format = format
local strupper = strupper
local strlen = strlen
local tinsert = tinsert
local TRAIN = TRAIN

CLASS_TRAINER_SKILLS_DISPLAYED = 11
CLASS_TRAINER_SKILL_HEIGHT = 16
MAX_LEARNABLE_PROFESSIONS = 2
SKILL_TEXT_WIDTH = 270

-- Trainer Filter Default Values
TRAINER_FILTER_AVAILABLE = true
TRAINER_FILTER_UNAVAILABLE = true
TRAINER_FILTER_USED = false
TRAINER_FILTER_IGNORED = true

UIPanelWindows["ClassTrainerPlusFrame"] = UIPanelWindows["ClassTrainerFrame"]

local _, englishClass = UnitClass("player")
englishClass = string.gsub(string.lower(englishClass), "^%l", string.upper)
if englishClass == 'Deathknight' then
	englishClass = 'DeathKnight'
end

local classSpellIds = _G[format("ClassTrainerPlus%sSpellIds", englishClass)]
ctp.Abilities:Load(classSpellIds)

local function TrainerUpdateHandler()
	ctp.TrainerServices:Update()

	local selectedIndex = GetTrainerSelectionIndex()
	if (selectedIndex > 1) then
		-- Select the first available ability
		local service = ctp.TrainerServices:GetService(selectedIndex)
		if (selectedIndex > ctp.TrainerServices.totalServices) then
			FauxScrollFrame_SetOffset(ClassTrainerPlusListScrollFrame, 0)
			ClassTrainerPlusListScrollFrameScrollBar:SetValue(0)
			local firstAbility = ctp.TrainerServices:GetFirstVisibleNonHeaderService()
			if (firstAbility == nil) then
				selectedIndex = nil
			else
				selectedIndex = firstAbility.serviceId
			end
		elseif (service and service.isHidden) then
			while (service and (service.isHidden or service.type == "header")) do
				selectedIndex = selectedIndex + 1
				service = ctp.TrainerServices:GetService(selectedIndex)
			end
			if (selectedIndex > ctp.TrainerServices.totalServices) then
				selectedIndex = nil
			end
		end
		ClassTrainerPlus_SetSelection(selectedIndex)
	else
		ClassTrainerPlus_SelectFirstLearnableSkill()
	end
	ClassTrainerPlusFrame_Update()
end

local function UpdateUserFilters()
	ctp.TrainerServices:Update()
	if (ClassTrainerPlusFrame and ClassTrainerPlusFrame:IsVisible()) then
		ClassTrainerPlusFrame_Update()
	end
end

local function IsSelected(filter)
	if filter == "ignored" then
		return TRAINER_FILTER_IGNORED
	else
		return GetTrainerServiceTypeFilter(filter);
	end
end

local function SetSelected(filter)
	local newFilterValue = not IsSelected(filter)
	_G["TRAINER_FILTER_" .. strupper(filter)] = newFilterValue
	if filter == "ignored" then 
		TrainerUpdateHandler()
	else
		SetTrainerServiceTypeFilter(filter, newFilterValue);
	end
end

function ClassTrainerPlusFrame_Show()
	-- ShowUIPanel(ClassTrainerPlusFrame)
	ClassTrainerPlusFrame:Show()
	if (not ClassTrainerFrame:IsVisible()) then
		CloseTrainer()
		return
	end
	UpdateUserFilters()
	ClassTrainerPlusTrainButton:Disable()
	--Reset scrollbar
	ClassTrainerPlusListScrollFrameScrollBar:SetMinMaxValues(0, 0)
	ClassTrainerPlusListScrollFrameScrollBar:SetValue(0)

	ClassTrainerPlus_SelectFirstLearnableSkill()

	ctp.TrainerServices:Update()
	ClassTrainerPlusFrame_Update()
	UpdateMicroButtons()

	SetTrainerServiceTypeFilter("available", TRAINER_FILTER_AVAILABLE)
	SetTrainerServiceTypeFilter("unavailable", TRAINER_FILTER_UNAVAILABLE)
	SetTrainerServiceTypeFilter("used", TRAINER_FILTER_USED)

	ClassTrainerPlusFrame.FilterDropdown:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("MENU_TRAINER_PLUS_FILTER");

		rootDescription:CreateCheckbox(GREEN_FONT_COLOR:WrapTextInColorCode(AVAILABLE), IsSelected, SetSelected, "available");
		if (not IsTradeskillTrainer()) then
			rootDescription:CreateCheckbox(LIGHTYELLOW_FONT_COLOR:WrapTextInColorCode(ctp.L["IGNORED"]), IsSelected, SetSelected, "ignored");
		end
		rootDescription:CreateCheckbox(RED_FONT_COLOR:WrapTextInColorCode(UNAVAILABLE), IsSelected, SetSelected, "unavailable");
		rootDescription:CreateCheckbox(GRAY_FONT_COLOR:WrapTextInColorCode(USED), IsSelected, SetSelected, "used");
	end);
end

function ClassTrainerPlusFrame_Hide()
	-- HideUIPanel(ClassTrainerPlusFrame)
	ClassTrainerPlusFrame:Hide()
end

local trainAllCostTooltip = CreateFrame("GameTooltip", "CTPTrainAllCostTooltip", UIParent, "GameTooltipTemplate")
function ClassTrainerPlusFrame_OnLoad(self)
	self:RegisterEvent("TRAINER_UPDATE")
	self:RegisterEvent("TRAINER_DESCRIPTION_UPDATE")
	self:RegisterEvent("TRAINER_SERVICE_INFO_NAME_UPDATE")
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("TRAINER_CLOSED")
	ClassTrainerPlusDetailScrollFrame.scrollBarHideable = 1
	local function ShowCostTooltip()
		trainAllCostTooltip:SetOwner(ClassTrainerPlusTrainButton, "ANCHOR_RIGHT")
		local coloredCoinString = GetCoinTextureString(ctp.TrainerServices.availableCost)
		if (GetMoney() < ctp.TrainerServices.availableCost) then
			coloredCoinString = RED_FONT_COLOR_CODE .. coloredCoinString .. FONT_COLOR_CODE_CLOSE
		end
		trainAllCostTooltip:AddLine(format(ctp.L.TOTAL_COST_TOOLTIP_FORMAT, ctp.TrainerServices.totalAvailable, coloredCoinString))
		trainAllCostTooltip:Show()
	end
	local mousedOver = false
	ClassTrainerPlusTrainButton:SetScript(
		"OnEnter",
		function()
			mousedOver = true
		end
	)
	ClassTrainerPlusTrainButton:SetScript(
		"OnLeave",
		function()
			mousedOver = false
			trainAllCostTooltip:Hide()
		end
	)
	self:SetScript(
		"OnUpdate",
		function()
			if (IsShiftKeyDown()) then
				ClassTrainerPlusTrainButton:SetText(ctp.L.TRAIN_ALL)
				if (mousedOver) then
					ShowCostTooltip()
				end
			else
				ClassTrainerPlusTrainButton:SetText(TRAIN)
				trainAllCostTooltip:Hide()
			end
		end
	)
	self.FilterDropdown:SetWidth(130)
end

function ClassTrainerPlus_OnSearchTextChanged(self)
	SearchBoxTemplate_OnTextChanged(self)
	local filterChanged = ctp.TrainerServices:SetFilter(self:GetText())
	if (not filterChanged) then
		return
	end
	ctp.TrainerServices:ApplyFilter()
	ClassTrainerPlus_SelectFirstLearnableSkill()
	ClassTrainerPlusFrame_Update()
end

function ClassTrainerPlusFrame_OnEvent(self, event, ...)
	if (event == "ADDON_LOADED" and ... == "ClassTrainerPlus") then
		-- Upgrade from 0/1 to true/false in 1.15.4
		TRAINER_FILTER_AVAILABLE = TRAINER_FILTER_AVAILABLE and true or false
		TRAINER_FILTER_UNAVAILABLE = TRAINER_FILTER_UNAVAILABLE and true or false
		TRAINER_FILTER_USED = TRAINER_FILTER_USED and true or false
		TRAINER_FILTER_IGNORED = TRAINER_FILTER_IGNORED and true or false
		SetTrainerServiceTypeFilter("available", TRAINER_FILTER_AVAILABLE)
		SetTrainerServiceTypeFilter("unavailable", TRAINER_FILTER_UNAVAILABLE)
		SetTrainerServiceTypeFilter("used", TRAINER_FILTER_USED)
		ClassTrainerPlusDBPC = ClassTrainerPlusDBPC or {}
		ignoreStore:LoadIfNotAlready()
		ignoreStore:MaybeMigrate(ClassTrainerPlusDBPC)
		ignoreStore:AddSubscription(UpdateUserFilters)
		UpdateUserFilters()
		self:UnregisterEvent("ADDON_LOADED")
	end
	if (not self:IsVisible()) then
		return
	end
	if (event == "TRAINER_UPDATE") then
		TrainerUpdateHandler()
	elseif (event == "TRAINER_DESCRIPTION_UPDATE") then
		ClassTrainerPlus_SetSelection(GetTrainerSelectionIndex())
	elseif (event == "TRAINER_SERVICE_INFO_NAME_UPDATE") then
		-- It would be really cool if I could uniquely identify the button associated
		-- with a particular spell here, and only update the name on that button.
		TrainerUpdateHandler()
	elseif (event == "TRAINER_CLOSED") then
		ClassTrainerPlusFrame_Hide()
	end
end

function ClassTrainerPlusFrame_Update()
	SetPortraitTexture(ClassTrainerPlusFramePortrait, "npc")
	ClassTrainerPlusNameText:SetText(UnitName("npc"))
	ClassTrainerPlusGreetingText:SetText(GetTrainerGreetingText())
	local numFilteredTrainerServices = ctp.TrainerServices.visibleServices
	local skillOffset = FauxScrollFrame_GetOffset(ClassTrainerPlusListScrollFrame)

	-- If no spells then clear everything out
	if (numFilteredTrainerServices == 0) then
		ClassTrainerPlusCollapseAllButton:Disable()
		ClassTrainerPlusFrame.selectedService = nil
	else
		ClassTrainerPlusCollapseAllButton:Enable()
	end

	-- If selectedService is nil hide everything
	if (not ClassTrainerPlusFrame.selectedService) then
		ClassTrainerPlus_HideSkillDetails()
		ClassTrainerPlusTrainButton:Disable()
	end

	-- Change the setup depending on if its a class trainer or tradeskill trainer
	if (IsTradeskillTrainer()) then
		ClassTrainerPlus_SetToTradeSkillTrainer()
	else
		ClassTrainerPlus_SetToClassTrainer()
	end

	-- ScrollFrame update
	FauxScrollFrame_Update(
		ClassTrainerPlusListScrollFrame,
		numFilteredTrainerServices,
		CLASS_TRAINER_SKILLS_DISPLAYED,
		CLASS_TRAINER_SKILL_HEIGHT,
		nil,
		nil,
		nil,
		ClassTrainerPlusSkillHighlightFrame,
		293,
		316
	)

	--ClassTrainerPlusUsedButton:Show();
	ClassTrainerPlusMoneyFrame:Show()

	ClassTrainerPlusSkillHighlightFrame:Hide()
	-- Fill in the skill buttons
	for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED, 1 do
		local skillIndex = i + skillOffset
		local skillButton = _G["ClassTrainerPlusSkill" .. i]
		local serviceName, serviceSubText, serviceType, isExpanded
		local moneyCost

		if (skillIndex <= numFilteredTrainerServices) then
			local service = ctp.TrainerServices:GetServiceAtPosition(skillIndex)
			serviceName = service.name
			serviceSubText = service.subText
			serviceType = service.type
			isExpanded = service.isExpanded
			if (not serviceName) then
				serviceName = UNKNOWN
			end

			-- Set button widths if scrollbar is shown or hidden
			if (ClassTrainerPlusListScrollFrame:IsVisible()) then
				skillButton:SetWidth(293)
			else
				skillButton:SetWidth(323)
			end
			local skillSubText = _G["ClassTrainerPlusSkill" .. i .. "SubText"]
			-- Type stuff
			if (serviceType == "header") then
				local skillText = _G["ClassTrainerPlusSkill" .. i .. "Text"]
				skillText:SetText(serviceName)
				skillText:SetWidth(0)
				skillButton:SetNormalFontObject("GameFontNormal")

				skillSubText:Hide()
				if (isExpanded) then
					skillButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
				else
					skillButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
				end
				_G["ClassTrainerPlusSkill" .. i .. "Highlight"]:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
			else
				skillButton:ClearNormalTexture()
				_G["ClassTrainerPlusSkill" .. i .. "Highlight"]:SetTexture("")
				local skillText = _G["ClassTrainerPlusSkill" .. i .. "Text"]
				skillText:SetText("  " .. serviceName)
				if (serviceSubText and serviceSubText ~= "") then
					skillSubText:SetText(format(PARENS_TEMPLATE, serviceSubText))
					skillText:SetWidth(0)
					skillSubText:SetPoint("LEFT", "ClassTrainerPlusSkill" .. i .. "Text", "RIGHT", 10, 0)
					skillSubText:Show()
				else
					skillSubText:Hide()
					-- A bit of a hack. If there's no subtext, we'll set a width to ensure that we don't overflow.
					skillText:SetWidth(SKILL_TEXT_WIDTH)
				end
				skillText:SetJustifyH('LEFT')

				-- Cost Stuff
				moneyCost, _ = GetTrainerServiceCost(skillIndex)
				if (serviceType == "available") then
					if (not service.isIgnored) then
						skillButton:SetNormalFontObject("GameFontNormalLeftGreen")
						ClassTrainerPlus_SetSubTextColor(skillButton, 0, 0.6, 0)
					else
						skillButton:SetNormalFontObject("ClassTrainerPlusIgnoredFont")
						ClassTrainerPlus_SetSubTextColor(skillButton, 0.6, 0.6, 0.1)
					end
				elseif (serviceType == "used") then
					skillButton:SetNormalFontObject("GameFontDisable")
					ClassTrainerPlus_SetSubTextColor(skillButton, 0.5, 0.5, 0.5)
				else
					if (service.isIgnored) then
						skillButton:SetText(skillButton:GetText() .. " |cFFffffa3*|r")
					end
					skillButton:SetNormalFontObject("GameFontNormalLeftRed")
					ClassTrainerPlus_SetSubTextColor(skillButton, 0.6, 0, 0)
				end
			end
			skillButton:SetID(service.serviceId)
			skillButton:Show()
			-- Place the highlight and lock the highlight state
			if (ctp.TrainerServices:IsSelected(service.serviceId)) then
				ClassTrainerPlusSkillHighlightFrame:SetPoint("TOPLEFT", "ClassTrainerPlusSkill" .. i, "TOPLEFT", 0, 0)
				ClassTrainerPlusSkillHighlightFrame:Show()
				skillButton:LockHighlight()
				ClassTrainerPlus_SetSubTextColor(
					skillButton,
					HIGHLIGHT_FONT_COLOR.r,
					HIGHLIGHT_FONT_COLOR.g,
					HIGHLIGHT_FONT_COLOR.b
				)
				if (moneyCost and moneyCost > 0) then
					ClassTrainerPlusCostLabel:Show()
				end
			else
				skillButton:UnlockHighlight()
			end
		else
			skillButton:Hide()
		end
	end

	-- Show skill details if the skill is visible
	if (ctp.TrainerServices:IsSelected(ClassTrainerPlusFrame.selectedService)) then
		ClassTrainerPlus_ShowSkillDetails()
	else
		ClassTrainerPlus_HideSkillDetails()
	end
	-- Set the expand/collapse all button texture
	if (ctp.TrainerServices.allHeadersCollapsed) then
		ClassTrainerPlusCollapseAllButton.collapsed = 1
		ClassTrainerPlusCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
	else
		ClassTrainerPlusCollapseAllButton.collapsed = nil
		ClassTrainerPlusCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
	end
end

function ClassTrainerPlus_SelectFirstLearnableSkill()
	if (ctp.TrainerServices.visibleServices > 0) then
		ClassTrainerPlusFrame.showSkillDetails = 1
		local firstAbility = ctp.TrainerServices:GetFirstVisibleNonHeaderService()
		if (firstAbility ~= nil) then
			ClassTrainerPlus_SetSelection(firstAbility.serviceId)
		else
			ClassTrainerPlusFrame.showSkillDetails = nil
			ClassTrainerPlusFrame.selectedService = nil
			ClassTrainerPlus_SetSelection()
		end

		FauxScrollFrame_SetOffset(ClassTrainerPlusListScrollFrame, 0)
	else
		ClassTrainerPlusFrame.showSkillDetails = nil
		ClassTrainerPlusFrame.selectedService = nil
		ClassTrainerPlus_SetSelection()
	end
	ClassTrainerPlusListScrollFrame:SetVerticalScroll(0)
end

function ClassTrainerPlus_SetSelection(id)
	-- General Info
	if (not id) then
		ClassTrainerPlus_HideSkillDetails()
		ClassTrainerPlusTrainButton:Disable()
		return
	end

	local showIgnored = TRAINER_FILTER_IGNORED == true
	local serviceName, serviceSubText, serviceType, isExpanded
	local service = ctp.TrainerServices:GetService(id)
	if (service == nil) then
		print("ClassTrainerPlus: Could not retrieve the correct service.  If the trainer window is blank, close and reopen it.  If the window is still blank, disable ClassTrainerPlus and report the issue to the author.")
		return;
	end
	serviceName = service.name
	serviceSubText = service.subText
	serviceType = service.type
	isExpanded = service.isExpanded

	ClassTrainerPlusSkillHighlightFrame:Show()

	if (serviceType == "available") then
		if (not service.isIgnored) then
			ClassTrainerPlusSkillHighlight:SetVertexColor(0, 1.0, 0)
		else
			ClassTrainerPlusSkillHighlight:SetVertexColor(1.0, 1.0, 0.6)
		end
	elseif (serviceType == "used") then
		ClassTrainerPlusSkillHighlight:SetVertexColor(0.5, 0.5, 0.5)
	elseif (serviceType == "unavailable") then
		ClassTrainerPlusSkillHighlight:SetVertexColor(0.9, 0, 0)
	else
		-- Is header, so collapse or expand header
		ClassTrainerPlusSkillHighlightFrame:Hide()

		if (isExpanded) then
			CollapseTrainerSkillLine(id)
		else
			ExpandTrainerSkillLine(id)
		end
		return
	end
	if (ClassTrainerPlusFrame.showSkillDetails) then
		ClassTrainerPlus_ShowSkillDetails()
	else
		ClassTrainerPlus_HideSkillDetails()
		--ClassTrainerPlusTrainButton:Disable();
		return
	end

	if (not serviceName) then
		serviceName = UNKNOWN
	end
	ClassTrainerPlusSkillName:SetText(serviceName)
	if (not serviceSubText) then
		serviceSubText = ""
	end
	ClassTrainerPlusSubSkillName:SetText(PARENS_TEMPLATE:format(serviceSubText))
	ClassTrainerPlusFrame.selectedService = id
	SelectTrainerService(id)
	ClassTrainerPlusSkillIcon:SetNormalTexture(GetTrainerServiceIcon(id))
	-- Build up the requirements string
	local requirements = ""
	-- Level Requirements
	local reqLevel = GetTrainerServiceLevelReq(id)
	local separator = ""
	if (reqLevel > 1) then
		separator = ", "
		local _, isPetLearnSpell = IsTrainerServiceLearnSpell(id)
		if (isPetLearnSpell) then
			if (UnitLevel("pet") >= reqLevel) then
				requirements = requirements .. format(TRAINER_PET_LEVEL, reqLevel)
			else
				requirements = requirements .. format(TRAINER_PET_LEVEL_RED, reqLevel)
			end
		else
			if (UnitLevel("player") >= reqLevel) then
				requirements = requirements .. format(TRAINER_REQ_LEVEL, reqLevel)
			else
				requirements = requirements .. format(TRAINER_REQ_LEVEL_RED, reqLevel)
			end
		end
	end
	-- Skill Requirements
	local skill, rank, hasReq = GetTrainerServiceSkillReq(id)
	if (skill) then
		if (hasReq) then
			requirements = requirements .. separator .. format(TRAINER_REQ_SKILL_RANK, skill, rank)
		else
			requirements = requirements .. separator .. format(TRAINER_REQ_SKILL_RANK_RED, skill, rank)
		end
		separator = ", "
	end
	-- Ability Requirements
	local numRequirements = GetTrainerServiceNumAbilityReq(id)
	local ability, abilityType
	if (numRequirements > 0) then
		for i = 1, numRequirements, 1 do
			ability, hasReq = GetTrainerServiceAbilityReq(id, i)
			_, _, abilityType = GetTrainerServiceInfo(id)
			if (ability) then
				if (hasReq or (abilityType == "used")) then
					requirements = requirements .. separator .. format(TRAINER_REQ_ABILITY, ability)
				else
					requirements = requirements .. separator .. format(TRAINER_REQ_ABILITY_RED, ability)
				end
			end
			separator = ", "
		end
	end
	if (requirements ~= "") then
		ClassTrainerPlusSkillRequirements:SetText(REQUIRES_LABEL .. " " .. requirements)
	else
		ClassTrainerPlusSkillRequirements:SetText("")
	end
	-- Money Frame and cost
	local moneyCost, isProfession = GetTrainerServiceCost(id)
	local unavailable
	if (moneyCost == 0) then
		ClassTrainerPlusDetailMoneyFrame:Hide()
		ClassTrainerPlusCostLabel:Hide()
		ClassTrainerPlusSkillDescription:SetPoint("TOPLEFT", "ClassTrainerPlusCostLabel", "TOPLEFT", 0, 0)
	else
		ClassTrainerPlusDetailMoneyFrame:Show()
		ClassTrainerPlusCostLabel:Show()
		ClassTrainerPlusSkillDescription:SetPoint("TOPLEFT", "ClassTrainerPlusCostLabel", "BOTTOMLEFT", 0, -10)
		if (GetMoney() >= moneyCost) then
			SetMoneyFrameColor("ClassTrainerPlusDetailMoneyFrame", "white")
		else
			SetMoneyFrameColor("ClassTrainerPlusDetailMoneyFrame", "red")
			unavailable = 1
		end
	end

	MoneyFrame_Update("ClassTrainerPlusDetailMoneyFrame", moneyCost)
	if (isProfession) then
		ClassTrainerPlusFrame.showDialog = true
		local profCount = GetNumPrimaryProfessions()
		if profCount >= 2 then
			unavailable = 1
		end
	else
		ClassTrainerPlusFrame.showDialog = nil
	end
	if (not showIgnored and service.isIgnored) then
		unavailable = 1
	end

	ClassTrainerPlusSkillDescription:SetText(GetTrainerServiceDescription(id))
	if (serviceType == "available" and not unavailable) then
		ClassTrainerPlusTrainButton:Enable()
	else
		ClassTrainerPlusTrainButton:Disable()
	end

	-- Determine what type of spell to display
	local isLearnSpell
	local isPetLearnSpell
	isLearnSpell, isPetLearnSpell = IsTrainerServiceLearnSpell(id)
	if (isLearnSpell) then
		if (isPetLearnSpell) then
			ClassTrainerPlusSkillName:SetText(ClassTrainerPlusSkillName:GetText() .. TRAINER_PET_SPELL_LABEL)
		end
	end
	ClassTrainerPlusDetailScrollFrame:UpdateScrollChildRect()

	-- Close the confirmation dialog if you choose a different skill
	if (StaticPopup_Visible("CONFIRM_PROFESSION")) then
		StaticPopup_Hide("CONFIRM_PROFESSION")
	end
end

local menuFrame = CreateFrame("Frame", "ClassTrainerPlusToggleFrame", UIParent, "UIDropDownMenuTemplate")
function ClassTrainerPlusSkillButton_OnClick(self, button)
	if (ClassTrainerPlusToggleFrame ~= nil and ClassTrainerPlusToggleFrame:IsVisible()) then
		CloseDropDownMenus()
	end

	if (button == "LeftButton") then
		local service = ctp.TrainerServices:GetService(self:GetID())
		ClassTrainerPlusFrame.selectedService = service.serviceId
		ClassTrainerPlusFrame.showSkillDetails = 1
		ClassTrainerPlus_SetSelection(self:GetID())
		ClassTrainerPlusFrame_Update()
	elseif (button == "RightButton") then
		local service = ctp.TrainerServices:GetService(self:GetID())
		if (service.type == "header" or service.type == "used") then
			return
		end
		PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
		local menuTitle = service.menuTitle
		local checked = false
		if (service.isIgnored) then
			checked = true
		end
		local ability = ctp.Abilities:GetByNameAndSubText(service.name, service.subText)
		local spellId = ability and ability.spellId or 0
		MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
			rootDescription:CreateTitle(menuTitle)
			rootDescription:CreateCheckbox(ctp.L["IGNORED"], function() return checked end, function()
				PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
				if (spellId ~= nil and spellId > 0) then
					ignoreStore:Flip(spellId)
				else
					print(format("ClassTrainerPlus: could not find spell for %s", service.name))
				end
				-- UpdateUserFilters()
				TrainerUpdateHandler()
				return MenuResponse.Close
			end)
			if (ctp.SpellsToIgnoreAllRanksOn == nil or not ctp.SpellsToIgnoreAllRanksOn[spellId]) then
				local spellIds = ctp.Abilities:GetAllIdsByName(service.name)
				if (spellIds ~= nil) then
					local allIgnored = true
					for _, id in ipairs(spellIds) do
						allIgnored = allIgnored and ignoreStore:IsIgnored(id)
					end
					rootDescription:CreateCheckbox(ctp.L["IGNOREALLRANKS"], function() return allIgnored end, function() 
						PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
						ignoreStore:UpdateMany(spellIds, not allIgnored)
						TrainerUpdateHandler()
						return MenuResponse.Close
					end)
				end
			end
		end)
	end
end

local function log(message)
	print(string.format("ClassTrainerPlus: %s", message))
end

function ClassTrainerPlusTrainButton_OnClick()
	if (IsTradeskillTrainer() and ClassTrainerPlusFrame.showDialog) then
		StaticPopup_Show("CONFIRM_PROFESSION")
	else
		if (not IsTradeskillTrainer() and IsShiftKeyDown()) then
			if (GetMoney() < ctp.TrainerServices.availableCost) then
				log(ctp.L.NOT_ENOUGH_ERROR)
				return
			end
			ClassTrainerPlusFrame:UnregisterEvent("TRAINER_UPDATE")
			local idsToLearn = ctp.TrainerServices:VisibleAvailableServiceIds()
			for i = #idsToLearn, 1, -1 do
				local id = idsToLearn[i]
				BuyTrainerService(id)
			end
			ClassTrainerPlusFrame:RegisterEvent("TRAINER_UPDATE")
			log(format(
				ctp.L.TOTAL_COST_LEARNED_FORMAT,
				#idsToLearn,
				GetCoinTextureString(ctp.TrainerServices.availableCost)
			))
		else
			BuyTrainerService(ClassTrainerPlusFrame.selectedService)
		end
		local nextSelection = ctp.TrainerServices:GetNextAvailableServiceId(ClassTrainerPlusFrame.selectedService)

		if (nextSelection ~= nil and nextSelection <= ctp.TrainerServices.totalServices) then
			ClassTrainerPlusFrame.showSkillDetails = 1
			ClassTrainerPlus_SetSelection(nextSelection)
		else
			ClassTrainerPlusFrame.showSkillDetails = nil
			ClassTrainerPlusFrame.selectedService = nil
		end

		ClassTrainerPlusFrame_Update()
	end
end

function ClassTrainerPlus_SetSubTextColor(button, r, g, b)
	button.subR = r
	button.subG = g
	button.subB = b
	_G[button:GetName() .. "SubText"]:SetTextColor(r, g, b)
end

function ClassTrainerPlusCollapseAllButton_OnClick(self)
	if (self.collapsed) then
		self.collapsed = nil
		ExpandTrainerSkillLine(0)
	else
		self.collapsed = 1
		ClassTrainerPlusListScrollFrameScrollBar:SetValue(0)
		CollapseTrainerSkillLine(0)
	end
end

function ClassTrainerPlus_HideSkillDetails()
	ClassTrainerPlusSkillName:Hide()
	ClassTrainerPlusSkillIcon:Hide()
	ClassTrainerPlusSkillRequirements:Hide()
	ClassTrainerPlusSkillDescription:Hide()
	ClassTrainerPlusDetailMoneyFrame:Hide()
	ClassTrainerPlusCostLabel:Hide()
end

function ClassTrainerPlus_ShowSkillDetails()
	ClassTrainerPlusSkillName:Show()
	ClassTrainerPlusSkillIcon:Show()
	ClassTrainerPlusSkillRequirements:Show()
	ClassTrainerPlusSkillDescription:Show()
	ClassTrainerPlusDetailMoneyFrame:Show()
	--ClassTrainerPlusCostLabel:Show();
end

function ClassTrainerPlus_SetToTradeSkillTrainer()
	CLASS_TRAINER_SKILLS_DISPLAYED = 10
	ClassTrainerPlusSkill11:Hide()
	ClassTrainerPlusListScrollFrame:SetHeight(168)
	ClassTrainerPlusDetailScrollFrame:SetHeight(135)
	ClassTrainerPlusHorizontalBarLeft:SetPoint("TOPLEFT", "ClassTrainerPlusFrame", "TOPLEFT", 15, -259)
end

function ClassTrainerPlus_SetToClassTrainer()
	CLASS_TRAINER_SKILLS_DISPLAYED = 11
	ClassTrainerPlusListScrollFrame:SetHeight(184)
	ClassTrainerPlusDetailScrollFrame:SetHeight(119)
	ClassTrainerPlusHorizontalBarLeft:SetPoint("TOPLEFT", "ClassTrainerPlusFrame", "TOPLEFT", 15, -275)
end

local function trim(str)
	return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

SLASH_CTP1 = "/ctp"
SLASH_CTP2 = "/ClassTrainerPlus"
SlashCmdList["CTP"] = function(msg)
	local _, _, cmd, args = string.find(msg, "%s?(%w+)%s?(.*)")
	cmd = trim(string.lower(cmd))
	args = trim(string.lower(args))
	if (cmd == "import" and args == "") then
		print("You must include the import string when importing")
		return
	elseif (cmd == "import") then
		local import = {}

		if (strlen(args) % 3 ~= 0) then
			print("ClassTrainerPlus could not import due to a malformed input string")
			return
		end
		for i = 1, strlen(args), 3 do
			local part = string.sub(args, i, i + 2)
			if (strlen(part) ~= 3) then
				print(format("ClassTrainerPlus ran into a malformed part, '%s', and aborted the import", part))
				return
			end
			local spellId = tonumber(part, 36)
			if (not ctp.Abilities:IsSpellIdStored(spellId)) then
				print(format("ClassTrainerPlus is aborting the import because spellId %d does not belong to this class", spellId))
				return
			end
			tinsert(import, spellId)
		end
		local newImports = ignoreStore:Import(import)
		TrainerUpdateHandler()
		print(
			format(
				"ClassTrainerPlus imported %d new ignored abilities (%d were already ignored)",
				newImports,
				#import - newImports
			)
		)
	elseif (cmd == "clear") then
		ignoreStore:Clear()
		ctp.Abilities:Load(classSpellIds)
		TrainerUpdateHandler()
		print("ClassTrainerPlus database cleared")
	end
end
