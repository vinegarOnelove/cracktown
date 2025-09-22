ITEM.name = "Косяк"
ITEM.description = "Ароматный косяк марихуаны, расслабляет и успокаивает."
ITEM.model = "models/props_zaza/zaza_avg.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Наркотики"
ITEM.price = 300
ITEM.noBusiness = true
ITEM.exRender = true
ITEM.iconCam = {
	pos = Vector(343.63, 283.64, 205.77),
	ang = Angle(25, 220, 0),
	fov = 3.55
}

ITEM.functions.Use = {
    name = "Курить",
    icon = "icon16/lightning.png",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        
        -- Проверяем, не активен ли уже эффект
        if client:GetNetVar("weedActive", false) then
            client:Notify("Эффект марихуаны уже активен! Дождитесь окончания.")
            return false
        end
        
        -- Добавляем эффекты марихуаны
        item:ApplyWeedEffects(client)
        
        -- Звук курения
        client:EmitSound("ambient/fire/mtov_flame2.wav")
        
        -- Эффект дыма
        if SERVER then
            timer.Simple(0.5, function()
                if IsValid(client) then
                    local effect = EffectData()
                    effect:SetOrigin(client:GetPos() + Vector(0, 0, 60))
                    effect:SetEntity(client)
                    util.Effect("cigarette_smoke", effect)
                end
            end)
        end
        
        -- Уведомление
        client:Notify("Вы покурили косяк! Расслабление на 3 минуты!")
        
        return true
    end
}

-- Эффекты марихуаны (легкие)
function ITEM:ApplyWeedEffects(client)
    if not IsValid(client) then return end
    
    -- Уникальный ID для эффекта
    local effectID = "weed_effect_" .. client:SteamID()
    
    -- Проверяем, не активен ли уже эффект
    if timer.Exists(effectID) then
        client:Notify("Эффект марихуаны уже активен!")
        return
    end
    
    -- Длительность эффекта (3 минуты)
    local duration = 180
    
    -- Сохраняем оригинальные скорости
    local oldRunSpeed = client:GetRunSpeed()
    local oldWalkSpeed = client:GetWalkSpeed()
    
    -- Помечаем эффект как активный
    client:SetNetVar("weedActive", true)
    client:SetNetVar("weedOldRunSpeed", oldRunSpeed)
    client:SetNetVar("weedOldWalkSpeed", oldWalkSpeed)
    
    -- Легкое увеличение скорости (не такое сильное как у крэка)
    client:SetRunSpeed(oldRunSpeed * 1.2) -- +20% скорости бега
    client:SetWalkSpeed(oldWalkSpeed * 1.1) -- +10% скорости ходьбы
    
    -- Эффект на клиенте
    if SERVER then
        net.Start("WeedEffectStart")
            net.WriteFloat(duration)
        net.Send(client)
    end
    
    -- Таймер для окончания эффекта
    timer.Create(effectID, duration, 1, function()
        if IsValid(client) then
            self:RemoveWeedEffects(client)
        end
    end)
    
    -- Случайные расслабляющие эффекты во время действия
    for i = 1, 2 do
        timer.Simple(math.random(30, 150), function()
            if IsValid(client) and timer.Exists(effectID) then
                -- Легкие позитивные эффекты
                client:SetHealth(math.min(client:GetMaxHealth(), client:Health() + 5))
                client:Notify("Чувствую расслабление... +5 HP")
                client:EmitSound("items/smallmedkit1.wav")
            end
        end)
    end
end

-- Функция сброса эффектов марихуаны
function ITEM:RemoveWeedEffects(client)
    if not IsValid(client) then return end
    
    local effectID = "weed_effect_" .. client:SteamID()
    
    -- Возвращаем оригинальные скорости
    local oldRunSpeed = client:GetNetVar("weedOldRunSpeed", ix.config.Get("runSpeed", 300))
    local oldWalkSpeed = client:GetNetVar("weedOldWalkSpeed", ix.config.Get("walkSpeed", 150))
    
    client:SetRunSpeed(oldRunSpeed)
    client:SetWalkSpeed(oldWalkSpeed)
    
    -- Снимаем метку активности
    client:SetNetVar("weedActive", false)
    
    -- Отправляем клиенту о завершении эффекта
    if SERVER then
        net.Start("WeedEffectEnd")
        net.Send(client)
    end
    
    -- Легкий эффект окончания
    client:Notify("Эффект марихуаны прошел. Вы чувствуете себя спокойно.")
    
    -- Удаляем таймер
    if timer.Exists(effectID) then
        timer.Remove(effectID)
    end
end

