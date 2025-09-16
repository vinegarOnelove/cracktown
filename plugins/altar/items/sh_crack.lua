ITEM.name = "Крэк"
ITEM.description = "Сильнодействующий наркотик, вызывающий экстремальную эйфорию и невероятную скорость."
ITEM.model = "models/jellik/cocaine.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Наркотики"
ITEM.price = 500
ITEM.noBusiness = true
ITEM.exRender = true
ITEM.iconCam = {
	pos = Vector(253.12, 1.25, 418.01),
	ang = Angle(58.88, 180.28, 0),
	fov = 0.35
}

ITEM.functions.Use = {
    name = "Употребить",
    icon = "icon16/lightning.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        
        -- Проверяем, не активен ли уже эффект
        if client:GetNetVar("crackActive", false) then
            client:Notify("Эффект крэка уже активен! Дождитесь окончания.")
            return false
        end
        
        -- Добавляем эффекты крэка
        item:ApplyCrackEffects(client)
        
        -- Звук употребления
        client:EmitSound("ambient/energy/zap9.wav")
        
        -- Уведомление
        client:Notify("Вы употребили крэк! Сверхскорость на 45 секунд!")
        
        return true
    end
}

-- Эффекты крэка
function ITEM:ApplyCrackEffects(client)
    if not IsValid(client) then return end
    
    -- Уникальный ID для эффекта
    local effectID = "crack_effect_" .. client:SteamID()
    
    -- Проверяем, не активен ли уже эффект
    if timer.Exists(effectID) then
        client:Notify("Эффект крэка уже активен!")
        return
    end
    
    -- Длительность эффекта (45 секунд - короче но мощнее)
    local duration = 45
    
    -- Сохраняем оригинальные скорости
    local oldRunSpeed = client:GetRunSpeed()
    local oldWalkSpeed = client:GetWalkSpeed()
    local oldJumpPower = client:GetJumpPower()
    
    -- Помечаем эффект как активный
    client:SetNetVar("crackActive", true)
    client:SetNetVar("crackOldRunSpeed", oldRunSpeed)
    client:SetNetVar("crackOldWalkSpeed", oldWalkSpeed)
    client:SetNetVar("crackOldJumpPower", oldJumpPower)
    
    -- Устанавливаем СУПЕР скорости
    client:SetRunSpeed(oldRunSpeed * 2.0) -- +100% скорости бега
    client:SetWalkSpeed(oldWalkSpeed * 1.8) -- +80% скорости ходьбы
    client:SetJumpPower(oldJumpPower * 1.5) -- +50% высоты прыжка
    
    -- Эффект на клиенте
    if SERVER then
        net.Start("CrackEffectStart")
            net.WriteFloat(duration)
        net.Send(client)
    end
    
    -- Таймер для окончания эффекта
    timer.Create(effectID, duration, 1, function()
        if IsValid(client) then
            self:RemoveCrackEffects(client)
        end
    end)
    
    -- Случайные побочные эффекты во время действия
    for i = 1, 3 do
        timer.Simple(math.random(5, 35), function()
            if IsValid(client) and timer.Exists(effectID) then
                -- Случайный побочный эффект
                local effectType = math.random(1, 3)
                
                if effectType == 1 then
                    -- Кратковременное замедление
                    client:SetRunSpeed(client:GetRunSpeed() * 0.5)
                    client:Notify("Резкий спазм! Замедление на 3 секунды!")
                    
                    timer.Simple(3, function()
                        if IsValid(client) and timer.Exists(effectID) then
                            client:SetRunSpeed(oldRunSpeed * 2.0)
                        end
                    end)
                    
                elseif effectType == 2 then
                    -- Дезориентация
                    client:ViewPunch(Angle(math.random(-180, 180), math.random(-180, 180), math.random(-180, 180)))
                    client:SetDSP(34)
                    client:Notify("Головокружение! Теряю ориентацию!")
                    
                elseif effectType == 3 then
                    -- Всплеск сверхскорости
                    client:SetRunSpeed(oldRunSpeed * 2.2) -- +120%
                    client:EmitSound("ambient/energy/spark" .. math.random(1,6) .. ".wav")
                    client:Notify("ВСПЛЕСК СКОРОСТИ! +120%!")
                    
                    timer.Simple(4, function()
                        if IsValid(client) and timer.Exists(effectID) then
                            client:SetRunSpeed(oldRunSpeed * 2.0)
                        end
                    end)
                end
            end
        end)
    end
