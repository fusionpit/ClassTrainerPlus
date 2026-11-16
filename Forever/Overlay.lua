-- copied from Blizzard_TrainerUI\Mainline\Blizzard_TrainerUI.lua, changes marked "CTP:"
local _, ctp = ...; -- CTP: addon namespace
local CLASS_TRAINER_SKILL_HEIGHT = 47;

-- these are from Blizzard_TrainerUI_Camelot.lua
function ClassTrainerPlus_UseCategories()
	return C_Trainer.GetTrainerType() ~= Enum.TrainerType.Pet;
end

local NAME_LEFT_OFFSET = 48;
local NAME_RIGHT_PADDING = 5;
local MONEY_RIGHT_OVERHANG = 5;
local NAME_SUBTEXT_SPACING = 5;
local ALTERNATE_COST_INSET = 15; -- matches the alternateCost anchor offset from money's right edge

local function ClassTrainerPlusSkillButton_UpdateNameWidth(self) -- CTP: was a mixin method
	local priceWidth = 0;
	if self.money:IsShown() then
		priceWidth = self.money:GetWidth();
	elseif self.alternateCost:IsShown() then
		priceWidth = self.alternateCost:GetStringWidth() + ALTERNATE_COST_INSET;
	end

	-- set max width of name so it fits against the price text.
	local availableWidth = self:GetWidth() + MONEY_RIGHT_OVERHANG - priceWidth - NAME_LEFT_OFFSET - NAME_RIGHT_PADDING;
	local nameWidth = math.max(1, math.min(self.name:GetUnboundedStringWidth(), availableWidth));
	self.name:SetWidth(nameWidth);

	-- Hide sub text if it isn't going to fit.
	local subTextWidth = availableWidth - nameWidth - NAME_SUBTEXT_SPACING;
	local showSubText = subTextWidth >= 1 and self.nameSubText:GetText() ~= "";
	-- nameSubText example "(Rank 4)" or "(Requires: Level 60)"
	self.nameSubText:SetShown(showSubText);

	if showSubText then
		self.nameSubText:SetWordWrap(false);
		self.nameSubText:SetWidth(math.min(self.nameSubText:GetUnboundedStringWidth(), subTextWidth));
	end
end

local TrainDisableReason = EnumUtil.MakeEnum("NoProfessionSlot", "CannotAfford");

local TRADE_SKILL_STEP_DISPLAY_INDEX = 0;

local function ClassTrainerPlus_GetSkillIndexForDisplayIndex(displayIndex)
	return (displayIndex and ClassTrainerPlusFrame.displayIndexToSkillIndex and ClassTrainerPlusFrame.displayIndexToSkillIndex[displayIndex]) or displayIndex;
end

local function ClassTrainerPlus_GetDisplayIndexForSkillIndex(skillIndex)
	return (skillIndex and ClassTrainerPlusFrame.skillIndexToDisplayIndex and ClassTrainerPlusFrame.skillIndexToDisplayIndex[skillIndex]) or skillIndex;
end

-- CTP: shared by the popup and the controller
local function ClassTrainerPlus_AcceptProfession()
	BuyTrainerService(ClassTrainerPlus_GetSkillIndexForDisplayIndex(ClassTrainerPlusFrame.selectedService));
	ClassTrainerPlusFrame.showSkillDetails = 1;
	ClassTrainerPlusFrame.showDialog = nil;
	ClassTrainerPlus_SetSelection(ClassTrainerPlus_GetDisplayIndexForSkillIndex(GetTrainerSelectionIndex()));
	local retainScrollPosition = true;
	ClassTrainerPlusFrame_Update(retainScrollPosition);
end

-- CTP: FrameControlsManager adopts StaticPopups in gamepad mode
local function ClassTrainerPlus_ConfirmProfessionWithController()
	local prof1 = GetProfessions();
	local skillLine = GetTrainerServiceSkillLine(ClassTrainerPlus_GetSkillIndexForDisplayIndex(ClassTrainerPlusFrame.selectedService));
	local text = format(prof1 and PROFESSION_CONFIRMATION2 or PROFESSION_CONFIRMATION1, skillLine);
	ctp.ShowControllerMenu(nil, function(owner, rootDescription)
		rootDescription:CreateText(text);
		rootDescription:CreateButton(ACCEPT, function()
			ClassTrainerPlus_AcceptProfession();
			return MenuResponse.Close;
		end);
		rootDescription:CreateButton(CANCEL, function() return MenuResponse.Close; end);
	end);
