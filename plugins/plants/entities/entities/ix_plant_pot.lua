AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Горшок для растений"
ENT.Category = "Helix"
ENT.Author = "Your Name"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Status")
    self:NetworkVar("String", 1, "PlantType")
    self:NetworkVar("Float", 0, "GrowStartTime")
    self:NetworkVar("Float", 1, "GrowEndTime")
    self:NetworkVar("Float", 2, "GrowProgress")
    self:NetworkVar("Int", 0, "CurrentStage")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_junk/terracotta01.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        self:SetStatus("Empty")
        self:SetPlantType("")
        self:SetGrowStartTime(0)
        self:SetGrowEndTime(0)
        self:SetGrowProgress(0)
        self:SetCurrentStage(0)
        
        self.plantEntity = nil
    end

    -- Посадка растения
    function ENT:PlantSeed(planter, plantType)
        local plugin = ix.plugin.Get("plantgrowing") or ix.plugin.Get("plants")
        if not plugin then return false end
        
        local plantData = plugin.plantTypes[plantType]
        if not plantData then return false end

        self:SetStatus("Growing")
        self:SetPlantType(plantType)
        self:SetGrowStartTime(CurTime())
        self:SetGrowEndTime(CurTime() + plantData.growTime)
        self:SetGrowProgress(0)
        self:SetCurrentStage(0)

        -- Создаем модель растения
        self:CreatePlantEntity()

        planter:Notify("Вы посадили " .. plantData.name .. "! Время роста: " .. plantData.growTime .. " сек")
        
        -- Запускаем таймер роста
        self.growTimer = "plant_grow_" .. self:EntIndex()
        timer.Create(self.growTimer, 0.1, 0, function()
            if IsValid(self) then
                self:UpdateGrowth()
            end
        end)

        return true
    end

    -- Создание entity растения
    function ENT:CreatePlantEntity()
        if IsValid(self.plantEntity) then
            self.plantEntity:Remove()
        end

        local plugin = ix.plugin.Get("plantgrowing") or ix.plugin.Get("plants")
        if not plugin then return end
        
        local plantData = plugin.plantTypes[self:GetPlantType()]
        if not plantData then return end

        self.plantEntity = ents.Create("prop_physics")
        self.plantEntity:SetModel('models/props_zaza/hemp.mdl')
        self.plantEntity:SetPos(self:GetPos() + Vector(0, 0, 0))
        self.plantEntity:SetAngles(self:GetAngles())
        self.plantEntity:SetParent(self)
        self.plantEntity:Spawn()
        self.plantEntity:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        
        -- Начальный размер
        self:UpdatePlantAppearance()
    end

    -- Обновление роста
    function ENT:UpdateGrowth()
        if self:GetStatus() ~= "Growing" then return end
        
        local progress = (CurTime() - self:GetGrowStartTime()) / (self:GetGrowEndTime() - self:GetGrowStartTime())
        progress = math.Clamp(progress, 0, 1)
        self:SetGrowProgress(progress)

        -- Проверка на увядание
        local plugin = ix.plugin.Get("plantgrowing") or ix.plugin.Get("plants")
        if plugin and not plugin:CheckWatering(self) and math.random(1, 100) <= 5 then
            self:Wither()
            return
        end

        -- Обновление стадии
        if plugin then
            local plantData = plugin.plantTypes[self:GetPlantType()]
            if plantData then
                for stage, stageData in ipairs(plantData.stages) do
                    if progress >= stageData.time and self:GetCurrentStage() < stage then
                        self:SetCurrentStage(stage)
                        self:UpdatePlantAppearance()
                    end
                end
            end
        end

        -- Проверка готовности
        if progress >= 1.0 then
            self:SetStatus("Ready")
            if self.growTimer then
                timer.Remove(self.growTimer)
            end
        end
    end

    -- Обновление внешнего вида растения
    function ENT:UpdatePlantAppearance()
        if not IsValid(self.plantEntity) then return end
        
        local plugin = ix.plugin.Get("plantgrowing") or ix.plugin.Get("plants")
        if not plugin then return end
        
        local plantData = plugin.plantTypes[self:GetPlantType()]
        local currentStage = self:GetCurrentStage()
        
        if plantData and plantData.stages[currentStage] then
            local scale = plantData.stages[currentStage].scale
            self.plantEntity:SetModelScale(scale, 0)
        end
    end

    -- Увядание растения
    function ENT:Wither()
        self:SetStatus("Withered")
        if self.growTimer then
            timer.Remove(self.growTimer)
        end
        
        if IsValid(self.plantEntity) then
            self.plantEntity:SetColor(Color(100, 100, 100))
        end
    end

    -- Сбор урожая
    function ENT:Harvest(harvester)
        if self:GetStatus() ~= "Ready" then return false end
        
        local plugin = ix.plugin.Get("plantgrowing") or ix.plugin.Get("plants")
        if not plugin then return false end
        
        local plantData = plugin.plantTypes[self:GetPlantType()]
        if not plantData then return false end

        plugin:GiveHarvest(harvester, plantData)
        self:ResetPot()
        
        return true
    end

    -- Сброс горшка
    function ENT:ResetPot()
        self:SetStatus("Empty")
        self:SetPlantType("")
        self:SetGrowStartTime(0)
        self:SetGrowEndTime(0)
        self:SetGrowProgress(0)
        self:SetCurrentStage(0)
        
        if IsValid(self.plantEntity) then
            self.plantEntity:Remove()
            self.plantEntity = nil
        end
        
        if self.growTimer then
            timer.Remove(self.growTimer)
        end
    end

    function ENT:Use(ply)
        if not IsValid(ply) or not ply:GetCharacter() then return end
        
        local status = self:GetStatus()
        local char = ply:GetCharacter()
        local inv = char:GetInventory()

        if status == "Empty" then
            -- Попытка посадить семена
            local plugin = ix.plugin.Get("plantgrowing") or ix.plugin.Get("plants")
            if plugin then
                for plantType, plantData in pairs(plugin.plantTypes) do
                    local seedItem = inv:HasItem(plantData.seed)
                    if seedItem then
                        seedItem:Remove()
                        self:PlantSeed(ply, plantType)
                        return
                    end
                end
            end
            
            ply:Notify("У вас нет семян для посадки!")
            
        elseif status == "Ready" then
            -- Сбор урожая
            self:Harvest(ply)
            
        elseif status == "Withered" then
            -- Очистка увядшего растения
            self:ResetPot()
            ply:Notify("Вы очистили горшок от увядшего растения")
            
        elseif status == "Growing" then
            local timeLeft = math.Round(self:GetGrowEndTime() - CurTime())
            ply:Notify("Растение растет... Осталось: " .. timeLeft .. " сек")
        end
    end

    function ENT:OnRemove()
        if self.growTimer then
            timer.Remove(self.growTimer)
        end
        if IsValid(self.plantEntity) then
            self.plantEntity:Remove()
        end
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end