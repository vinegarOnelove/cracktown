CLASS.name = "Гвардеец"
CLASS.faction = FACTION_POLICE
CLASS.limit = 2

function CLASS:OnSet(client)
    local character = client:GetCharacter()

    if (character) then
        -- Сохраняем оригинальную модель перед сменой
        if not character:GetData("originalModel") then
            character:SetData("originalModel", character:GetModel())
        end
        
        -- Устанавливаем новую модель
        character:SetModel("models/arachnit/random/georgian_riot_police/georgian_riot_police_player.mdl")
        
        -- Проверяем, есть ли уже щит в инвентаре
        local inventory = character:GetInventory()
        local hasShield = inventory:HasItem("riot_shield")
        
        if not hasShield then
            -- Выдаем щит только если его нет
            inventory:Add("riot_shield", 1)
            client:Notify("Вам выдан щит!")
        else
            client:Notify("У вас уже есть щит!")
        end
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
        
        -- Убираем щит из инвентаря при смене класса
        local inventory = character:GetInventory()
        local shield = inventory:HasItem("riot_shield")
        
        if shield then
            shield:Remove()
            client:Notify("Щит убран из инвентаря!")
        end
    end
end

function CLASS:OnCanBe(client)
    return false
end

CLASS_POLICE_CHIEF = CLASS.index