end

StaticPopupDialogs["CLASS_TRAINER_PLUS_CONFIRM_PROFESSION"] = {
	text = format(PROFESSION_CONFIRMATION1, "XXX"),
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function(dialog, data)
		ClassTrainerPlus_AcceptProfession(); -- CTP
	end,
	OnShow = function(dialog, data)
		local prof1, prof2 = GetProfessions();
		local skillIndex = ClassTrainerPlus_GetSkillIndexForDisplayIndex(ClassTrainerPlusFrame.selectedService);
		if ( prof1 and not prof2 ) then
			dialog:SetFormattedText(PROFESSION_CONFIRMATION2, GetTrainerServiceSkillLine(skillIndex));
		elseif ( not prof1 ) then
			dialog:SetFormattedText(PROFESSION_CONFIRMATION1, GetTrainerServiceSkillLine(skillIndex));
		end
	end,
	showAlert = 1,
	timeout = 0,
	hideOnEscape = 1
};

-- CTP: Blizzard's gamepad support is removed, running it over our frame taints protected calls

function ClassTrainerPlusFrame_OnLoad(self)
	self:RegisterEvent("TRAINER_UPDATE");
	self:RegisterEvent("TRAINER_DESCRIPTION_UPDATE");
	self:RegisterEvent("TRAINER_SERVICE_INFO_NAME_UPDATE");
	self:RegisterEvent("UNIT_PET_TRAINING_POINTS");
	-- CTP: in case a close event is missed
	self:SetScript("OnUpdate", function()
		if not (ClassTrainerFrame and ClassTrainerFrame:IsShown()) then
			self:Hide();
		end
	end);

	self.BG:SetPoint("TOPLEFT", self.ScrollBox, "TOPLEFT", -3, 4);
	self.BG:SetPoint("BOTTOMRIGHT", self.ScrollBox, "BOTTOMRIGHT", 3, -4);
	-- CTP: covers Blizzard's scroll bar and its gamepad hint beneath ours
	local scrollBarBG = self:CreateTexture(nil, "BACKGROUND");
	scrollBarBG:SetColorTexture(0.035, 0.035, 0.035);
	scrollBarBG:SetPoint("TOPLEFT", self.ScrollBar, "TOPLEFT", -2, 0);
	scrollBarBG:SetPoint("BOTTOMRIGHT", self.ScrollBar, "BOTTOMRIGHT", 6, 0);

	local indent = 10;
	local padLeft = 0;
	local pad = 1;
	local spacing = 0;
	local view = CreateScrollBoxListTreeListView(indent, pad, pad, padLeft, pad, spacing);
	view:SetElementFactory(function(factory, node)
		local elementData = node:GetData();
		if elementData.categoryInfo then
			local function Initializer(button)
				ClassTrainerPlusFrame_InitCategoryButton(button, node);
			end
			factory("ClassTrainerPlusCategoryTemplate", Initializer);
		else
			local function Initializer(button)
		ClassTrainerPlusFrame_InitServiceButton(button, elementData);
			end
			factory("ClassTrainerPlusSkillButtonTemplate", Initializer);
		end
	end);

	view:SetElementExtentCalculator(function(dataIndex, node)
		local elementData = node:GetData();
		if elementData.categoryInfo then
			return 25;
		end

		return CLASS_TRAINER_SKILL_HEIGHT;
	end);

	ScrollUtil.InitScrollBoxListWithScrollBar(self.ScrollBox, self.ScrollBar, view);

	self.collapsedCategories = {};
end

