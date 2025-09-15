CLASS.name = "Варщик"
CLASS.faction = FACTION_CITIZEN
CLASS.isDefault = false
CLASS.limit = 2

function CLASS:OnSet(client)
    local character = client:GetCharacter()

    if (character) then
        -- Сохраняем оригинальную модель перед сменой
        if not character:GetData("originalModel") then
            character:SetData("originalModel", character:GetModel())
        end
        
        -- Устанавливаем новую модель варщика
        character:SetModel("models/humans/group03/chemsuit.mdl")
        
        -- Уведомление о выборе класса
        client:Notify("Вы выбрали класс Варщик!")
    end
end

function CLASS:OnLeave(client)
    local character = client:GetCharacter()

    if (character) then
        -- Восстанавливаем оригинальную модель
        local originalModel = character:GetData("originalModel")
        if originalModel then
            character:SetModel(originalModel)
            character:SetData("originalModel", nil) -- Очищаем данные
        end
        
        -- Уведомление о смене класса
        client:Notify("Вы сменили класс с Варщика!")
    end
end

function CLASS:OnCanBe(client)
    return false
end

CLASS_CHEMIST = CLASS.index