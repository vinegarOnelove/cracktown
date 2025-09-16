local PLUGIN = PLUGIN

PLUGIN.name = "Simple Brewing"
PLUGIN.author = "ChatGPT"
PLUGIN.description = "Простая система варки алкоголя с шансом взрыва."

-- Рецепты: ингредиенты + результат + время (секунды) + шанс взрыва (%)
PLUGIN.recipes = {
    ["vodkawater"] = {
        input = {"vodka", "water"},
        output = "moonshine",
        time = 220,
        risk = 20
    },
    ["ginwater"] = {
        input = {"gin", "water"},
        output = "moonshine",
        time = 240,
        risk = 15
    },
    ["whiskeywater"] = {
        input = {"whiskey", "water"},
        output = "moonshine",
        time = 240,
        risk = 10
    },
    ["ginsparkling"] = {
        input = {"gin", "sparklingwater"},
        output = "moonshine",
        time = 180,
        risk = 25
    },
    ["vodkasparkling"] = {
        input = {"vodka", "sparklingwater"},
        output = "moonshine",
        time = 160,
        risk = 30
    },
    ["whiskeysparkling"] = {
        input = {"whiskey", "sparklingwater"},
        output = "moonshine",
        time = 180,
        risk = 20
    },
    ["ginspecial"] = {
        input = {"gin", "energetic"},
        output = "moonshine",
        time = 120,
        risk = 35
    },
    ["vodkaspecial"] = {
        input = {"vodka", "energetic"},
        output = "moonshine",
        time = 110,
        risk = 40
    },
    ["whiskeyspecial"] = {
        input = {"whiskey", "energetic"},
        output = "moonshine",
        time = 120,
        risk = 30
    }
}

-- Локализованные статусы
PLUGIN.statusText = {
    ["Idle"] = "Пустая",
    ["Brewing"] = "Варка идёт...",
    ["Finished"] = "Готово!"
}

if CLIENT then
    -- Кэш для отслеживания уже обработанных entity в текущем кадре
    local processedEntities = {}
    local lastClearTime = CurTime()

    -- Безопасное получение статуса с защитными проверками
    local function GetEntityStatusSafe(ent)
        if not IsValid(ent) then return "Invalid" end
        if not isfunction(ent.GetStatus) then return "NoGetStatus" end
        
        local status = ent:GetStatus()
        return status or "Unknown"
    end

    -- Безопасное получение времени варки
    local function GetBrewTimeSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetBrewTime) then return 0 end
        
        return ent:GetBrewTime() or 0
    end

    -- Безопасное получение оставшегося времени
    local function GetTimeLeftSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetTimeLeft) then return 0 end
        
        return ent:GetTimeLeft() or 0
    end

    function PLUGIN:PopulateEntityInfo(ent, tooltip)
        if ent:GetClass() ~= "ix_brewbarrel" then return end

        -- Очищаем кэш каждую секунду
        if CurTime() - lastClearTime > 1 then
            processedEntities = {}
            lastClearTime = CurTime()
        end

        -- Проверяем, не обрабатывали ли мы уже эту entity в текущем кадре
        local entIndex = ent:EntIndex()
        if processedEntities[entIndex] then return end
        processedEntities[entIndex] = true

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
        local brewTime = GetBrewTimeSafe(ent)
        local timeLeft = GetTimeLeftSafe(ent)

        -- Заголовок (только один раз)
        local name = tooltip:AddRow("name")
        name:SetText("Бочка для варки")
        name:SetBackgroundColor(Color(100, 50, 20))
        name:SetImportant()
        name:SizeToContents()

        -- Статус
        local statusRow = tooltip:AddRow("status")
        statusRow:SetText("Статус: " .. (self.statusText[status] or status))
        
        -- Цвет статуса в зависимости от состояния
        if status == "Idle" then
            statusRow:SetBackgroundColor(Color(50, 50, 50))
        elseif status == "Brewing" then
            statusRow:SetBackgroundColor(Color(50, 30, 0))
        elseif status == "Finished" then
            statusRow:SetBackgroundColor(Color(0, 50, 0))
        else
            statusRow:SetBackgroundColor(Color(30, 30, 30))
        end
        
        statusRow:SizeToContents()

        -- Дополнительная информация в зависимости от статуса
        if status == "Brewing" then
            -- Время варки
            if brewTime > 0 then
                local timeRow = tooltip:AddRow("brew_time")
                timeRow:SetText("Общее время: " .. brewTime .. " сек")
                timeRow:SetBackgroundColor(Color(40, 20, 0))
                timeRow:SizeToContents()
            end
            
            -- Оставшееся время
            if timeLeft > 0 then
                local timeLeftRow = tooltip:AddRow("time_left")
                timeLeftRow:SetText("Осталось: " .. math.Round(timeLeft) .. " сек")
                timeLeftRow:SetBackgroundColor(Color(60, 30, 0))
                timeLeftRow:SizeToContents()
                
                -- Прогресс-бар в текстовом виде
                local progress = 100 - math.Round((timeLeft / brewTime) * 100)
                local progressRow = tooltip:AddRow("progress")
                progressRow:SetText("Прогресс: " .. progress .. "%")
                progressRow:SetBackgroundColor(Color(70, 35, 0))
                progressRow:SizeToContents()
            end
            
        elseif status == "Finished" then
            local readyRow = tooltip:AddRow("ready")
            readyRow:SetBackgroundColor(Color(0, 70, 0))
            readyRow:SizeToContents()
        elseif status == "Idle" then
        end
        
        -- Информация о риске взрыва (если доступна)
        if isfunction(ent.GetRisk) then
            local risk = ent:GetRisk() or 0
            if risk > 0 then
                local riskRow = tooltip:AddRow("risk")
                riskRow:SetText("Риск взрыва: " .. risk .. "%")
                riskRow:SetBackgroundColor(Color(100, 0, 0))
                riskRow:SizeToContents()
            end
        end
    end

    -- Альтернативное решение: используем хук для очистки кэша
    hook.Add("Think", "ixBrewingClearCache", function()
        if CurTime() - lastClearTime > 0.1 then -- Очищаем чаще
            processedEntities = {}
            lastClearTime = CurTime()
        end
    end)
end


