CLASS.name = "Варщик"
CLASS.faction = FACTION_CITIZEN
CLASS.isDefault = false
CLASS.limit = 1

function CLASS:OnSet(client)
    local character = client:GetCharacter()

    if (character) then
        character:SetModel("models/humans/group03/chemsuit.mdl")
    end
end

function CLASS:OnCanBe(client)
    return false
end

CLASS_CHEMIST = CLASS.index