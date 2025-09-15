ITEM.name = "Мясной крэк"
ITEM.model = "models/jellik/krokodil.mdl"
ITEM.description = "Продукт красного оттенка, что - то в нем не то..."
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Наркотики";

ITEM.functions.Use = {
    name = "Употребить",
    icon = "icon16/lightning_red.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        
        -- Проверяем, не активен ли уже эффект
        if client:GetNetVar("redphantomActive", false) then
            client:Notify("Эффект Красного Фантома уже активен! Дождитесь окончания.")
            return false
        end
        
        -- Добавляем эффекты
        item:ApplyRedPhantomEffects(client)
        
        -- Звук употребления
        client:EmitSound("ambient/energy/zap9.wav")
        
        -- Уведомление
        client:Notify("Вы употребили мясной крэк! Сверхспособности на 60 секунд!")
        
        return true
    end
}

-- Эффекты Красного Фантома
function ITEM:ApplyRedPhantomEffects(client)
    if not IsValid(client) then return end
    
    -- Уникальный ID для эффекта
    local effectID = "redphantom_effect_" .. client:SteamID()
    
    -- Проверяем, не активен ли уже эффект
    if timer.Exists(effectID) then
        client:Notify("Эффект Красного Фантома уже активен!")
        return
    end
    
    -- Длительность эффекта (60 секунд)
    local duration = 60
    
    -- Сохраняем оригинальные значения
    local oldRunSpeed = client:GetRunSpeed()
    local oldWalkSpeed = client:GetWalkSpeed()
    local oldJumpPower = client:GetJumpPower()
    
    -- Помечаем эффект как активный
    client:SetNetVar("redphantomActive", true)
    client:SetNetVar("redphantomOldRunSpeed", oldRunSpeed)
    client:SetNetVar("redphantomOldWalkSpeed", oldWalkSpeed)
    client:SetNetVar("redphantomOldJumpPower", oldJumpPower)
    
    -- Устанавливаем УЛУЧШЕННЫЕ характеристики
    client:SetRunSpeed(oldRunSpeed * 1.8) -- +80% скорости бега
    client:SetWalkSpeed(oldWalkSpeed * 1.6) -- +60% скорости ходьбы
    client:SetJumpPower(oldJumpPower * 1.8) -- +80% высоты прыжка
    
    -- Регенерация здоровья
    client:SetNetVar("redphantomHealthRegen", true)
    
    -- Усиление урона
    client:SetNetVar("redphantomDamageBoost", true)
    
    -- Эффект на клиенте
    if SERVER then
        net.Start("RedPhantomEffectStart")
            net.WriteFloat(duration)
        net.Send(client)
    end
    
    -- Таймер для окончания эффекта
    timer.Create(effectID, duration, 1, function()
        if IsValid(client) then
            self:RemoveRedPhantomEffects(client)
        end
    end)
    
    -- ПОЛЕЗНЫЕ побочные эффекты во время действия
    for i = 1, 3 do
        timer.Simple(math.random(10, 50), function()
            if IsValid(client) and timer.Exists(effectID) then
                -- Случайный полезный эффект
                local bonusType = math.random(1, 3) -- Уменьшено с 5 до 3 вариантов
                
                if bonusType == 1 then
                    -- Всплеск сверхскорости
                    client:SetRunSpeed(oldRunSpeed * 2.2)
                    client:EmitSound("ambient/energy/spark" .. math.random(1,6) .. ".wav")
                    client:Notify("КРАСНАЯ МОЛНИЯ! +120% скорости на 7 секунд!")
                    
                    timer.Simple(7, function()
                        if IsValid(client) and timer.Exists(effectID) then
                            client:SetRunSpeed(oldRunSpeed * 1.8)
                        end
                    end)
                    
                elseif bonusType == 2 then
                    -- Временная неуязвимость
                    client:GodEnable()
                    client:SetColor(Color(255, 50, 50, 255))
                    client:Notify("КРАСНЫЙ ЩИТ! Неуязвимость на 4 секунды!")
                    
                    timer.Simple(4, function()
                        if IsValid(client) and timer.Exists(effectID) then
                            client:GodDisable()
                            client:SetColor(Color(255, 255, 255, 255))
                        end
                    end)
                    
                elseif bonusType == 3 then
                    -- Увеличение урона
                    client:SetNetVar("redphantomDamageBoost", true)
                    client:ScreenFade(SCREENFADE.IN, Color(255, 0, 0, 50), 1, 0)
                    client:Notify("КРАСНАЯ ЯРОСТЬ! +50% урона на 10 секунд!")
                    
                    timer.Simple(10, function()
                        if IsValid(client) and timer.Exists(effectID) then
                            client:SetNetVar("redphantomDamageBoost", false)
                        end
                    end)
                end
            end
        end)
    end
    
    -- Таймер регенерации здоровья
    timer.Create(effectID .. "_regen", 3, 20, function()
        if IsValid(client) and client:Alive() and timer.Exists(effectID) then
            local newHealth = math.min(client:GetMaxHealth(), client:Health() + 5)
            client:SetHealth(newHealth)
            
            -- Эффект частиц при лечении
            if math.random(1, 3) == 1 then
                local effect = EffectData()
                effect:SetOrigin(client:GetPos() + Vector(0, 0, 50))
                effect:SetMagnitude(1)
                effect:SetScale(1)
                effect:SetColor(255)
                util.Effect("BloodImpact", effect)
            end
        end
    end)
