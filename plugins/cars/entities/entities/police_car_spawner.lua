AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Спавнер полицейской машины"
ENT.Category = "Helix"
ENT.Author = "Your Name"
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- Конфигурация спавнера
ENT.UseCooldown = 1
ENT.SpawnLimit = 1 -- Лимит машин на этот спавнер
ENT.VehicleClass = "monaco_police_glide" -- Класс машины по умолчанию
ENT.AllowedFaction = FACTION_POLICE -- Фракция по умолчанию
ENT.SpawnOffset = Vector(-250, 0, 10) -- Смещение для спавна

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "SpawnedCount")
    self:NetworkVar("String", 1, "VehicleClass")
    self:NetworkVar("Int", 2, "AllowedFaction")
end

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_wasteland/gaspump001a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        self.nextUse = 0
        self:SetSpawnedCount(0)
        self:SetVehicleClass(self.VehicleClass)
        self:SetAllowedFaction(self.AllowedFaction)
        
        -- Таблица для отслеживания машин этого спавнера
        self.spawnedVehicles = {}
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply:GetCharacter() then return end

    if SERVER then
        -- Проверка кулдауна
        if CurTime() < (self.nextUse or 0) then return end
        self.nextUse = CurTime() + self.UseCooldown

        -- Проверка фракции
        local char = ply:GetCharacter()
        if char:GetFaction() ~= self:GetAllowedFaction() then
            ply:ChatPrint("Доступ запрещен для вашей фракции!")
            return
        end

        -- Проверка лимита спавнера
        if self:GetSpawnedCount() >= self.SpawnLimit then
            ply:ChatPrint("Машины кончились!")
            return
        end

        -- Позиция спавна
        local spawnPos = self:GetPos() + self:GetForward() * self.SpawnOffset.x + 
                        self:GetRight() * self.SpawnOffset.y + 
                        self:GetUp() * self.SpawnOffset.z
        local spawnAng = self:GetAngles() + Angle(0, 180, 0)

        -- Проверка занятости зоны
        local tr = util.TraceHull({
            start = spawnPos,
            endpos = spawnPos,
            mins = Vector(-60, -120, 0),
            maxs = Vector(60, 120, 60),
            mask = MASK_SHOT_HULL,
            filter = function(ent) 
                return ent ~= self and not ent:IsPlayer() 
            end
        })

        if tr.Hit then
            ply:ChatPrint("Место для вызова машины занято!")
            return
        end

        -- Создаём машину :cite[4]
        local vehicleClass = self:GetVehicleClass()
        local vehicle = ents.Create(vehicleClass)
        
        if not IsValid(vehicle) then
            -- Попытка создать запасную модель
            vehicle = ents.Create("prop_vehicle_jeep")
            if IsValid(vehicle) then
                vehicle:SetModel("models/tdmcars/ford_police.mdl")
                vehicle:SetKeyValue("vehiclescript", "scripts/vehicles/tdm_charger.txt")
            end
        end

        if not IsValid(vehicle) then
            ply:ChatPrint("Ошибка: не удалось создать машину.")
            return
        end

        vehicle:SetPos(spawnPos)
        vehicle:SetAngles(spawnAng)
        vehicle:Spawn()
        vehicle:Activate()

        -- Добавляем машину в таблицу спавнера
        table.insert(self.spawnedVehicles, vehicle)
        self:SetSpawnedCount(self:GetSpawnedCount() + 1)

        -- Обработчик удаления машины
        vehicle:CallOnRemove("SpawnerCleanup", function(ent)
            if IsValid(self) then
                for k, v in pairs(self.spawnedVehicles) do
                    if v == ent then
                        table.remove(self.spawnedVehicles, k)
                        self:SetSpawnedCount(math.max(0, self:GetSpawnedCount() - 1))
                        break
                    end
                end
            end
        end)

        ply:ChatPrint("Машина успешно создана! (" .. self:GetSpawnedCount() .. "/" .. self.SpawnLimit .. ")")
    end
end

