CLASS.name = "Агент управления"
CLASS.faction = FACTION_POLICE
CLASS.isDefault = false
CLASS.limit = 1

-- Список моделей для случайного выбора
CLASS.modelVariants = {
    "models/mrduck/sentry/gangs/italian/male_07_shirt_tie.mdl",
    "models/mrduck/sentry/gangs/italian/male_08_closed_tie.mdl",
    "models/mrduck/sentry/gangs/italian/male_06_shirt_tie.mdl", 
    "models/mrduck/sentry/gangs/italian/male_09_shirt_tie.mdl",
    "models/mrduck/sentry/gangs/italian/male_06_closed_tie.mdl"
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
        local hasCrowbar = inventory:HasItem("ohlderogl_wricht")
        
        if not hasCrowbar then
            -- Выдаем фомку только если ее нет
            inventory:Add("ohlderogl_wricht", 1)
            client:Notify("Вам выдан пистолет!")
        else
            client:Notify("У вас уже есть пистолет!")
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
        local crowbar = inventory:HasItem("ohlderogl_wricht")
        
        if crowbar then
            crowbar:Remove()
            client:Notify("У вас забрали пистолет!")
        end
    end
end

function CLASS:OnCanBe(client)
    return false
end

CLASS_POLICE_AGENT = CLASS.index