function ClassTrainerPlusFrame_InitCategoryButton(categoryButton, node)
	local elementData = node:GetData();
	categoryButton.Label:SetText(elementData.categoryInfo.name);

	local function SetCollapseState(collapsed)
		local atlas = collapsed and "Professions-recipe-header-expand" or "Professions-recipe-header-collapse";
		categoryButton.CollapseIcon:SetAtlas(atlas, TextureKitConstants.UseAtlasSize);
		categoryButton.CollapseIconAlphaAdd:SetAtlas(atlas, TextureKitConstants.UseAtlasSize);
	end

	SetCollapseState(node:IsCollapsed());
	categoryButton:SetScript("OnClick", function()
		node:ToggleCollapsed();
		local collapsed = node:IsCollapsed();
		SetCollapseState(collapsed);
		ClassTrainerPlusFrame.collapsedCategories[elementData.categoryInfo.name] = collapsed or nil;
	end);

	categoryButton:SetScript("OnEnter", function()
		categoryButton.Label:SetFontObject(GameFontHighlight_NoShadow);
	end);

	categoryButton:SetScript("OnLeave", function()
		categoryButton.Label:SetFontObject(GameFontNormal_NoShadow);
	end);
end

local function AreCategoriesEnabled()
	return C_Trainer.GetCategorizeTrainerUI();
end

local function ToggleCategoriesEnabled()
	if not ClassTrainerPlus_UseCategories() then
		return;
	end

	C_Trainer.SetCategorizeTrainerUI(not C_Trainer.GetCategorizeTrainerUI());

	ClassTrainerPlusFrame_Update(true);
end

local function IsSelected(filter)
	return GetTrainerServiceTypeFilter(filter);
end

local function SetSelected(filter)
	ClassTrainerPlusFrame.filterPending = true;
	SetTrainerServiceTypeFilter(filter, not IsSelected(filter));
end

function ClassTrainerPlusFrame_OnShow(self)
	ClassTrainerPlusTrainButton.disableReason = nil;
	ClassTrainerPlusFrame_SetTrainButtonEnabled(false);

	ClassTrainerPlusFrame.selectedService = nil;

	local retainScrollPosition = false;
	ClassTrainerPlusFrame_Update(retainScrollPosition);

	ClassTrainerPlus_SelectNearestLearnableSkill();

	self.FilterDropdown:SetupMenu(ctp.GenerateFilterMenu); -- CTP: shared with the controller
end

-- CTP: filter menu for mouse and controller
function ctp.GenerateFilterMenu(dropdown, rootDescription)
	rootDescription:SetTag("MENU_CLASS_TRAINER_PLUS_FILTER");

	if ClassTrainerPlus_UseCategories() then
		local filtersSubmenu = rootDescription:CreateButton(FILTERS);
		filtersSubmenu:CreateCheckbox(GREEN_FONT_COLOR:WrapTextInColorCode(AVAILABLE), IsSelected, SetSelected, "available");
		filtersSubmenu:CreateCheckbox(RED_FONT_COLOR:WrapTextInColorCode(UNAVAILABLE), IsSelected, SetSelected, "unavailable");
		filtersSubmenu:CreateCheckbox(GRAY_FONT_COLOR:WrapTextInColorCode(USED), IsSelected, SetSelected, "used");
		if ctp.IgnoresApply() then -- CTP: class trainers only, like Era/TBC
			filtersSubmenu:CreateCheckbox(LIGHTYELLOW_FONT_COLOR:WrapTextInColorCode(ctp.L.IGNORED), ctp.IsShowingIgnored, ctp.ToggleShowIgnored);
		end

		rootDescription:CreateCheckbox(CATEGORIZE, AreCategoriesEnabled, ToggleCategoriesEnabled, "categorize");
	else
		rootDescription:CreateCheckbox(GREEN_FONT_COLOR:WrapTextInColorCode(AVAILABLE), IsSelected, SetSelected, "available");
		rootDescription:CreateCheckbox(RED_FONT_COLOR:WrapTextInColorCode(UNAVAILABLE), IsSelected, SetSelected, "unavailable");
		rootDescription:CreateCheckbox(GRAY_FONT_COLOR:WrapTextInColorCode(USED), IsSelected, SetSelected, "used");
	end
end

-- CTP: Blizzard's frame closes the trainer
function ClassTrainerPlusFrame_OnHide(self)
	self.SearchBox:SetText(""); -- CTP: start unfiltered
	if ( StaticPopup_Visible("CLASS_TRAINER_PLUS_CONFIRM_PROFESSION") ) then
		StaticPopup_Hide("CLASS_TRAINER_PLUS_CONFIRM_PROFESSION");
	end