-- Конфигурация спавнера через консольные команды
if SERVER then
    -- Команда для изменения лимита спавнера
    concommand.Add("spawner_set_limit", function(ply, cmd, args)
        if not ply:IsAdmin() then return end
        
        local spawner = ply:GetEyeTrace().Entity
        if IsValid(spawner) and spawner:GetClass() == "universal_vehicle_spawner" then
            local newLimit = tonumber(args[1]) or 1
            spawner.SpawnLimit = math.Clamp(newLimit, 1, 10)
            ply:ChatPrint("Лимит спавнера установлен на: " .. spawner.SpawnLimit)
        end
    end)

    -- Команда для изменения класса машины
    concommand.Add("spawner_set_vehicle", function(ply, cmd, args)
        if not ply:IsAdmin() then return end
        
        local spawner = ply:GetEyeTrace().Entity
        if IsValid(spawner) and spawner:GetClass() == "universal_vehicle_spawner" then
            local vehicleClass = args[1] or "monaco_police_glide"
            spawner:SetVehicleClass(vehicleClass)
            ply:ChatPrint("Класс машины установлен на: " .. vehicleClass)
        end
    end)

    -- Команда для изменения фракции
    concommand.Add("spawner_set_faction", function(ply, cmd, args)
        if not ply:IsAdmin() then return end
        
        local spawner = ply:GetEyeTrace().Entity
        if IsValid(spawner) and spawner:GetClass() == "universal_vehicle_spawner" then
            local factionID = tonumber(args[1]) or FACTION_POLICE
            spawner:SetAllowedFaction(factionID)
            ply:ChatPrint("Фракция установлена на ID: " .. factionID)
        end
    end)
end

-- Клиентская часть (надпись над спавнером)
if CLIENT then
    function ENT:Draw()
        self:DrawModel()

        local distance = self:GetPos():Distance(LocalPlayer():GetPos())
        if distance > 300 then return end

        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        local pos = self:GetPos() + self:GetUp() * 70

        cam.Start3D2D(pos, ang, 0.1)
            -- Фон
            draw.RoundedBox(8, -80, -30, 160, 60, Color(0, 0, 0, 200))

            -- Рамка
            surface.SetDrawColor(0, 100, 200, 255)
            surface.DrawOutlinedRect(-80, -30, 160, 60, 2)

            -- Основной текст
            draw.SimpleText("ВЫЗВАТЬ ПОЛИЦЕЙСКУЮ МАШИНУ", "DermaDefaultBold", 0, -15,
                Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Информация о лимите
            draw.SimpleText("Лимит: " .. self:GetSpawnedCount() .. "/" .. self.SpawnLimit, "DermaDefault", 0, 0,
                Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Информация о классе машины
            local vehicleClass = self:GetVehicleClass() or "unknown"
            if string.len(vehicleClass) > 15 then
                vehicleClass = string.sub(vehicleClass, 1, 12) .. "..."
            end
            draw.SimpleText("Машина: " .. vehicleClass, "DermaDefault", 0, 15,
                Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end

    -- Информация при наведении
    hook.Add("HUDPaint", "UniversalSpawnerInfo", function()
        local trace = LocalPlayer():GetEyeTrace()
        if not IsValid(trace.Entity) or trace.Entity:GetClass() ~= "universal_vehicle_spawner" then return end
        
        local spawner = trace.Entity
        local pos = trace.HitPos:ToScreen()
        
        draw.SimpleText("Универсальный спавнер машин", "DermaDefaultBold", pos.x, pos.y - 40, Color(255, 255, 255), TEXT_ALIGN_CENTER)
        draw.SimpleText("Нажмите E для использования", "DermaDefault", pos.x, pos.y - 25, Color(200, 200, 200), TEXT_ALIGN_CENTER)
        draw.SimpleText("Лимит: " .. spawner:GetSpawnedCount() .. "/" .. spawner.SpawnLimit, "DermaDefault", pos.x, pos.y - 10, Color(200, 200, 200), TEXT_ALIGN_CENTER)
    end)
	
end





