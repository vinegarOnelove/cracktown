ITEM.name = "Самогон"
ITEM.model = Model("models/props_junk/garbage_glassbottle003a.mdl")
ITEM.width = 1
ITEM.height = 1
ITEM.description = "Немного самогона, может получится сбагрить кому - то. Крепкий напиток с непредсказуемыми последствиями."
ITEM.category = "Варка"
ITEM.noBusiness = true
ITEM.price = 100
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
        local timerName = "samogon_effects_" .. steamID
        
        -- Удаляем старый таймер если есть
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
        
        -- Случайный эффект (1 - урон, 2 - лечение, 3 - неустойчивость)
        local randomEffect = math.random(1, 3)
        client:SetNetVar("samogonEffectType", randomEffect)
        
        -- Эффекты на 40 секунд
        timer.Create(timerName, 40, 1, function()
            if IsValid(client) and client:SteamID() == steamID then
                client:SetNetVar("hasSamogonEffect", false)
                client:SetNetVar("samogonEffectType", 0)
                client:SetWalkSpeed(ix.config.Get("walkSpeed"))
                client:SetRunSpeed(ix.config.Get("runSpeed"))
            end
        end)
        
        -- Устанавливаем эффект
        client:SetNetVar("hasSamogonEffect", true)
        client:SetNetVar("samogonEffectStart", CurTime())
        
        -- Применяем мгновенный эффект в зависимости от типа
        if randomEffect == 1 then
            -- Урон (8-12 единиц)
            local damage = math.random(8, 12)
            client:TakeDamage(damage, client, client)
            client:Notify("Вы выпили самогон! Чувствуете жгучую боль! (-" .. damage .. " HP)")
            
        elseif randomEffect == 2 then
            -- Лечение (10-15 единиц)
            local heal = math.random(10, 15)
            client:SetHealth(math.min(client:Health() + heal, client:GetMaxHealth()))
            client:Notify("Вы выпили самогон! Чувствуете прилив сил! (+" .. heal .. " HP)")
            
        elseif randomEffect == 3 then
            -- Неустойчивость (дрожание рук)
            client:SetWalkSpeed(ix.config.Get("walkSpeed") * 0.8)
            client:SetRunSpeed(ix.config.Get("runSpeed") * 1.2)
            client:Notify("Вы выпили самогон! Ноги ватные, но бежится быстро!")
        end
        
        -- Звук употребления
        client:EmitSound("npc/barnacle/barnacle_gulp" .. math.random(1,2) .. ".wav", 90, 85, 0.8)
        client:EmitSound("ambient/voices/cough" .. math.random(1,4) .. ".wav", 75, 95, 0.6)
        
        -- Случайная деревенская фраза
        if math.random(1, 3) == 1 then
            timer.Simple(1.5, function()
                if IsValid(client) then
                    local phrases = {
                        "Ох, жжёт!",
                        "На посошок!",
                        "За здоровье!",
                        "Деревенская сила!",
                        "Хозяин в доме!"
                    }
                    client:ChatPrint(table.Random(phrases))
                end
            end)
        end
        
        return true
    end
}

-- Хук для удаления эффекта при смерти
hook.Add("PlayerDeath", "RemoveSamogonEffectOnDeath", function(client)
    if client:GetNetVar("hasSamogonEffect", false) then
        client:SetNetVar("hasSamogonEffect", false)
        client:SetNetVar("samogonEffectType", 0)
        client:SetWalkSpeed(ix.config.Get("walkSpeed"))
        client:SetRunSpeed(ix.config.Get("runSpeed"))
        
        -- Удаляем таймер
        local timerName = "samogon_effects_" .. client:SteamID()
        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end
    end
end)

-- Хук для удаления эффекта при отключении игрока
hook.Add("PlayerDisconnected", "RemoveSamogonEffectOnDisconnect", function(client)
    local timerName = "samogon_effects_" .. client:SteamID()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
end)

