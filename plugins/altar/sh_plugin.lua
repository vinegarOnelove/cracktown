local PLUGIN = PLUGIN

PLUGIN.name = "altar"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система кровавого алтаря для жертвоприношений и перманентных усилений"

PLUGIN.altarStatusText = {
    ["Idle"] = "Ожидает",
    ["Accepting"] = "Принимает жертву",
    ["Blessing"] = "Дарует благословение",
    ["Cooldown"] = "Перезарядка"
}

PLUGIN.altarBlessings = {
    ["health"] = {
        name = "Усиление здоровья",
        description = "+25 к максимальному здоровью",
        maxLevel = 5,
        cost = {["human_heart"] = 1}
    },
    ["stamina"] = {
        name = "Усиление выносливости",
        description = "+20% к максимальной выносливости",
        maxLevel = 5,
        cost = {["human_heart"] = 1}
    },
    ["strength"] = {
        name = "Усиление силы",
        description = "+15% к физическому урону",
        maxLevel = 5,
        cost = {["human_heart"] = 1}
    },
    ["speed"] = {
        name = "Усиление скорости",
        description = "+20% к скорости бега",
        maxLevel = 5,
        cost = {["human_heart"] = 1}
    }
}

PLUGIN.config = {
    cooldownTime = 300,
    maxBlessingsPerPlayer = 10
}

if CLIENT then
    -- Безопасное получение статуса с защитными проверками
    local function GetEntityStatusSafe(ent)
        if not IsValid(ent) then return "Invalid" end
        if not isfunction(ent.GetStatus) then return "NoGetStatus" end
        
        local status = ent:GetStatus()
        return status or "Unknown"
    end

    -- Безопасное получение времени перезарядки
    local function GetCooldownTimeSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetCooldownTime) then return 0 end
        
        return ent:GetCooldownTime() or 0
    end

    -- Безопасное получение оставшегося времени
    local function GetTimeLeftSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetTimeLeft) then return 0 end
        
        return ent:GetTimeLeft() or 0
    end

    -- Безопасное получение текущего благословения
    local function GetCurrentBlessingSafe(ent)
        if not IsValid(ent) then return nil end
        if not isfunction(ent.GetCurrentBlessing) then return nil end
        
        return ent:GetCurrentBlessing()
    end

    -- Кэш для отслеживания уже обработанных entity
    local processedAltars = {}
    local lastAltarClearTime = CurTime()

    function PLUGIN:PopulateEntityInfo(ent, tooltip)
        if ent:GetClass() ~= "ix_bloodaltar" then return end

        -- Очищаем кэш каждую секунду
        if CurTime() - lastAltarClearTime > 1 then
            processedAltars = {}
            lastAltarClearTime = CurTime()
        end

        -- Проверяем, не обрабатывали ли мы уже эту entity
        local entIndex = ent:EntIndex()
        if processedAltars[entIndex] then return end
        processedAltars[entIndex] = true

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
        local cooldownTime = GetCooldownTimeSafe(ent)
        local timeLeft = GetTimeLeftSafe(ent)
        local currentBlessing = GetCurrentBlessingSafe(ent)

        -- Заголовок
        local name = tooltip:AddRow("name")
        name:SetText("Кровавый Алтарь")
        name:SetBackgroundColor(Color(150, 0, 0))
        name:SetImportant()
        name:SizeToContents()

        -- Статус
        local statusRow = tooltip:AddRow("status")
        statusRow:SetText("Статус: " .. (self.altarStatusText[status] or status))
        
        -- Цвет статуса в зависимости от состояния
        if status == "Idle" then
            statusRow:SetBackgroundColor(Color(50, 50, 50))
        elseif status == "Accepting" then
            statusRow:SetBackgroundColor(Color(150, 0, 0))
        elseif status == "Blessing" then
            statusRow:SetBackgroundColor(Color(0, 150, 0))
        elseif status == "Cooldown" then
            statusRow:SetBackgroundColor(Color(100, 50, 0))
        else
            statusRow:SetBackgroundColor(Color(30, 30, 30))
        end
        
        statusRow:SizeToContents()

        -- Дополнительная информация в зависимости от статуса
        if status == "Accepting" then
            local acceptRow = tooltip:AddRow("accepting")
            acceptRow:SetText("Жертва принята!")
            acceptRow:SetBackgroundColor(Color(100, 0, 0))
            acceptRow:SizeToContents()
            
        elseif status == "Blessing" and currentBlessing then
            local blessingInfo = self.altarBlessings[currentBlessing]
            if blessingInfo then
                local blessingRow = tooltip:AddRow("blessing")
                blessingRow:SetText("Благословение: " .. blessingInfo.name)
                blessingRow:SetBackgroundColor(Color(0, 100, 0))
                blessingRow:SizeToContents()
                
                local descRow = tooltip:AddRow("desc")
                descRow:SetText(blessingInfo.description)
                descRow:SetBackgroundColor(Color(0, 80, 0))
                descRow:SizeToContents()
            end
            
        elseif status == "Cooldown" then
            -- Время перезарядки
            if cooldownTime > 0 then
                local timeRow = tooltip:AddRow("cooldown_time")
                timeRow:SetText("Общее время: " .. cooldownTime .. " сек")
                timeRow:SetBackgroundColor(Color(80, 40, 0))
                timeRow:SizeToContents()
            end
            
            -- Оставшееся время
            if timeLeft > 0 then
                local timeLeftRow = tooltip:AddRow("time_left")
                timeLeftRow:SetText("Осталось: " .. math.Round(timeLeft) .. " сек")
                timeLeftRow:SetBackgroundColor(Color(100, 50, 0))
                timeLeftRow:SizeToContents()
                
                -- Прогресс-бар в текстовом виде
                local progress = 100 - math.Round((timeLeft / cooldownTime) * 100)
                local progressRow = tooltip:AddRow("progress")
                progressRow:SetText("Прогресс: " .. progress .. "%")
                progressRow:SetBackgroundColor(Color(120, 60, 0))
                progressRow:SizeToContents()
            end
            
        elseif status == "Idle" then
            local idleRow = tooltip:AddRow("idle")
            idleRow:SetText("Готов к принятию жертвы")
            idleRow:SetBackgroundColor(Color(50, 50, 50))
            idleRow:SizeToContents()
            
            -- Показываем доступные благословения
            local blessingsRow = tooltip:AddRow("blessings_info")
            blessingsRow:SetText("Доступные благословения:")
            blessingsRow:SetBackgroundColor(Color(70, 0, 0))
            blessingsRow:SizeToContents()
            
            for id, blessing in pairs(self.altarBlessings) do
                local blessingRow = tooltip:AddRow("blessing_" .. id)
                blessingRow:SetText("- " .. blessing.name .. " (" .. blessing.description .. ")")
                blessingRow:SetBackgroundColor(Color(60, 0, 0))
                blessingRow:SizeToContents()
            end
        end
        
        -- Инструкция по использованию
        local useRow = tooltip:AddRow("usage")
        useRow:SetText("Нажмите E для взаимодействия")
        useRow:SetBackgroundColor(Color(30, 30, 30))
        useRow:SizeToContents()
    end

    -- Очистка кэша
    hook.Add("Think", "ixAltarClearCache", function()
        if CurTime() - lastAltarClearTime > 0.1 then
            processedAltars = {}
            lastAltarClearTime = CurTime()
        end
    end)
