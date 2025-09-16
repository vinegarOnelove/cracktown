local PLUGIN = PLUGIN

PLUGIN.name = "Container Robbery"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система ограбления контейнеров с уведомлением полиции и наградой полиции."

ix.containerRobbery = ix.containerRobbery or {
    config = {
        robberyTime = 120,
        minReward = 500,
        maxReward = 1500,
        policeFaction = FACTION_POLICE,
        cooldownTime = 300,
        alertRadius = 1500,
        policeReward = 300,
        policeRewardPercent = 0.3
    }
}

PLUGIN.config = ix.containerRobbery.config
PLUGIN.activeRobberies = PLUGIN.activeRobberies or {}

if SERVER then
    util.AddNetworkString("ContainerRobberyAlert")
    util.AddNetworkString("ContainerRobberyRemoveMarker")

    function PLUGIN:AlertPolice(container, robber)
        if not IsValid(container) or not IsValid(robber) then return end

        local position = container:GetPos()
        local containerID = container:EntIndex()

        self.activeRobberies[containerID] = {
            robber = robber,
            robberSteamID = robber:SteamID64(),
            container = container,
            startTime = CurTime(),
            rewardAmount = math.random(self.config.minReward, self.config.maxReward),
            position = position
        }

        for _, ply in ipairs(player.GetAll()) do
            if ply:GetCharacter() and ply:GetCharacter():GetFaction() == self.config.policeFaction then
                ply:Notify("ВНИМАНИЕ! Ограбление контейнера!")
                ply:Notify("Преступник: " .. robber:Name())
                ply:Notify("Награда за поимку: ☋" .. self.config.policeReward)

                net.Start("ContainerRobberyAlert")
                net.WriteVector(position)
                net.WriteString("📍 Ограбление контейнера")
                net.WriteUInt(containerID, 16)
                net.Send(ply)
            end
        end

        ix.chat.Send(nil, "notice", "Начато ограбление контейнера!", nil, nil, nil)
    end

    function PLUGIN:GiveReward(robber, containerID)
        if not IsValid(robber) or not robber:GetCharacter() then return end
        local robberyData = self.activeRobberies[containerID]
        if not robberyData then return end

        local reward = robberyData.rewardAmount
        robber:GetCharacter():GiveMoney(reward)
        robber:Notify("Вы получили награду: ☋" .. reward)

        net.Start("ContainerRobberyRemoveMarker")
        net.WriteUInt(containerID, 16)
        net.Broadcast()

        self.activeRobberies[containerID] = nil
    end

    function PLUGIN:GivePoliceReward(killer, robber, containerID)
        if not IsValid(killer) or not killer:GetCharacter() then return end
        local robberyData = self.activeRobberies[containerID]
        if not robberyData then return end

        local baseReward = self.config.policeReward
        local percentReward = math.Round(robberyData.rewardAmount * self.config.policeRewardPercent)
        local totalReward = baseReward + percentReward

        -- Проверка что награда является числом :cite[2]:cite[5]
        if not isnumber(totalReward) or totalReward <= 0 then
            totalReward = self.config.policeReward -- Используем базовую награду
        end

        killer:GetCharacter():GiveMoney(totalReward)
        killer:Notify("Вы получили награду за поимку преступника: ☋" .. totalReward)

        net.Start("ContainerRobberyRemoveMarker")
        net.WriteUInt(containerID, 16)
        net.Broadcast()

        self.activeRobberies[containerID] = nil
    end

    -- Функция для получения контейнера по SteamID грабителя
    function PLUGIN:GetContainerByRobberSteamID(steamID64)
        for containerID, data in pairs(self.activeRobberies) do
            if data.robberSteamID == steamID64 then
                return containerID, data
            end
        end
        return nil, nil
    end

    -- Новая функция: проверка смерти конкретного игрока
    function PLUGIN:CheckRobberDeath(victim, attacker)
        if not IsValid(victim) or not victim:IsPlayer() then return end

        local containerID, robberyData = self:GetContainerByRobberSteamID(victim:SteamID64())
        if not containerID or not robberyData then return end

        local killer = IsValid(attacker) and attacker:IsPlayer() and attacker or (IsValid(attacker) and attacker.GetOwner and attacker:GetOwner() and attacker:GetOwner():IsPlayer() and attacker:GetOwner())
        
        if IsValid(killer) and killer:GetCharacter() and killer:GetCharacter():GetFaction() == self.config.policeFaction then
            self:GivePoliceReward(killer, victim, containerID)
            ix.chat.Send(nil, "notice", "Преступник пойман полицией! Награда выплачена.", nil, nil, nil)
        else
            ix.chat.Send(nil, "notice", "Ограбление провалено! Преступник убит.", nil, nil, nil)
            self.activeRobberies[containerID] = nil
            
            net.Start("ContainerRobberyRemoveMarker")
            net.WriteUInt(containerID, 16)
            net.Broadcast()
        end
    end

    -- Проверка смерти
    hook.Add("PlayerDeath", "ContainerRobbery_PlayerDeath", function(victim, inflictor, attacker)
        if PLUGIN and PLUGIN.CheckRobberDeath then
            PLUGIN:CheckRobberDeath(victim, attacker)
        end
    end)
    
    hook.Add("OnCharacterDeath", "ContainerRobbery_CharDeath", function(client, inflictor, attacker)
        if PLUGIN and PLUGIN.CheckRobberDeath then
            PLUGIN:CheckRobberDeath(client, attacker)
        end
    end)
end

if CLIENT then
    local robberyMarkers = {}

    net.Receive("ContainerRobberyAlert", function()
        local pos = net.ReadVector()
        local text = net.ReadString()
        local id = net.ReadUInt(16)

        robberyMarkers[id] = { position = pos, text = text }
        hook.Add("PostDrawTranslucentRenderables", "ContainerRobberyMarkers", function()
            for _, marker in pairs(robberyMarkers) do
                local dist = LocalPlayer():GetPos():Distance(marker.position)
                if dist > 2000 then continue end

                cam.Start3D2D(marker.position + Vector(0,0,50), Angle(0,0,0), 0.1)
                    draw.SimpleText(marker.text, "DermaDefault", 0, 0, Color(255,0,0), TEXT_ALIGN_CENTER)
                cam.End3D2D()
            end
        end)
    end)

    net.Receive("ContainerRobberyRemoveMarker", function()
        local id = net.ReadUInt(16)
        robberyMarkers[id] = nil
        if table.IsEmpty(robberyMarkers) then
            hook.Remove("PostDrawTranslucentRenderables", "ContainerRobberyMarkers")
        end
    end)
end