-- Хук для применения постоянных эффектов
hook.Add("Think", "SamogonEffectsHandler", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasSamogonEffect", false) then
            local effectType = client:GetNetVar("samogonEffectType", 0)
            
            -- Дрожание камеры для всех эффектов
            if math.random(1, 100) > 70 then
                local angles = client:EyeAngles()
                angles.p = angles.p + math.Rand(-1.0, 1.0)
                angles.y = angles.y + math.Rand(-1.0, 1.0)
                client:SetEyeAngles(angles)
            end
            
            -- Эффект неустойчивости (дрожание рук при прицеливании)
            if effectType == 3 then
                if client:KeyDown(IN_ATTACK2) then -- Если игрок прицеливается
                    local angles = client:EyeAngles()
                    angles.p = angles.p + math.Rand(-2.0, 2.0)
                    angles.y = angles.y + math.Rand(-2.0, 2.0)
                    client:SetEyeAngles(angles)
                end
                
                -- Случайные толчки при движении
                if math.random(1, 100) > 85 and (client:KeyDown(IN_FORWARD) or client:KeyDown(IN_BACK) or client:KeyDown(IN_MOVELEFT) or client:KeyDown(IN_MOVERIGHT)) then
                    client:SetVelocity(Vector(math.Rand(-40, 40), math.Rand(-40, 40), 0))
                end
            end
            
            -- Замедление движения для эффекта урона
            if effectType == 1 and (client:KeyDown(IN_FORWARD) or client:KeyDown(IN_BACK) or client:KeyDown(IN_MOVELEFT) or client:KeyDown(IN_MOVERIGHT)) then
                client:SetVelocity(client:GetAimVector() * -8)
            end
            
        elseif not client:Alive() and client:GetNetVar("hasSamogonEffect", false) then
            -- Убираем эффект если игрок умер
            client:SetNetVar("hasSamogonEffect", false)
            client:SetNetVar("samogonEffectType", 0)
        end
    end
end)

-- Хук для визуальных эффектов
hook.Add("RenderScreenspaceEffects", "SamogonVisualEffects", function()
    local client = LocalPlayer()
    if not IsValid(client) or not client:Alive() or not client:GetNetVar("hasSamogonEffect", false) then return end
    
    local effectType = client:GetNetVar("samogonEffectType", 0)
    
    -- Сильное размытие движения для самогона
    DrawMotionBlur(0.15, 0.5, 0.02)
    
    -- Цветовые эффекты в зависимости от типа
    if effectType == 1 then
        -- Красноватый оттенок для урона
        DrawColorModify({
            ["$pp_colour_addr"] = 0.08,
            ["$pp_colour_addg"] = 0,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -0.03,
            ["$pp_colour_contrast"] = 1.1,
            ["$pp_colour_colour"] = 0.9,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    elseif effectType == 2 then
        -- Зеленоватый оттенок для лечения
        DrawColorModify({
            ["$pp_colour_addr"] = 0,
            ["$pp_colour_addg"] = 0.08,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = 0.03,
            ["$pp_colour_contrast"] = 1.08,
            ["$pp_colour_colour"] = 1.05,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    elseif effectType == 3 then
        -- Коричневатый оттенок для неустойчивости
        DrawColorModify({
            ["$pp_colour_addr"] = 0.05,
            ["$pp_colour_addg"] = 0.03,
            ["$pp_colour_addb"] = 0,
            ["$pp_colour_brightness"] = -0.02,
            ["$pp_colour_contrast"] = 1.06,
            ["$pp_colour_colour"] = 0.92,
            ["$pp_colour_mulr"] = 0,
            ["$pp_colour_mulg"] = 0,
            ["$pp_colour_mulb"] = 0
        })
    end
end)

-- Хук для случайных деревенских фраз
hook.Add("Think", "SamogonVillageMessages", function()
    for _, client in ipairs(player.GetAll()) do
        if client:Alive() and client:GetNetVar("hasSamogonEffect", false) then
            -- Редкие сообщения (раз в 20-30 секунд)
            if math.random(1, 1500) > 1498 then
                local messages = {
                    "Эх, раззудись плечо!",
                    "Похмелье будет знатным...",
                    "Настоящий деревенский продукт!",
                    "За ударный труд!",
                    "Сама гнало - сама пью!",
                    "Ничего, крепче стану!",
                    "За технический прогресс!",
                    "Хорошо пошло!",
                    "Ещё по одной?",
                    "За здоровье не пить!"
                }
                client:ChatPrint(table.Random(messages))
            end
        end
    end
end)