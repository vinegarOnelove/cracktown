local PLUGIN = PLUGIN

PLUGIN.name = "altar"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система кровавого алтаря для жертвоприношений и перманентных усилений"

-- Локализация статусов для алтаря
PLUGIN.altarStatusText = {
    ["Idle"] = "Ожидает",
    ["Accepting"] = "Принимает жертву", 
    ["Blessing"] = "Дарует благословение",
    ["Cooldown"] = "Перезарядка"
}

-- Перманентные усиления
PLUGIN.altarBlessings = {
    ["health"] = {
        name = "Усиление здоровья",
        description = "+25 к максимальному здоровью",
        maxLevel = 4,
        cost = {["human_part"] = 1}
    },
    ["stamina"] = {
        name = "Усиление выносливости", 
        description = "+20% к максимальной выносливости",
        maxLevel = 3,
        cost = {["human_part"] = 1}
    },
    ["strength"] = {
        name = "Усиление силы",
        description = "+15% к физическому урону",
        maxLevel = 3,
        cost = {["human_brain"] = 1}
    },
    ["speed"] = {
        name = "Усиление скорости",
        description = "+10% к скорости бега",
        maxLevel = 2,
        cost = {["human_heart"] = 2, ["human_bone"] = 1}
    }
}

-- Конфигурация
PLUGIN.config = {
    cooldownTime = 300, -- 5 минут в секундах
    maxBlessingsPerPlayer = 10 -- Максимум усилений на игрока
}

if SERVER then
    -- Хук для применения усилений при загрузке персонажа
    hook.Add("PlayerLoadedCharacter", "BloodAltarApplyBlessings", function(ply, char)
        timer.Simple(1, function() -- Небольшая задержка для инициализации
            if IsValid(ply) and char then
                PLUGIN:ApplySavedBlessings(ply, char)
            end
        end)
    end)

    -- Функция применения сохраненных усилений
    function PLUGIN:ApplySavedBlessings(ply, char)
        local blessings = char:GetData("altarBlessings", {})
        
        for blessingID, level in pairs(blessings) do
            local blessing = self.altarBlessings[blessingID]
            if blessing then
                self:ApplyBlessingEffect(char, blessingID, level)
            end
        end
    end

    -- Функция применения эффекта усиления
    function PLUGIN:ApplyBlessingEffect(char, blessingID, level)
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
    end

    -- Хук для усиления урона
    hook.Add("EntityTakeDamage", "BloodAltarDamageBoost", function(target, dmg)
        local attacker = dmg:GetAttacker()
        if IsValid(attacker) and attacker:IsPlayer() then
            local char = attacker:GetCharacter()
            if char then
                local damageBonus = char:GetData("altar_strength_bonus", 0)
                if damageBonus > 0 then
                    dmg:SetDamage(dmg:GetDamage() * (1 + damageBonus))
                end
            end
        end
    end)

    -- Хук для усиления скорости
    hook.Add("SetupPlayerSpeed", "BloodAltarSpeedBoost", function(ply, mv)
        local char = ply:GetCharacter()
        if char then
            local speedBonus = char:GetData("altar_speed_bonus", 0)
            if speedBonus > 0 then
                mv:SetMaxSpeed(mv:GetMaxSpeed() * (1 + speedBonus))
                mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * (1 + speedBonus))
            end
        end
    end)

    -- Хук для усиления выносливости
    hook.Add("SetupMove", "BloodAltarStaminaBoost", function(ply, mv, cmd)
        local char = ply:GetCharacter()
        if char then
            local staminaBonus = char:GetData("altar_stamina_bonus", 0)
            if staminaBonus > 0 and ix and ix.stamina then
                local maxStamina = ix.stamina.GetMax(ply)
                ix.stamina.SetMax(ply, maxStamina * (1 + staminaBonus))
            end
        end
    end)

    -- Хук для усиления здоровья
    hook.Add("PlayerSpawn", "BloodAltarHealthBoost", function(ply)
        local char = ply:GetCharacter()
        if char then
            local healthBonus = char:GetData("altar_health_bonus", 0)
            if healthBonus > 0 then
                ply:SetMaxHealth(ply:GetMaxHealth() + healthBonus)
                ply:SetHealth(ply:GetMaxHealth())
            end
        end
    end)
end


