local _, ctp = ...

local GetLocale = GetLocale

local localeText = {
    enUS = {
        IGNORED = "Ignored",
        TRAIN_ALL = "Train All",
        IGNOREALLRANKS = "Ignore all ranks",
        TOTAL_COST_TOOLTIP_FORMAT = "Total cost for %d |4spell:spells;: %s",
        TOTAL_COST_LEARNED_FORMAT = "You learned %d |4spell:spells; at a cost of %s",
        NOT_ENOUGH_ERROR = "You don't have enough money to train everything!",
    },
    frFR = {
        IGNORED = "Ignoré",
        TRAIN_ALL = "Tout entrainer"
    }
}

ctp.L = localeText["enUS"]
local locale = GetLocale()
if (locale == "enUS" or locale == "enGB" or localeText[locale] == nil) then
    return
end
for k, v in pairs(localeText[locale]) do
    ctp.L[k] = v
end