end

-- Функция сброса эффектов
function ITEM:RemoveRedPhantomEffects(client)
    if not IsValid(client) then return end
    
    local effectID = "redphantom_effect_" .. client:SteamID()
    
    -- Возвращаем оригинальные характеристики
    local oldRunSpeed = client:GetNetVar("redphantomOldRunSpeed", ix.config.Get("runSpeed", 300))
    local oldWalkSpeed = client:GetNetVar("redphantomOldWalkSpeed", ix.config.Get("walkSpeed", 150))
    local oldJumpPower = client:GetNetVar("redphantomOldJumpPower", ix.config.Get("jumpPower", 200))
    
    client:SetRunSpeed(oldRunSpeed)
    client:SetWalkSpeed(oldWalkSpeed)
    client:SetJumpPower(oldJumpPower)
    
    -- Снимаем все эффекты
    client:SetColor(Color(255, 255, 255, 255))
    client:SetMaterial("")
    client:GodDisable()
    
    -- Снимаем метки
    client:SetNetVar("redphantomActive", false)
    client:SetNetVar("redphantomHealthRegen", false)
    client:SetNetVar("redphantomDamageBoost", false)
    
    -- Отправляем клиенту о завершении эффекта
    if SERVER then
        net.Start("RedPhantomEffectEnd")
        net.Send(client)
    end
    
    -- Мягкий отходняк
    client:SetHealth(math.max(20, client:Health() - 10))
    client:ScreenFade(SCREENFADE.IN, Color(100, 0, 0, 100), 3, 0)
    client:Notify("Эффект Красного Фантома прошел. Легкая усталость.")
    
    -- Удаляем все таймеры
    if timer.Exists(effectID) then
        timer.Remove(effectID)
    end
    
    if timer.Exists(effectID .. "_regen") then
        timer.Remove(effectID .. "_regen")
    end
    
    for i = 1, 10 do
        if timer.Exists(effectID .. "_bonus_" .. i) then
            timer.Remove(effectID .. "_bonus_" .. i)
        end
    end
end

-- Хук для усиления урона
if SERVER then
    hook.Add("EntityTakeDamage", "RedPhantomDamageBoost", function(target, dmg)
        local attacker = dmg:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() and attacker:GetNetVar("redphantomDamageBoost", false) then
            dmg:SetDamage(dmg:GetDamage() * 1.5) -- +50% урона
        end
    end)
end

-- Автоматическое использование при нажатии на предмет
function ITEM:OnUse(client)
    self.functions.Use.OnRun(self)
    return true
end

if SERVER then
    util.AddNetworkString("RedPhantomEffectStart")
    util.AddNetworkString("RedPhantomEffectEnd")
    
    -- Универсальная функция для сброса эффектов
    local function ResetRedPhantomEffects(client)
        if not IsValid(client) then return end
        
        local effectID = "redphantom_effect_" .. client:SteamID()
        
        if client:GetNetVar("redphantomActive", false) then
            local item = ix.item.list["red_phantom"]
            if item then
                item:RemoveRedPhantomEffects(client)
            else
                -- Ручной сброс
                local oldRunSpeed = client:GetNetVar("redphantomOldRunSpeed", ix.config.Get("runSpeed", 300))
                local oldWalkSpeed = client:GetNetVar("redphantomOldWalkSpeed", ix.config.Get("walkSpeed", 150))
                local oldJumpPower = client:GetNetVar("redphantomOldJumpPower", ix.config.Get("jumpPower", 200))
                
                client:SetRunSpeed(oldRunSpeed)
                client:SetWalkSpeed(oldWalkSpeed)
                client:SetJumpPower(oldJumpPower)
                client:SetColor(Color(255, 255, 255, 255))
                client:SetMaterial("")
                client:GodDisable()
                
                client:SetNetVar("redphantomActive", false)
                client:SetNetVar("redphantomHealthRegen", false)
                client:SetNetVar("redphantomDamageBoost", false)
                
                net.Start("RedPhantomEffectEnd")
                net.Send(client)
            end
        end
        
        -- Удаляем таймеры
        if timer.Exists(effectID) then timer.Remove(effectID) end
        if timer.Exists(effectID .. "_regen") then timer.Remove(effectID .. "_regen") end
        
        for i = 1, 10 do
            local bonusTimerID = effectID .. "_bonus_" .. i
            if timer.Exists(bonusTimerID) then timer.Remove(bonusTimerID) end
        end
    end
    
    -- Хуки для сброса эффектов
    hook.Add("PlayerDeath", "RedPhantomDeathReset", ResetRedPhantomEffects)
    hook.Add("PlayerSpawn", "RedPhantomSpawnReset", ResetRedPhantomEffects)
    hook.Add("PlayerDisconnected", "RedPhantomDisconnectReset", ResetRedPhantomEffects)
    hook.Add("PlayerLoadedCharacter", "RedPhantomCharReset", ResetRedPhantomEffects)
    
