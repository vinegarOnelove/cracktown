local PLUGIN = PLUGIN

PLUGIN.name = "Подпольные бои"
PLUGIN.author = "Ваше имя"
PLUGIN.description = "Система подпольных боёв с организатором"

PLUGIN.config = {
    minBet = 50,
    maxBet = 2000,
    organizerCut = 0.2,
    fightDuration = 180,
    cooldownTime = 300,
    arenaRadius = 500,
    inviteCooldown = 60, -- 60 секунд кд на приглашения
    arenaLeaveRadius = 1000 -- Радиус, за который нельзя выходить из арены
}

PLUGIN.activeFights = PLUGIN.activeFights or {}
PLUGIN.fightQueue = PLUGIN.fightQueue or {}
PLUGIN.inviteCooldowns = PLUGIN.inviteCooldowns or {} -- Таблица кд приглашений

-- Глобальная функция для entity
function PLUGIN:OpenFightMenu(organizer, client)
    if not IsValid(client) or not client:GetCharacter() then return end
    
    print("[Бои] Открываем меню для " .. client:Name())
    
    -- Сначала отправляем данные об активных боях
    self:SendActiveFightsToClient(client)
    
    -- Затем отправляем основное меню
    timer.Simple(0.1, function()
        if IsValid(client) then
            net.Start("UndergroundFightMainMenu")
            net.WriteEntity(organizer)
            net.Send(client)
        end
    end)
end

-- Функция отправки активных боёв клиенту
function PLUGIN:SendActiveFightsToClient(client)
    if not IsValid(client) then return end
    
    net.Start("UndergroundFightSync")
    
    -- Считаем только активные бои
    local activeCount = 0
    for fightID, fight in pairs(self.activeFights) do
        if fight.status == "active" then
            activeCount = activeCount + 1
        end
    end
    
    net.WriteUInt(activeCount, 16)
    
    for fightID, fight in pairs(self.activeFights) do
        if fight.status == "active" then
            net.WriteUInt(fightID, 16)
            net.WriteString(fight.fighter1Name or "Неизвестный")
            net.WriteString(fight.fighter2Name or "Неизвестный")
            net.WriteUInt(fight.betAmount or 0, 32)
            net.WriteFloat(fight.endTime or 0)
        end
    end
    
    net.Send(client)
end

-- Проверка кд приглашения
function PLUGIN:CanInvitePlayer(challenger, target)
    if not IsValid(challenger) or not IsValid(target) then return false end
    
    local challengerID = challenger:SteamID64()
    local targetID = target:SteamID64()
    local cooldownKey = challengerID .. "_" .. targetID
    
    -- Проверяем кд
    if self.inviteCooldowns[cooldownKey] and self.inviteCooldowns[cooldownKey] > CurTime() then
        local timeLeft = math.Round(self.inviteCooldowns[cooldownKey] - CurTime())
        challenger:Notify("Подождите " .. timeLeft .. " секунд перед повторным приглашением " .. target:Name())
        return false
    end
    
    -- Проверяем, есть ли уже приглашение этому игроку
    for _, fight in ipairs(self.fightQueue) do
        if fight.target == target and IsValid(fight.challenger) and fight.challenger == challenger then
            challenger:Notify("Вы уже отправили приглашение " .. target:Name())
            return false
        end
    end
    
    return true
end

-- Установка кд приглашения
function PLUGIN:SetInviteCooldown(challenger, target)
    if not IsValid(challenger) or not IsValid(target) then return end
    
    local challengerID = challenger:SteamID64()
    local targetID = target:SteamID64()
    local cooldownKey = challengerID .. "_" .. targetID
    
    self.inviteCooldowns[cooldownKey] = CurTime() + self.config.inviteCooldown
    
    -- Очистка старых кд
    for key, expiration in pairs(self.inviteCooldowns) do
        if expiration < CurTime() then
            self.inviteCooldowns[key] = nil
        end
    end
end

-- Проверка, может ли игрок сделать ставку на бой
function PLUGIN:CanPlaceBet(client, fightID, fighter)
    if not IsValid(client) or not client:GetCharacter() then return false end
    
    local fight = self.activeFights[fightID]
    if not fight then return false end
    
    -- Проверяем, не является ли игрок одним из бойцов
    if fight.fighter1 == client or fight.fighter2 == client then
        client:Notify("Нельзя делать ставки на свой собственный бой!")
        return false
    end
    
    -- Проверяем, не делал ли уже игрок ставку на этот бой
    for steamID, betData in pairs(fight.bets) do
        if steamID == client:SteamID64() then
            client:Notify("Вы уже сделали ставку на этот бой!")
            return false
        end
    end
    
    return true
