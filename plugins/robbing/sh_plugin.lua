local PLUGIN = PLUGIN

PLUGIN.name = "Container Robbery"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система ограбления контейнеров с уведомлением полиции"

-- Объявляем глобально чтобы entity мог получить доступ
ix.containerRobbery = ix.containerRobbery or {
    config = {
        robberyTime = 120,
        minReward = 500,
        maxReward = 1500,
        policeFaction = FACTION_POLICE,
        cooldownTime = 300,
        alertRadius = 1500,
        policeReward = 300, -- Награда полиции за убийство преступника
        policeRewardPercent = 0.3 -- Процент от суммы ограбления
    }
}

-- Таблица для отслеживания активных ограблений
PLUGIN.activeRobberies = PLUGIN.activeRobberies or {}

-- Таблица статусов для клиентской части
PLUGIN.robberyStatus = {
    ["Idle"] = "Свободен",
    ["Robbing"] = "Ограбление...",
    ["Cooldown"] = "Перезарядка",
    ["Invalid"] = "Недействителен",
    ["NoGetStatus"] = "Ошибка статуса",
    ["Unknown"] = "Неизвестно"
}

if SERVER then
    -- Оповещение полиции о ограблении
    function PLUGIN:AlertPolice(container, robber)
        if not IsValid(container) or not IsValid(robber) then return end
        
        local robberName = robber:Name()
        local position = container:GetPos()
        local containerID = container:EntIndex()
        
        -- Сохраняем информацию об ограблении
        self.activeRobberies[containerID] = {
            robber = robber,
            container = container,
            startTime = CurTime(),
            rewardAmount = math.random(self.config.minReward, self.config.maxReward)
        }
        
        -- Оповещаем всех полицейских
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetCharacter() and ply:GetCharacter():GetFaction() == self.config.policeFaction then
                ply:Notify("ВНИМАНИЕ! Ограбление контейнера!")
                ply:Notify("Преступник: " .. robberName)
                ply:Notify("Награда за поимку: ☋" .. self.config.policeReward)
                ply:Notify("Местоположение отмечено на карте!")
                
                -- Создаем метку на карте
                if ix and ix.util then
                    ix.util.HoverText(ply, "📍 Ограбление контейнера", position, Color(255, 0, 0))
                end
            end
        end
        
        -- Глобальное оповещение
        ix.chat.Send(nil, "notice", "ВНИМАНИЕ! Начато ограбление контейнера! Награда за поимку: ☋" .. self.config.policeReward, nil, nil, nil)
    end

    -- Выдача награды грабителю
    function PLUGIN:GiveReward(robber, containerID)
        if not IsValid(robber) or not robber:GetCharacter() then return end
        
        local reward = self.activeRobberies[containerID] and self.activeRobberies[containerID].rewardAmount or math.random(self.config.minReward, self.config.maxReward)
        local char = robber:GetCharacter()
        
        char:GiveMoney(reward)
        robber:Notify("Вы успешно ограбили контейнер! Получено: " .. reward .. "☋")
        
        -- Оповещаем о завершении
        ix.chat.Send(nil, "notice", "Ограбление контейнера завершено. Преступник скрылся.", nil, nil, nil)
        
        -- Удаляем из активных ограблений
        self.activeRobberies[containerID] = nil
    end

    -- Выдача награды полиции
    function PLUGIN:GivePoliceReward(killer, robber, containerID)
        if not IsValid(killer) or not killer:GetCharacter() then return end
        if not IsValid(robber) then return end
        
        local robberyData = self.activeRobberies[containerID]
        if not robberyData then return end
        
        -- Вычисляем награду (фиксированная + процент от суммы)
        local baseReward = self.config.policeReward
        local percentReward = math.Round(robberyData.rewardAmount * self.config.policeRewardPercent)
        local totalReward = baseReward + percentReward
        
        local char = killer:GetCharacter()
        char:GiveMoney(totalReward)
        
        killer:Notify("Вы получили награду за поимку преступника: ☋" .. totalReward)
        killer:Notify("(Базовая: ☋" .. baseReward .. " + Бонус: ☋" .. percentReward .. ")")
        
        -- Оповещаем всех полицейских
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetCharacter() and ply:GetCharacter():GetFaction() == self.config.policeFaction and ply ~= killer then
                ply:Notify("Преступник " .. robber:Name() .. " задержан! Награда выплачена.")
            end
        end
        
        ix.chat.Send(nil, "notice", "Преступник " .. robber:Name() .. " задержан полицией! Награда выплачена.", nil, nil, nil)
        
        -- Удаляем из активных ограблений
        self.activeRobberies[containerID] = nil
    end

    -- Прерывание ограбления
    function PLUGIN:AbortRobbery(container, reason)
        if not IsValid(container) then return end
        
        local containerID = container:EntIndex()
        
        if container.robber then
            local robber = container.robber
            if IsValid(robber) then
                robber:Notify(reason or "Ограбление прервано!")
            end
        end
        
        -- Удаляем из активных ограблений
        self.activeRobberies[containerID] = nil
        
        container:ResetRobbery()
    end

    -- Хук для отслеживания убийств во время ограбления
    hook.Add("PlayerDeath", "ContainerRobberyPoliceReward", function(victim, inflictor, attacker)
        if not IsValid(victim) or not IsValid(attacker) then return end
        if not attacker:IsPlayer() or not victim:IsPlayer() then return end
        
        -- Проверяем что убийца - полиция
        local attackerChar = attacker:GetCharacter()
        local victimChar = victim:GetCharacter()
        
        if not attackerChar or not victimChar then return end
        if attackerChar:GetFaction() ~= PLUGIN.config.policeFaction then return end
        
        -- Ищем активное ограбление с этим преступником
        for containerID, robberyData in pairs(PLUGIN.activeRobberies) do
            if IsValid(robberyData.robber) and robberyData.robber == victim then
                -- Выдаем награду полиции
                PLUGIN:GivePoliceReward(attacker, victim, containerID)
                
                -- Прерываем ограбление
                if IsValid(robberyData.container) then
                    robberyData.container:ResetRobbery()
                end
                
                break
            end
        end
    end)

    -- Очистка старых ограблений
    hook.Add("Think", "ContainerRobberyCleanup", function()
        for containerID, robberyData in pairs(PLUGIN.activeRobberies) do
            -- Если контейнер или грабитель не валидны, очищаем
            if not IsValid(robberyData.container) or not IsValid(robberyData.robber) then
                PLUGIN.activeRobberies[containerID] = nil
            end
            
            -- Если ограбление длится слишком долго (10 минут), очищаем
            if robberyData.startTime and CurTime() - robberyData.startTime > 600 then
                PLUGIN.activeRobberies[containerID] = nil
            end
        end
    end)

    -- Команда для проверки активных ограблений (для админов)
    ix.command.Add("robberies", {
        description = "Показать активные ограбления",
        adminOnly = true,
        OnRun = function(self, client)
            local count = 0
            for containerID, robberyData in pairs(PLUGIN.activeRobberies) do
                if IsValid(robberyData.container) and IsValid(robberyData.robber) then
                    count = count + 1
                    client:Notify("Ограбление #" .. containerID .. ": " .. robberyData.robber:Name() .. 
                                 " | Награда: ☋" .. robberyData.rewardAmount)
                end
            end
            
            if count == 0 then
                client:Notify("Активных ограблений нет.")
            else
                client:Notify("Всего активных ограблений: " .. count)
            end
        end
    })
end