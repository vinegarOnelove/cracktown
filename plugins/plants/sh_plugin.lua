local PLUGIN = PLUGIN

PLUGIN.name = "Plant Growing"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система выращивания растений в горшках"

PLUGIN.plantTypes = {
    ["weed"] = {
        name = "Конопля",
        model = "models/props_lab/minitexture.mdl",
        growTime = 300,
        yield = {min = 2, max = 5},
        seed = "weed_seed",
        product = "weed",
        stages = {
            {time = 0.0, scale = 0.1, desc = "Посажено"},
            {time = 0.3, scale = 0.3, desc = "Росток"},
            {time = 0.6, scale = 0.6, desc = "Растет"},
            {time = 0.9, scale = 0.9, desc = "Цветет"},
            {time = 1.0, scale = 1.0, desc = "Готово"}
        }
    },
    ["tomato"] = {
        name = "Помидор",
        model = "models/props/de_inferno/pot_medium.mdl",
        growTime = 240,
        yield = {min = 3, max = 6},
        seed = "tomato_seed",
        product = "tomato",
        stages = {
            {time = 0.0, scale = 0.1, desc = "Посеяно"},
            {time = 0.4, scale = 0.4, desc = "Всходы"},
            {time = 0.7, scale = 0.7, desc = "Зеленеет"},
            {time = 1.0, scale = 1.0, desc = "Созрело"}
        }
    },
    ["herb"] = {
        name = "Лечебная трава",
        model = "models/props/de_inferno/pot_small.mdl",
        growTime = 180,
        yield = {min = 1, max = 3},
        seed = "herb_seed",
        product = "herb",
        stages = {
            {time = 0.0, scale = 0.1, desc = "Посажено"},
            {time = 0.5, scale = 0.5, desc = "Прорастает"},
            {time = 1.0, scale = 1.0, desc = "Готово"}
        }
    }
}

PLUGIN.plantStatus = {
    ["Empty"] = "Пустой",
    ["Growing"] = "Растет",
    ["Ready"] = "Готово",
    ["Withered"] = "Завяло"
}

if SERVER then
    -- Создание предметов семян
    function PLUGIN:CreateSeedItems()
        for plantType, data in pairs(self.plantTypes) do
            if not ix.item.list[data.seed] then
                ix.item.Register(data.seed, "base_seeds", true, nil, true)
            end
        end
    end

    -- Инициализация при загрузке
    function PLUGIN:InitializedPlugins()
        self:CreateSeedItems()
    end

    -- Выдача урожая
    function PLUGIN:GiveHarvest(harvester, plantData)
        if not IsValid(harvester) or not harvester:GetCharacter() then return end
        
        local yield = math.random(plantData.yield.min, plantData.yield.max)
        local char = harvester:GetCharacter()
        local inv = char:GetInventory()
        
        if inv then
            for i = 1, yield do
                inv:Add(plantData.product)
            end
            harvester:Notify("Вы собрали урожай: " .. yield .. "x " .. plantData.name)
        end
    end

    -- Проверка полива
    function PLUGIN:CheckWatering(pot)
        if not IsValid(pot) then return false end
        
        -- Упрощенная проверка - всегда true для тестирования
        return true
    end
end