end

-- Проверка расстояния от арены
function PLUGIN:CheckFighterDistance(fightID)
    local fight = self.activeFights[fightID]
    if not fight or fight.status ~= "active" then return end
    
    local arenaPos = fight.arenaPosition
    local maxDistance = self.config.arenaLeaveRadius
    
    -- Проверяем первого бойца
    if IsValid(fight.fighter1) then
        local distance = fight.fighter1:GetPos():Distance(arenaPos)
        if distance > maxDistance then
            fight.fighter1:Notify("Вы покинули арену и проиграли бой!")
            if IsValid(fight.fighter2) then
                fight.fighter2:Notify("Противник покинул арену! Вы победили!")
                self:EndFight(fightID, "winner", fight.fighter2)
            else
                self:EndFight(fightID, "timeout")
            end
            return
        end
    end
    
    -- Проверяем второго бойца
    if IsValid(fight.fighter2) then
        local distance = fight.fighter2:GetPos():Distance(arenaPos)
        if distance > maxDistance then
            fight.fighter2:Notify("Вы покинули арену и проиграли бой!")
            if IsValid(fight.fighter1) then
                fight.fighter1:Notify("Противник покинул арену! Вы победили!")
                self:EndFight(fightID, "winner", fight.fighter1)
            else
                self:EndFight(fightID, "timeout")
            end
            return
        end
    end
end