if SERVER then
    util.AddNetworkString("WeedEffectStart")
    util.AddNetworkString("WeedEffectEnd")
    
    -- Функция для сброса эффектов
    local function ResetWeedEffects(client)
        if not IsValid(client) then return end
        
        local effectID = "weed_effect_" .. client:SteamID()
        
        -- Если эффект активен, сбрасываем его
        if client:GetNetVar("weedActive", false) then
            local item = ix.item.list["weed_joint"]
            if item then
                item:RemoveWeedEffects(client)
            else
                -- Если предмет не найден, сбрасываем вручную
                local oldRunSpeed = client:GetNetVar("weedOldRunSpeed", ix.config.Get("runSpeed", 300))
                local oldWalkSpeed = client:GetNetVar("weedOldWalkSpeed", ix.config.Get("walkSpeed", 150))
                
                client:SetRunSpeed(oldRunSpeed)
                client:SetWalkSpeed(oldWalkSpeed)
                client:SetNetVar("weedActive", false)
                
                net.Start("WeedEffectEnd")
                net.Send(client)
            end
        end
        
        -- Удаляем таймер
        if timer.Exists(effectID) then
            timer.Remove(effectID)
        end
    end
    
    -- Хуки для сброса эффектов
    hook.Add("PlayerDeath", "WeedEffectDeathReset", ResetWeedEffects)
    hook.Add("PlayerSpawn", "WeedEffectSpawnReset", ResetWeedEffects)
    hook.Add("PlayerDisconnected", "WeedEffectDisconnectReset", ResetWeedEffects)
    hook.Add("PlayerLoadedCharacter", "WeedEffectCharReset", ResetWeedEffects)
    
else
    -- Клиентские эффекты марихуаны (легкие)
    local weedEffects = {}
    
    net.Receive("WeedEffectStart", function()
        local duration = net.ReadFloat()
        
        -- Визуальные эффекты
        weedEffects.startTime = CurTime()
        weedEffects.duration = duration
        
        -- Хук для рендера
        hook.Add("RenderScreenspaceEffects", "WeedVisualEffects", function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            
            local timeLeft = (weedEffects.startTime + weedEffects.duration) - CurTime()
            if timeLeft <= 0 then return end
            
            -- Легкий цветовой эффект (зеленоватый оттенок)
            DrawColorModify({
                ["$pp_colour_addr"] = 0.05,
                ["$pp_colour_addg"] = 0.1,
                ["$pp_colour_addb"] = 0.05,
                ["$pp_colour_brightness"] = 0.03,
                ["$pp_colour_contrast"] = 1.1,
                ["$pp_colour_colour"] = 1.2,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 0.2,
                ["$pp_colour_mulb"] = 0
            })
            
            -- Очень легкое дрожание камеры
            if math.random(1, 100) <= 10 then
                ply:ViewPunch(Angle(
                    math.random(-0.5, 0.5),
                    math.random(-0.5, 0.5),
                    math.random(-0.5, 0.5)
                ))
            end
        end)
        
        -- Звуковой эффект
        surface.PlaySound("ambient/levels/canals/windchime2.wav")
    end)
    
    net.Receive("WeedEffectEnd", function()
        -- Убираем эффекты
        hook.Remove("RenderScreenspaceEffects", "WeedVisualEffects")
        weedEffects = {}
        
        -- Легкий эффект окончания
        LocalPlayer():ScreenFade(SCREENFADE.IN, Color(100, 150, 100, 50), 1, 0)
        surface.PlaySound("ambient/levels/canals/windchime1.wav")
    end)
    
    -- Хук для HUD
    hook.Add("HUDPaint", "WeedEffectHUD", function()
        if not weedEffects.startTime then return end
        
        local timeLeft = (weedEffects.startTime + weedEffects.duration) - CurTime()
        if timeLeft <= 0 then
            hook.Remove("HUDPaint", "WeedEffectHUD")
            return
        end
        
        -- Полоска длительности
        local width = ScrW() * 0.2
        local height = 6
        local x = (ScrW() - width) / 2
        local y = ScrH() * 0.03
        
        -- Фон
        surface.SetDrawColor(0, 0, 0, 100)
        surface.DrawRect(x, y, width, height)
        
        -- Заполнение
        local progress = timeLeft / weedEffects.duration
        surface.SetDrawColor(100, 200, 100, 150)
        surface.DrawRect(x, y, width * progress, height)
        
        -- Текст
        draw.SimpleText("Марихуана: " .. math.ceil(timeLeft) .. "с", "DermaDefault", ScrW() / 2, y + height + 3, Color(100, 200, 100), TEXT_ALIGN_CENTER)
    end)
end

function ITEM:OnRemove()
    local client = self:GetOwner()
    if IsValid(client) then
        self:RemoveWeedEffects(client)
    end
end