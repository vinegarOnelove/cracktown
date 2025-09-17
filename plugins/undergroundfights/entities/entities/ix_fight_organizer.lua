AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Организатор боёв"
ENT.Category = "Helix"
ENT.Author = "Ваше имя"
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- Критически важные настройки для анимации
ENT.AutomaticFrameAdvance = true
ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "OrganizerName")
    self:NetworkVar("Int", 0, "ActiveFights")
    self:NetworkVar("Int", 1, "TotalEarnings")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/odessa.mdl")
        self:SetSolid(SOLID_BBOX)
        self:SetUseType(SIMPLE_USE)
        
        -- Инициализация сетевых переменных
        self:SetOrganizerName("Борис 'Кулак'")
        self:SetActiveFights(0)
        self:SetTotalEarnings(0)
        
        self:PhysicsInit(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_NONE)
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end
        
        self:SetCollisionBounds(Vector(-20, -20, 0), Vector(20, 20, 80))
        
        -- Устанавливаем анимацию стояния
        local sequence = self:LookupSequence("Idle_subtle")
        if sequence and sequence > 0 then
            self:ResetSequence(sequence)
            self:SetPlaybackRate(1.0)
            self:SetCycle(0)
        end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        
        if PLUGIN and PLUGIN.OpenFightMenu then
            PLUGIN:OpenFightMenu(self, activator)
        else
            net.Start("UndergroundFightMainMenu")
            net.WriteEntity(self)
            net.Send(activator)
        end
    end

    function ENT:Think()
        -- Обновляем статистику боёв
        local activeCount = 0
        if PLUGIN and PLUGIN.activeFights then
            for _, fight in pairs(PLUGIN.activeFights) do
                if fight.status == "active" then
                    activeCount = activeCount + 1
                end
            end
        end
        
        -- Обновляем сетевые переменные
        self:SetActiveFights(activeCount)
        
        -- Здесь можно добавить логику для обновления TotalEarnings
        -- Например: self:SetTotalEarnings(calculateEarnings())
        
        -- Обновление анимации
        if self.AutomaticFrameAdvance then
            self:FrameAdvance(FrameTime())
        end
        
        self:NextThink(CurTime() + 1)
        return true
    end
end

if CLIENT then
    -- Безопасные функции получения данных
    local function SafeGetClass(ent)
        if not IsValid(ent) then return "invalid" end
        if not isfunction(ent.GetClass) then return "no_getclass" end
        return ent:GetClass() or "unknown"
    end

    function ENT:Initialize()
        self.statusInitialized = false
        self.lastStatusCheck = 0
    end

    function ENT:Think()
        if CurTime() > self.lastStatusCheck + 1 then
            self.lastStatusCheck = CurTime()
            self.statusInitialized = true
        end
    end

    function ENT:Draw()
        self:DrawModel()
        
        if not self.statusInitialized then return end
        
        local distance = self:GetPos():Distance(LocalPlayer():GetPos())
        if distance > 300 then return end
        
        -- Получаем значения через сетевые переменные
        local activeFights = self:GetActiveFights() or 0
        local totalEarnings = self:GetTotalEarnings() or 0
        
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)
        
        local pos = self:GetPos() + self:GetUp() * 80 + self:GetForward() * 5
        
        cam.Start3D2D(pos, ang, 0.1)
            draw.RoundedBox(8, -120, -60, 240, 100, Color(0, 0, 0, 230))
            surface.SetDrawColor(255, 0, 0, 255)
            surface.DrawOutlinedRect(-120, -60, 240, 100, 2)
            
            draw.SimpleText("ОРГАНИЗАТОР БОЁВ", "DermaDefaultBold", 0, -50, 
                Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            draw.SimpleText(self:GetOrganizerName(), "DermaDefault", 0, -30, 
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            draw.SimpleText("Активных боёв: " .. activeFights, "DermaDefault", 0, -10, 
                Color(255, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            draw.SimpleText("Заработано: ☋" .. totalEarnings, "DermaDefault", 0, 10, 
                Color(0, 255, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            draw.SimpleText("Нажми E для взаимодействия", "DermaDefault", 0, 30, 
                Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end

    -- Хук для tooltip
    hook.Add("PopulateEntityInfo", "ixFightOrganizerInfo", function(tooltip, ent)
        if not IsValid(ent) then return end
        if not isfunction(ent.GetClass) then return end
        if SafeGetClass(ent) ~= "ix_fight_organizer" then return end
        
        local name = tooltip:AddRow("name")
        name:SetText("Организатор подпольных боёв")
        name:SetBackgroundColor(Color(50, 0, 0))
        name:SetImportant()
        name:SizeToContents()
        
        local organizerRow = tooltip:AddRow("organizer")
        organizerRow:SetText("Организатор: " .. (ent:GetOrganizerName() or "Неизвестно"))
        organizerRow:SetBackgroundColor(Color(30, 0, 0))
        organizerRow:SizeToContents()
        
        local fightsRow = tooltip:AddRow("fights")
        fightsRow:SetText("Активных боёв: " .. (ent:GetActiveFights() or 0))
        fightsRow:SetBackgroundColor(Color(40, 20, 0))
        fightsRow:SizeToContents()
        
        local earningsRow = tooltip:AddRow("earnings")
        earningsRow:SetText("Заработано: ☋" .. (ent:GetTotalEarnings() or 0))
        earningsRow:SetBackgroundColor(Color(0, 40, 0))
        earningsRow:SizeToContents()
        
        local descRow = tooltip:AddRow("description")
        descRow:SetText("Вызывайте игроков на бой и делайте ставки!")
        descRow:SetBackgroundColor(Color(20, 20, 20))
        descRow:SizeToContents()
        
        local actionRow = tooltip:AddRow("action")
        actionRow:SetText("Нажмите E чтобы открыть меню")
        actionRow:SetBackgroundColor(Color(0, 0, 50))
        actionRow:SizeToContents()
    end)
end