if SERVER then
    -- Сетевые сообщения
    util.AddNetworkString("UndergroundFightMainMenu")
    util.AddNetworkString("UndergroundFightInviteMenu")
    util.AddNetworkString("UndergroundFightAccept")
    util.AddNetworkString("UndergroundFightDecline")
    util.AddNetworkString("UndergroundFightChallenge")
    util.AddNetworkString("UndergroundFightBet")
    util.AddNetworkString("UndergroundFightStart")
    util.AddNetworkString("UndergroundFightEnd")
    util.AddNetworkString("UndergroundFightSync")

    -- Вызов на бой
    net.Receive("UndergroundFightChallenge", function(len, ply)
        local organizer = net.ReadEntity()
        local target = net.ReadEntity()
        local betAmount = net.ReadUInt(32)
        
        if IsValid(organizer) and IsValid(target) then
            PLUGIN:ChallengePlayer(organizer, ply, target, betAmount)
        end
    end)

    -- Принятие боя
    net.Receive("UndergroundFightAccept", function(len, ply)
        local organizer = net.ReadEntity()
        if IsValid(organizer) then
            PLUGIN:AcceptFight(organizer, ply)
        end
    end)

    -- Отклонение боя
    net.Receive("UndergroundFightDecline", function(len, ply)
        local organizer = net.ReadEntity()
        if IsValid(organizer) then
            PLUGIN:DeclineFight(organizer, ply)
        end
    end)

    -- Ставка
    net.Receive("UndergroundFightBet", function(len, ply)
        local organizer = net.ReadEntity()
        local fightID = net.ReadUInt(16)
        local betOnFighter1 = net.ReadBool()
        local amount = net.ReadUInt(32)
        
        if IsValid(organizer) then
            local fight = PLUGIN.activeFights[fightID]
            if fight then
                local fighter = betOnFighter1 and fight.fighter1 or fight.fighter2
                
                -- Проверяем, может ли игрок сделать ставку
                if not PLUGIN:CanPlaceBet(ply, fightID, fighter) then
                    return
                end
                
                PLUGIN:PlaceBet(organizer, ply, fightID, fighter, amount)
            end
        end
    end)

    -- Функция вызова на бой
    function PLUGIN:ChallengePlayer(organizer, challenger, target, betAmount)
        if not IsValid(challenger) or not IsValid(target) then return false end
        if challenger == target then
            challenger:Notify("Нельзя вызвать самого себя на бой!")
            return false
        end

        -- Проверяем кд приглашения
        if not self:CanInvitePlayer(challenger, target) then
            return false
        end

        if betAmount < self.config.minBet or betAmount > self.config.maxBet then
            challenger:Notify("Ставка должна быть между ☋" .. self.config.minBet .. " и ☋" .. self.config.maxBet)
            return false
        end

        if challenger:GetCharacter():GetMoney() < betAmount then
            challenger:Notify("Недостаточно денег для ставки!")
            return false
        end

        -- Добавляем в очередь
        table.insert(self.fightQueue, {
            challenger = challenger,
            target = target,
            betAmount = betAmount,
            organizer = organizer,
            challengeTime = CurTime()
        })

        -- Устанавливаем кд приглашения
        self:SetInviteCooldown(challenger, target)

        -- Отправляем приглашение цели
        net.Start("UndergroundFightInviteMenu")
        net.WriteEntity(organizer)
        net.WriteString(challenger:Name())
        net.WriteUInt(betAmount, 32)
        net.Send(target)

        challenger:Notify("Приглашение отправлено " .. target:Name())
        return true
    end

    -- Функция принятия боя
    function PLUGIN:AcceptFight(organizer, client)
        for i, fight in ipairs(self.fightQueue) do
            if fight.target == client and IsValid(fight.challenger) then
                if fight.challenger:GetCharacter():GetMoney() < fight.betAmount then
                    client:Notify(fight.challenger:Name() .. " больше не может участвовать в бою!")
                    table.remove(self.fightQueue, i)
                    return false
                end

                if client:GetCharacter():GetMoney() < fight.betAmount then
                    client:Notify("У вас недостаточно денег для участия!")
                    return false
                end

                -- Снимаем деньги
                fight.challenger:GetCharacter():TakeMoney(fight.betAmount)
                client:GetCharacter():TakeMoney(fight.betAmount)

                -- Начинаем бой
                self:StartFight(organizer, fight.challenger, client, fight.betAmount)
                
                -- Удаляем из очереди
                table.remove(self.fightQueue, i)
                return true
            end
        end

        client:Notify("Активных приглашений не найдено!")
        return false
    end

    -- Функция отклонения боя
    function PLUGIN:DeclineFight(organizer, client)
        for i, fight in ipairs(self.fightQueue) do
            if fight.target == client then
                table.remove(self.fightQueue, i)
                client:Notify("Вы отклонили вызов на бой")
                
                if IsValid(fight.challenger) then
                    fight.challenger:Notify(client:Name() .. " отклонил ваш вызов")
                end
                return true
            end
        end
        
        client:Notify("Приглашений не найдено")
        return false
    end

    -- Функция начала боя
    function PLUGIN:StartFight(organizer, fighter1, fighter2, betAmount)
        if not IsValid(fighter1) or not IsValid(fighter2) then return false end

        local fightID = #self.activeFights + 1
        local arenaPos = organizer:GetPos() + Vector(0, 200, 0)

        self.activeFights[fightID] = {
            fighter1 = fighter1,
            fighter2 = fighter2,
            fighter1Name = fighter1:Name(),
            fighter2Name = fighter2:Name(),
            betAmount = betAmount,
            arenaPosition = arenaPos,
            startTime = CurTime(),
            endTime = CurTime() + self.config.fightDuration,
            bets = {},
            status = "active"
        }

        -- Телепортируем бойцов
        fighter1:SetPos(arenaPos + Vector(-150, 0, 50))
        fighter2:SetPos(arenaPos + Vector(150, 0, 50))

        -- Уведомляем
        fighter1:Notify("Бой начинается! Ставка: ☋" .. betAmount)
        fighter2:Notify("Бой начинается! Ставка: ☋" .. betAmount)
        
        -- Уведомляем о радиусе арены
        fighter1:Notify("Не отходите дальше " .. self.config.arenaLeaveRadius .. " единиц от арены!")
        fighter2:Notify("Не отходите дальше " .. self.config.arenaLeaveRadius .. " единиц от арены!")

        -- Отправляем информацию о начале боя всем клиентам
        self:BroadcastFightStart(fightID)

        -- Таймер боя
        timer.Create("underground_fight_" .. fightID, self.config.fightDuration, 1, function()
            if self.activeFights[fightID] then
                self:EndFight(fightID, "timeout")
            end
        end)
        
        -- Таймер проверки расстояния (каждую секунду)
        timer.Create("underground_fight_distance_" .. fightID, 1, 0, function()
            if self.activeFights[fightID] and self.activeFights[fightID].status == "active" then
                self:CheckFighterDistance(fightID)
            else
                timer.Remove("underground_fight_distance_" .. fightID)
            end
        end)

        return true
    end

    -- Функция отправки информации о начале боя
    function PLUGIN:BroadcastFightStart(fightID)
        local fight = self.activeFights[fightID]
        if not fight then return end

        net.Start("UndergroundFightStart")
        net.WriteUInt(fightID, 16)
        net.WriteString(fight.fighter1Name)
        net.WriteString(fight.fighter2Name)
        net.WriteUInt(fight.betAmount, 32)
        net.WriteFloat(fight.endTime)
        net.Broadcast()
    end

    -- Функция завершения боя
    function PLUGIN:EndFight(fightID, reason, winner)
        local fight = self.activeFights[fightID]
        if not fight then return end

        fight.status = "ended"
        local totalPot = fight.betAmount * 2
        local organizerCut = math.Round(totalPot * self.config.organizerCut)
        local winnerPrize = totalPot - organizerCut

        -- Удаляем таймер проверки расстояния
        timer.Remove("underground_fight_distance_" .. fightID)

        if reason == "timeout" then
            -- Возвращаем деньги
            if IsValid(fight.fighter1) and fight.fighter1:GetCharacter() then
                fight.fighter1:GetCharacter():GiveMoney(fight.betAmount)
                fight.fighter1:Notify("Бой завершен по таймауту. Деньги возвращены.")
            end
            if IsValid(fight.fighter2) and fight.fighter2:GetCharacter() then
                fight.fighter2:GetCharacter():GiveMoney(fight.betAmount)
                fight.fighter2:Notify("Бой завершен по таймауту. Деньги возвращены.")
            end
        elseif reason == "winner" and IsValid(winner) then
            -- Выдаем награду победителю
            if winner:GetCharacter() then
                winner:GetCharacter():GiveMoney(winnerPrize)
                winner:Notify("Вы победили и получаете ☋" .. winnerPrize)
            end

            -- Выдаем выигрыши по ставкам
            for steamID, betData in pairs(fight.bets) do
                if betData.fighter == winner then
                    local player = player.GetBySteamID64(steamID)
                    if IsValid(player) and player:GetCharacter() then
                        local winAmount = math.Round(betData.amount * 1.8)
                        player:GetCharacter():GiveMoney(winAmount)
                        player:Notify("Ваша ставка выиграла! Вы получаете ☋" .. winAmount)
                    end
                end
            end
        end

        -- Отправляем информацию о завершении боя всем клиентам
        net.Start("UndergroundFightEnd")
        net.WriteUInt(fightID, 16)
        net.Broadcast()

        -- Очищаем бой через 10 секунд
        timer.Simple(10, function()
            if self.activeFights[fightID] then
                self.activeFights[fightID] = nil
                print("[Бои] Бой #" .. fightID .. " полностью удален с сервера")
            end
        end)
    end

    -- Функция размещения ставки
    function PLUGIN:PlaceBet(organizer, client, fightID, fighter, amount)
        if not IsValid(client) or not client:GetCharacter() then return false end
        
        local fight = self.activeFights[fightID]
        if not fight or fight.status ~= "active" then
            client:Notify("Бой уже завершен!")
            return false
        end

        if not IsValid(fighter) or (fighter ~= fight.fighter1 and fighter ~= fight.fighter2) then
            client:Notify("Неверный боец!")
            return false
        end

        if amount < self.config.minBet or amount > self.config.maxBet then
            client:Notify("Ставка должна быть между ☋" .. self.config.minBet .. " и ☋" .. self.config.maxBet)
            return false
        end

        if client:GetCharacter():GetMoney() < amount then
            client:Notify("Недостаточно денег!")
            return false
        end

        -- Снимаем деньги
        client:GetCharacter():TakeMoney(amount)

        -- Регистрируем ставку
        fight.bets[client:SteamID64()] = {
            fighter = fighter,
            amount = amount,
            playerName = client:Name()
        }

        client:Notify("Ставка принята: ☋" .. amount)
        return true
    end

    -- Обработка смерти бойца
    hook.Add("PlayerDeath", "UndergroundFightDeath", function(victim, inflictor, attacker)
        for fightID, fight in pairs(PLUGIN.activeFights) do
            if fight.status == "active" and (victim == fight.fighter1 or victim == fight.fighter2) then
                local winner = (victim == fight.fighter1) and fight.fighter2 or fight.fighter1
                if IsValid(winner) then
                    PLUGIN:EndFight(fightID, "winner", winner)
                end
                break
            end
        end
    end)

    print("[Подпольные бои] Серверная часть загружена!")
