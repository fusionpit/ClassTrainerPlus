local addonName, ctp = ...
-- ignores are keyed by spell id, shared with What's Training?
local ignoreStore = LibStub:GetLibrary("FusionIgnoreStore-1.0")

-- called from the CTP: edits in Overlay.lua
-- TRAINER_FILTER_IGNORED = show ignored services, same name as Era/TBC

local search = ""

-- spell name -> every id in Classes\Camelot with that name, filled as spell data loads
local ranksByName = {}
local function loadRanks()
	for _, spellId in ipairs(ctp.SpellIds or {}) do
		if (C_Spell.DoesSpellExist(spellId)) then
			local spell = Spell:CreateFromSpellID(spellId)
			spell:ContinueOnSpellLoad(function()
				local name = spell:GetSpellName()
				ranksByName[name] = ranksByName[name] or {}
				tinsert(ranksByName[name], spellId)
			end)
		end
	end
end

-- no spell id getter for services, but the tooltip data has it
local function getSpellId(index)
	local data = C_TooltipInfo.GetTrainerService(index)
	if (data and data.type == Enum.TooltipDataType.Spell) then
		return data.id
	end
end

local function isPetTrainer()
	return C_Trainer.GetTrainerType() == Enum.TrainerType.Pet
end

-- class trainers only, like Era/TBC
function ctp.IgnoresApply()
	return not isPetTrainer() and not IsTradeskillTrainer()
end

function ctp.IsIgnored(index)
	if (not ctp.IgnoresApply()) then
		return false
	end
	local spellId = getSpellId(index)
	return spellId ~= nil and ignoreStore:IsIgnored(spellId) == true
end

local function matchesSearch(name)
	return search == "" or strfind(strlower(name), search, 1, true) ~= nil
end

function ctp.IsServiceShown(index)
	local name, serviceType = GetTrainerServiceInfo(index)
	if (not name) then
		return true
	end
	if (not matchesSearch(name)) then
		return false
	end
	return serviceType == "used" or TRAINER_FILTER_IGNORED or not ctp.IsIgnored(index)
end

-- shown, available and not ignored
local function getTrainAllServices()
	local ids, cost = {}, 0
	local stepIndex = GetTrainerServiceStepIndex()
	for i = 1, GetNumTrainerServices() do
		local name, serviceType = GetTrainerServiceInfo(i)
		if (name and serviceType == "available" and i ~= stepIndex
				and matchesSearch(name) and not ctp.IsIgnored(i)) then
			tinsert(ids, i)
			cost = cost + GetTrainerServiceCost(i)
		end
	end
	return ids, cost
end

function ctp.HasTrainAll()
	return not IsTradeskillTrainer() and not isPetTrainer() and #getTrainAllServices() > 0
end

function ctp.CanTrainAll()
	if (not ctp.HasTrainAll()) then
		return false
	end
	local _, cost = getTrainAllServices()
	return GetMoney() >= cost
end

-- spells are learned one TRAINER_UPDATE at a time, so the summary waits until none are left
local TRAIN_ALL_TIMEOUT = 5
local pendingTrain

local function finishTrainAll()
	local pending = pendingTrain
	if (not pending) then
		return
	end
	pendingTrain = nil
	pending.timer:Cancel()
	local learned, cost = 0, 0
	for spellId, spellCost in pairs(pending.costs) do
		if (not pending.remaining[spellId]) then
			learned = learned + 1
			cost = cost + spellCost
		end
	end
	if (learned > 0) then
		print(format(ctp.L.TOTAL_COST_LEARNED_FORMAT, learned, GetMoneyString(cost)))
	end
end

local function startTrainAllTimer()
	if (pendingTrain.timer) then
		pendingTrain.timer:Cancel()
	end
	-- refused purchases never leave the list
	pendingTrain.timer = C_Timer.NewTimer(TRAIN_ALL_TIMEOUT, finishTrainAll)
end

local function updateTrainAllProgress()
	if (not pendingTrain) then
		return
	end
	local remaining, numRemaining = {}, 0
	for i = 1, GetNumTrainerServices() do
		local _, serviceType = GetTrainerServiceInfo(i)
		local spellId = serviceType == "available" and getSpellId(i)
		if (spellId and pendingTrain.costs[spellId]) then
			remaining[spellId] = true
			numRemaining = numRemaining + 1
		end
	end
	local madeProgress = numRemaining < pendingTrain.numRemaining
	pendingTrain.remaining = remaining
	pendingTrain.numRemaining = numRemaining
	if (numRemaining == 0) then
		finishTrainAll()
	elseif (madeProgress) then
		startTrainAllTimer()
	end
end

function ctp.TrainAll()
	if (pendingTrain or not ctp.CanTrainAll()) then
		return
	end
	local ids = getTrainAllServices()
	-- by spell id, indexes shift as services are learned
	local costs, remaining, numRemaining = {}, {}, 0
	for _, id in ipairs(ids) do
		local spellId = getSpellId(id)
		if (spellId) then
			costs[spellId] = GetTrainerServiceCost(id)
			remaining[spellId] = true
			numRemaining = numRemaining + 1
		end
	end
	pendingTrain = {costs = costs, remaining = remaining, numRemaining = numRemaining}
	startTrainAllTimer()
	-- backwards so learned services don't shift the rest
	for i = #ids, 1, -1 do
		BuyTrainerService(ids[i])
	end
end