if CLIENT then
    -- Безопасное получение статуса с защитными проверками
    local function GetEntityStatusSafe(ent)
        if not IsValid(ent) then return "Invalid" end
        if not isfunction(ent.GetStatus) then return "NoGetStatus" end
        return ent:GetStatus() or "Unknown"
    end

    -- Безопасное получение прогресса роста
    local function GetGrowProgressSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetGrowProgress) then return 0 end
        return ent:GetGrowProgress() or 0
    end

    -- Безопасное получение типа растения
    local function GetPlantTypeSafe(ent)
        if not IsValid(ent) then return "" end
        if not isfunction(ent.GetPlantType) then return "" end
        return ent:GetPlantType() or ""
    end

    -- Безопасное получение времени окончания роста
    local function GetGrowEndTimeSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetGrowEndTime) then return 0 end
        return ent:GetGrowEndTime() or 0
    end

    -- Кэш для отслеживания уже обработанных entity
    local processedPots = {}
    local lastClearTime = CurTime()

    function PLUGIN:PopulateEntityInfo(ent, tooltip)
        if ent:GetClass() ~= "ix_plant_pot" then return end

        -- Очищаем кэш каждую секунду
        if CurTime() - lastClearTime > 1 then
            processedPots = {}
            lastClearTime = CurTime()
        end

        -- Проверяем, не обрабатывали ли мы уже эту entity
        local entIndex = ent:EntIndex()
        if processedPots[entIndex] then return end
        processedPots[entIndex] = true

        -- Защитные проверки методов
        if not isfunction(ent.GetStatus) then
            local row = tooltip:AddRow("error")
            row:SetText("Ошибка: GetStatus не доступен")
            row:SetBackgroundColor(Color(255, 0, 0))
            row:SizeToContents()
            return
        end

        -- Безопасное получение данных
        local status = GetEntityStatusSafe(ent)
        local progress = GetGrowProgressSafe(ent)
        local plantType = GetPlantTypeSafe(ent)
        local growEndTime = GetGrowEndTimeSafe(ent)
        local plantData = plantType ~= "" and self.plantTypes[plantType] or nil

        -- Заголовок
        local name = tooltip:AddRow("name")
        name:SetText("Горшок для растений")
        name:SetBackgroundColor(Color(0, 100, 0))
        name:SetImportant()
        name:SizeToContents()

        -- Статус
        local statusRow = tooltip:AddRow("status")
        statusRow:SetText("Статус: " .. (self.plantStatus[status] or status))
        
        -- Цвет статуса в зависимости от состояния
        if status == "Empty" then
            statusRow:SetBackgroundColor(Color(50, 50, 50))
        elseif status == "Growing" then
            statusRow:SetBackgroundColor(Color(50, 50, 0))
        elseif status == "Ready" then
            statusRow:SetBackgroundColor(Color(0, 100, 0))
        elseif status == "Withered" then
            statusRow:SetBackgroundColor(Color(100, 0, 0))
        else
            statusRow:SetBackgroundColor(Color(30, 30, 30))
        end
        
        statusRow:SizeToContents()

        -- Информация о растении
        if plantData then
            local plantRow = tooltip:AddRow("plant")
            plantRow:SetText("Растение: " .. plantData.name)
            plantRow:SetBackgroundColor(Color(0, 80, 0))
            plantRow:SizeToContents()
        end

        -- Дополнительная информация в зависимости от статуса
        if status == "Growing" then
            -- Прогресс роста
            local progressRow = tooltip:AddRow("progress")
            progressRow:SetText("Прогресс: " .. math.Round(progress * 100) .. "%")
            progressRow:SetBackgroundColor(Color(60, 60, 0))
            progressRow:SizeToContents()

            -- Оставшееся время
            if growEndTime > 0 then
                local timeLeft = math.Round(growEndTime - CurTime())
                if timeLeft > 0 then
                    local timeRow = tooltip:AddRow("time")
                    timeRow:SetText("Осталось: " .. timeLeft .. " сек")
                    timeRow:SetBackgroundColor(Color(70, 70, 0))
                    timeRow:SizeToContents()
                end
            end

            -- Предупреждение о поливе
            local waterRow = tooltip:AddRow("water")
            waterRow:SetText("️Требуется регулярный полив")
            waterRow:SetBackgroundColor(Color(0, 0, 100))
            waterRow:SizeToContents()

        elseif status == "Ready" and plantData then
            -- Информация об урожае
            local yieldRow = tooltip:AddRow("yield")
            yieldRow:SetText("Урожай: " .. plantData.yield.min .. "-" .. plantData.yield.max .. "x")
            yieldRow:SetBackgroundColor(Color(0, 120, 0))
            yieldRow:SizeToContents()

        elseif status == "Empty" then
            -- Информация для посадки
            local infoRow = tooltip:AddRow("info")
            infoRow:SetText("Используйте семена для посадки")
            infoRow:SetBackgroundColor(Color(50, 50, 50))
            infoRow:SizeToContents()
        end

        -- Инструкция по использованию
        local useRow = tooltip:AddRow("usage")
        if status == "Empty" then
            useRow:SetText("Нажмите E с семенами в руках")
        elseif status == "Ready" then
            useRow:SetText("Нажмите E чтобы собрать урожай")
        elseif status == "Withered" then
            useRow:SetText("Нажмите E чтобы очистить горшок")
        else
            useRow:SetText("Нажмите E для информации")
        end
        useRow:SetBackgroundColor(Color(20, 20, 20))
        useRow:SizeToContents()
    end

    -- Очистка кэша
    hook.Add("Think", "ixPlantPotClearCache", function()
        if CurTime() - lastClearTime > 0.1 then
            processedPots = {}
            lastClearTime = CurTime()
        end
    end)
end