ITEM.name = "Водка"
ITEM.model = Model("models/props_junk/garbage_glassbottle001a.mdl")
ITEM.width = 1
ITEM.height = 1
ITEM.description = "Будьте осторожны, ваш ручной коммунист может захотеть немного. Крепкий напиток для настоящих товарищей."
ITEM.category = "Варка"
ITEM.iconCam = {
    pos = Vector(509.64, 427.61, 310.24),
    ang = Angle(25, 220, 0),
    fov = 1.5
}
ITEM.exRender = true

-- Функция использования предмета
ITEM.functions.Consume = {
    name = "Выпить",
    OnRun = function(item)
        local client = item.player
        if not client:Alive() then return false end
        
        local steamID = client:SteamID()
        local timerName = "vodka_effects_" .. steamID
        
        -- Удаляем старый таймер если есть
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
        
        -- Случайный эффект водки (1 - мороз, 2 - жар, 3 - коммунистическая бодрость)
        local randomEffect = math.random(1, 3)
        client:SetNetVar("vodkaEffectType", randomEffect)
        
        -- Эффекты на 35 секунд
        timer.Create(timerName, 35, 1, function()
            if IsValid(client) and client:SteamID() == steamID then
                client:SetNetVar("hasVodkaEffect", false)
                client:SetNetVar("vodkaEffectType", 0)
                client:SetWalkSpeed(ix.config.Get("walkSpeed"))
                client:SetRunSpeed(ix.config.Get("runSpeed"))
            end
        end)
        
        -- Устанавливаем эффект
        client:SetNetVar("hasVodkaEffect", true)
        client:SetNetVar("vodkaEffectStart", CurTime())
        
        -- Применяем мгновенный эффект в зависимости от типа
        if randomEffect == 1 then
            -- Эффект мороза (легкое лечение + замедление)
            local heal = math.random(5, 8)
            client:SetHealth(math.min(client:Health() + heal, client:GetMaxHealth()))
            client:SetWalkSpeed(ix.config.Get("walkSpeed") * 0.9)
            client:SetRunSpeed(ix.config.Get("runSpeed") * 0.9)
            client:Notify("Вы выпили водку! Чувствуете морозную свежесть! (+" .. heal .. " HP, скорость -10%)")
            
        elseif randomEffect == 2 then
            -- Эффект жара (урон + ускорение)
            local damage = math.random(4, 7)
            client:TakeDamage(damage, client, client)
            client:SetWalkSpeed(ix.config.Get("walkSpeed") * 1.15)
            client:SetRunSpeed(ix.config.Get("runSpeed") * 1.2)
            client:Notify("Вы выпили водку! Горит внутри! (-" .. damage .. " HP, скорость +15%)")
            
        elseif randomEffect == 3 then
            -- Коммунистическая бодрость (баланс)
            local balance = math.random(3, 6)
            client:SetHealth(math.min(client:Health() + balance, client:GetMaxHealth()))
            client:SetWalkSpeed(ix.config.Get("walkSpeed") * 1.4)
            client:SetRunSpeed(ix.config.Get("runSpeed") * 1.6)
            client:Notify("За Родину! За Сталина! Чувствуете бодрость духа! (+" .. balance .. " HP, скорость +40%)")
        end
        
        -- Звук употребления
        client:EmitSound("npc/barnacle/barnacle_gulp" .. math.random(1,2) .. ".wav", 80, 95, 0.6)
        client:EmitSound("ambient/voices/cough" .. math.random(1,2) .. ".wav", 65, 105, 0.4)
        
        -- Случайный патриотический возглас
        if math.random(1, 3) == 1 then
            timer.Simple(1, function()
                if IsValid(client) then
                    client:EmitSound("ambient/voices/playground_memory" .. math.random(1,4) .. ".wav", 60, 100, 0.3)
                end
            end)
        end
        
        return true
    end
}