end

function ClassTrainerPlusFrame_OnEvent(self, event, ...)
	if ( event == "TRAINER_UPDATE" ) then
		local retainScrollPosition = true;
		if ClassTrainerPlusFrame.filterPending then
			ClassTrainerPlusFrame.filterPending = nil;
			retainScrollPosition = false;
		end

		ClassTrainerPlusFrame_Update(retainScrollPosition);
	elseif ( event == "TRAINER_DESCRIPTION_UPDATE" ) then
		ClassTrainerPlus_SetSelection(ClassTrainerPlus_GetDisplayIndexForSkillIndex(GetTrainerSelectionIndex()));
	elseif ( event == "TRAINER_SERVICE_INFO_NAME_UPDATE" ) then
		-- It would be really cool if I could uniquely identify the button associated
		-- with a particular spell here, and only update the name on that button.
		local retainScrollPosition = true;
		ClassTrainerPlusFrame_Update(retainScrollPosition);
	elseif ( event == "UNIT_PET_TRAINING_POINTS" ) then
		ClassTrainerPlusFrame_UpdateTrainingPoints();
	end
end

function ClassTrainerPlusFrame_SetTrainButtonEnabled(enabled, disableReason)
	ClassTrainerPlusTrainButton:SetEnabled(enabled);

	if enabled then
		ClassTrainerPlusTrainButton:SetScript("OnEnter", nil);
		ClassTrainerPlusTrainButton:SetScript("OnLeave", nil);
	else
		ClassTrainerPlusTrainButton:SetScript("OnEnter", function()
			-- Tooltips have not been asked for other disabled cases
			if ClassTrainerPlusTrainButton.disableReason == TrainDisableReason.NoProfessionSlot then
				GameTooltip:SetOwner(ClassTrainerPlusTrainButton, "ANCHOR_RIGHT");
				GameTooltip_AddNormalLine(GameTooltip, TRAINER_CANNOT_EXCEED_MAX_PROFESSIONS, true);
				GameTooltip:Show();
			end
		end);
		ClassTrainerPlusTrainButton:SetScript("OnLeave", function()
			GameTooltip_Hide();
		end);
	end

	if ctp.controllerActive then -- CTP: was the PromptedBindings footer
		ctp.RefreshControllerLegend();
	end
end

local function EntrySortComparator(lhs, rhs)
	local lhsCategory = lhs.data.categoryInfo;
	local rhsCategory = rhs.data.categoryInfo;

	if lhsCategory and rhsCategory then
		return lhsCategory.name < rhsCategory.name;
	end

	if lhsCategory and not rhsCategory then
		return true;
	end

	if not lhsCategory and rhsCategory then
		return false;
	end

	return lhs.data.skillIndex < rhs.data.skillIndex;
end

