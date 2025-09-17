AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Коробка доставки"
ENT.Category = "Helix"
ENT.Author = "Your Name"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ItemID")
    self:NetworkVar("String", 1, "OwnerSteamID")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_junk/cardboard_box001a.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        -- Автоматическое удаление через 10 минут
        timer.Simple(600, function()
            if IsValid(self) then
                self:Remove()
            end
        end)
    end

    function ENT:SetDeliveryData(itemID, owner)
        self:SetItemID(itemID)
        if IsValid(owner) then
            self:SetOwnerSteamID(owner:SteamID64())
        end
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end
        
        local itemID = self:GetItemID()
        if not itemID then return end
        
        local ownerID = self:GetOwnerSteamID()
        if ownerID and ownerID ~= activator:SteamID64() then
            activator:Notify("Эта посылка не для вас!")
            return
        end
        
        local character = activator:GetCharacter()
        if character then
            character:GetInventory():Add(itemID)
            activator:Notify("Вы получили предмет: " .. itemID)
            
            local effect = EffectData()
            effect:SetEntity(activator)
            util.Effect("item_pickup", effect)
            
            self:Remove()
        end
    end

    function ENT:OnRemove()
        local effect = EffectData()
        effect:SetOrigin(self:GetPos())
        util.Effect("RagdollImpact", effect)
    end
end

if CLIENT then
    -- Безопасные вспомогательные функции
    local function IsTooltipObject(obj)
        return obj ~= nil and isfunction(obj.AddRow)
    end

    local function ResolveTooltipArgs(a, b)
        -- Игнорируем nils
        if IsTooltipObject(a) and IsValid(b) then
            return a, b
        end

        if IsTooltipObject(b) and IsValid(a) then
            return b, a
        end

        -- Если один из аргументов не является tooltip, постараемся угадать
        if IsTooltipObject(a) then return a, b end
        if IsTooltipObject(b) then return b, a end

        return a, b
    end

    -- Безопасно получить класс сущности
    local function SafeGetClass(ent)
        if not IsValid(ent) then return nil end
        if not isfunction(ent.GetClass) then return nil end
        local ok, res = pcall(function() return ent:GetClass() end)
        if not ok then return nil end
        return res
    end

    function ENT:Draw()
        self:DrawModel()

        local distance = self:GetPos():Distance(LocalPlayer():GetPos())
        if distance > 300 then return end

        local itemID = self:GetItemID() or "unknown"

        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        local pos = self:GetPos() + self:GetUp() * 50 + self:GetForward() * 5

        cam.Start3D2D(pos, ang, 0.1)
            draw.RoundedBox(8, -60, -25, 120, 40, Color(0, 0, 0, 200))

            surface.SetDrawColor(0, 255, 0, 255)
            surface.DrawOutlinedRect(-60, -25, 120, 40, 2)

            draw.SimpleText("Посылка", "DermaDefaultBold", 0, -8,
                color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            draw.SimpleText(itemID, "DermaDefault", 0, 10,
                Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end

    hook.Add("PopulateEntityInfo", "ixDeliveryBoxInfo", function(arg1, arg2)
        local tooltip, ent = ResolveTooltipArgs(arg1, arg2)

        -- Проверяем tooltip
        if not tooltip or not IsTooltipObject(tooltip) then return end

        -- Проверяем сущность
        if not IsValid(ent) then return end

        local class = SafeGetClass(ent)
        if not class or class ~= "ix_delivery_box" then return end

        local itemID = ent.GetItemID and ent:GetItemID() or "unknown"

        -- Заголовок
        local name = tooltip:AddRow("ix_delivery_name")
        name:SetText("Посылка")
        name:SetBackgroundColor(Color(0, 80, 0))
        name:SetImportant()
        name:SizeToContents()

        -- Информация о предмете
        local row = tooltip:AddRow("ix_delivery_item")
        row:SetText("Предмет: " .. itemID)
        row:SetBackgroundColor(Color(20, 20, 20))
        row:SizeToContents()

        -- Подсказка
        local hint = tooltip:AddRow("ix_delivery_hint")
        hint:SetText("Нажмите E, чтобы забрать посылку")
        hint:SetBackgroundColor(Color(40, 40, 40))
        hint:SizeToContents()
    end)
end