end

-- Функция сброса эффектов крэка
function ITEM:RemoveCrackEffects(client)
    if not IsValid(client) then return end
    
    local effectID = "crack_effect_" .. client:SteamID()
    
    -- Возвращаем оригинальные скорости
    local oldRunSpeed = client:GetNetVar("crackOldRunSpeed", ix.config.Get("runSpeed", 300))
    local oldWalkSpeed = client:GetNetVar("crackOldWalkSpeed", ix.config.Get("walkSpeed", 150))
    local oldJumpPower = client:GetNetVar("crackOldJumpPower", ix.config.Get("jumpPower", 200))
    
    client:SetRunSpeed(oldRunSpeed)
    client:SetWalkSpeed(oldWalkSpeed)
    client:SetJumpPower(oldJumpPower)
    
    -- Снимаем метку активности
    client:SetNetVar("crackActive", false)
    
    -- Отправляем клиенту о завершении эффекта
    if SERVER then
        net.Start("CrackEffectEnd")
        net.Send(client)
    end
    
    -- Сильный эффект отходняка
    client:SetHealth(math.max(5, client:Health() - 20))
    client:SetDSP(36) -- Сильное оглушение
    client:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 150), 2, 0)
    client:Notify("Эффект крэка прошел. Вы чувствуете полное истощение!")
    
    -- Удаляем таймер
    if timer.Exists(effectID) then
        timer.Remove(effectID)
    end
    
    -- Удаляем все побочные таймеры
    for i = 1, 10 do
        if timer.Exists(effectID .. "_side_" .. i) then
            timer.Remove(effectID .. "_side_" .. i)
        end
    end
end

-- Автоматическое использование при нажатии на предмет
function ITEM:OnUse(client)
    self.functions.Use.OnRun(self)
    return true
end

if SERVER then
    util.AddNetworkString("CrackEffectStart")
    util.AddNetworkString("CrackEffectEnd")
    
    -- УНИВЕРСАЛЬНАЯ ФУНКЦИЯ ДЛЯ СБРОСА ЭФФЕКТОВ
    local function ResetCrackEffects(client)
        if not IsValid(client) then return end
        
        local effectID = "crack_effect_" .. client:SteamID()
        
        -- Если эффект активен, сбрасываем его
        if client:GetNetVar("crackActive", false) then
            local item = ix.item.list["crack_cocaine"]
            if item then
                item:RemoveCrackEffects(client)
            else
                -- Если предмет не найден, сбрасываем вручную
                local oldRunSpeed = client:GetNetVar("crackOldRunSpeed", ix.config.Get("runSpeed", 300))
                local oldWalkSpeed = client:GetNetVar("crackOldWalkSpeed", ix.config.Get("walkSpeed", 150))
                local oldJumpPower = client:GetNetVar("crackOldJumpPower", ix.config.Get("jumpPower", 200))
                
                client:SetRunSpeed(oldRunSpeed)
                client:SetWalkSpeed(oldWalkSpeed)
                client:SetJumpPower(oldJumpPower)
                client:SetNetVar("crackActive", false)
                
                -- Отправляем клиенту о завершении эффекта
                net.Start("CrackEffectEnd")
                net.Send(client)
            end
        end
        
        -- Удаляем все связанные таймеры
        if timer.Exists(effectID) then
            timer.Remove(effectID)
        end
        
        for i = 1, 10 do
            local sideTimerID = effectID .. "_side_" .. i
            if timer.Exists(sideTimerID) then
                timer.Remove(sideTimerID)
            end
        end
    end
    
    -- Хук для сброса эффектов при смерти
    hook.Add("PlayerDeath", "CrackEffectDeathReset", function(client)
        ResetCrackEffects(client)
    end)
    
    -- Хук для сброса эффектов при возрождении
    hook.Add("PlayerSpawn", "CrackEffectSpawnReset", function(client)
        ResetCrackEffects(client)
    end)
    
    -- Хук для сброса эффектов при дисконнекте
    hook.Add("PlayerDisconnected", "CrackEffectDisconnectReset", function(client)
        ResetCrackEffects(client)
    end)
    
    -- Хук для сброса эффектов при смене персонажа
    hook.Add("PlayerLoadedCharacter", "CrackEffectCharReset", function(client)
        ResetCrackEffects(client)
    end)
    
    -- Хук для сброса эффектов при изменении скорости извне
    hook.Add("PlayerSpeedChanged", "CrackEffectSpeedReset", function(client, newRunSpeed, newWalkSpeed)
        if client:GetNetVar("crackActive", false) then
            -- Если эффект активен и скорость изменена извне, сбрасываем эффект
            ResetCrackEffects(client)
            client:Notify("Эффект крэка прерван из-за изменения скорости!")
        end
    end)
