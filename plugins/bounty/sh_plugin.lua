local PLUGIN = PLUGIN

PLUGIN.name = "Доска розыска преступников"
PLUGIN.author = "Ваше имя"
PLUGIN.description = "Система розыска преступников с наградами"

PLUGIN.config = {
    minBounty = 100,
    maxBounty = 5000,
    crimeExpireTime = 600,
    killRewardMultiplier = 0.8
}

PLUGIN.wantedPlayers = PLUGIN.wantedPlayers or {}
PLUGIN.crimeRecords = PLUGIN.crimeRecords or {}

-- Локализованные статусы для системы
PLUGIN.bountyStatusText = {
    ["Active"] = "Активен",
    ["Killed"] = "Убит"
}

-- Регистрация преступления
function PLUGIN:RegisterCrime(attacker, victim, damage)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if not IsValid(victim) or not victim:IsPlayer() then return end
    if attacker == victim then return end
    
    local crimeID = #self.crimeRecords + 1
    local crimeTime = CurTime()
    
    self.crimeRecords[crimeID] = {
        attacker = attacker,
        victim = victim,
        damage = damage,
        time = crimeTime,
        expired = false
    }
    
    -- Автоматически добавляем в розыск при серьезном уроне
    if damage >= 50 then
        self:AddToWantedList(attacker, victim, damage)
    end
    
    -- Очистка старых записей
    timer.Simple(self.config.crimeExpireTime, function()
        if self.crimeRecords[crimeID] then
            self.crimeRecords[crimeID].expired = true
        end
    end)
end

-- Добавление в розыск
function PLUGIN:AddToWantedList(attacker, victim, damage)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    
    local steamID = attacker:SteamID64()
    local bounty = math.Clamp(damage * 10, self.config.minBounty, self.config.maxBounty)
    
    self.wantedPlayers[steamID] = {
        player = attacker,
        playerName = attacker:Name(),
        crimes = self.wantedPlayers[steamID] and self.wantedPlayers[steamID].crimes + 1 or 1,
        totalBounty = self.wantedPlayers[steamID] and self.wantedPlayers[steamID].totalBounty + bounty or bounty,
        lastCrimeTime = CurTime(),
        lastVictim = victim:Name(),
        status = "Active"
    }
    
    -- Уведомление
    attacker:Notify("Вы в розыске! Награда: ☋" .. bounty)
    for _, ply in ipairs(player.GetAll()) do
        if ply:Team() == FACTION_CP then -- FACTION_CP нужно заменить на ваш ID полиции
            ply:Notify("Новый преступник в розыске: " .. attacker:Name() .. " - ☋" .. bounty)
        end
    end
end

-- Удаление из розыска
function PLUGIN:RemoveFromWantedList(steamID)
    if self.wantedPlayers[steamID] then
        self.wantedPlayers[steamID] = nil
    end
end

-- Получение награды за убийство
function PLUGIN:ClaimBounty(hunter, target)
    if not IsValid(hunter) or not IsValid(target) then return false end
    
    local steamID = target:SteamID64()
    local wantedData = self.wantedPlayers[steamID]
    
    if not wantedData then return false end
    
    local reward = wantedData.totalBounty * self.config.killRewardMultiplier
    
    if hunter:GetCharacter() then
        hunter:GetCharacter():GiveMoney(reward)
        hunter:Notify("Вы получили награду за убийство преступника: ☋" .. reward)
        
        self:RemoveFromWantedList(steamID)
        return true
    end
    
    return false
end

if SERVER then
    util.AddNetworkString("BountyBoardMenu")
    util.AddNetworkString("BountyBoardClaim")
    util.AddNetworkString("BountyBoardUpdate")

    -- Хук для урона
    hook.Add("PlayerHurt", "BountySystemDamage", function(victim, attacker, healthRemaining, damage)
        if IsValid(attacker) and attacker:IsPlayer() and IsValid(victim) and victim:IsPlayer() then
            PLUGIN:RegisterCrime(attacker, victim, damage)
        end
    end)

    -- Хук для смерти
    hook.Add("PlayerDeath", "BountySystemDeath", function(victim, inflictor, attacker)
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
            local steamID = attacker:SteamID64()
            if PLUGIN.wantedPlayers[steamID] then
                -- Автоматическая выдача награды за убийство преступника
                for _, ply in ipairs(player.GetAll()) do
                    if ply == attacker then
                        PLUGIN:ClaimBounty(ply, attacker)
                        break
                    end
                end
            end
        end
    end)

    -- Открытие меню доски
    net.Receive("BountyBoardMenu", function(len, ply)
        if ply:Team() ~= FACTION_CP then -- Проверка, что игрок полицейский
            ply:Notify("Доступно только для полиции!")
            return
        end
        
        PLUGIN:SendBountyData(ply)
    end)

    -- Запрос награды за убийство
    net.Receive("BountyBoardClaim", function(len, ply)
        local targetSteamID = net.ReadString()
        
        local target = player.GetBySteamID64(targetSteamID)
        if IsValid(target) then
            PLUGIN:ClaimBounty(ply, target)
        end
    end)

    -- Отправка данных о розыске
    function PLUGIN:SendBountyData(client)
        net.Start("BountyBoardUpdate")
        
        local bountyCount = 0
        for steamID, data in pairs(self.wantedPlayers) do
            if IsValid(data.player) then
                bountyCount = bountyCount + 1
            end
        end
        
        net.WriteUInt(bountyCount, 16)
        
        for steamID, data in pairs(self.wantedPlayers) do
            if IsValid(data.player) then
                net.WriteString(steamID)
                net.WriteString(data.playerName)
                net.WriteUInt(data.crimes, 8)
                net.WriteUInt(data.totalBounty, 32)
                net.WriteString(data.lastVictim or "Неизвестно")
                net.WriteString(data.status or "Active")
            end
        end
        
        net.Send(client)
    end
end

if CLIENT then
    local bountyData = {}

    -- Получение данных о розыске
    net.Receive("BountyBoardUpdate", function()
        bountyData = {}
        local count = net.ReadUInt(16)
        
        for i = 1, count do
            local steamID = net.ReadString()
            bountyData[steamID] = {
                steamID = steamID,
                name = net.ReadString(),
                crimes = net.ReadUInt(8),
                bounty = net.ReadUInt(32),
                lastVictim = net.ReadString(),
                status = net.ReadString()
            }
        end
    end)

    -- Меню доски розыска
    net.Receive("BountyBoardMenu", function()
        local frame = vgui.Create("DFrame")
        frame:SetSize(600, 500)
        frame:SetTitle("Доска розыска преступников")
        frame:Center()
        frame:MakePopup()

        local list = vgui.Create("DListView", frame)
        list:SetPos(10, 40)
        list:SetSize(580, 400)
        list:AddColumn("Преступник")
        list:AddColumn("Преступления")
        list:AddColumn("Награда")
        list:AddColumn("Последняя жертва")
        list:AddColumn("Статус")

        for steamID, data in pairs(bountyData) do
            list:AddLine(data.name, data.crimes, "☋" .. data.bounty, data.lastVictim, data.status)
        end

        local claimBtn = vgui.Create("DButton", frame)
        claimBtn:SetPos(10, 450)
        claimBtn:SetSize(580, 40)
        claimBtn:SetText("Заявить награду за убийство")
        claimBtn.DoClick = function()
            local line = list:GetSelectedLine()
            if line then
                local steamID = table.GetKeys(bountyData)[line]
                net.Start("BountyBoardClaim")
                net.WriteString(steamID)
                net.SendToServer()
                frame:Close()
            end
        end
    end)
end
