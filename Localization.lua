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
    ruRU = {
        -- Translator ZamestoTV
        IGNORED = "Игнорируется",
        TRAIN_ALL = "Выучить всё",
        IGNOREALLRANKS = "Игнорировать все ранги",
        TOTAL_COST_TOOLTIP_FORMAT = "Общая стоимость для %d |4заклинания:заклинаний:заклинаний;: %s",
        TOTAL_COST_LEARNED_FORMAT = "Вы выучили %d |4заклинание:заклинания:заклинаний; за %s",
        NOT_ENOUGH_ERROR = "У вас недостаточно денег, чтобы выучить всё!",
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