else
    -- Клиентские эффекты
    local crackEffects = {}
    
    net.Receive("CrackEffectStart", function()
        local duration = net.ReadFloat()
        
        -- Визуальные эффекты
        crackEffects.startTime = CurTime()
        crackEffects.duration = duration
        
        -- Хук для рендера
        hook.Add("RenderScreenspaceEffects", "CrackVisualEffects", function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            
            local timeLeft = (crackEffects.startTime + crackEffects.duration) - CurTime()
            if timeLeft <= 0 then return end
            
            -- Умеренный цветовой эффект
            DrawColorModify({
                ["$pp_colour_addr"] = 0.1,
                ["$pp_colour_addg"] = 0.3,
                ["$pp_colour_addb"] = 0.1,
                ["$pp_colour_brightness"] = 0.07,
                ["$pp_colour_contrast"] = 1.4,
                ["$pp_colour_colour"] = 1.5,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0.4,
                ["$pp_colour_mulb"] = 0
            })
            
            -- Легкий motion blur
            if ply:GetVelocity():Length() > 150 then
                DrawMotionBlur(0.3, 0.6, 0.015)
            end
            
            -- Умеренное дрожание камеры
            if math.random(1, 100) <= 20 then
                ply:ViewPunch(Angle(
                    math.random(-1, 1),
                    math.random(-1, 1),
                    math.random(-1, 1)
                ))
            end
            
            -- Субтильные полоски по краям экрана
            local pulse = math.sin(CurTime() * 4) * 0.2 + 0.3
            surface.SetDrawColor(0, 200, 0, 20 * pulse)
            surface.DrawRect(0, 0, ScrW(), 3) -- Верх
            surface.DrawRect(0, ScrH() - 3, ScrW(), 3) -- Низ
        end)
        
        -- Звуковой эффект
        surface.PlaySound("ambient/energy/zap6.wav")
    end)
    
    net.Receive("CrackEffectEnd", function()
        -- Убираем эффекты
        hook.Remove("RenderScreenspaceEffects", "CrackVisualEffects")
        crackEffects = {}
        
        -- Эффект протрезвления
        LocalPlayer():ScreenFade(SCREENFADE.IN, Color(100, 100, 100, 100), 2, 0)
        surface.PlaySound("ambient/energy/zap1.wav")
    end)
    
    -- Хук для HUD
    hook.Add("HUDPaint", "CrackEffectHUD", function()
        if not crackEffects.startTime then return end
        
        local timeLeft = (crackEffects.startTime + crackEffects.duration) - CurTime()
        if timeLeft <= 0 then
            hook.Remove("HUDPaint", "CrackEffectHUD")
            return
        end
        
        -- Полоска длительности
        local width = ScrW() * 0.25
        local height = 8
        local x = (ScrW() - width) / 2
        local y = ScrH() * 0.03
        
        -- Фон
        surface.SetDrawColor(0, 0, 0, 150)
        surface.DrawRect(x, y, width, height)
        
        -- Заполнение
        local progress = timeLeft / crackEffects.duration
        surface.SetDrawColor(0, 220, 0, 180)
        surface.DrawRect(x, y, width * progress, height)
        
        -- Текст
        if math.sin(CurTime() * 2) > 0 then
            draw.SimpleText("Эффект крэка: " .. math.ceil(timeLeft) .. "с", "DermaDefaultBold", ScrW() / 2, y + height + 5, Color(0, 220, 0), TEXT_ALIGN_CENTER)
        end
    end)
end

function ITEM:OnRemove()
    local client = self:GetOwner()
    if IsValid(client) then
        self:RemoveCrackEffects(client)
    end
end