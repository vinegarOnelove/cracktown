ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Доска розыска"
ENT.Author = "Your Name"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_lab/securitybank.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    if SERVER then
        net.Start("WantedListOpen")
        net.Send(activator)
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
        
        local distance = self:GetPos():Distance(LocalPlayer():GetPos())
        if distance > 500 then return end
        
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)
        
        -- Поднимаем текст выше, чтобы он не застревал в пропе
        local pos = self:GetPos() + self:GetUp() * 125 + self:GetForward() * 2
        
        cam.Start3D2D(pos, ang, 0.08)
            -- Фон с закругленными углами
            draw.RoundedBox(8, -60, -25, 120, 45, Color(0, 0, 50, 230))
            
            -- Синяя рамка (полицейская тематика)
            surface.SetDrawColor(0, 100, 255, 255)
            surface.DrawOutlinedRect(-60, -25, 120, 45, 2)
            
            -- Текст статуса
            draw.SimpleText("ДОСКА", "DermaDefaultBold", 0, -15, 
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
            draw.SimpleText("РОЗЫСКА", "DermaDefaultBold", 0, 0, 
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                
            -- Иконка полиции
            draw.SimpleText("", "DermaDefault", 50, -20, 
                Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end