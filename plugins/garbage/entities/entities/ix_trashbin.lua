ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Мусорный бак"
ENT.Author = "Your Name"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_junk/TrashBin01a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
        
        self.nextSearchTime = 0
        self.searchCooldown = 60
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    if SERVER then
        net.Start("TrashCanOpenMenu")
        net.Send(activator)
    end
end

if CLIENT then
    -- Безопасные функции доступа
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
        
        -- Текст над мусоркой
        local pos = self:GetPos() + self:GetUp() * 35 + self:GetForward() * 5
        
        cam.Start3D2D(pos, ang, 0.08)
            -- Фон с закругленными углами
            draw.RoundedBox(8, -50, -20, 100, 40, Color(50, 50, 50, 230))
            
            -- Рамка
            surface.SetDrawColor(100, 100, 100, 255)
            surface.DrawOutlinedRect(-50, -20, 100, 40, 2)
            
            -- Текст
            draw.SimpleText("МУСОРКА", "DermaDefaultBold", 0, -10, 
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end