-- Хук для удаления эффекта при смерти
hook.Add("PlayerDeath", "RemoveVodkaEffectOnDeath", function(client)
    if client:GetNetVar("hasVodkaEffect", false) then
        client:SetNetVar("hasVodkaEffect", false)
        client:SetNetVar("vodkaEffectType", 0)
        client:SetWalkSpeed(ix.config.Get("walkSpeed"))
        client:SetRunSpeed(ix.config.Get("runSpeed"))
        
        -- Удаляем таймер
        local timerName = "vodka_effects_" .. client:SteamID()
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end
end)

-- Хук для удаления эффекта при отключении игрока
hook.Add("PlayerDisconnected", "RemoveVodkaEffectOnDisconnect", function(client)
    local timerName = "vodka_effects_" .. client:SteamID()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
end)

-- Хук для применения постоянных эффектов
hook.Add("Think", "VodkaEffectsHandler", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasVodkaEffect", false) then
            local effectType = client:GetNetVar("vodkaEffectType", 0)
            
            -- Легкое дрожание камеры для всех эффектов
            if math.random(1, 100) > 85 then
                local angles = client:EyeAngles()
                angles.p = angles.p + math.Rand(-0.4, 0.4)
                angles.y = angles.y + math.Rand(-0.4, 0.4)
                client:SetEyeAngles(angles)
            end
            
            -- Специфические эффекты для каждого типа
            if effectType == 1 then
                -- Мороз: периодические частицы холода
                if math.random(1, 100) > 95 then
                    local effect = EffectData()
                    effect:SetOrigin(client:GetPos() + Vector(0, 0, 50))
                    effect:SetMagnitude(1)
                    effect:SetScale(1)
                    util.Effect("GlassImpact", effect, true, true)
                end
                
            elseif effectType == 2 then
                -- Жар: случайные толчки
                if math.random(1, 100) > 92 then
                    client:SetVelocity(Vector(math.Rand(-15, 15), math.Rand(-15, 15), 0))
                end
            end
            
        elseif not client:Alive() and client:GetNetVar("hasVodkaEffect", false) then
            -- Убираем эффект если игрок умер
            client:SetNetVar("hasVodkaEffect", false)
            client:SetNetVar("vodkaEffectType", 0)
        end
    end
end)

-- Хук для визуальных эффектов
hook.Add("RenderScreenspaceEffects", "VodkaVisualEffects", function()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() or not client:GetNetVar("hasVodkaEffect", false) then return end
    
    local effectType = client:GetNetVar("vodkaEffectType", 0)
    
    -- Легкое размытие движения
    DrawMotionBlur(0.08, 0.25, 0.008)
    
    -- Цветовые эффекты в зависимости от типа
    if effectType == 1 then
        -- Голубоватый оттенок для мороза
        DrawColorModify({
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0.03,
            ["$pp_colour_addb"] = 0.06,
            ["$pp_colour_brightness"] = 0.01,
            ["$pp_colour_contrast"] = 1.04,
            ["$pp_colour_colour"] = 0.97,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
        
    elseif effectType == 2 then
        -- Красноватый оттенок для жара
        DrawColorModify({
            ["$pp_colour_addr"] = 0.04,
            ["$pp_colour_addg"] = 0.01,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.02,
            ["$pp_colour_contrast"] = 1.06,
            ["$pp_colour_colour"] = 1.05,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
        
    elseif effectType == 3 then
        -- Золотистый оттенок для бодрости
        DrawColorModify({
            ["$pp_colour_addr"] = 0.03,
            ["$pp_colour_addg"] = 0.03,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.03,
            ["$pp_colour_contrast"] = 1.03,
            ["$pp_colour_colour"] = 1.08,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    end
end)

-- Хук для случайных патриотических сообщений
hook.Add("Think", "VodkaPatrioticMessages", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasVodkaEffect", false) and client:GetNetVar("vodkaEffectType", 0) == 3 then
            if math.random(1, 1500) > 1498 then
                local messages = {
                    "За СССР!",
                    "Вперед, товарищи!",
                    "За родину!",
                    "Слава партии!",
                    "Коммунизм победит!"
                }
                ix.chat.Send(client, "ic", table.Random(messages))
            end
        end
    end
end)