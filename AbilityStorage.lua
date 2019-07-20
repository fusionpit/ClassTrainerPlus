local _, ctp = ...

local spellsToStripSubtextFrom = {
	[3127] = true, -- Parry, which is flagged Passive by GetSpellSubtext but not by GetTrainerServiceInfo
	[674] = true, -- Dual Wield, same as Parry
	[2836] = true, -- Detect Traps, passive
	[20608] = true -- Reincarnation, passive
}
local spellsToAllowRanklessMatch = {
	[921] = true, -- Pick Pocket, has Rank 1 in trainer ui, no rank from spell info
	[29166] = true -- Innervate, has Rank 1 in trainer ui, no rank from spell info
}

ctp.RealSpellNameMap = {}
ctp.Abilities = {
	_store = {},
	_spellIds = {},
	_partialMatchSpells = {},
	_getKey = function(serviceName, serviceSubText)
		local abilityKey = serviceName
		if (serviceSubText ~= nil and serviceSubText ~= "") then
			abilityKey = abilityKey .. " " .. serviceSubText
		end
		return abilityKey
	end,
	_getAlternateKey = function(serviceName)
		return serviceName .. " *"
	end,
	-- postStoreFunc gets key as input
	_storeSpellInfo = function(self, spellId, isIgnored, postStoreFunc)
		local spell = Spell:CreateFromSpellID(spellId)
		spell:ContinueOnSpellLoad(
			function()
				local spellName = spell:GetSpellName()
				local subText = spell:GetSpellSubtext()
				if (spellsToStripSubtextFrom[spellId]) then
					subText = ""
				end
				if (spellsToAllowRanklessMatch[spellId]) then
					subText = "*"
				end
				local key = self._getKey(spellName, subText)
				self._store[key] = {
					spellId = spellId,
					isIgnored = isIgnored
				}
				if (postStoreFunc ~= nil) then
					postStoreFunc(key)
				end
			end
		)
	end,
	GetByNameAndSubText = function(self, serviceName, serviceSubText)
		local key = self._getKey(serviceName, serviceSubText)
		if (self._store[key] == nil) then
			key = self._getAlternateKey(serviceName)
			if (self._store[key] ~= nil) then
				return self._store[key]
			end
		end
		if (ctp.RealSpellNameMap[serviceName] and ctp.RealSpellNameMap[serviceName][serviceSubText]) then
			key = self._getKey(ctp.RealSpellNameMap[serviceName][serviceSubText], serviceSubText)
		end
		return self._store[key]
	end,
	IsIgnored = function(self, serviceName, serviceSubText)
		local ability = self:GetByNameAndSubText(serviceName, serviceSubText)
		return ability ~= nil and ability.isIgnored
	end,
	IsSpellIdStored = function(self, spellId)
		return self._spellIds[spellId] ~= nil
	end,
	Load = function(self, table)
		self._store = {}
		self._spellIds = {}
		for _, spellId in pairs(table) do
			self:_storeSpellInfo(
				spellId,
				false,
				function(key)
					self._spellIds[spellId] = key
					if (ClassTrainerPlusFrame and ClassTrainerPlusFrame:IsVisible()) then
						ctp.TrainerServices:Update()
						ClassTrainerPlusFrame_Update()
					end
				end
			)
		end
	end,
	Update = function(self, table)
		for spellId, isIgnored in pairs(table) do
			self:_storeSpellInfo(spellId, isIgnored)
		end
	end
}