function ClassTrainerPlusFrame_Update(retainScrollPosition)

	-- CTP: portrait, title, rank bar and money are Blizzard's
	ClassTrainerPlusFrame.FilterDropdown:SetText(ClassTrainerPlus_UseCategories() and SETTINGS or FILTERS);

	local scrollBox = ClassTrainerPlusFrame.ScrollBox;

	local numTrainerServices = GetNumTrainerServices();
	local playerMoney = GetMoney();
	local tradeSkillStepIndex = GetTrainerServiceStepIndex();

	local empty = true;

	local dataProvider = CreateTreeDataProvider();
	dataProvider:SetSortComparator(EntrySortComparator);
	local categoryNodes = {};
	for index = 1, numTrainerServices do
		if index ~= tradeSkillStepIndex and ctp.IsServiceShown(index) then -- CTP: filters
			local _serviceName, _serviceType, _texture, _reqLevel, _serviceSubText, category = GetTrainerServiceInfo(index);
			local elementData = {
				skillIndex=index,
				playerMoney=playerMoney,
				trainerType=C_Trainer.GetTrainerType(),
			};

			if ClassTrainerPlus_UseCategories() and AreCategoriesEnabled() and category and category ~= "" then
				local categoryNode = categoryNodes[category];
				if not categoryNode then
					categoryNode = dataProvider:Insert({
						categoryInfo = {
							name = category,
						},
					});
					categoryNodes[category] = categoryNode;

					if ClassTrainerPlusFrame.collapsedCategories[category] then
						categoryNode:SetCollapsed(true);
					end
				end

				categoryNode:Insert(elementData);
				elementData.categoryNode = categoryNode;
			else
				dataProvider:Insert(elementData);
			end
			empty = false;
		end
	end

	if tradeSkillStepIndex then
		local elementData = {
			skillIndex=tradeSkillStepIndex,
			displayIndex=TRADE_SKILL_STEP_DISPLAY_INDEX,
			playerMoney=playerMoney,
			trainerType=C_Trainer.GetTrainerType(),
		}
		ClassTrainerPlusFrame_InitServiceButton(ClassTrainerPlusFrame.skillStepButton, elementData);
	else
		ClassTrainerPlusFrame.skillStepButton:Hide();
	end

	-- Assign a display index to each skill since by this point the data provider will have sorted them
	local displayIndex = 1;
	local displayIndexToSkillIndex = {};
	local skillIndexToDisplayIndex = {};
	local selectedElementData;
	for _, node in dataProvider:EnumerateEntireRange() do
		local elementData = node.data;
		if elementData.skillIndex then
			elementData.displayIndex = displayIndex;
			displayIndexToSkillIndex[displayIndex] = elementData.skillIndex;
			skillIndexToDisplayIndex[elementData.skillIndex] = displayIndex;
			if displayIndex == ClassTrainerPlusFrame.selectedService then
				selectedElementData = elementData;
			end
			displayIndex = displayIndex + 1;
		end
	end

	-- If you train all the skills in a category and the next category is collapsed we need to expand it
	if selectedElementData and selectedElementData.categoryNode and selectedElementData.categoryNode:IsCollapsed() then
		selectedElementData.categoryNode:SetCollapsed(false);
		ClassTrainerPlusFrame.collapsedCategories[selectedElementData.categoryNode:GetData().categoryInfo.name] = false;
	end

	if tradeSkillStepIndex then
		displayIndexToSkillIndex[TRADE_SKILL_STEP_DISPLAY_INDEX] = tradeSkillStepIndex;
		skillIndexToDisplayIndex[tradeSkillStepIndex] = TRADE_SKILL_STEP_DISPLAY_INDEX;
	end

	ClassTrainerPlusFrame.displayIndexToSkillIndex = displayIndexToSkillIndex;
	ClassTrainerPlusFrame.skillIndexToDisplayIndex = skillIndexToDisplayIndex;

	-- CTP: a selection past the end of a filtered list would map to a hidden service
	if ClassTrainerPlusFrame.selectedService and not displayIndexToSkillIndex[ClassTrainerPlusFrame.selectedService] then
		ClassTrainerPlusFrame.selectedService = nil;
		ClassTrainerPlusFrame_SetTrainButtonEnabled(false);
	end

	scrollBox:SetDataProvider(dataProvider, retainScrollPosition, false);

	local rank = GetTrainerTradeskillRankValues();
	ClassTrainerPlusFrame.SearchBox:SetShown(not (rank and rank > 0)); -- CTP: the rank bar's spot

	if empty then
		ClassTrainerPlusFrame_SetTrainButtonEnabled(false);
	end

	if ctp.controllerActive then -- CTP: was UpdateGamepadFocus
		ctp.OnTrainerListUpdated();
	end
end

-- CTP: Blizzard's frame shows the points, this updates row costs
function ClassTrainerPlusFrame_UpdateTrainingPoints()
	local view = ClassTrainerPlusFrame.ScrollBox:GetView();

	for i=1,view:GetFrameCount(),1 do
		if view.frames[i] and view.frames[i].update then
			view.frames[i].update();
		end
	end
end