-- covers the Train button while Shift is held
local trainAllButton = CreateFrame("Button", nil, ClassTrainerPlusFrame.TrainButton, "UIPanelButtonTemplate")
trainAllButton:SetAllPoints()
trainAllButton:SetText(ctp.L.TRAIN_ALL)
trainAllButton:SetMotionScriptsWhileDisabled(true) -- keep the tooltip when unaffordable
trainAllButton:Hide()

local function showCostTooltip(button)
	local ids, cost = getTrainAllServices()
	local coinString = GetMoneyString(cost)
	if (GetMoney() < cost) then
		coinString = RED_FONT_COLOR:WrapTextInColorCode(coinString)
	end
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:SetText(format(ctp.L.TOTAL_COST_TOOLTIP_FORMAT, #ids, coinString))
	GameTooltip:Show()
end

local function applyTrainAll()
	local show = IsShiftKeyDown() and ctp.HasTrainAll()
	trainAllButton:SetShown(show)
	trainAllButton:SetEnabled(show and ctp.CanTrainAll())
	if (show and trainAllButton:IsMouseOver()) then
		showCostTooltip(trainAllButton)
	elseif (not show and GameTooltip:GetOwner() == trainAllButton) then
		GameTooltip:Hide()
	end
end

trainAllButton:SetScript("OnClick", ctp.TrainAll)
trainAllButton:SetScript("OnEnter", showCostTooltip)
trainAllButton:SetScript("OnLeave", GameTooltip_Hide)

-- after a search/ignore change, keep the selected service if it's still listed
local function refresh()
	local frame = ClassTrainerPlusFrame
	if (not frame:IsShown()) then
		return
	end
	local skillIndex = frame.selectedService and frame.displayIndexToSkillIndex[frame.selectedService]
	ClassTrainerPlusFrame_Update(true)
	local displayIndex = skillIndex and frame.skillIndexToDisplayIndex[skillIndex]
	if (displayIndex) then
		ClassTrainerPlus_SetSelection(displayIndex)
	elseif (not ctp.controllerActive) then
		-- the controller already moved focus to a nearby row
		ClassTrainerPlus_SetSelection(nil)
		ClassTrainerPlusFrame_SetTrainButtonEnabled(false)
		ClassTrainerPlus_SelectNearestLearnableSkill()
	end
	applyTrainAll()
end

function ctp.IsShowingIgnored()
	return TRAINER_FILTER_IGNORED
end

function ctp.ToggleShowIgnored()
	TRAINER_FILTER_IGNORED = not TRAINER_FILTER_IGNORED
	refresh()
end

function ctp.CanIgnore(skillButton)
	return skillButton ~= nil and skillButton ~= ClassTrainerPlusFrame.skillStepButton and ctp.IgnoresApply()
end

function ctp.ShowIgnoreMenu(skillButton)
	local index = skillButton:GetID()
	local name, _, _, _, subText = GetTrainerServiceInfo(index)
	local spellId = getSpellId(index)
	if (not name or not spellId) then
		return
	end
	local allRanks = ranksByName[C_Spell.GetSpellName(spellId)] or {}
	local function areAllRanksIgnored()
		for _, id in ipairs(allRanks) do
			if (not ignoreStore:IsIgnored(id)) then
				return false
			end
		end
		return true
	end
	-- the store's subscription refreshes the trainer
	local function generator(owner, rootDescription)
		local hasSubText = subText and subText ~= ""
		rootDescription:CreateTitle(hasSubText and (name .. " " .. format(PARENS_TEMPLATE, subText)) or name)
		rootDescription:CreateCheckbox(ctp.L.IGNORED, function()
			return ignoreStore:IsIgnored(spellId)
		end, function()
			PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
			ignoreStore:Flip(spellId)
			return MenuResponse.Close
		end)
		if (#allRanks > 1) then
			rootDescription:CreateCheckbox(ctp.L.IGNOREALLRANKS, areAllRanksIgnored, function()
				PlaySound(SOUNDKIT.U_CHAT_SCROLL_BUTTON)
				ignoreStore:UpdateMany(allRanks, not areAllRanksIgnored())
				return MenuResponse.Close
			end)
		end
	end
	-- the gamepad managers adopt Blizzard's menus
	if (ctp.controllerActive) then
		ctp.ShowControllerMenu(skillButton, generator)
	else
		MenuUtil.CreateContextMenu(skillButton, generator)
	end
end

ClassTrainerPlusFrame.SearchBox:HookScript("OnTextChanged", function(self)
	search = strlower(self:GetText())
	refresh()
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
eventFrame:RegisterEvent("PLAYER_MONEY") -- Train All affordability
eventFrame:RegisterEvent("TRAINER_UPDATE")
eventFrame:RegisterEvent("TRAINER_CLOSED")
eventFrame:SetScript("OnEvent", function(_, event)
	if (event == "TRAINER_CLOSED") then
		-- reports what the last update saw
		finishTrainAll()
		return
	end
	if (event == "TRAINER_UPDATE") then
		updateTrainAllProgress()
	end
	if (ClassTrainerPlusFrame:IsShown()) then
		applyTrainAll()
		if (ctp.controllerActive) then
			ctp.RefreshControllerLegend(true) -- Train All availability
		end
	end
end)

EventUtil.ContinueOnAddOnLoaded(addonName, function()
	if (TRAINER_FILTER_IGNORED == nil) then
		TRAINER_FILTER_IGNORED = true -- Era/TBC default
	end
	ignoreStore:LoadIfNotAlready()
	-- also fires for What's Training? changes
	ignoreStore:AddSubscription(refresh)
	loadRanks()
end)
