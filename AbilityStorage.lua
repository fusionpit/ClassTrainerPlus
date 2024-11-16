local _, ctp = ...

local spellsToStripSubtextFrom = {
	[3127] = true, -- Parry, which is flagged Passive by GetSpellSubtext but not by GetTrainerServiceInfo
	[674] = true, -- Dual Wield, same as Parry
	[2836] = true, -- Detect Traps, passive
	[20608] = true, -- Reincarnation, passive
}
local spellsToAllowRanklessMatch = {
	[921] = true, -- Pick Pocket, has Rank 1 in trainer ui, no rank from spell info
	[29166] = true, -- Innervate, has Rank 1 in trainer ui, no rank from spell info
}
local spellsToSubstituteSubtextFor = {
	[35694] = 4195, -- Avoidance rank 1, marked passive from spell subtext
	[35698] = 4196, -- Avoidance rank 2
}
local subtextSubstutiteSpells = {}
for spellId,subtextFromSpellId in pairs(spellsToSubstituteSubtextFor) do
	subtextSubstutiteSpells[spellId] = Spell:CreateFromSpellID(subtextFromSpellId)
end
local spellKeysToSkipTooltipNameOn = {}
ctp.TooltipNameMap = {}
ctp.Abilities = {
	_byNameStore = {},
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
	_storeSpellInfo = function(self, spellId, postStoreFunc)
		local spell = Spell:CreateFromSpellID(spellId)
		spell:ContinueOnSpellLoad(
			function()
				-- some stuff, like subtext, might be nil even though we're in the load continuation
        		-- delaying it seems to fix it, and subtext always appears
				RunNextFrame(function()
					local spellName = spell:GetSpellName()
					local subText = spell:GetSpellSubtext()
					if (spellsToStripSubtextFrom[spellId]) then
						subText = ""
					end
					if (spellsToAllowRanklessMatch[spellId]) then
						subText = "*"
					end
					local function store(subText)
						local key = self._getKey(spellName, subText)
						if (ctp.SpellsToIgnoreTooltipNameFor and ctp.SpellsToIgnoreTooltipNameFor[spellId]) then
							spellKeysToSkipTooltipNameOn[key] = true
						end
						self._store[key] = {
							spellId = spellId
						}
						-- when the spell has multiple ranks, add its id to the 'by name' store
						if (string.match(subText or '', RANK)) then
							if (self._byNameStore[spellName] == nil) then
								self._byNameStore[spellName] = {}
							end
							tinsert(self._byNameStore[spellName], spellId)
						end
						if (postStoreFunc ~= nil) then
							postStoreFunc(key)
						end
					end
					if (subtextSubstutiteSpells[spellId]) then
						subtextSubstutiteSpells[spellId]:ContinueOnSpellLoad(
							function()
								RunNextFrame(function() store(subtextSubstutiteSpells[spellId]:GetSpellSubtext()) end)
							end
						)
					else
						store(subText)
					end
				end)
			end
		)
	end,
	GetByNameAndSubText = function(self, serviceName, serviceSubText)
		local key = self._getKey(serviceName, serviceSubText)
		if (spellKeysToSkipTooltipNameOn[key]) then
			return self._store[key]
		end
		if (self._store[key] == nil) then
			key = self._getAlternateKey(serviceName)
			if (self._store[key] ~= nil) then
				return self._store[key]
			end
		end
		if (ctp.TooltipNameMap[serviceName]) then
			local realSpellName = ctp.TooltipNameMap[serviceName][serviceSubText]
			if (realSpellName) then
				key = self._getKey(realSpellName, serviceSubText)
			end
		end
		return self._store[key]
	end,
	GetAllIdsByName = function(self, serviceName)
		return self._byNameStore[serviceName]
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
				function(key)
					self._spellIds[spellId] = key
					if (ClassTrainerPlusFrame and ClassTrainerPlusFrame:IsVisible()) then
						ctp.TrainerServices:Update()
						ClassTrainerPlusFrame_Update()
					end
				end
			)
		end
	end
}