function ClassTrainerPlusFrame_InitServiceButton(skillButton, elementData)
	elementData = elementData and (elementData.data or elementData);
	if not elementData or not elementData.skillIndex then
		return;
	end

	local skillIndex = elementData.skillIndex;
	local displayIndex = elementData.displayIndex;
	local playerMoney = elementData.playerMoney;
	local isPetSkill = elementData.trainerType == Enum.TrainerType.Pet;

	local unit = isPetSkill and "pet" or "player";

	ClassTrainerPlusTrainButton.disableReason = nil;

	local available = true;
	local serviceName, serviceType, texture, reqLevel, serviceSubText = GetTrainerServiceInfo(skillIndex);
	if ( not serviceName ) then
		serviceName = UNKNOWN;
	end

	skillButton.icon:SetTexture(texture);

	local requirements = "";
	local separator = "";
	if reqLevel and reqLevel > 1 then
		if ( UnitLevel(unit) >= reqLevel ) then
			requirements = requirements..format(TRAINER_REQ_LEVEL, reqLevel);
		else
			requirements = requirements..format(TRAINER_REQ_LEVEL_RED, reqLevel);
		end
		separator = PLAYER_LIST_DELIMITER;
	end


	local skill, rank, hasSkillReq = GetTrainerServiceSkillReq(skillIndex);
	if ( skill ) then
		if ( hasSkillReq ) then
			requirements = requirements..separator..format(TRAINER_REQ_SKILL_RANK, skill, rank );
		else
			requirements = requirements..separator..format(TRAINER_REQ_SKILL_RANK_RED, skill, rank );
		end
		separator = PLAYER_LIST_DELIMITER;
	end


	-- Ability Requirements
	local numRequirements = GetTrainerServiceNumAbilityReq(skillIndex);
	local ability, hasAbilReq;
	if ( numRequirements > 0 ) then
		for i=1, numRequirements, 1 do
			ability, hasAbilReq = GetTrainerServiceAbilityReq(skillIndex, i);
			if ( ability ) then
				if ( hasAbilReq ) then
					requirements = requirements..separator..format(TRAINER_REQ_ABILITY, ability );
				else
					requirements = requirements..separator..format(TRAINER_REQ_ABILITY_RED, ability );
				end
			end
		end
	end

	if ( serviceType == "unavailable" ) then
		skillButton.icon:SetDesaturated(true);
		skillButton.name:SetText(GRAY_FONT_COLOR_CODE..serviceName..FONT_COLOR_CODE_CLOSE);
		skillButton.disabledBG:Show();
	else
		skillButton.icon:SetDesaturated(false);
		skillButton.disabledBG:Hide();
	end

	local showMoney = true;
	if ( requirements ~= "" and serviceType ~= "used" ) then
		requirements = REQUIRES_LABEL.." "..requirements;
	elseif ( serviceType == "used" ) then
		requirements = ITEM_SPELL_KNOWN;
		showMoney = false;
	else
		requirements = "";
	end

	skillButton.name:SetText(serviceName);
	if serviceType ~= "used" and ctp.IsIgnored(skillIndex) then -- CTP: ignored
		skillButton.name:SetText(LIGHTYELLOW_FONT_COLOR:WrapTextInColorCode(serviceName));
	end
	skillButton.subText:SetText(requirements);
	if ( serviceSubText and serviceSubText ~= "") then
		skillButton.nameSubText:SetText(PARENS_TEMPLATE:format(serviceSubText));
	else
		skillButton.nameSubText:SetText("");
	end


	local moneyCost, isProfession = GetTrainerServiceCost(skillIndex);
	if ( not isPetSkill and showMoney and moneyCost and moneyCost > 0 ) then
		MoneyFrame_Update(skillButton.money, moneyCost);
		if ( playerMoney >= moneyCost ) then
			SetMoneyFrameColorByFrame(skillButton.money, "white");
		else
			SetMoneyFrameColorByFrame(skillButton.money, "red");
			available = false;
			ClassTrainerPlusTrainButton.disableReason = TrainDisableReason.CannotAfford;
		end
		skillButton.money:Show();
	else
		skillButton.money:SetWidth(1);
		skillButton.money:Hide();
	end

	-- Alternate Costs
	if isPetSkill and moneyCost > 0 then
		skillButton.money:Hide();
		skillButton.alternateCost:Show();

		skillButton.update = function()
			local total, used = C_PetInfo.GetPetTrainingPoints();
			local points = total - used;

			skillButton.alternateCost:SetFormattedText(TRAINING_POINTS_ABBREV, tostring(moneyCost));
			if points < moneyCost then
				skillButton.alternateCost:SetTextColor(RED_FONT_COLOR:GetRGB());
				available = false;
				ClassTrainerPlusTrainButton.disableReason = TrainDisableReason.CannotAfford;
			else
				skillButton.alternateCost:SetTextColor(DARKYELLOW_FONT_COLOR:GetRGB());
			end
		end

		skillButton.update();
	else
		skillButton.alternateCost:Hide();
	end

	ClassTrainerPlusSkillButton_UpdateNameWidth(skillButton);

	-- Place the highlight and lock the highlight state
	if isProfession then
		local noAvailableSlot = select(2, GetProfessions()) ~= nil;
		local cannotAcquireService = serviceType == "available" and noAvailableSlot;
		if cannotAcquireService then
			available = false;
			ClassTrainerPlusTrainButton.disableReason = TrainDisableReason.NoProfessionSlot;
		end
	end

	if ( ClassTrainerPlusFrame.selectedService == displayIndex ) then
		ClassTrainerPlusFrame.showDialog = isProfession;
		skillButton.selectedTex:Show();

		-- This ClassTrainerPlusFrame_SetTrainButtonEnabled logic should be moved out of the button initializer to
		-- the point where a button/option is selected.
		ClassTrainerPlusFrame_SetTrainButtonEnabled(serviceType == "available" and available);
		-- CTP: no SmartNavigation sync
	else
		skillButton.selectedTex:Hide();
	end

	if skillButton.showingTooltip then
		GameTooltip:SetTrainerService(skillButton:GetID());
	end

	skillButton.isAvailable = serviceType == "available" and available;
	skillButton.displayIndex = displayIndex;
	skillButton:SetID(skillIndex);
	skillButton:Hide(); -- Forces the anchors in the button to update (Hack)
	skillButton:Show();
