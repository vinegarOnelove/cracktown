AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Контейнер для ограбления"
ENT.Category = "Helix"
ENT.Author = "Your Name"
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- Локальные переменные для конфигурации
local CONFIG = {
    robberyTime = 120,
    minReward = 500,
    maxReward = 1500,
    policeFaction = FACTION_POLICE,
    cooldownTime = 300,
    alertRadius = 1500
}

local STATUS_TEXTS = {
    ["Idle"] = "Свободен",
    ["Robbing"] = "Ограбление...",
    ["Cooldown"] = "Перезарядка"
}

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Status")
    self:NetworkVar("Float", 0, "RobberyTime")
    self:NetworkVar("Float", 1, "StartTime")
    self:NetworkVar("Float", 2, "CooldownEnd")
end

if SERVER then
    -- Оповещение полиции
    function ENT:AlertPolice(robber)
        if not IsValid(robber) then return end
        
        -- Используем функцию из плагина если доступна
        if PLUGIN and PLUGIN.AlertPolice then
            PLUGIN:AlertPolice(self, robber)
        else
            -- Резервный вариант
            local robberName = robber:Name()
            local position = self:GetPos()
            
            for _, ply in ipairs(player.GetAll()) do
                if ply:GetCharacter() and ply:GetCharacter():GetFaction() == CONFIG.policeFaction then
                    ply:Notify("ВНИМАНИЕ! Ограбление контейнера!")
                    ply:Notify("Преступник: " .. robberName)
                    
                    if ix and ix.util then
                        ix.util.HoverText(ply, "📍 Ограбление контейнера", position, Color(255, 0, 0))
                    end
                end
            end
            
            ix.chat.Send(nil, "notice", "ВНИМАНИЕ! Начато ограбление контейнера!", nil, nil, nil)
        end
    end

    -- Выдача награды
    function ENT:GiveReward(robber)
        if not IsValid(robber) or not robber:GetCharacter() then return end
        
        -- Используем функцию из плагина если доступна
        if PLUGIN and PLUGIN.GiveReward then
            PLUGIN:GiveReward(robber, self:EntIndex())
        else
            -- Резервный вариант
            local reward = math.random(CONFIG.minReward, CONFIG.maxReward)
            local char = robber:GetCharacter()
            
            char:GiveMoney(reward)
            robber:Notify("Вы успешно ограбили контейнер! Получено: " .. reward .. "☋")
            
            ix.chat.Send(nil, "notice", "Ограбление контейнера завершено.", nil, nil, nil)
        end
    end

    function ENT:Initialize()
        self:SetModel("models/props_junk/wood_crate001a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        self:SetStatus("Idle")
        self:SetRobberyTime(0)
        self:SetStartTime(0)
        self:SetCooldownEnd(0)
        
        self.robber = nil
        self.robberyActive = false
    end

    -- Сброс состояния ограбления
    function ENT:ResetRobbery()
        self:SetStatus("Idle")
        self:SetRobberyTime(0)
        self:SetStartTime(0)
        self.robber = nil
        self.robberyActive = false
        
        if self.robberyTimer then
            timer.Remove(self.robberyTimer)
            self.robberyTimer = nil
        end
        
        -- Удаляем из активных ограблений плагина
        if PLUGIN and PLUGIN.activeRobberies then
            PLUGIN.activeRobberies[self:EntIndex()] = nil
        end
    end

    -- Начало перезарядки
    function ENT:StartCooldown()
        self:SetStatus("Cooldown")
        self:SetCooldownEnd(CurTime() + CONFIG.cooldownTime)
        
        timer.Simple(CONFIG.cooldownTime, function()
            if IsValid(self) then
                self:ResetRobbery()
            end
        end)
    end

    -- Проверка на полицию поблизости
    function ENT:PoliceNearby()
        for _, ply in ipairs(player.GetAll()) do
            if ply:GetCharacter() and ply:GetCharacter():GetFaction() == CONFIG.policeFaction then
                if ply:GetPos():Distance(self:GetPos()) < 500 then
                    return true
                end
            end
        end
        return false
    end

    function ENT:Use(ply)
        if not IsValid(ply) or not ply:GetCharacter() then return end
        
        local status = self:GetStatus()
        
        if status == "Cooldown" then
            local timeLeft = math.Round(self:GetCooldownEnd() - CurTime())
            ply:Notify("Контейнер опустошен! Перезарядка: " .. timeLeft .. " сек")
            return
        end
        
        if status == "Robbing" then
            if self.robber == ply then
                ply:Notify("Вы уже грабите этот контейнер!")
            else
                ply:Notify("Этот контейнер уже кто-то грабит!")
            end
            return
        end

        -- Проверка на полицию поблизости
        if self:PoliceNearby() then
            ply:Notify("Слишком опасно! Полиция рядом!")
            return
        end

        -- Начинаем ограбление
        self:SetStatus("Robbing")
        self:SetRobberyTime(CONFIG.robberyTime)
        self:SetStartTime(CurTime())
        self.robber = ply
        self.robberyActive = true

        -- Оповещаем полицию
        self:AlertPolice(ply)

        ply:Notify("Начато ограбление! Оставайтесь рядом " .. CONFIG.robberyTime .. " секунд!")

        -- Таймер ограбления
        self.robberyTimer = "container_robbery_" .. self:EntIndex()
        timer.Create(self.robberyTimer, CONFIG.robberyTime, 1, function()
            if IsValid(self) and IsValid(self.robber) then
                self:GiveReward(self.robber)
                self:StartCooldown()
            end
        end)
    end

    function ENT:Think()
        if self.robberyActive then
            -- Проверяем не ушел ли грабитель
            if not IsValid(self.robber) or self.robber:GetPos():Distance(self:GetPos()) > 200 then
                if IsValid(self.robber) then
                    self.robber:Notify("Ограбление прервано! Вы отошли слишком далеко!")
                end
                self:ResetRobbery()
                return
            end
            
            -- Проверяем не появилась ли полиция
            if self:PoliceNearby() then
                if IsValid(self.robber) then
                    self.robber:Notify("Ограбление прервано! Приближается полиция!")
                end
                self:ResetRobbery()
                return
            end
            
            self:NextThink(CurTime() + 1)
            return true
        end
    end

    function ENT:OnRemove()
        if self.robberyTimer then
            timer.Remove(self.robberyTimer)
        end
        
        -- Удаляем из активных ограблений плагина
        if PLUGIN and PLUGIN.activeRobberies then
            PLUGIN.activeRobberies[self:EntIndex()] = nil
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

    -- Безопасное получение времени ограбления
    local function GetRobberyTimeSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetRobberyTime) then return 0 end
        
        return ent:GetRobberyTime() or 0
    end

    -- Безопасное получение времени начала
    local function GetStartTimeSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetStartTime) then return 0 end
        
        return ent:GetStartTime() or 0
    end

    -- Безопасное получение оставшегося времени
    local function GetTimeLeftSafe(ent)
        if not IsValid(ent) then return 0 end
        
        local startTime = GetStartTimeSafe(ent)
        local robberyTime = GetRobberyTimeSafe(ent)
        
        if startTime == 0 or robberyTime == 0 then return 0 end
        
        local elapsed = CurTime() - startTime
        return math.max(0, robberyTime - elapsed)
    end

    -- Безопасное получение времени перезарядки
    local function GetCooldownEndSafe(ent)
        if not IsValid(ent) then return 0 end
        if not isfunction(ent.GetCooldownEnd) then return 0 end
        
        return ent:GetCooldownEnd() or 0
    end

    -- Кэш для отслеживания уже обработанных контейнеров
    local processedContainers = {}
    local lastClearTime = CurTime()

    -- Функция для безопасного получения плагина
    local function GetPlugin()
        return ix.plugin and ix.plugin.Get and ix.plugin.Get("container_robbery")
    end

    -- Функция для безопасного получения текста статуса
    local function GetStatusText(status)
        local plugin = GetPlugin()
        if plugin and plugin.robberyStatus then
            return plugin.robberyStatus[status] or status
        end
        
        -- Резервные тексты статусов
        local defaultStatuses = {
            ["Idle"] = "Свободен",
            ["Robbing"] = "Ограбление...",
            ["Cooldown"] = "Перезарядка",
            ["Invalid"] = "Недействителен",
            ["NoGetStatus"] = "Ошибка статуса",
            ["Unknown"] = "Неизвестно"
        }
        
        return defaultStatuses[status] or status
    end

    hook.Add("PopulateEntityInfo", "ixContainerRobberyInfo", function(ent, tooltip)
        if ent:GetClass() ~= "ix_container_robbery" then return end

        -- Очищаем кэш каждую секунду
        if CurTime() - lastClearTime > 1 then
            processedContainers = {}
            lastClearTime = CurTime()
        end

        -- Проверяем, не обрабатывали ли мы уже эту entity
        local entIndex = ent:EntIndex()
        if processedContainers[entIndex] then return end
        processedContainers[entIndex] = true

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
        local robberyTime = GetRobberyTimeSafe(ent)
        local timeLeft = GetTimeLeftSafe(ent)
        local cooldownEnd = GetCooldownEndSafe(ent)

        -- Заголовок
        local name = tooltip:AddRow("name")
        name:SetText("Ящик c ценностями")
        name:SetBackgroundColor(Color(50, 0, 0))
        name:SetImportant()
        name:SizeToContents()

        -- Статус - используем безопасную функцию
        local statusRow = tooltip:AddRow("status")
        local statusText = GetStatusText(status)
        statusRow:SetText("Статус: " .. statusText)
        
        -- Цвет статуса в зависимости от состояния
        if status == "Idle" then
            statusRow:SetBackgroundColor(Color(50, 50, 50))
        elseif status == "Robbing" then
            statusRow:SetBackgroundColor(Color(50, 30, 0))
        elseif status == "Cooldown" then
            statusRow:SetBackgroundColor(Color(30, 30, 30))
        else
            statusRow:SetBackgroundColor(Color(30, 30, 30))
        end
        
        statusRow:SizeToContents()

        -- Дополнительная информация в зависимости от статуса
        if status == "Robbing" then
            -- Время ограбления
            if robberyTime > 0 then
                local timeRow = tooltip:AddRow("robbery_time")
                timeRow:SetText("Общее время: " .. robberyTime .. " сек")
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
                if robberyTime > 0 then
                    local progress = 100 - math.Round((timeLeft / robberyTime) * 100)
                    local progressRow = tooltip:AddRow("progress")
                    progressRow:SetText("Прогресс: " .. progress .. "%")
                    progressRow:SetBackgroundColor(Color(70, 35, 0))
                    progressRow:SizeToContents()
                end
            end
            
            -- Предуреждание
            local warnRow = tooltip:AddRow("warning")
            warnRow:SetText("Не отходите далеко от контейнера!")
            warnRow:SetBackgroundColor(Color(100, 50, 0))
            warnRow:SizeToContents()
            
        elseif status == "Cooldown" then
            -- Оставшееся время перезарядки
            if cooldownEnd > 0 then
                local cooldownLeft = math.max(0, cooldownEnd - CurTime())
                local timeLeftRow = tooltip:AddRow("cooldown_left")
                timeLeftRow:SetText("Перезарядка: " .. math.Round(cooldownLeft) .. " сек")
                timeLeftRow:SetBackgroundColor(Color(30, 30, 30))
                timeLeftRow:SizeToContents()
                
                -- Прогресс перезарядки
                local progress = math.Round((cooldownLeft / CONFIG.cooldownTime) * 100)
                local progressRow = tooltip:AddRow("cooldown_progress")
                progressRow:SetText("Готовность: " .. (100 - progress) .. "%")
                progressRow:SetBackgroundColor(Color(40, 40, 40))
                progressRow:SizeToContents()
            end
            
        elseif status == "Idle" then
            local infoRow = tooltip:AddRow("info")
            infoRow:SetText("Готов к ограблению")
            infoRow:SetBackgroundColor(Color(0, 50, 0))
            infoRow:SizeToContents()
            
            local rewardRow = tooltip:AddRow("reward")
            rewardRow:SetText("Награда: ☋" .. CONFIG.minReward .. " - ☋" .. CONFIG.maxReward)
            rewardRow:SetBackgroundColor(Color(0, 60, 0))
            rewardRow:SizeToContents()
            
            local timeRow = tooltip:AddRow("time_info")
            timeRow:SetText("Время ограбления: " .. CONFIG.robberyTime .. " сек")
            timeRow:SetBackgroundColor(Color(0, 70, 0))
            timeRow:SizeToContents()
        end
        
        -- Инструкция по использованию
        local useRow = tooltip:AddRow("usage")
        useRow:SetText("Нажмите E для взаимодействия")
        useRow:SetBackgroundColor(Color(20, 20, 20))
        useRow:SizeToContents()
        
        -- Предупреждение о полиции
        if status == "Idle" then
            local policeRow = tooltip:AddRow("police_warning")
            policeRow:SetText("Полиция будет оповещена!")
            policeRow:SetBackgroundColor(Color(100, 0, 0))
            policeRow:SizeToContents()
        end
    end)

    -- Очистка кэша
    hook.Add("Think", "ixContainerClearCache", function()
        if CurTime() - lastClearTime > 0.1 then
            processedContainers = {}
            lastClearTime = CurTime()
        end
    end)

    -- 3D отображение
    function ENT:Draw()
        self:DrawModel()
        
        local distance = self:GetPos():Distance(LocalPlayer():GetPos())
        if distance > 300 then return end
        
        local status = self:GetStatus()
        local statusText = STATUS_TEXTS[status] or status
        
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)
        
        local pos = self:GetPos() + self:GetUp() * 60
        
        cam.Start3D2D(pos, ang, 0.1)
            -- Фон
            draw.RoundedBox(8, -70, -25, 140, 50, Color(0, 0, 0, 200))
            
            -- Рамка в зависимости от статуса
            if status == "Robbing" then
                surface.SetDrawColor(255, 100, 0, 255)
            elseif status == "Cooldown" then
                surface.SetDrawColor(100, 100, 100, 255)
            else
                surface.SetDrawColor(0, 150, 0, 255)
            end
            surface.DrawOutlinedRect(-70, -25, 140, 50, 2)
            
            -- Текст статуса
            draw.SimpleText("КОНТЕЙНЕР", "DermaDefaultBold", 0, -15, 
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(statusText, "DermaDefault", 0, 0, 
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Таймер
            if status == "Robbing" then
                local timeLeft = math.Round((self:GetStartTime() + self:GetRobberyTime()) - CurTime())
                draw.SimpleText(timeLeft .. " сек", "DermaDefault", 0, 15, 
                    Color(255, 100, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            elseif status == "Cooldown" then
                local timeLeft = math.Round(self:GetCooldownEnd() - CurTime())
                draw.SimpleText(timeLeft .. " сек", "DermaDefault", 0, 15, 
                    Color(150, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        cam.End3D2D()
    end

    -- Убираем старый HUDPaint хук чтобы не было дублирования
    hook.Remove("HUDPaint", "ContainerRobberyInfo")
end