end

if CLIENT then
    local activeFights = {}

    -- Синхронизация активных боёв
    net.Receive("UndergroundFightSync", function()
        activeFights = {}
        local count = net.ReadUInt(16)
        
        for i = 1, count do
            local fightID = net.ReadUInt(16)
            local fighter1 = net.ReadString()
            local fighter2 = net.ReadString()
            local betAmount = net.ReadUInt(32)
            local endTime = net.ReadFloat()
            
            activeFights[fightID] = {
                fighter1 = fighter1,
                fighter2 = fighter2,
                betAmount = betAmount,
                endTime = endTime,
                valid = true
            }
        end
        
        print("[Бои] Синхронизировано " .. count .. " активных боёв")
    end)

    -- Основное меню организатора
    net.Receive("UndergroundFightMainMenu", function()
        local organizer = net.ReadEntity()
        if not IsValid(organizer) then return end

        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 550)
        frame:SetTitle("🥊 Организатор подпольных боёв")
        frame:Center()
        frame:MakePopup()

        local players = {}
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= LocalPlayer() and ply:GetCharacter() then
                table.insert(players, ply)
            end
        end

        local betAmount = 100

        -- Выбор противника
        local playerCombo = vgui.Create("DComboBox", frame)
        playerCombo:SetPos(20, 40)
        playerCombo:SetSize(360, 30)
        playerCombo:SetValue("Выберите противника")
        
        for _, ply in ipairs(players) do
            playerCombo:AddChoice(ply:Name(), ply)
        end

        -- Выбор ставки
        local betSlider = vgui.Create("DNumSlider", frame)
        betSlider:SetPos(20, 80)
        betSlider:SetSize(360, 40)
        betSlider:SetText("Ставка:")
        betSlider:SetMin(50)
        betSlider:SetMax(2000)
        betSlider:SetDecimals(0)
        betSlider:SetValue(100)
        betSlider.OnValueChanged = function(_, value)
            betAmount = math.Round(value)
        end

        -- Кнопка вызова на бой
        local challengeBtn = vgui.Create("DButton", frame)
        challengeBtn:SetPos(20, 130)
        challengeBtn:SetSize(360, 40)
        challengeBtn:SetText("Вызвать на бой")
        challengeBtn.DoClick = function()
            local _, selectedPlayer = playerCombo:GetSelected()
            if selectedPlayer then
                net.Start("UndergroundFightChallenge")
                net.WriteEntity(organizer)
                net.WriteEntity(selectedPlayer)
                net.WriteUInt(betAmount, 32)
                net.SendToServer()
                frame:Close()
            else
                Derma_Message("Выберите противника!", "Ошибка", "OK")
            end
        end

        -- Разделитель
        local line = vgui.Create("DPanel", frame)
        line:SetPos(10, 180)
        line:SetSize(380, 2)
        line.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, Color(100, 100, 100))
        end

        local fightsLabel = vgui.Create("DLabel", frame)
        fightsLabel:SetPos(20, 190)
        fightsLabel:SetText("Активные бои для ставок:")
        fightsLabel:SizeToContents()

        -- Список активных боёв
        local fightsList = vgui.Create("DListView", frame)
        fightsList:SetPos(20, 210)
        fightsList:SetSize(360, 150)
        fightsList:AddColumn("ID")
        fightsList:AddColumn("Бойцы")
        fightsList:AddColumn("Ставка")
        fightsList:AddColumn("Осталось")

        -- Заполняем список активными боями
        for fightID, fight in pairs(activeFights) do
            local timeLeft = math.max(0, math.Round(fight.endTime - CurTime()))
            if timeLeft > 0 and fight.valid then
                fightsList:AddLine(fightID, fight.fighter1 .. " vs " .. fight.fighter2, "☋" .. fight.betAmount, timeLeft .. "с")
            end
        end

        -- Выбор размера ставки
        local betAmountSlider = vgui.Create("DNumSlider", frame)
        betAmountSlider:SetPos(20, 370)
        betAmountSlider:SetSize(360, 40)
        betAmountSlider:SetText("Размер ставки:")
        betAmountSlider:SetMin(50)
        betAmountSlider:SetMax(2000)
        betAmountSlider:SetDecimals(0)
        betAmountSlider:SetValue(100)
        betAmountSlider.OnValueChanged = function(_, value)
            betAmount = math.Round(value)
        end

        -- КНОПКА ДЛЯ СТАвКИ
        local placeBetBtn = vgui.Create("DButton", frame)
        placeBetBtn:SetPos(20, 420)
        placeBetBtn:SetSize(360, 40)
        placeBetBtn:SetText("Сделать ставку")
        placeBetBtn.DoClick = function()
            local selectedLine = fightsList:GetSelectedLine()
            if selectedLine and selectedLine > 0 then
                local line = fightsList:GetLine(selectedLine)
                local fightID = tonumber(line:GetColumnText(1))
                
                if fightID and activeFights[fightID] and activeFights[fightID].valid then
                    local fight = activeFights[fightID]
                    local fightersText = fight.fighter1 .. " vs " .. fight.fighter2
                    
                    Derma_Query(
                        "Сделать ставку на бой: " .. fightersText .. "?",
                        "Ставки на бой",
                        "На 1-го бойца", function()
                            net.Start("UndergroundFightBet")
                            net.WriteEntity(organizer)
                            net.WriteUInt(fightID, 16)
                            net.WriteBool(true)
                            net.WriteUInt(betAmount, 32)
                            net.SendToServer()
                            frame:Close()
                        end,
                        "На 2-го бойца", function()
                            net.Start("UndergroundFightBet")
                            net.WriteEntity(organizer)
                            net.WriteUInt(fightID, 16)
                            net.WriteBool(false)
                            net.WriteUInt(betAmount, 32)
                            net.SendToServer()
                            frame:Close()
                        end,
                        "Отмена", nil
                    )
                else
                    Derma_Message("Этот бой больше не доступен для ставок!", "Ошибка", "OK")
                end
            else
                Derma_Message("Выберите бой для ставки!", "Ошибка", "OK")
            end
        end

        -- Кнопка обновления
        local refreshBtn = vgui.Create("DButton", frame)
        refreshBtn:SetPos(20, 470)
        refreshBtn:SetSize(360, 30)
        refreshBtn:SetText("Обновить список боёв")
        refreshBtn.DoClick = function()
            frame:Close()
            net.Start("UndergroundFightMainMenu")
            net.WriteEntity(organizer)
            net.SendToServer()
        end
    end)

    -- Меню приглашения на бой
    net.Receive("UndergroundFightInviteMenu", function()
        local organizer = net.ReadEntity()
        local challengerName = net.ReadString()
        local betAmount = net.ReadUInt(32)
        
        if not IsValid(organizer) then return end

        Derma_Query(
            "Игрок " .. challengerName .. " вызывает вас на бой!\nСтавка: ☋" .. betAmount,
            "Вызов на подпольный бой",
            "Принять", function()
                net.Start("UndergroundFightAccept")
                net.WriteEntity(organizer)
                net.SendToServer()
            end,
            "Отклонить", function()
                net.Start("UndergroundFightDecline")
                net.WriteEntity(organizer)
                net.SendToServer()
            end
        )
    end)

    -- Обновление информации о боях
    net.Receive("UndergroundFightStart", function()
        local fightID = net.ReadUInt(16)
        local fighter1 = net.ReadString()
        local fighter2 = net.ReadString()
        local betAmount = net.ReadUInt(32)
        local endTime = net.ReadFloat()

        activeFights[fightID] = {
            fighter1 = fighter1,
            fighter2 = fighter2,
            betAmount = betAmount,
            endTime = endTime,
            valid = true
        }
        
        print("[Бои] Начат новый бой: " .. fighter1 .. " vs " .. fighter2)
    end)

    net.Receive("UndergroundFightEnd", function()
        local fightID = net.ReadUInt(16)
        if activeFights[fightID] then
            activeFights[fightID].valid = false
            print("[Бои] Бой #" .. fightID .. " отмечен как завершенный")
            
            -- Удаляем бой из списка через 5 секунд
            timer.Simple(5, function()
                if activeFights[fightID] then
                    activeFights[fightID] = nil
                    print("[Бои] Бой #" .. fightID .. " удален из клиентского списка")
                end
            end)
        end
    end)
end