end

function ClassTrainerPlus_SelectNearestLearnableSkill()
	local scrollBox = ClassTrainerPlusFrame.ScrollBox;

	local startDisplayIndex = 1;
	if ClassTrainerPlusFrame.selectedService then
		local skillIndex = ClassTrainerPlus_GetSkillIndexForDisplayIndex(ClassTrainerPlusFrame.selectedService);
		local _, serviceType = GetTrainerServiceInfo(skillIndex);
		if serviceType ~= "unavailable" then
			startDisplayIndex = ClassTrainerPlusFrame.selectedService;
		end
	end

	local newSelection = nil;
	for _, node in scrollBox:EnumerateDataProviderEntireRange() do
		local elementData = node.data;
		if elementData.skillIndex and elementData.displayIndex >= startDisplayIndex then
			local _, serviceType = GetTrainerServiceInfo(elementData.skillIndex);
			if ( serviceType == "available" ) then
				newSelection = elementData.displayIndex;
				break;
			end
		end
	end

	if newSelection then
		ClassTrainerPlus_SetSelection( newSelection );

		ClassTrainerPlusFrame.ScrollBox:ScrollToElementDataByPredicate(function(elementData)
			elementData = elementData and (elementData.data or elementData);
			return elementData and elementData.displayIndex and elementData.displayIndex == ClassTrainerPlusFrame.selectedService;
		end, ScrollBoxConstants.AlignNearest);
	end
end

