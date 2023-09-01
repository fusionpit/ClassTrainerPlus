local hiddenFrame = CreateFrame("Frame", UIParent)
hiddenFrame:SetSize(1,1)
hiddenFrame:SetPoint("CENTER", UIParent, "CENTER", -10000, -10000)

local eventFrame = CreateFrame("Frame")

local oldCtp_OnEvent
local oldCtp_OnHide

eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local type = ...
        if type == Enum.PlayerInteractionType.Trainer then
            if IsTradeskillTrainer() then
                return
            end
            RunNextFrame(function()
                oldCtp_OnEvent = ClassTrainerFrame_OnEvent
                ClassTrainerFrame_OnEvent = function() end
                oldCtp_OnHide = ClassTrainerFrame:GetScript("OnHide")
                ClassTrainerFrame:SetScript("OnHide", nil)
                ClassTrainerPlusFrame_Show()
                HideUIPanel(ClassTrainerFrame)
            end)
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local type = ...
        if type == Enum.PlayerInteractionType.Trainer then
            ClassTrainerPlusFrame_Hide()
            ClassTrainerFrame_OnEvent = oldCtp_OnEvent
            ClassTrainerFrame:SetScript("OnHide", oldCtp_OnHide)
        end
    end
end)
