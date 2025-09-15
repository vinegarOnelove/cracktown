local PLUGIN = PLUGIN

PLUGIN.name = "Crack Cooking System"
PLUGIN.author = "ChatGPT"
PLUGIN.description = "Система варки крэка с риском и этапами приготовления."

-- Рецепты для крэка
PLUGIN.recipes = {
    ["crack_basic"] = {
        input = {"baking_soda", "cocaine"},
        output = "crack",
        time = 180,
        risk = 25,
        stages = 3,
        heat = "medium"
    },
    ["crack_pro"] = {
        input = {"ammonia", "cocaine", "ether"},
        output = "crack_pure",
        time = 240,
        risk = 35,
        stages = 4,
        heat = "high"
    },
    ["crack_quick"] = {
        input = {"baking_soda", "cocaine", "water"},
        output = "crack",
        time = 120,
        risk = 40,
        stages = 2,
        heat = "high"
    }
}

-- Стадии варки с описаниями
PLUGIN.cookingStages = {
    [1] = "Смешивание ингредиентов",
    [2] = "Нагревание смеси", 
    [3] = "Формирование кристаллов",
    [4] = "Охлаждение и сушка"
}

-- Уровни нагрева
PLUGIN.heatLevels = {
    ["low"] = {color = Color(255, 150, 50), risk_mod = 0.8},
    ["medium"] = {color = Color(255, 100, 50), risk_mod = 1.0},
    ["high"] = {color = Color(255, 50, 50), risk_mod = 1.3}
}

-- Локализация
PLUGIN.statusText = {
    ["Idle"] = "Пустая",
    ["Brewing"] = "Варка идёт...",
    ["Finished"] = "Готово!",
    ["Failed"] = "Неудача!"
}

-- Конфигурация
PLUGIN.config = {
    explosionDamage = 50,
    explosionRadius = 200,
    policeNotifyChance = 30,
    smokeEffect = true,
    soundVolume = 75
}

if SERVER then
    -- Уведомление полиции при взрыве
    function PLUGIN:NotifyPolice(position, reason)
        if math.random(1, 100) <= self.config.policeNotifyChance then
            for _, v in ipairs(player.GetAll()) do
                if v:IsValid() and v:Team() == FACTION_POLICE then
                    v:Notify("Поступил сигнал о незаконной деятельности: " .. reason .. " | " .. tostring(position))
                end
            end
        end
    end
end

if CLIENT then
    -- Безопасное получение статуса с защитными проверками
    local function GetEntityStatusSafe(ent)
        if not IsValid(ent) then return "Invalid" end
        if not isfunction(ent.GetStatus) then return "NoGetStatus" end
        
        local status = ent:GetStatus()
        return status or "Unknown"
    end

    function PLUGIN:PopulateEntityInfo(ent, tooltip)
        if ent:GetClass() ~= "ix_cracklab" then return end

        -- Защитные проверки методов
        if not isfunction(ent.GetStatus) then
            local row = tooltip:AddRow("error")
            row:SetText("Ошибка: GetStatus не доступен")
            row:SetBackgroundColor(Color(255, 0, 0))
            row:SizeToContents()
            return
        end

        if not isfunction(ent.GetStage) or not isfunction(ent.GetTotalStages) then
            local row = tooltip:AddRow("error")
            row:SetText("Ошибка: Методы прогресса не доступны")
            row:SetBackgroundColor(Color(255, 100, 0))
            row:SizeToContents()
            return
        end

        -- Безопасное получение данных
        local status = GetEntityStatusSafe(ent)
        local stage = isfunction(ent.GetStage) and ent:GetStage() or 0
        local totalStages = isfunction(ent.GetTotalStages) and ent:GetTotalStages() or 0

        -- Заголовок
        local name = tooltip:AddRow("name")
        name:SetText("Лаборатория крэка")
        name:SetBackgroundColor(Color(50, 0, 0))
        name:SetImportant()
        name:SizeToContents()

        -- Статус
        local statusRow = tooltip:AddRow("status")
        statusRow:SetText("Статус: " .. (self.statusText[status] or status))
        statusRow:SetBackgroundColor(Color(30, 30, 30))
        statusRow:SizeToContents()

        -- Прогресс если варим
        if status == "Brewing" then
            local progress = tooltip:AddRow("progress")
            progress:SetText("Этап: " .. stage .. "/" .. totalStages)
            progress:SetBackgroundColor(Color(50, 30, 0))
            progress:SizeToContents()
            
            local desc = tooltip:AddRow("description")
            desc:SetText(self.cookingStages[stage] or "В процессе...")
            desc:SetBackgroundColor(Color(40, 20, 0))
            desc:SizeToContents()
        end
    end

    -- Эффекты дыма
    function PLUGIN:Think()
        for _, ent in ipairs(ents.FindByClass("ix_cracklab")) do
            if not IsValid(ent) then continue end
            
            -- Проверяем доступность метода GetStatus
            if not isfunction(ent.GetStatus) then continue end
            
            local status = ent:GetStatus()
            if status == "Brewing" and self.config.smokeEffect then
                if not ent.nextSmoke or CurTime() > ent.nextSmoke then
                    ent.nextSmoke = CurTime() + 0.5
                    
                    local pos = ent:GetPos() + ent:GetUp() * 40 + VectorRand() * 10
                    local emitter = ParticleEmitter(pos)
                    
                    if emitter then
                        local particle = emitter:Add("particles/smokey", pos)
                        if particle then
                            particle:SetVelocity(Vector(0, 0, 20) + VectorRand() * 5)
                            particle:SetDieTime(2)
                            particle:SetStartAlpha(100)
                            particle:SetEndAlpha(0)
                            particle:SetStartSize(5)
                            particle:SetEndSize(15)
                            particle:SetColor(150, 100, 100)
                            particle:SetAirResistance(50)
                        end
                        emitter:Finish()
                    end
                end
            end
        end
    end
end


