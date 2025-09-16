AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Спавнер полицейских машин"
ENT.Category = "Helix"
ENT.Author = "Your Name"
ENT.Spawnable = true
ENT.AdminSpawnable = true

-- Кулдаун на использование (сек)
ENT.UseCooldown = 1

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/props_wasteland/gaspump001a.mdl") -- замени на подходящую модель
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        self.nextUse = 0
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if not ply:GetCharacter() then return end

    if SERVER then
        -- кулдаун
        if CurTime() < (self.nextUse or 0) then return end
        self.nextUse = CurTime() + self.UseCooldown

        -- проверка фракции
        local char = ply:GetCharacter()
        if char:GetFaction() ~= FACTION_POLICE then -- замени на свою фракцию
            ply:ChatPrint("Только полиция может вызвать полицейскую машину!")
            return
        end

        -- если у игрока уже есть машина
        if IsValid(ply.ixSpawnedCar) then
            ply:ChatPrint("Полицейские машины кончились!")
            return
        end

        -- позиция спавна
        local spawnPos = self:GetPos() - self:GetForward() * 250 + Vector(0, 0, 10)
        local spawnAng = self:GetAngles() + Angle(0, 180, 0)

        -- проверка занятости зоны
        local tr = util.TraceHull({
            start = spawnPos,
            endpos = spawnPos,
            mins = Vector(-60, -120, 0),  -- примерный размер машины
            maxs = Vector(60, 120, 60),
            mask = MASK_SHOT_HULL
        })

        if tr.Hit then
            ply:ChatPrint("Место для спавна занято!")
            return
        end

        -- создаём машину
        local vehicle = ents.Create("monaco_police_glide")
        if not IsValid(vehicle) then
            ply:ChatPrint("Ошибка: не удалось создать машину.")
            return
        end

        vehicle:SetPos(spawnPos)
        vehicle:SetAngles(spawnAng)
        vehicle:Spawn()
        vehicle:Activate()

        ply.ixSpawnedCar = vehicle

        vehicle:CallOnRemove("ClearPlayerCar", function(ent, owner)
            if IsValid(owner) then
                owner.ixSpawnedCar = nil
                owner:ChatPrint("Твоя машина была удалена.")
            end
        end, ply)

        ply:ChatPrint("Ты заспавнил полицейскую машину!")
    end
end

-- клиентская часть (надпись над спавнером)
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
            -- фон
            draw.RoundedBox(8, -60, -20, 120, 30, Color(0, 0, 0, 200))

            -- рамка
            surface.SetDrawColor(0, 100, 200, 255)
            surface.DrawOutlinedRect(-60, -20, 120, 30, 2)

            -- текст
            draw.SimpleText("ВЫЗВАТЬ ПОЛИЦЕЙСКУЮ МАШИНУ", "DermaDefault", 0, -5,
                Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end