else
    -- КЛИЕНТСКИЕ ЭФФЕКТЫ (КРАСНЫЕ)
    local redPhantomEffects = {}
    
    net.Receive("RedPhantomEffectStart", function()
        local duration = net.ReadFloat()
        
        redPhantomEffects.startTime = CurTime()
        redPhantomEffects.duration = duration
        
        -- КРАСНЫЕ визуальные эффекты
        hook.Add("RenderScreenspaceEffects", "RedPhantomVisualEffects", function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            
            local timeLeft = (redPhantomEffects.startTime + redPhantomEffects.duration) - CurTime()
            if timeLeft <= 0 then return end
            
            -- КРАСНЫЙ цветовой эффект
            DrawColorModify({
                ["$pp_colour_addr"] = 0.3,
                ["$pp_colour_addg"] = 0.1,
                ["$pp_colour_addb"] = 0.1,
                ["$pp_colour_brightness"] = 0.08,
                ["$pp_colour_contrast"] = 1.3,
                ["$pp_colour_colour"] = 1.2,
                ["$pp_colour_mulr"] = 0.4,
                ["$pp_colour_mulg"] = 0.1,
                ["$pp_colour_mulb"] = 0.1
            })
            
            -- Motion blur для скорости
            if ply:GetVelocity():Length() > 100 then
                DrawMotionBlur(0.2, 0.8, 0.01)
            end
            
            -- Пульсирующие красные полоски
            local pulse = math.sin(CurTime() * 3) * 0.3 + 0.4
            surface.SetDrawColor(255, 0, 0, 30 * pulse)
            surface.DrawRect(0, 0, ScrW(), 4)
            surface.DrawRect(0, ScrH() - 4, ScrW(), 4)
            surface.DrawRect(0, 0, 4, ScrH())
            surface.DrawRect(ScrW() - 4, 0, 4, ScrH())
        end)
        
        -- Звуковой эффект
        surface.PlaySound("ambient/energy/zap8.wav")
    end)
    
    net.Receive("RedPhantomEffectEnd", function()
        hook.Remove("RenderScreenspaceEffects", "RedPhantomVisualEffects")
        redPhantomEffects = {}
        
        LocalPlayer():ScreenFade(SCREENFADE.IN, Color(100, 0, 0, 80), 3, 0)
        surface.PlaySound("ambient/energy/zap3.wav")
    end)
    
    -- HUD с красной темой
    hook.Add("HUDPaint", "RedPhantomEffectHUD", function()
        if not redPhantomEffects.startTime then return end
        
        local timeLeft = (redPhantomEffects.startTime + redPhantomEffects.duration) - CurTime()
        if timeLeft <= 0 then
            hook.Remove("HUDPaint", "RedPhantomEffectHUD")
            return
        end
        
        -- Полоска длительности
        local width = ScrW() * 0.3
        local height = 10
        local x = (ScrW() - width) / 2
        local y = ScrH() * 0.03
        
        -- Фон
        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(x, y, width, height)
        
        -- Заполнение (красное)
        local progress = timeLeft / redPhantomEffects.duration
        surface.SetDrawColor(220, 0, 0, 200)
        surface.DrawRect(x, y, width * progress, height)
        
        -- Текст с пульсацией
        local alpha = math.abs(math.sin(CurTime() * 2) * 255)
        draw.SimpleText("МЯСНОЙ КРЭК: " .. math.ceil(timeLeft) .. "с", "DermaDefaultBold", 
            ScrW() / 2, y + height + 5, Color(255, 50, 50, alpha), TEXT_ALIGN_CENTER)
            
        -- Индикаторы эффектов
        draw.SimpleText("⚡ СКОРОСТЬ", "DermaDefault", 20, ScrH() - 80, Color(255, 100, 100), TEXT_ALIGN_LEFT)
        draw.SimpleText("❤ РЕГЕНЕРАЦИЯ", "DermaDefault", 20, ScrH() - 60, Color(255, 100, 100), TEXT_ALIGN_LEFT)
        draw.SimpleText("⚔ УСИЛЕНИЕ УРОНА", "DermaDefault", 20, ScrH() - 40, Color(255, 100, 100), TEXT_ALIGN_LEFT)
    end)
end

function ITEM:OnRemove()
    local client = self:GetOwner()
    if IsValid(client) then
        self:RemoveRedPhantomEffects(client)
    end
end