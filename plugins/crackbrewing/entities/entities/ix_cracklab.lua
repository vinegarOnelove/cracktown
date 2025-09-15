AddCSLuaFile()

local PLUGIN = PLUGIN

ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName = "Crack Laboratory"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

-- Локализация статусов для лаборатории (единый стиль)
PLUGIN.labStatusText = PLUGIN.labStatusText or {
    ["Idle"] = "Пустая",
    ["Brewing"] = "Варка...", 
    ["Finished"] = "Готово!",
    ["Failed"] = "Неудача!"
}

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Status")
    self:NetworkVar("Int", 1, "Health")
    self:NetworkVar("Int", 2, "MaxHealth")
    self:NetworkVar("Int", 3, "Stage")
    self:NetworkVar("Int", 4, "TotalStages")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_lab/crematorcase.mdl")
        self:SetSolid(SOLID_VPHYSICS)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local physObj = self:GetPhysicsObject()
        if IsValid(physObj) then
            physObj:EnableMotion(true)
            physObj:Wake()
        end

        -- Инициализация NetworkVar значений
        self:SetHealth(PLUGIN.config.explosionDamage)
        self:SetMaxHealth(PLUGIN.config.explosionDamage)
        self:SetStatus("Idle")
        self:SetStage(0)
        self:SetTotalStages(0)
        
        self.health = PLUGIN.config.explosionDamage
        self.maxHealth = PLUGIN.config.explosionDamage
    end

    function ENT:OnTakeDamage(dmg)
        if self:GetStatus() == "Brewing" then
            self.riskModifier = (self.riskModifier or 1.0) + 0.2
        end

        local damage = dmg:GetDamage()
        self.health = math.max(0, self.health - damage)
        self:SetHealth(self.health)

        if self.health <= 0 and not self.Destroyed then
            self:BreakLab(dmg:GetAttacker())
        end
    end

    function ENT:BreakLab(attacker)
        if self.Destroyed then return end
        self.Destroyed = true

        self:StopSound("ambient/fire/fire_small_loop1.wav")
        
        util.BlastDamage(self, attacker or self, self:GetPos(), PLUGIN.config.explosionRadius, PLUGIN.config.explosionDamage)
        
        local effect = EffectData()
        effect:SetOrigin(self:GetPos())
        effect:SetMagnitude(2)
        util.Effect("Explosion", effect)
        
        self:EmitSound("weapons/explode5.wav", 100, 100)
        
        PLUGIN:NotifyPolice(self:GetPos(), "Взрыв лаборатории")

        timer.Simple(0.5, function()
            if IsValid(self) then self:Remove() end
        end)
    end

    function ENT:StartCooking(ply, recipe)
        self:SetStatus("Brewing")
        self:SetStage(1)
        self:SetTotalStages(recipe.stages)
        self.recipeID = recipeID
        self.currentRecipe = recipe
        self.riskModifier = PLUGIN.heatLevels[recipe.heat].risk_mod

        self:EmitSound("ambient/fire/fire_small_loop1.wav", PLUGIN.config.soundVolume, 100)

        local stageTime = recipe.time / recipe.stages
        
        for stage = 1, recipe.stages do
            timer.Simple(stageTime * stage, function()
                if not IsValid(self) then return end
                
                if stage < recipe.stages then
                    self:SetStage(stage + 1)
                    self:EmitSound("buttons/button14.wav", 60, 100)
                    
                    if math.random(1, 100) <= (recipe.risk * self.riskModifier) / recipe.stages then
                        self:FailCooking(ply, "Этап " .. stage .. " провален")
                        return
                    end
                else
                    self:FinishCooking(ply)
                end
            end)
        end
    end

    function ENT:FailCooking(ply, reason)
        self:SetStatus("Failed")
        self:StopSound("ambient/fire/fire_small_loop1.wav")
        
        self:EmitSound("ambient/energy/spark" .. math.random(1,6) .. ".wav", 80, 100)
        
        if IsValid(ply) then
            ply:Notify("Варка провалена: " .. reason)
        end
        
        if math.random(1, 100) <= 20 then
            PLUGIN:NotifyPolice(self:GetPos(), "Неудачная попытка варки")
        end

        timer.Simple(5, function()
            if IsValid(self) then
                self:SetStatus("Idle")
                self:SetStage(0)
            end
        end)
    end

    function ENT:FinishCooking(ply)
        self:SetStatus("Finished")
        self:StopSound("ambient/fire/fire_small_loop1.wav")
        self:EmitSound("buttons/button3.wav", 70, 100)

        if IsValid(ply) then
            ply:Notify("Варка завершена успешно!")
        end
    end

    function ENT:Use(ply)
        if CurTime() < (self.nextUse or 0) then return end
        self.nextUse = CurTime() + 1

        local char = ply:GetCharacter()
        local inv = char and char:GetInventory()
        if not inv then return end

        local status = self:GetStatus()

        if status == "Idle" then
            for recipeID, recipe in pairs(PLUGIN.recipes) do
                local hasAll = true
                for _, item in ipairs(recipe.input) do
                    if not inv:HasItem(item) then
                        hasAll = false
                        break
                    end
                end

                if hasAll then
                    for _, item in ipairs(recipe.input) do
                        local found = inv:HasItem(item)
                        if found then found:Remove() end
                    end

                    ply:Notify("Начинаем варку крэка...")
                    self:StartCooking(ply, recipe)
                    return
                end
            end
            ply:Notify("Не хватает ингредиентов!")

        elseif status == "Finished" then
            local recipe = self.currentRecipe
            if recipe and inv:Add(recipe.output) then
                ply:Notify("Вы забрали " .. recipe.output)
                self:SetStatus("Idle")
                self:SetStage(0)
                self.currentRecipe = nil
            end

        elseif status == "Brewing" then
            ply:Notify("Идет процесс варки... Этап " .. self:GetStage() .. "/" .. self:GetTotalStages())
        end
    end

    function ENT:OnRemove()
        self:StopSound("ambient/fire/fire_small_loop1.wav")
    end