function ClassTrainerPlus_SetSelection(displayIndex)
	local oldSelectedService = ClassTrainerPlusFrame.selectedService;
	ClassTrainerPlusFrame.selectedService = displayIndex;

	-- Setting it to > count effectively resets it
	local skillIndex = ClassTrainerPlus_GetSkillIndexForDisplayIndex(displayIndex);
	SelectTrainerService(skillIndex or (GetNumTrainerServices() + 1));

	local function ReinitializeButton(displayIndexToFind)
		if not displayIndexToFind then
			return;
		end

		local button = ClassTrainerPlusFrame.ScrollBox:FindFrameByPredicate(function(frame, elementData)
			elementData = elementData and (elementData.data or elementData);
			return elementData and elementData.displayIndex and elementData.displayIndex == displayIndexToFind;
		end);
		if button then
			ClassTrainerPlusFrame_InitServiceButton(button, button:GetElementData());
		end
	end

	ReinitializeButton(oldSelectedService);
	ReinitializeButton(ClassTrainerPlusFrame.selectedService);

	local tradeSkillStepIndex = GetTrainerServiceStepIndex();
	if tradeSkillStepIndex then
		local elementData = {
			skillIndex=tradeSkillStepIndex,
			displayIndex=TRADE_SKILL_STEP_DISPLAY_INDEX,
			playerMoney=GetMoney(),
			trainerType=C_Trainer.GetTrainerType(),
		}
		ClassTrainerPlusFrame_InitServiceButton(ClassTrainerPlusFrame.skillStepButton, elementData);
	end

	-- Close the confirmation dialog if you choose a different skill
	if ( StaticPopup_Visible("CLASS_TRAINER_PLUS_CONFIRM_PROFESSION") ) then
		StaticPopup_Hide("CLASS_TRAINER_PLUS_CONFIRM_PROFESSION");
	end

	if ctp.controllerActive then -- CTP: was OnSmartNavSelect
		ctp.OnSelectionChanged(displayIndex);
	end
end

function ClassTrainerPlusSkillButton_OnClick(self, button)
	if ( button == "LeftButton" ) then
		ClassTrainerPlus_SetSelection(self.displayIndex);
	elseif ctp.CanIgnore(self) then -- CTP: ignore menu
		ctp.ShowIgnoreMenu(self);
	end
end

function ClassTrainerPlusTrainButton_OnClick(self, button)
	if ( IsTradeskillTrainer() and ClassTrainerPlusFrame.showDialog) then
		if ctp.controllerActive then -- CTP
			ClassTrainerPlus_ConfirmProfessionWithController();
		else
			StaticPopup_Show("CLASS_TRAINER_PLUS_CONFIRM_PROFESSION");
		end
	else
		local skillIndex = ClassTrainerPlus_GetSkillIndexForDisplayIndex(ClassTrainerPlusFrame.selectedService);
		if skillIndex then
			BuyTrainerService(skillIndex);
		end
	end
end

-- CTP: laid over Blizzard's trainer a frame after it opens
local function open()
	local frame = ClassTrainerPlusFrame;
	if frame:IsShown() or not (ClassTrainerFrame and ClassTrainerFrame:IsShown()) then
		return;
	end
	ctp.controllerActive = InputUtil.IsGamepadUIEnabled();
	if ctp.controllerActive and not ctp.ArmController then
		return; -- CTP: no Controller.lua in beta, use Blizzard's trainer
	end
	-- anchoring onto Blizzard's frames only reads them; their layout drives ours
	frame:SetAllPoints(ClassTrainerFrame);
	for _, key in ipairs({ "ScrollBox", "ScrollBar", "skillStepButton", "TrainButton", "FilterDropdown" }) do
		frame[key]:SetAllPoints(ClassTrainerFrame[key]);
	end
	if ctp.controllerActive then
		ctp.ArmController();
	end
	frame:Show();
end

local events = CreateFrame("Frame");
events:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW");
events:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE");
events:RegisterEvent("TRAINER_CLOSED");
events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION");
events:RegisterEvent("GAME_PAD_ACTIVE_CHANGED");
events:SetScript("OnEvent", function(_, event, kind)
	local frame = ClassTrainerPlusFrame;
	if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
		if kind == Enum.PlayerInteractionType.Trainer then
			C_Timer.After(0, open); -- after Blizzard's frame and footer are up
		end
	elseif event == "INPUT_DEVICE_INTERFACE_TRANSITION" or event == "GAME_PAD_ACTIVE_CHANGED" then
		-- re-arm for the new input mode
		if ClassTrainerFrame and ClassTrainerFrame:IsShown() and ctp.controllerActive ~= InputUtil.IsGamepadUIEnabled() then
			frame:Hide();
			C_Timer.After(0, open);
		end
	elseif event == "TRAINER_CLOSED" or kind == Enum.PlayerInteractionType.Trainer then
		frame:Hide();
	end
end);
