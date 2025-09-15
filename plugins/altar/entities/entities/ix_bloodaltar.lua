AddCSLuaFile()

ENT.Base = "base_anim"
ENT.Type = "anim"
ENT.PrintName = "Кровавый Алтарь"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.AutomaticFrameAdvance = true

-- Локализация статусов для алтаря (дублируем на клиенте)
local altarStatusText = {
    ["Idle"] = "Ожидает",
    ["Accepting"] = "Принимает жертву", 
    ["Blessing"] = "Дарует благословение",
    ["Cooldown"] = "Перезарядка"
}

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Status")
    self:NetworkVar("Int", 1, "Cooldown")
    self:NetworkVar("Int", 2, "TotalBlessings")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_c17/gravestone001a.mdl")
        self:SetSolid(SOLID_VPHYSICS)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local physObj = self:GetPhysicsObject()
        if IsValid(physObj) then
            physObj:EnableMotion(true)
            physObj:Wake()
        end

        self:SetStatus("Idle")
        self:SetCooldown(0)
        self:SetTotalBlessings(0)
        
        -- Эффекты алтаря
        self:SetMaterial("models/shiny")
        self:SetColor(Color(150, 0, 0))
    end

    -- 🔧 ИСПРАВЛЕННАЯ ФУНКЦИЯ: Безопасный доступ к плагину
    function ENT:GetAltarPlugin()
        return ix.plugin.list["altar"] or ix.plugin.list["bloodaltar"] or ix.plugin.list["blood_altar"]
    end

    function ENT:StartCooldown()
        self:SetStatus("Cooldown")
        self:SetCooldown(CurTime() + 300) -- 5 минут cooldown
        
        timer.Simple(300, function()
            if IsValid(self) then
                self:SetStatus("Idle")
                self:SetCooldown(0)
            end
        end)
    end

    function ENT:CanAcceptSacrifice(ply)
        if self:GetStatus() == "Cooldown" then
            local timeLeft = math.ceil(self:GetCooldown() - CurTime())
            ply:Notify("Алтарь перезаряжается! Осталось: " .. timeLeft .. "с")
            return false
        end
        
        if self:GetStatus() == "Blessing" then
            ply:Notify("Алтарь уже дарует благословение!")
            return false
        end
        
        return true
    end

    -- 🔧 ИСПРАВЛЕННАЯ ФУНКЦИЯ: Получение доступных благословений
    function ENT:GetAvailableBlessings(ply)
        local char = ply:GetCharacter()
        local available = {}
        
        -- Безопасный доступ к плагину
        local altarPlugin = self:GetAltarPlugin()
        if not altarPlugin or not altarPlugin.altarBlessings then
            ply:Notify("Система благословений недоступна!")
            return available
        end
        
        for blessingID, blessing in pairs(altarPlugin.altarBlessings) do
            local currentLevel = char:GetData("altar_" .. blessingID, 0)
            if currentLevel < blessing.maxLevel then
                table.insert(available, {
                    id = blessingID,
                    data = blessing,
                    level = currentLevel + 1
                })
            end
        end
        
        return available
    end

    -- 🔧 ИСПРАВЛЕННАЯ ФУНКЦИЯ: Проверка жертвенных предметов
    function ENT:HasSacrificeItems(ply, cost)
        if not IsValid(ply) or not ply:GetCharacter() then return false end
        if type(cost) ~= "table" then return false end
        
        local char = ply:GetCharacter()
        local inv = char:GetInventory()
        if not inv then return false end
        
        for itemID, requiredAmount in pairs(cost) do
            -- Проверяем существование предмета
            if not ix.item.Get(itemID) then
                print("[BloodAltar] Invalid item ID: " .. tostring(itemID))
                return false
            end
            
            -- Получаем количество предметов в инвентаре
            local actualAmount = inv:GetItemCount(itemID)
            
            if actualAmount < requiredAmount then
                return false
            end
        end
        
        return true
    end

    -- 🔧 ИСПРАВЛЕННАя ФУНКЦИЯ: Забор жертвенных предметов
    function ENT:TakeSacrificeItems(ply, cost)
        if not IsValid(ply) or not ply:GetCharacter() then return end
        if type(cost) ~= "table" then return end
        
        local char = ply:GetCharacter()
        local inv = char:GetInventory()
        if not inv then return end
        
        for itemID, amount in pairs(cost) do
            -- Удаляем предметы по одному
            for i = 1, amount do
                local item = inv:HasItem(itemID)
                if item then
                    item:Remove()
                else
                    print("[BloodAltar] Failed to remove item: " .. itemID)
                    break
                end
            end
        end
    end

    -- 🔧 ИСПРАВЛЕННАЯ ФУНКЦИЯ: Применение благословения
    function ENT:ApplyBlessing(ply, blessingID, level)
        local char = ply:GetCharacter()
        if not char then return end
        
        -- Безопасный доступ к плагину
        local altarPlugin = self:GetAltarPlugin()
        if not altarPlugin or not altarPlugin.altarBlessings then
            ply:Notify("Ошибка системы благословений!")
            return
        end
        
        local blessing = altarPlugin.altarBlessings[blessingID]
        if not blessing then
            ply:Notify("Неизвестное благословение!")
            return
        end
        
        char:SetData("altar_" .. blessingID, level)
        
        -- Применяем эффекты в зависимости от типа благословения
        if blessingID == "health" then
            local bonusHealth = 25 * level
            char:SetData("altar_health_bonus", bonusHealth)
            
        elseif blessingID == "stamina" then
            local bonusStamina = 0.2 * level
            char:SetData("altar_stamina_bonus", bonusStamina)
            
        elseif blessingID == "strength" then
            local bonusDamage = 0.15 * level
            char:SetData("altar_strength_bonus", bonusDamage)
            
        elseif blessingID == "speed" then
            local bonusSpeed = 0.1 * level
            char:SetData("altar_speed_bonus", bonusSpeed)
        end
        
        -- Сохраняем в перманентные данные
        if not char:GetData("altarBlessings", false) then
            char:SetData("altarBlessings", {})
        end
        
        local blessings = char:GetData("altarBlessings")
        blessings[blessingID] = level
        char:SetData("altarBlessings", blessings)
    end

    function ENT:Use(ply)
        if CurTime() < (self.nextUse or 0) then return end
        self.nextUse = CurTime() + 1

        if not self:CanAcceptSacrifice(ply) then return end

        local char = ply:GetCharacter()
        if not char then return end

        -- Получаем доступные благословения
        local availableBlessings = self:GetAvailableBlessings(ply)
        
        if #availableBlessings == 0 then
            ply:Notify("Вы достигли максимума всех благословений!")
            return
        end

        -- Проверяем есть ли жертвенные предметы
        local hasSacrifice = false
        local possibleBlessings = {}

        for _, blessing in ipairs(availableBlessings) do
            if self:HasSacrificeItems(ply, blessing.data.cost) then
                hasSacrifice = true
                table.insert(possibleBlessings, blessing)
            end
        end

        if not hasSacrifice then
            ply:Notify("У вас нет подходящих жертвенных предметов!")
            return
        end

        -- Если только одно доступное благословение
        if #possibleBlessings == 1 then
            local blessing = possibleBlessings[1]
            self:PerformSacrifice(ply, blessing)
            return
        end

        -- Меню выбора благословения
        net.Start("BloodAltarOpenMenu")
            net.WriteUInt(#possibleBlessings, 4)
            for _, blessing in ipairs(possibleBlessings) do
                net.WriteString(blessing.id)
                net.WriteString(blessing.data.name)
                net.WriteString(blessing.data.description)
                net.WriteUInt(blessing.level, 2)
            end
        net.Send(ply)
    end

    function ENT:PerformSacrifice(ply, blessing)
        self:SetStatus("Accepting")
        
        -- Забираем жертвенные предметы
        self:TakeSacrificeItems(ply, blessing.data.cost)
        
        -- Эффекты жертвоприношения
        self:EmitSound("ambient/creatures/teddy.wav", 75, 100)
        
        -- 🔧 ИСПРАВЛЕННЫЙ ЭФФЕКТ: Используем стандартный эффект вместо кастомных частиц
        local effect = EffectData()
        effect:SetOrigin(self:GetPos() + Vector(0, 0, 30))
        effect:SetColor(255)
        effect:SetScale(2)
        util.Effect("BloodImpact", effect)
        
        ply:Notify("Жертва принята! Алтарь дарует благословение...")
        
        timer.Simple(3, function()
            if IsValid(self) and IsValid(ply) then
                self:SetStatus("Blessing")
                
                -- Применяем благословение
                self:ApplyBlessing(ply, blessing.id, blessing.level)
                
                -- Эффекты благословения
                self:EmitSound("ambient/energy/zap9.wav", 85, 100)
                
                -- 🔧 ИСПРАВЛЕННЫЙ ЭФФЕКТ: Используем стандартный эффект
                local effect = EffectData()
                effect:SetOrigin(self:GetPos() + Vector(0, 0, 40))
                effect:SetMagnitude(3)
                effect:SetScale(1)
                util.Effect("cball_explode", effect)
                
                -- Сообщение игроку
                ply:Notify("Вы получили: " .. blessing.data.name .. " (Уровень " .. blessing.level .. ")")
                
                -- Увеличиваем счетчик благословений
                self:SetTotalBlessings(self:GetTotalBlessings() + 1)
                
                -- Cooldown
                timer.Simple(2, function()
                    if IsValid(self) then
                        self:StartCooldown()
                    end
                end)
            end
        end)
    end

    -- Сетевые сообщения
    util.AddNetworkString("BloodAltarOpenMenu")
    util.AddNetworkString("BloodAltarChooseBlessing")

    net.Receive("BloodAltarChooseBlessing", function(len, ply)
        local altar = net.ReadEntity()
        local blessingID = net.ReadString()
        
        if IsValid(altar) and altar:GetClass() == "ix_bloodaltar" then
            local availableBlessings = altar:GetAvailableBlessings(ply)
            
            for _, blessing in ipairs(availableBlessings) do
                if blessing.id == blessingID and altar:HasSacrificeItems(ply, blessing.data.cost) then
                    altar:PerformSacrifice(ply, blessing)
                    return
                end
            end
            
            ply:Notify("Невозможно принести эту жертву!")
        end
    end)
end

if CLIENT then
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
        
        -- 🔧 ИСПРАВЛЕННЫЕ ПАРТИКЛЫ: Проверка доступности системы частиц
        if self.statusInitialized and self:GetStatus() ~= "Idle" then
            if not self.nextParticle or CurTime() > self.nextParticle then
                self.nextParticle = CurTime() + 2.0  -- Увеличен интервал
                
                -- Проверяем доступность системы частиц
                if not ParticleEffectNames or table.Count(ParticleEffectNames) >= 500 then
                    return  -- Не создавать частицы если система переполнена
                end
                
                local pos = self:GetPos() + Vector(math.Rand(-20,20), math.Rand(-20,20), 40)
                
                -- 🔧 Безопасное создание частиц
                if ParticleEffectNames and ParticleEffectNames["blood_impact"] then
                    local effect = EffectData()
                    effect:SetOrigin(pos)
                    effect:SetColor(255)
                    effect:SetScale(1)
                    util.Effect("blood_impact", effect)
                else
                    -- Альтернатива: декали крови
                    util.Decal("Blood", pos, pos + Vector(0, 0, 10))
                end
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
        
        local status = self:GetStatus() or "Idle"
        local localizedStatus = altarStatusText[status] or status
        
        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)
        
        local pos = self:GetPos() + self:GetUp() * 70 + self:GetForward() * 5
        
        cam.Start3D2D(pos, ang, 0.1)
            -- Фон
            draw.RoundedBox(8, -60, -25, 120, 40, Color(0, 0, 0, 230))
            
            -- Рамка (кровавая)
            surface.SetDrawColor(150, 0, 0, 255)
            surface.DrawOutlinedRect(-60, -25, 120, 40, 2)
            
            -- Текст статуса
            draw.SimpleText(localizedStatus, "DermaDefaultBold", 0, -8, 
                Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            -- Cooldown
            if status == "Cooldown" then
                local timeLeft = math.ceil(self:GetCooldown() - CurTime())
                draw.SimpleText("Осталось: " .. timeLeft .. "с", "DermaDefault", 0, 8, 
                    Color(200, 150, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            
            -- Общее количество благословений
            if self:GetTotalBlessings() > 0 then
                draw.SimpleText("🩸 " .. self:GetTotalBlessings(), "DermaDefault", 50, -20, 
                    Color(255, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        cam.End3D2D()
    end

    -- Меню выбора благословения
    net.Receive("BloodAltarOpenMenu", function()
        local count = net.ReadUInt(4)
        local blessings = {}
        
        for i = 1, count do
            table.insert(blessings, {
                id = net.ReadString(),
                name = net.ReadString(),
                description = net.ReadString(),
                level = net.ReadUInt(2)
            })
        end
        
        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 300)
        frame:SetTitle("Кровавый Алтарь - Выбор благословения")
        frame:Center()
        frame:MakePopup()
        
        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        
        for _, blessing in ipairs(blessings) do
            local btn = scroll:Add("DButton")
            btn:Dock(TOP)
            btn:DockMargin(5, 5, 5, 0)
            btn:SetTall(60)
            btn:SetText("")
            
            btn.Paint = function(self, w, h)
                surface.SetDrawColor(50, 0, 0, 200)
                surface.DrawRect(0, 0, w, h)
                
                surface.SetDrawColor(150, 0, 0, 255)
                surface.DrawOutlinedRect(0, 0, w, h)
                
                draw.SimpleText(blessing.name, "DermaDefaultBold", 10, 10, Color(255, 100, 100))
                draw.SimpleText(blessing.description, "DermaDefault", 10, 30, Color(200, 150, 150))
                draw.SimpleText("Уровень " .. blessing.level, "DermaDefault", w - 10, 10, Color(255, 100, 100), TEXT_ALIGN_RIGHT)
            end
            
            btn.DoClick = function()
                frame:Close()
                net.Start("BloodAltarChooseBlessing")
                    net.WriteEntity(LocalPlayer():GetEyeTrace().Entity)
                    net.WriteString(blessing.id)
                net.SendToServer()
            end
        end
    end)

    -- Tooltip
    hook.Add("PopulateEntityInfo", "ixBloodAltarInfo", function(tooltip, ent)
        if not IsValid(ent) then return end
        if not isfunction(ent.GetClass) then return end
        if ent:GetClass() ~= "ix_bloodaltar" then return end
        
        local status = ent:GetStatus() or "Idle"
        
        -- Заголовок
        local name = tooltip:AddRow("name")
        name:SetText("Кровавый Алтарь")
        name:SetBackgroundColor(Color(50, 0, 0))
        name:SetImportant()
        name:SizeToContents()
        
        -- Статус
        local statusRow = tooltip:AddRow("status")
        statusRow:SetText("Статус: " .. (altarStatusText[status] or status))
        statusRow:SetBackgroundColor(Color(30, 0, 0))
        statusRow:SizeToContents()
        
        -- Описание
        local desc = tooltip:AddRow("description")
        desc:SetText("Принесите человеческие части в жертву для получения вечных усилений")
        desc:SetBackgroundColor(Color(40, 0, 0))
        desc:SizeToContents()
        
        -- Cooldown
        if status == "Cooldown" then
            local timeLeft = math.ceil(ent:GetCooldown() - CurTime())
            local cdRow = tooltip:AddRow("cooldown")
            cdRow:SetText("Перезарядка: " .. timeLeft .. " секунд")
            cdRow:SetBackgroundColor(Color(60, 0, 0))
            cdRow:SizeToContents()
        end
    end)
end