local PLUGIN = PLUGIN

PLUGIN.name = "Wanted System"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система розыска преступников для полиции"

-- Конфигурация системы розыска
PLUGIN.wantedConfig = {
    policeFactions = {
        ["Полицейский департамент"] = true  -- Только эта фракция имеет доступ
    },
    minBounty = 100,
    maxBounty = 5000,
    minDuration = 300, -- 5 минут
    maxDuration = 3600, -- 1 час
    maxActiveWanted = 10
}

PLUGIN.activeWanted = PLUGIN.activeWanted or {}
PLUGIN.wantedHistory = PLUGIN.wantedHistory or {}

-- Проверка, является ли игрок полицейским
function PLUGIN:IsPolice(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return false end
    
    local character = ply:GetCharacter()
    local factionID = character:GetFaction()
    local factionData = ix.faction.indices[factionID]
    
    if not factionData then return false end
    
    -- Проверяем по имени фракции
    return self.wantedConfig.policeFactions[factionData.name] or false
end

-- Отладочная функция для проверки фракции игрока
function PLUGIN:DebugPlayerFaction(ply)
    if not IsValid(ply) or not ply:GetCharacter() then return end
    
    local character = ply:GetCharacter()
    local factionID = character:GetFaction()
    local factionData = ix.faction.indices[factionID]
    
    print("=== DEBUG: Информация о фракции игрока ===")
    print("Игрок:", ply:Name())
    print("Faction ID:", factionID)
    
    if factionData then
        print("Faction Name:", factionData.name)
        print("Faction UniqueID:", factionData.uniqueID)
        print("Is Police:", self:IsPolice(ply))
    end
    print("=========================================")
end

-- Генерация уникального ID для розыска
local function GenerateWantedID()
    return "W" .. tostring(os.time()) .. tostring(math.random(1000, 9999))
end

-- Проверка условий для объявления в розыск
function PLUGIN:CanCreateWanted(issuer, target, reason, bounty, duration)
    if not IsValid(issuer) or not IsValid(target) then
        return false, "Недействительный игрок"
    end
    
    if not self:IsPolice(issuer) then
        return false, "Только полиция может объявлять в розыск"
    end
    
    if issuer == target then
        return false, "Нельзя объявить в розыск себя"
    end
    
    if not reason or #reason < 5 then
        return false, "Укажите причину розыска (мин. 5 символов)"
    end
    
    if bounty < self.wantedConfig.minBounty or bounty > self.wantedConfig.maxBounty then
        return false, string.format("Награда должна быть от %d до %d", 
            self.wantedConfig.minBounty, self.wantedConfig.maxBounty)
    end
    
    if duration < self.wantedConfig.minDuration or duration > self.wantedConfig.maxDuration then
        return false, string.format("Срок розыска должен быть от %d до %d минут", 
            self.wantedConfig.minDuration/60, self.wantedConfig.maxDuration/60)
    end
    
    -- Проверяем, достаточно ли денег у игрока
    local character = issuer:GetCharacter()
    if not character then return false, "Нет персонажа" end
    
    if character:GetMoney() < bounty then
        return false, string.format("Недостаточно денег. Нужно: ☋%d", bounty)
    end
    
    -- Проверяем, не в розыске ли уже цель
    for _, wanted in pairs(self.activeWanted) do
        if wanted.target == target and wanted.status == "active" then
            return false, "Этот игрок уже в розыске"
        end
    end
    
    -- Проверяем лимит активных розысков
    if table.Count(self.activeWanted) >= self.wantedConfig.maxActiveWanted then
        return false, "Достигнут лимит активных розысков"
    end
    
    return true, ""
end

-- Объявление игрока в розыск
function PLUGIN:CreateWanted(issuer, target, reason, bounty, duration)
    local canCreate, errorMsg = self:CanCreateWanted(issuer, target, reason, bounty, duration)
    if not canCreate then
        if IsValid(issuer) then
            issuer:Notify(errorMsg)
        end
        return false, errorMsg
    end

    -- Списываем деньги с игрока
    local character = issuer:GetCharacter()
    character:TakeMoney(bounty)

    local wantedID = GenerateWantedID()
    local endTime = CurTime() + duration

    self.activeWanted[wantedID] = {
        id = wantedID,
        issuer = issuer,
        issuerName = issuer:Name(),
        target = target,
        targetName = target:Name(),
        reason = reason,
        bounty = bounty,
        createdTime = CurTime(),
        endTime = endTime,
        status = "active"
    }

    -- Уведомления
    if IsValid(issuer) then
        issuer:Notify(string.format("Розыск объявлен: %s. Списанно: ☋%d", target:Name(), bounty))
    end
    
    if IsValid(target) then
        target:Notify("Вас объявили в розыск! Причина: " .. reason)
    end

    -- Уведомление всей полиции
    for _, ply in ipairs(player.GetAll()) do
        if self:IsPolice(ply) then
            ply:Notify(string.format("Новый розыск: %s - ☋%d - %s", target:Name(), bounty, reason))
        end
    end

    -- Таймер завершения розыска
    timer.Create("wanted_expire_" .. wantedID, duration, 1, function()
        if self.activeWanted[wantedID] and self.activeWanted[wantedID].status == "active" then
            self:ExpireWanted(wantedID)
        end
    end)

    return true, wantedID
end

-- Завершение розыска (убийство преступника)
function PLUGIN:CompleteWanted(wantedID, killer)
    local wanted = self.activeWanted[wantedID]
    if not wanted or wanted.status ~= "active" then return false end
    
    -- Проверяем, является ли убийца полицейским
    if not IsValid(killer) or not killer:IsPlayer() or not self:IsPolice(killer) then
        if IsValid(killer) then
            killer:Notify("Награда за розыск доступна только полиции")
        end
        return false
    end
    
    -- Выплачиваем награду убийце
    if killer:GetCharacter() then
        killer:GetCharacter():GiveMoney(wanted.bounty)
        killer:Notify(string.format("Розыск выполнен! Получено: ☋%d", wanted.bounty))
    end
    
    if IsValid(wanted.target) then
        wanted.target:Notify("Вас сняли с розыска")
    end
    
    if IsValid(wanted.issuer) then
        wanted.issuer:Notify(string.format("Ваш розыск выполнен: %s убит", wanted.targetName))
    end
    
    wanted.status = "completed"
    wanted.completedBy = killer
    wanted.completedTime = CurTime()
    self.wantedHistory[#self.wantedHistory + 1] = wanted
    self.activeWanted[wantedID] = nil
    
    timer.Remove("wanted_expire_" .. wantedID)
    
    return true
end

-- Снятие розыска вручную
function PLUGIN:CancelWanted(wantedID, cop)
    local wanted = self.activeWanted[wantedID]
    if not wanted or wanted.status ~= "active" then return false end
    
    -- Проверяем, является ли снимающий полицейским
    if not IsValid(cop) or not cop:IsPlayer() or not self:IsPolice(cop) then
        return false
    end
    
    -- Возвращаем деньги заказчику
    if IsValid(wanted.issuer) and wanted.issuer:GetCharacter() then
        wanted.issuer:GetCharacter():GiveMoney(wanted.bounty)
        wanted.issuer:Notify(string.format("Розыск отменен. Возвращено: ☋%d", wanted.bounty))
    end
    
    if IsValid(wanted.target) then
        wanted.target:Notify("Вас сняли с розыска")
    end
    
    wanted.status = "cancelled"
    wanted.cancelledBy = cop
    wanted.cancelledTime = CurTime()
    self.wantedHistory[#self.wantedHistory + 1] = wanted
    self.activeWanted[wantedID] = nil
    
    timer.Remove("wanted_expire_" .. wantedID)
    
    return true
end

-- Истечение срока розыска
function PLUGIN:ExpireWanted(wantedID)
    local wanted = self.activeWanted[wantedID]
    if not wanted or wanted.status ~= "active" then return false end
    
    -- Возвращаем деньги заказчику при истечении срока
    if IsValid(wanted.issuer) and wanted.issuer:GetCharacter() then
        wanted.issuer:GetCharacter():GiveMoney(wanted.bounty)
        wanted.issuer:Notify(string.format("Срок розыска истек. Возвращено: ☋%d", wanted.bounty))
    end
    
    if IsValid(wanted.target) then
        wanted.target:Notify("Срок вашего розыска истек")
    end
    
    wanted.status = "expired"
    wanted.expiredTime = CurTime()
    self.wantedHistory[#self.wantedHistory + 1] = wanted
    self.activeWanted[wantedID] = nil
    
    return true
end

-- Получение активных розысков
function PLUGIN:GetActiveWanted()
    local active = {}
    for _, wanted in pairs(self.activeWanted) do
        if wanted.status == "active" then
            table.insert(active, wanted)
        end
    end
    return active
end

-- Проверка, в розыске ли игрок
function PLUGIN:IsPlayerWanted(ply)
    if not IsValid(ply) then return false end
    
    for _, wanted in pairs(self.activeWanted) do
        if wanted.target == ply and wanted.status == "active" then
            return true, wanted
        end
    end
    
    return false
end

if SERVER then
    util.AddNetworkString("WantedOpenMenu")
    util.AddNetworkString("WantedCreate")
    util.AddNetworkString("WantedListOpen")
    util.AddNetworkString("WantedListData")
    util.AddNetworkString("WantedComplete")
    util.AddNetworkString("WantedCancel")
    util.AddNetworkString("WantedDebugFaction")
    util.AddNetworkString("WantedAccessDenied")
    util.AddNetworkString("WantedMenuData")
    
    -- Команда для отладки фракции
    ix.command.Add("debugfaction", {
        description = "Отладочная информация о фракции",
        OnRun = function(self, client)
            PLUGIN:DebugPlayerFaction(client)
            return "Информация выведена в консоль сервера"
        end
    })
    
    -- Обработка использования доски розыска
    net.Receive("WantedListOpen", function(len, ply)
        if not PLUGIN:IsPolice(ply) then 
            net.Start("WantedAccessDenied")
            net.WriteString("Доступно только для полиции")
            net.Send(ply)
            return 
        end
        
        local activeWanted = PLUGIN:GetActiveWanted()
        
        net.Start("WantedListData")
        net.WriteUInt(#activeWanted, 16)
        
        for _, wanted in ipairs(activeWanted) do
            net.WriteString(wanted.targetName)
            net.WriteString(wanted.reason)
            net.WriteUInt(wanted.bounty, 32)
            net.WriteFloat(wanted.endTime - CurTime())
            net.WriteString(wanted.issuerName)
            net.WriteString(wanted.id)
        end
        
        net.Send(ply)
    end)
    
    -- Обработка запроса на открытие меню
    net.Receive("WantedOpenMenu", function(len, ply)
        if not PLUGIN:IsPolice(ply) then 
            net.Start("WantedAccessDenied")
            net.WriteString("Доступно только для полиции")
            net.Send(ply)
            return 
        end
        
        -- Отправляем данные для меню создания розыска
        net.Start("WantedMenuData")
        net.Send(ply)
    end)
    
    -- Обработка создания розыска
    net.Receive("WantedCreate", function(len, ply)
        if not PLUGIN:IsPolice(ply) then 
            net.Start("WantedAccessDenied")
            net.WriteString("Доступно только для полиции")
            net.Send(ply)
            return 
        end
        
        local targetSteamID = net.ReadString()
        local reason = net.ReadString()
        local bounty = net.ReadUInt(32)
        local duration = net.ReadUInt(32)
        
        -- Находим цель по SteamID
        local target
        for _, player in ipairs(player.GetAll()) do
            if player:SteamID() == targetSteamID then
                target = player
                break
            end
        end
        
        if not IsValid(target) then
            ply:Notify("Цель не найдена!")
            return
        end
        
        PLUGIN:CreateWanted(ply, target, reason, bounty, duration)
    end)
    
    -- Обработка завершения розыска
    net.Receive("WantedComplete", function(len, ply)
        if not PLUGIN:IsPolice(ply) then 
            net.Start("WantedAccessDenied")
            net.WriteString("Доступно только для полиции")
            net.Send(ply)
            return 
        end
        
        local wantedID = net.ReadString()
        PLUGIN:CompleteWanted(wantedID, ply)
    end)
    
    -- Обработка отмены розыска
    net.Receive("WantedCancel", function(len, ply)
        if not PLUGIN:IsPolice(ply) then 
            net.Start("WantedAccessDenied")
            net.WriteString("Доступно только для полиции")
            net.Send(ply)
            return 
        end
        
        local wantedID = net.ReadString()
        PLUGIN:CancelWanted(wantedID, ply)
    end)
    
    -- Обработка убийства преступника
    hook.Add("PlayerDeath", "WantedSystemKill", function(victim, inflictor, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
        
        -- Проверяем, является ли жертва в розыске
        local isWanted, wantedData = PLUGIN:IsPlayerWanted(victim)
        if not isWanted then return end
        
        -- Выплачиваем награду за убийство преступника (только полиции)
        PLUGIN:CompleteWanted(wantedData.id, attacker)
    end)
    
    -- Автоматическое снятие розыска при аресте
    hook.Add("PlayerArrested", "WantedSystemArrest", function(arrested, time, cop)
        if not IsValid(cop) or not cop:IsPlayer() then return end
        
        local isWanted, wantedData = PLUGIN:IsPlayerWanted(arrested)
        if isWanted then
            -- При аресте не выплачиваем награду, просто снимаем розыск
            PLUGIN:CancelWanted(wantedData.id, cop)
            cop:Notify("Преступник арестован. Розыск снят.")
        end
    end)
end

if CLIENT then
    -- Безопасная проверка класса entity
    local function SafeGetClass(ent)
        if not IsValid(ent) then return "invalid" end
        if not isfunction(ent.GetClass) then return "no_getclass" end
        return ent:GetClass() or "unknown"
    end

    -- Обработка данных для меню создания розыска
    net.Receive("WantedMenuData", function()
        OpenWantedMenu()
    end)
    
    -- Обработка отказа в доступе
    net.Receive("WantedAccessDenied", function()
        local reason = net.ReadString()
        LocalPlayer():Notify(reason)
    end)
    
    -- Обработка данных списка розысков
    net.Receive("WantedListData", function()
        local count = net.ReadUInt(16)
        OpenWantedList(count)
    end)
    
    -- Хук для tooltip доски розыска
    hook.Add("PopulateEntityInfo", "ixWantedBoardInfo", function(tooltip, ent)
        if not IsValid(ent) then return end
        if SafeGetClass(ent) ~= "ix_wanted_board" then return end
        
        -- Заголовок
        local name = tooltip:AddRow("name")
        name:SetText("Доска розыска")
        name:SetBackgroundColor(Color(0, 0, 80))
        name:SetImportant()
        name:SizeToContents()
        
        -- Описание
        local desc = tooltip:AddRow("description")
        desc:SetText("Полицейская система розыска преступников")
        desc:SetBackgroundColor(Color(0, 0, 60))
        desc:SizeToContents()
        
        -- Инструкция
        local info = tooltip:AddRow("info")
        info:SetText("Нажмите E для просмотра активных розысков")
        info:SetBackgroundColor(Color(0, 0, 70))
        info:SizeToContents()
        
        -- Доступ
        local access = tooltip:AddRow("access")
        access:SetText("Доступно только для полиции")
        access:SetBackgroundColor(Color(0, 60, 0))
        access:SizeToContents()
    end)
    
    -- Открытие меню создания розыска
    function OpenWantedMenu()
        local frame = vgui.Create("DFrame")
        frame:SetSize(450, 400)
        frame:SetTitle("Объявление в розыск")
        frame:Center()
        frame:MakePopup()
        
        local playerList = vgui.Create("DComboBox", frame)
        playerList:SetPos(20, 40)
        playerList:SetSize(410, 30)
        playerList:SetValue("Выберите преступника")
        
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= LocalPlayer() then
                local isWanted = PLUGIN:IsPlayerWanted(ply)
                if not isWanted then
                    playerList:AddChoice(ply:Name() .. " (" .. ply:SteamID() .. ")", ply:SteamID())
                end
            end
        end
        
        local reasonEntry = vgui.Create("DTextEntry", frame)
        reasonEntry:SetPos(20, 90)
        reasonEntry:SetSize(410, 30)
        reasonEntry:SetPlaceholderText("Причина розыска")
        
        local bountySlider = vgui.Create("DNumSlider", frame)
        bountySlider:SetPos(20, 140)
        bountySlider:SetSize(410, 50)
        bountySlider:SetText("Награда за поимку")
        bountySlider:SetMin(PLUGIN.wantedConfig.minBounty)
        bountySlider:SetMax(PLUGIN.wantedConfig.maxBounty)
        bountySlider:SetDecimals(0)
        bountySlider:SetValue(1000)
        
        local durationSlider = vgui.Create("DNumSlider", frame)
        durationSlider:SetPos(20, 210)
        durationSlider:SetSize(410, 50)
        durationSlider:SetText("Срок розыска")
        durationSlider:SetMin(PLUGIN.wantedConfig.minDuration / 60)
        durationSlider:SetMax(PLUGIN.wantedConfig.maxDuration / 60)
        durationSlider:SetDecimals(0)
        durationSlider:SetValue(15)
        
        -- Отображение текущего баланс
        local balanceLabel = vgui.Create("DLabel", frame)
        balanceLabel:SetPos(20, 270)
        balanceLabel:SetSize(410, 20)
        balanceLabel:SetText("Ваш баланс: ☋" .. (LocalPlayer():GetCharacter() and LocalPlayer():GetCharacter():GetMoney() or 0))
        balanceLabel:SetFont("DermaDefaultBold")
        
        local createButton = vgui.Create("DButton", frame)
        createButton:SetPos(20, 300)
        createButton:SetSize(410, 40)
        createButton:SetText("Объявить в розыск")
        createButton.DoClick = function()
            local _, targetSteamID = playerList:GetSelected()
            local reason = reasonEntry:GetText()
            local bounty = bountySlider:GetValue()
            local duration = durationSlider:GetValue() * 60 -- конвертируем в секунды
            
            if not targetSteamID then
                LocalPlayer():Notify("Выберите преступника!")
                return
            end
            
            if not reason or #reason < 5 then
                LocalPlayer():Notify("Укажите причину розыска")
                return
            end
            
            net.Start("WantedCreate")
            net.WriteString(targetSteamID)
            net.WriteString(reason)
            net.WriteUInt(bounty, 32)
            net.WriteUInt(duration, 32)
            net.SendToServer()
            
            frame:Close()
        end
    end
    
    -- Открытие списка активных розысков
    function OpenWantedList(count)
        local frame = vgui.Create("DFrame")
        frame:SetSize(700, 400)
        frame:SetTitle("Активные розыски - Полиция")
        frame:Center()
        frame:MakePopup()
        
        local list = vgui.Create("DListView", frame)
        list:Dock(FILL)
        list:AddColumn("Преступник")
        list:AddColumn("Причина")
        list:AddColumn("Награда")
        list:AddColumn("Осталось")
        list:AddColumn("Объявил")
        
        for i = 1, count do
            local targetName = net.ReadString()
            local reason = net.ReadString()
            local bounty = net.ReadUInt(32)
            local timeLeft = net.ReadFloat()
            local issuerName = net.ReadString()
            local wantedID = net.ReadString()
            
            local mins = math.floor(timeLeft / 60)
            local secs = math.floor(timeLeft % 60)
            local timeText = string.format("%02d:%02d", mins, secs)
            
            local line = list:AddLine(targetName, reason, "☋" .. bounty, timeText, issuerName)
            line.wantedID = wantedID
        end
        
        local completeButton = vgui.Create("DButton", frame)
        completeButton:SetPos(5, 365)
        completeButton:SetSize(150, 30)
        completeButton:SetText("Снять с розыска")
        completeButton.DoClick = function()
            local selectedLine = list:GetSelectedLine()
            if not selectedLine then 
                LocalPlayer():Notify("Выберите розыск из списка!")
                return 
            end
            
            local wantedID = list:GetLine(selectedLine).wantedID
            if wantedID then
                net.Start("WantedCancel")
                net.WriteString(wantedID)
                net.SendToServer()
                frame:Close()
            end
        end
        
        local createButton = vgui.Create("DButton", frame)
        createButton:SetPos(160, 365)
        createButton:SetSize(150, 30)
        createButton:SetText("Новый розыск")
        createButton.DoClick = function()
            frame:Close()
            net.Start("WantedOpenMenu")
            net.SendToServer()
        end
    end
    
    -- Обработка открытия списка розысков
    net.Receive("WantedListOpen", function()
        net.Start("WantedListOpen")
        net.SendToServer()
    end)
end

