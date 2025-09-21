CLASS.name = "Охотник за головами"
CLASS.faction = FACTION_CITIZEN
CLASS.isDefault = false
CLASS.limit = 1

-- Список моделей для случайного выбора
CLASS.modelVariants = {
    "models/jessev92/player/l4d/m9-hunter.mdl"
}

function CLASS:OnSet(client)
    local character = client:GetCharacter()

    if (character) then
        -- Сохраняем оригинальную модель перед сменой
        if not character:GetData("originalModel") then
            character:SetData("originalModel", character:GetModel())
        end
        
        -- Выбираем случайную модель из списка
        local randomModel = table.Random(self.modelVariants)
        character:SetModel(randomModel)
        
        -- Сохраняем выбранную модель для восстановления при смене класса
        character:SetData("rebelModel", randomModel)
        
        -- Проверяем, есть ли уже фомка в инвентаре
        local inventory = character:GetInventory()
        local hasCrowbar = inventory:HasItem("melee_akula")
        
        if not hasCrowbar then
            -- Выдаем фомку только если ее нет
            inventory:Add("melee_akula", 1)
            client:Notify("Вам выдан нож!")
        else
            client:Notify("У вас уже есть нож!")
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
        
        -- Очищаем данные о выбранной модели
        character:SetData("rebelModel", nil)
        
        -- Убираем фомку из инвентаря при смене класса
        local inventory = character:GetInventory()
        local crowbar = inventory:HasItem("melee_akula")
        
        if crowbar then
            crowbar:Remove()
            client:Notify("Нож спизжен!")
        end
    end
end

function CLASS:OnCanBe(client)
    return false
end

CLASS_CITIZEN_BOUNTY_HUNTER = CLASS.index