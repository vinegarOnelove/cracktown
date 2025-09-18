AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Доска розыска"
ENT.Category = "Helix"
ENT.Author = "Ваше имя"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "WantedCount")
    self:NetworkVar("Int", 1, "TotalBounty")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_lab/corkboard001.mdl")
        self:SetSolid(SOLID_BBOX)
        self:SetUseType(SIMPLE_USE)
        
        self:PhysicsInit(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_NONE)
        
        self:SetWantedCount(0)
        self:SetTotalBounty(0)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        
        -- Получаем плагин через ix.plugin.Get
        local bountyPlugin = ix.plugin.Get("bounty")
        if not bountyPlugin then return end
        
        -- Проверка, что игрок полицейский (замените FACTION_CP на ваш ID полиции)
        if activator:Team() ~= FACTION_POLICE then
            activator:Notify("Доступно только для сотрудников правоохранительных органов!")
            return
        end
        
        net.Start("BountyBoardMenu")
        net.Send(activator)
        
        -- Обновляем статистику доски
        self:UpdateBoardStats()
    end

    function ENT:Think()
        self:UpdateBoardStats()
        self:NextThink(CurTime() + 5)
        return true
    end

    function ENT:UpdateBoardStats()
        local bountyPlugin = ix.plugin.Get("bounty")
        if not bountyPlugin then return end
        
        local wantedCount = 0
        local totalBounty = 0
        
        for steamID, data in pairs(bountyPlugin.wantedPlayers or {}) do
            if IsValid(data.player) then
                wantedCount = wantedCount + 1
                totalBounty = totalBounty + data.totalBounty
            end
        end
        
        self:SetWantedCount(wantedCount)
        self:SetTotalBounty(totalBounty)
    end
end

if CLIENT then
    -- Локализация статусов для доски розыска
    PLUGIN = PLUGIN or {}
    PLUGIN.boardStatusText = PLUGIN.boardStatusText or {
        ["Idle"] = "Пустая",
        ["Active"] = "Активна"
    }

    -- Глобальные функции для безопасного доступа
    function SafeGetClass(ent)
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
            
            if isfunction(self.GetWantedCount) and isfunction(self.GetTotalBounty) then
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
        
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)
        
        -- Позиция текста над доской
        local pos = self:GetPos() + self:GetUp() * 60 + self:GetForward() * 5
        
        cam.Start3D2D(pos, ang, 0.1)
            -- Фон с закругленными углами (единый стиль)
            draw.RoundedBox(8, -120, -25, 240, 50, Color(0, 0, 0, 230))
            
            -- Рамка красного цвета (стиль полиции)
            surface.SetDrawColor(255, 0, 0, 255)
            surface.DrawOutlinedRect(-120, -25, 240, 50, 2)
            
            -- Заголовок
            draw.SimpleText("ДОСКА РОЗЫСКА", "DermaDefaultBold", 0, -15, 
                Color(255, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Статистика
            draw.SimpleText("В розыске: " .. self:GetWantedCount() .. " | Награда: ☋" .. self:GetTotalBounty(), 
                "DermaDefault", 0, 5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end

    -- Хук для tooltip (единый стиль)
    hook.Add("PopulateEntityInfo", "ixBountyBoardInfo", function(tooltip, ent)
        -- 🔥 ЗАЩИТНЫЕ ПРОВЕРКИ
        if not IsValid(ent) then return end
        if not isfunction(ent.GetClass) then return end
        if SafeGetClass(ent) ~= "ix_bounty_board" then return end
        
        if not isfunction(ent.GetWantedCount) or not isfunction(ent.GetTotalBounty) then return end
        
        -- Заголовок (единый стиль)
        local name = tooltip:AddRow("name")
        name:SetText("Доска розыска преступников")
        name:SetBackgroundColor(Color(50, 0, 0))
        name:SetImportant()
        name:SizeToContents()
        
        -- Описание (единый стиль)
        local info = tooltip:AddRow("info")
        info:SetText("Просмотр разыскиваемых преступников и наград")
        info:SetBackgroundColor(Color(30, 0, 0))
        info:SizeToContents()
        
        -- Статистика (единый стиль)
        local stats = tooltip:AddRow("stats")
        stats:SetText("В розыске: " .. ent:GetWantedCount() .. " | Награда: ☋" .. ent:GetTotalBounty())
        stats:SetBackgroundColor(Color(40, 20, 0))
        stats:SizeToContents()
        
        -- Действие (единый стиль)
        local action = tooltip:AddRow("action")
        action:SetText("Нажмите E для просмотра списка розыска")
        action:SetBackgroundColor(Color(0, 0, 50))
        action:SizeToContents()
    end)
end