end

if SERVER then
    -- Возвращает уровень усиления (0 если нет)
    function PLUGIN:GetBlessingLevel(char, id)
        if not char then return 0 end
        local blessings = char:GetData("altarBlessings", {})
        return blessings[id] or 0
    end

    -- Применить все усиления к игроку
    function PLUGIN:ApplyBlessingBonusesToPlayer(ply)
        if not IsValid(ply) then return end
        local char = ply:GetCharacter()
        if not char then return end

        -- HEALTH
        local healthLevel = self:GetBlessingLevel(char, "health")
        local healthBonus = 25 * healthLevel

        -- Устанавливаем максимальное здоровье
        ply:SetMaxHealth(100 + healthBonus)
        if ply:Health() < ply:GetMaxHealth() then
            ply:SetHealth(ply:GetMaxHealth())
        end

        -- SPEED
        local speedLevel = self:GetBlessingLevel(char, "speed")
        local speedBonus = 0.2 * speedLevel
        
        local walkSpeed = ix.config.Get("walkSpeed", 200) * (1 + speedBonus)
        local runSpeed = ix.config.Get("runSpeed", 400) * (1 + speedBonus)
        
        ply:SetWalkSpeed(walkSpeed)
        ply:SetRunSpeed(runSpeed)

        -- STAMINA (если установлен ix.stamina)
        if ix and ix.stamina and ix.stamina.GetMax and ix.stamina.SetMax then
            local stamLevel = self:GetBlessingLevel(char, "stamina")
            local stamBonus = 0.2 * stamLevel
            local baseStamina = ix.config.Get("maxStamina", 100)
            local newMaxStam = math.Round(baseStamina * (1 + stamBonus))
            ix.stamina.SetMax(ply, newMaxStam)
        end

        -- Сохраняем базовые значения для дальнейшего использования
        ply.ix_altar_healthBonus = healthBonus
        ply.ix_altar_speedBonus = speedBonus
    end

    -- Когда персонаж загружен — применяем усиления
    hook.Add("PlayerLoadedCharacter", "BloodAltarApplyBlessings", function(ply, char)
        timer.Simple(1, function()
            if IsValid(ply) and char then
                PLUGIN:ApplyBlessingBonusesToPlayer(ply)
            end
        end)
    end)

    -- На спавне также применяем
    hook.Add("PlayerSpawn", "BloodAltarApplyOnSpawn", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) then
                PLUGIN:ApplyBlessingBonusesToPlayer(ply)
            end
        end)
    end)

    -- Увеличение урона
    hook.Add("EntityTakeDamage", "BloodAltarDamageBoost", function(target, dmg)
        local attacker = dmg:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() then
            local char = attacker:GetCharacter()
            if char then
                local lvl = PLUGIN:GetBlessingLevel(char, "strength")
                if lvl > 0 then
                    local damageBonus = 0.15 * lvl
                    dmg:SetDamage(dmg:GetDamage() * (1 + damageBonus))
                end
            end
        end
    end)

    -- Обработка скорости
    hook.Add("SetupPlayerSpeed", "BloodAltarSpeedBoost", function(ply, mv)
        local char = ply:GetCharacter()
        if not char then return end
        
        local lvl = PLUGIN:GetBlessingLevel(char, "speed")
        if lvl <= 0 then return end

        local speedBonus = 0.1 * lvl
        local baseRunSpeed = ix.config.Get("runSpeed", 400)
        local baseWalkSpeed = ix.config.Get("walkSpeed", 200)
        
        mv:SetMaxSpeed(baseRunSpeed * (1 + speedBonus))
        mv:SetMaxClientSpeed(baseRunSpeed * (1 + speedBonus))
        
        ply:SetWalkSpeed(baseWalkSpeed * (1 + speedBonus))
        ply:SetRunSpeed(baseRunSpeed * (1 + speedBonus))
    end)

    -- Обработка выносливости
    hook.Add("Think", "BloodAltarStaminaBoost", function()
        for _, ply in ipairs(player.GetAll()) do
            local char = ply:GetCharacter()
            if char then
                local lvl = PLUGIN:GetBlessingLevel(char, "stamina")
                if lvl > 0 and ix and ix.stamina then
                    local stamBonus = 0.2 * lvl
                    local baseStamina = ix.config.Get("maxStamina", 100)
                    local newMaxStam = math.Round(baseStamina * (1 + stamBonus))
                    
                    if ix.stamina.GetMax(ply) ~= newMaxStam then
                        ix.stamina.SetMax(ply, newMaxStam)
                    end
                end
            end
        end
    end)

    -- Команда для тестирования: /AltarGrant <blessingID> <level>
    ix.command.Add("AltarGrant", {
        description = "Выдать (и сохранить) усиление для текущего персонажа (только для админов)",
        arguments = {ix.type.string, ix.type.number},
        adminOnly = true,
        OnRun = function(self, client, blessingID, level)
            local char = client:GetCharacter()
            if not char then
                client:Notify("Нет загруженного персонажа.")
                return
            end

            if not PLUGIN.altarBlessings[blessingID] then
                client:Notify("Неверный ID усиления.")
                return
            end

            local maxLevel = PLUGIN.altarBlessings[blessingID].maxLevel
            level = math.Clamp(math.floor(level), 1, maxLevel)
            
            -- Получаем текущие благословения
            local blessings = char:GetData("altarBlessings", {})
            blessings[blessingID] = level
            char:SetData("altarBlessings", blessings)
            
            -- Применяем эффект
            PLUGIN:ApplyBlessingBonusesToPlayer(client)
            
            client:Notify("Выдано усиление: " .. PLUGIN.altarBlessings[blessingID].name .. " (Уровень " .. level .. ")")
        end
    })

    -- Команда для проверки текущих усилений
    ix.command.Add("AltarCheck", {
        description = "Проверить текущие усиления от алтаря",
        OnRun = function(self, client)
            local char = client:GetCharacter()
            if not char then
                client:Notify("Нет загруженного персонажа.")
                return
            end
            
            local blessings = char:GetData("altarBlessings", {})
            if table.Count(blessings) == 0 then
                client:Notify("У вас нет усилений от кровавого алтаря.")
                return
            end
            
            local message = "Ваши усиления от кровавого алтаря:\n"
            for blessingID, level in pairs(blessings) do
                local blessing = PLUGIN.altarBlessings[blessingID]
                if blessing then
                    message = message .. "- " .. blessing.name .. ": Уровень " .. level .. "/" .. blessing.maxLevel .. "\n"
                end
            end
            
            client:Notify(message)
        end
    })
end


