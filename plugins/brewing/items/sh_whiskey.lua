ITEM.name = "Виски"
ITEM.model = Model("models/props_junk/garbage_glassbottle002a.mdl")
ITEM.width = 1
ITEM.height = 1
ITEM.description = "Немного хорошего виски, теперь ты можешь быть пьяным и одиноким. Напиток для изысканных гурманов."
ITEM.category = "Варка"
ITEM.iconCam = {
    pos = Vector(509.64, 427.61, 310.24),
    ang = Angle(25, 220, 0),
    fov = 1.67
}
ITEM.exRender = true

-- Функция использования предмета
ITEM.functions.Consume = {
    name = "Выпить",
    OnRun = function(item)
        local client = item.player
        if not client:Alive() then return false end
        
        local steamID = client:SteamID()
        local timerName = "whiskey_effects_" .. steamID
        
        -- Удаляем старый таймер если есть
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
        
        -- Случайный эффект виски (1 - элегантность, 2 - меланхолия, 3 - рефлексия)
        local randomEffect = math.random(1, 3)
        client:SetNetVar("whiskeyEffectType", randomEffect)
        
        -- Эффекты на 45 секунд
        timer.Create(timerName, 45, 1, function()
            if IsValid(client) and client:SteamID() == steamID then
                client:SetNetVar("hasWhiskeyEffect", false)
                client:SetNetVar("whiskeyEffectType", 0)
                client:SetWalkSpeed(ix.config.Get("walkSpeed"))
                client:SetRunSpeed(ix.config.Get("runSpeed"))
            end
        end)
        
        -- Устанавливаем эффект
        client:SetNetVar("hasWhiskeyEffect", true)
        client:SetNetVar("whiskeyEffectStart", CurTime())
        
        -- Применяем мгновенный эффект в зависимости от типа
        if randomEffect == 1 then
            -- Эффект элегантности (точность + скорость)
            client:SetWalkSpeed(ix.config.Get("walkSpeed") * 1.08)
            client:SetRunSpeed(ix.config.Get("runSpeed") * 1.12)
            client:Notify("Вы выпили виски! Чувствуете элегантность и точность движений! (Скорость +12%)")
            
        elseif randomEffect == 2 then
            -- Эффект меланхолии (лечение + замедление)
            local heal = math.random(1, 2)
            client:SetHealth(math.min(client:Health() + heal, client:GetMaxHealth()))
            client:SetWalkSpeed(ix.config.Get("walkSpeed") * 0.88)
            client:SetRunSpeed(ix.config.Get("runSpeed") * 0.85)
            client:Notify("Вы выпили виски... Накатывает меланхолия. (+" .. heal .. " HP, скорость -15%)")
            
        elseif randomEffect == 3 then
            -- Эффект рефлексии (баланс)
            local balance = math.random(3, 4)
            client:SetHealth(math.min(client:Health() + balance, client:GetMaxHealth()))
            client:SetWalkSpeed(ix.config.Get("walkSpeed") * 1.04)
            client:Notify("Вы выпили виски. Время для размышлений... (+" .. balance .. " HP, скорость +4%)")
        end
        
        -- Элегантный звук употребления
        client:EmitSound("npc/barnacle/barnacle_gulp" .. math.random(1,2) .. ".wav", 75, 100, 0.5)
        client:EmitSound("ambient/water/drip" .. math.random(1,4) .. ".wav", 60, 110, 0.3)
        
        -- Случайная философская фраза
        if math.random(1, 2) == 1 then
            timer.Simple(2, function()
                if IsValid(client) then
                    local phrases = {
                        "Одиночество - это роскошь...",
                        "Вкус напоминает о прошлом...",
                        "Искусство требует жертв...",
                        "Дорогой напиток для дорогих мыслей...",
                        "Время течет как виски по стеклу..."
                    }
                    ix.chat.Send(client, "ic", table.Random(messages))
                end
            end)
        end
        
        return true
    end
}

