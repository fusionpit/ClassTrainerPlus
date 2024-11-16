local _, ctp = ...
local ignoreStore = LibStub:GetLibrary("FusionIgnoreStore-1.0")

ctp.TrainerServices = {
	totalServices = 0,
	availableCost = 0,
	totalAvailable = 0,
	visibleServices = 0,
	showIgnored = TRAINER_FILTER_IGNORED,
	allHeadersCollapsed = false,
	_updateCandidates = function(self)
		self._byServiceId = {}
		self.showIgnored = TRAINER_FILTER_IGNORED == true
		self.totalServices = GetNumTrainerServices()
		local currentSection = nil
		local candidateSections = {}
		for i = 1, self.totalServices, 1 do
			local serviceName, serviceSubText, serviceType, isExpanded = GetTrainerServiceInfo(i)
			if (serviceType == "header") then
				currentSection = {
					name = serviceName,
					type = serviceType,
					subText = serviceSubText,
					isExpanded = isExpanded,
					serviceId = i,
					skills = {},
					isHidden = false
				}
				self._byServiceId[i] = currentSection
				tinsert(candidateSections, currentSection)
			else
				if (ctp.TooltipNameMap[serviceName] == nil) then
					ctp.TooltipNameMap[serviceName] = {}
				end
				if (serviceSubText and
						ctp.TooltipNameMap[serviceName][serviceSubText] == nil
						and not IsTradeskillTrainer()) then
					GameTooltip:SetTrainerService(i)
					local tooltipName = GameTooltipTextLeft1:GetText()
					if (tooltipName and string.find(tooltipName, serviceName, 1, true)) then
						ctp.TooltipNameMap[serviceName][serviceSubText] = tooltipName
					end
				end
				local ai = ctp.Abilities:GetByNameAndSubText(serviceName, serviceSubText)
				local isIgnored = ai and ignoreStore:IsIgnored(ai.spellId) or false
				local ability = {
					serviceId = i,
					name = serviceName,
					lowerName = strlower(serviceName),
					subText = serviceSubText,
					isIgnored = isIgnored,
					type = serviceType,
					isHidden = false
				}
				if (serviceSubText ~= nil and serviceSubText ~= "") then
					ability.menuTitle = serviceName .. " " .. format(PARENS_TEMPLATE, serviceSubText)
				else
					ability.menuTitle = serviceName
				end
				self._byServiceId[i] = ability
				if (not isIgnored or self.showIgnored or serviceType == 'used') then
					tinsert(currentSection.skills, ability)
				end
				if (isIgnored and serviceType ~= "used") then
					if (not self.showIgnored) then
						ability.isHidden = true
					end
				end
			end
		end
		self._candidates = candidateSections
	end,
	VisibleAvailableServiceIds = function(self)
		if (self._byPosition == nil) then return {} end
		local ids = {}
		for _, ability in ipairs(self._byPosition) do
			if (ability.type == "available" and not ability.isIgnored) then
				tinsert(ids, ability.serviceId)
			end
		end
		return ids
	end,
	SetFilter = function(self, text)
		local oldFilter = self._filter
		self._filter = strlower(text)
		return oldFilter ~= self._filter
	end,
	ApplyFilter = function(self)
		self._byPosition = {}
		self.visibleServices = 0
		self.availableCost = 0
		self.totalAvailable = 0
		local candidateSections = self._candidates
		local numHeaders = #candidateSections
		local numNotExpanded = 0
		for _, candidate in ipairs(candidateSections) do
			local skillsInCandidate = #candidate.skills
			if (self.showIgnored or skillsInCandidate > 0 or not candidate.isExpanded) then
				if (self._filter ~= nil and self._filter ~= "" and candidate.isExpanded) then
					local headerInserted = false
					for _, skill in ipairs(candidate.skills) do
						if (strfind(skill.lowerName, self._filter, 1, true)) then
							if (not headerInserted) then
								tinsert(self._byPosition, candidate)
								headerInserted = true
							end
							if (skill.type == "available" and not skill.isIgnored) then
								self.availableCost = self.availableCost + GetTrainerServiceCost(skill.serviceId)
								self.totalAvailable = self.totalAvailable + 1
							end
							tinsert(self._byPosition, skill)
						end
					end
				else
					tinsert(self._byPosition, candidate)
					for _, skill in ipairs(candidate.skills) do
						tinsert(self._byPosition, skill)
						if (skill.type == "available" and not skill.isIgnored) then
							self.availableCost = self.availableCost + GetTrainerServiceCost(skill.serviceId)
							self.totalAvailable = self.totalAvailable + 1
						end
					end
				end
			else
				candidate.isHidden = true
			end
			if (not candidate.isExpanded and not candidate.isHidden) then
				numNotExpanded = numNotExpanded + 1
			end
		end
		self.visibleServices = #self._byPosition
		self.allHeadersCollapsed = numHeaders == numNotExpanded
	end,
	Update = function(self)
		self:_updateCandidates()
		self:ApplyFilter()
	end,
	IsSelected = function(self, serviceId)
		if (not serviceId or serviceId == 0) then
			return false
		end
		local service = self._byServiceId[serviceId]
		return (service and not service.isHidden) and GetTrainerSelectionIndex() == serviceId
	end,
	GetFirstVisibleNonHeaderService = function(self)
		for _, service in ipairs(self._byPosition) do
			if (service.type ~= "header") then
				return service
			end
		end
	end,
	GetNextAvailableServiceId = function(self, serviceId)
		for id, service in ipairs(self._byPosition) do
			if (service.serviceId == serviceId and id < #self._byPosition) then
				local nextService = self._byPosition[id + 1]
				if (nextService.type == "available") then
					return nextService.serviceId
				else
					serviceId = nextService.serviceId
				end
			end
		end
	end,
	GetServiceAtPosition = function(self, position)
		return self._byPosition[position]
	end,
	GetService = function(self, id)
		return self._byServiceId[id]
	end
}