end

if CLIENT then
    -- Используем те же глобальные функции (единый стиль)
    function SafeGetClass(ent)
        if not IsValid(ent) then return "invalid" end
        if not isfunction(ent.GetClass) then return "no_getclass" end
        return ent:GetClass() or "unknown"
    end

    function SafeGetStatus(ent)
        if not IsValid(ent) then return "invalid" end
        if not isfunction(ent.GetStatus) then return "no_getstatus" end
        return ent:GetStatus() or "unknown"
    end

    function ENT:Initialize()
        self.statusInitialized = false
        self.lastStatusCheck = 0
    end

    function ENT:Think()
        if CurTime() > self.lastStatusCheck + 1 then
            self.lastStatusCheck = CurTime()
            
            if isfunction(self.GetStatus) and self:GetStatus() then
                self.statusInitialized = true
            end
        end
        
        self:NextThink(CurTime() + 0.5)
        return true
    end

    function ENT:Draw()
        self:DrawModel()
        
        if not self.statusInitialized then return end
        
        local distance = self:GetPos():Distance(LocalPlayer():GetPos())
        if distance > 300 then return end
        
        local status = SafeGetStatus(self)
        local localizedStatus = PLUGIN.labStatusText[status] or status
        local stage = self:GetStage() or 0
        local totalStages = self:GetTotalStages() or 0
        
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)
        
        -- Единый стиль: Выше и с небольшим смещением вперед
        local pos = self:GetPos() + self:GetUp() * 50 + self:GetForward() * 5
        
        cam.Start3D2D(pos, ang, 0.1)
            -- Фон с закругленными углами (единый стиль)
            draw.RoundedBox(8, -50, -20, 100, 35, Color(0, 0, 0, 230))
            
            -- Рамка в зависимости от статуса (единый стиль)
            if status == "Brewing" then
                surface.SetDrawColor(255, 150, 0, 255)
            elseif status == "Finished" then
                surface.SetDrawColor(0, 255, 0, 255)
            elseif status == "Failed" then
                surface.SetDrawColor(255, 0, 0, 255)
            else
                surface.SetDrawColor(150, 150, 150, 255)
            end
            surface.DrawOutlinedRect(-50, -20, 100, 35, 2)
            
            -- Текст статуса с жирным шрифтом (единый стиль)
            draw.SimpleText(localizedStatus, "DermaDefaultBold", 0, -5, 
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
            -- Прогресс этапов для статуса варки (единый стиль)
            if status == "Brewing" then
                draw.SimpleText("Этап: " .. stage .. "/" .. totalStages, "DermaDefault", 0, 10, 
                    color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
                draw.SimpleText("⚡", "DermaDefault", 40, -15, 
                    Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        cam.End3D2D()
    end

    -- Хук для tooltip (единый стиль)
    hook.Add("PopulateEntityInfo", "ixCrackLabInfo", function(tooltip, ent)
        -- Защитные проверки
        if not IsValid(ent) then return end
        if not isfunction(ent.GetClass) then return end
        if SafeGetClass(ent) ~= "ix_cracklab" then return end
        
        if not isfunction(ent.GetStatus) then return end
        
        local status = SafeGetStatus(ent)
        local localizedStatus = PLUGIN.labStatusText[status] or status
        local stage = ent:GetStage() or 0
        local totalStages = ent:GetTotalStages() or 0
        
        -- Заголовок (единый стиль)
        local name = tooltip:AddRow("name")
        name:SetText("Крэк лаборатория")
        name:SetBackgroundColor(Color(50, 0, 0))
        name:SetImportant()
        name:SizeToContents()
        
        -- Статус (единый стиль)
        local statusRow = tooltip:AddRow("status")
        statusRow:SetText("Статус: " .. localizedStatus)
        statusRow:SetBackgroundColor(Color(30, 0, 0))
        statusRow:SizeToContents()
        
        -- Дополнительная информация (единый стиль)
        if status == "Brewing" then
            local progress = tooltip:AddRow("progress")
            progress:SetText("Этап: " .. stage .. "/" .. totalStages)
            progress:SetBackgroundColor(Color(50, 20, 0))
            progress:SizeToContents()
            
            local info = tooltip:AddRow("info")
            info:SetText("Идет процесс варки крэка...")
            info:SetBackgroundColor(Color(60, 30, 0))
            info:SizeToContents()
        elseif status == "Finished" then
            local info = tooltip:AddRow("info")
            info:SetText("Нажмите E чтобы забрать готовый продукт")
            info:SetBackgroundColor(Color(0, 50, 0))
            info:SizeToContents()
        elseif status == "Failed" then
            local info = tooltip:AddRow("info")
            info:SetText("Процесс варки провален")
            info:SetBackgroundColor(Color(50, 0, 0))
            info:SizeToContents()
        end
    end)
end