-- Хук для удаления эффекта при смерти
hook.Add("PlayerDeath", "RemoveWhiskeyEffectOnDeath", function(client)
    if client:GetNetVar("hasWhiskeyEffect", false) then
        client:SetNetVar("hasWhiskeyEffect", false)
        client:SetNetVar("whiskeyEffectType", 0)
        client:SetWalkSpeed(ix.config.Get("walkSpeed"))
        client:SetRunSpeed(ix.config.Get("runSpeed"))
        
        -- Удаляем таймер
        local timerName = "whiskey_effects_" .. client:SteamID()
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end
end)

-- Хук для удаления эффекта при отключении игрока
hook.Add("PlayerDisconnected", "RemoveWhiskeyEffectOnDisconnect", function(client)
    local timerName = "whiskey_effects_" .. client:SteamID()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
end)

-- Хук для применения постоянных эффектов
hook.Add("Think", "WhiskeyEffectsHandler", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasWhiskeyEffect", false) then
            local effectType = client:GetNetVar("whiskeyEffectType", 0)
            
            -- Очень легкое дрожание камеры (едва заметное)
            if math.random(1, 100) > 90 then
                local angles = client:EyeAngles()
                angles.p = angles.p + math.Rand(-0.2, 0.2)
                angles.y = angles.y + math.Rand(-0.2, 0.2)
                client:SetEyeAngles(angles)
            end
            
            -- Специфические эффекты для каждого типа
            if effectType == 1 then
                -- Элегантность: плавные движения
                if client:KeyDown(IN_FORWARD) or client:KeyDown(IN_BACK) or client:KeyDown(IN_MOVELEFT) or client:KeyDown(IN_MOVERIGHT) then
                    client:SetVelocity(client:GetAimVector() * 3)
                end
                
            elseif effectType == 2 then
                -- Меланхолия: случайные паузы в движении
                if math.random(1, 100) > 97 then
                    client:SetVelocity(Vector(0, 0, 0))
                end
            end
            
        elseif not client:Alive() and client:GetNetVar("hasWhiskeyEffect", false) then
            -- Убираем эффект если игрок умер
            client:SetNetVar("hasWhiskeyEffect", false)
            client:SetNetVar("whiskeyEffectType", 0)
        end
    end
end)

-- Хук для визуальных эффектов
hook.Add("RenderScreenspaceEffects", "WhiskeyVisualEffects", function()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() or not client:GetNetVar("hasWhiskeyEffect", false) then return end
    
    local effectType = client:GetNetVar("whiskeyEffectType", 0)
    
    -- Очень легкое размытие движения
    DrawMotionBlur(0.05, 0.2, 0.005)
    
    -- Утонченные цветовые эффекты
    if effectType == 1 then
        -- Золотистый оттенок для элегантности
        DrawColorModify({
            ["$pp_colour_addr"] = 0.02,
            ["$pp_colour_addg"] = 0.02,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.01,
            ["$pp_colour_contrast"] = 1.03,
            ["$pp_colour_colour"] = 1.06,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
        
    elseif effectType == 2 then
        -- Сине-серый оттенок для меланхолии
        DrawColorModify({
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0.01,
            ["$pp_colour_addb"] = 0.03,
            ["$pp_colour_brightness"] = -0.01,
            ["$pp_colour_contrast"] = 0.98,
            ["$pp_colour_colour"] = 0.95,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
        
    elseif effectType == 3 then
        -- Теплый янтарный оттенок для рефлексии
        DrawColorModify({
            ["$pp_colour_addr"] = 0.03,
            ["$pp_colour_addg"] = 0.02,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.02,
            ["$pp_colour_contrast"] = 1.02,
            ["$pp_colour_colour"] = 1.04,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    end
    
end)

-- Хук для случайных философских сообщений
hook.Add("Think", "WhiskeyPhilosophicalMessages", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasWhiskeyEffect", false) then
            if math.random(1, 5000) > 4998 then
                local messages = {
                    "Одиночество - это выбор...",
                    "Вкус напоминает об ушедшем лете...",
                    "Иногда тишина говорит громче слов...",
                    "Дорогие напитки для дорогих воспоминаний...",
                    "Время, проведенное в одиночестве, не бывает потрачено зря..."
                }
                ix.chat.Send(client, "ic", table.Random(messages))
            end
        end
    end
end)