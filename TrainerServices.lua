local _, ctp = ...;

ctp.TrainerServices = {
	totalServices = 0,
	visibleServices = 0,
	showIgnored = TRAINER_FILTER_IGNORED,
	allHeadersCollapsed = false,
	Update = function(self)
		self._byPosition = {};
		self._byServiceId = {};
		self.showIgnored = TRAINER_FILTER_IGNORED == 1;
		self.totalServices = GetNumTrainerServices();
		local currentSection = nil;
		local candidateSections = {};
		for i = 1, self.totalServices, 1 do
			local serviceName, serviceSubText, serviceType, isExpanded = GetTrainerServiceInfo(i);
			if (serviceType == "header") then
				currentSection = {
					name = serviceName,
					type = serviceType,
					subText = serviceSubText,
					isExpanded = isExpanded,
					serviceId = i,
					skills = {},
					isHidden = false
				};
				self._byServiceId[i] = currentSection;
				tinsert(candidateSections, currentSection);
			else 
				if (ctp.RealSpellNameMap[serviceName] == nil) then
					ctp.RealSpellNameMap[serviceName] = {};
				end
				if (serviceSubText and ctp.RealSpellNameMap[serviceName][serviceSubText] == nil and not IsTradeskillTrainer()) then
					GameTooltip:SetTrainerService(i);
					local tooltipName = GameTooltipTextLeft1:GetText();
					if (tooltipName and string.find(tooltipName, serviceName, 1, true)) then
						ctp.RealSpellNameMap[serviceName][serviceSubText] = tooltipName;
					end
				end
				local isIgnored = ctp.Abilities:IsIgnored(serviceName, serviceSubText);
				local ability =  {
					serviceId = i,
					name = serviceName,
					subText = serviceSubText,
					isIgnored = isIgnored,
					type = serviceType,
					isHidden = false
				};
				if (serviceSubText ~= nil and serviceSubText ~= "") then
					ability.menuTitle = serviceName.." "..format(PARENS_TEMPLATE, serviceSubText);
				else
					ability.menuTitle = serviceName;
				end
				self._byServiceId[i] = ability;
				if (not isIgnored or self.showIgnored) then
					tinsert(currentSection.skills, ability);
				end
				if (isIgnored and serviceType ~= "used") then
					if (not self.showIgnored) then
						ability.isHidden = true;
					end
				end
			end
		end
		self.visibleServices = 0;
		local numHeaders = #candidateSections;
		local numNotExpanded = 0;
		for _, candidate in ipairs(candidateSections) do
			local skillsInCandidate = #candidate.skills
			if (self.showIgnored or skillsInCandidate > 0 or not candidate.isExpanded) then
				self.visibleServices = self.visibleServices + 1;
				self._byPosition[self.visibleServices] = candidate;
				for j = 1, #candidate.skills, 1 do
					self.visibleServices = self.visibleServices + 1;
					self._byPosition[self.visibleServices] = candidate.skills[j];
				end
			else
				candidate.isHidden = true;
			end
			if (not candidate.isExpanded and not candidate.isHidden) then
				numNotExpanded = numNotExpanded + 1;
			end
		end
		self.allHeadersCollapsed = numHeaders == numNotExpanded;
	end,
	IsSelected = function(self, serviceId)
		if (not serviceId or serviceId == 0) then return false; end;
		local service = self._byServiceId[serviceId];
		return (service and not service.isHidden) and GetTrainerSelectionIndex() == serviceId;
	end,
	GetFirstVisibleNonHeaderService = function(self)
		for _, service in ipairs(self._byPosition) do
			if (service.type ~= "header") then
				return service;
			end
		end
	end,
	GetNextAvailableServiceId = function(self, serviceId)
		for id, service in ipairs(self._byPosition) do
			if (service.serviceId == serviceId and id < #self._byPosition) then
				local nextService = self._byPosition[id+1];
				if (nextService.type == "available") then
					return nextService.serviceId;
				else
					serviceId = nextService.serviceId;
				end
			end
		end
	end,
	GetServiceAtPosition = function(self, position)
		return self._byPosition[position];
	end,
	GetService = function(self, id)
		return self._byServiceId[id];
	end
};
function CTP_UpdateService()
	ctp.TrainerServices:Update();
end