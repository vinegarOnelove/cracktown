local PLUGIN = PLUGIN

PLUGIN.name = "Phone Systems"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система заказа доставки и охоты за головами через телефон"

-- Конфигурация доставки
ix.phoneDelivery = ix.phoneDelivery or {
    config = {
        deliveryCost = 450,
        deliveryTime = 60,
        maxActiveDeliveries = 3,
        deliveryRadius = 1500,
        minDistanceFromPlayer = 500,
        maxDistanceFromPlayer = 2000,
        items = {
            "crack",
            "ether",
            "moonshine",
            "melee_akula",
            "vodka",
            "whiskey",
            "cocaine",
            "hoellenfeuer"
        }
    }
}

-- Конфигурация охоты за головами
PLUGIN.bountyConfig = {
    minBounty = 100,
    maxBounty = 10000,
    hunterClass = "citizen_bounty_hunter",
    contractDuration = 1800,
    maxActiveContracts = 3,
    serviceFee = 200
}

PLUGIN.config = ix.phoneDelivery.config
PLUGIN.activeDeliveries = PLUGIN.activeDeliveries or {}
PLUGIN.activeContracts = PLUGIN.activeContracts or {}
PLUGIN.contractHistory = PLUGIN.contractHistory or {}

-- Генерация уникального ID для контракта
local function GenerateContractID()
    return tostring(os.time()) .. tostring(math.random(1000, 9999))
end

-- Проверка: игрок охотник за головами?
function PLUGIN:IsBountyHunter(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    local char = ply:GetCharacter()
    if not char then return false end

    local classID = char:GetClass()
    local classData = ix.class.list[classID]
    if not classData then return false end

    return classData.uniqueID == self.bountyConfig.hunterClass
end

-- Проверка условий для создания контракта
function PLUGIN:CanCreateContract(client, target, bounty)
    if not IsValid(client) or not IsValid(target) then
        return false, "Недействительный игрок"
    end
    if client == target then
        return false, "Нельзя создать контракт на себя"
    end
    if not client:GetCharacter() then
        return false, "Нет персонажа"
    end
    if client:GetCharacter():GetMoney() < (bounty + self.bountyConfig.serviceFee) then
        return false, "Недостаточно денег"
    end
    if bounty < self.bountyConfig.minBounty or bounty > self.bountyConfig.maxBounty then
        return false, string.format("Награда должна быть от %d до %d",
            self.bountyConfig.minBounty, self.bountyConfig.maxBounty)
    end

    local activeCount = 0
    for _, contract in pairs(self.activeContracts) do
        if contract.client == client then
            activeCount = activeCount + 1
        end
    end
    if activeCount >= self.bountyConfig.maxActiveContracts then
        return false, "Достигнут лимит активных контрактов"
    end

    for _, contract in pairs(self.activeContracts) do
        if contract.target == target and contract.status == "active" then
            return false, "На этого игрока уже есть контракт"
        end
    end

    return true, ""
end

-- Создание контракта через телефон
function PLUGIN:CreateBountyContract(client, target, bounty)
    print("=== DEBUG: CreateBountyContract вызвана ===")
    print("DEBUG: Клиент:", client:Name(), "Цель:", target:Name(), "Награда:", bounty)
    
    local canCreate, reason = self:CanCreateContract(client, target, bounty)
    if not canCreate then
        print("DEBUG: Нельзя создать контракт:", reason)
        client:Notify(reason)
        return false, reason
    end

    client:GetCharacter():TakeMoney(bounty + self.bountyConfig.serviceFee)

    local contractID = GenerateContractID()
    self.activeContracts[contractID] = {
        id = contractID,
        client = client,
        clientName = client:Name(),
        target = target,
        targetName = target:Name(),
        bounty = bounty,
        createdTime = CurTime(),
        expireTime = CurTime() + self.bountyConfig.contractDuration,
        status = "active"
    }

    print("DEBUG: Контракт создан успешно! ID:", contractID)
    client:Notify(string.format("Контракт создан через телефон! Награда: ☋%d, Услуга: ☋%d", bounty, self.bountyConfig.serviceFee))
    target:Notify(string.format("На вас создан контракт! Награда: ☋%d", bounty))

    for _, ply in ipairs(player.GetAll()) do
        if self:IsBountyHunter(ply) then
            ply:Notify(string.format("Новый контракт: %s - ☋%d", target:Name(), bounty))
        end
    end

    timer.Create("bounty_contract_" .. contractID, self.bountyConfig.contractDuration, 1, function()
        if self.activeContracts[contractID] and self.activeContracts[contractID].status == "active" then
            self:ExpireContract(contractID)
        end
    end)

    return true, "Контракт создан"
end

-- Выполнение контракта
function PLUGIN:CompleteContract(contractID, killer)
    local contract = self.activeContracts[contractID]
    if not contract or contract.status ~= "active" then return false end
    if not IsValid(killer) or not killer:IsPlayer() then return false end

    if killer:GetCharacter() then
        killer:GetCharacter():GiveMoney(contract.bounty)
        killer:Notify("Контракт выполнен! Получено: ☋" .. contract.bounty)
    end
    if IsValid(contract.client) then
        contract.client:Notify("Ваш контракт выполнен игроком " .. killer:Name())
    end

    contract.status = "completed"
    contract.completedBy = killer
    self.contractHistory[#self.contractHistory + 1] = contract
    self.activeContracts[contractID] = nil
end

-- Истечение контракта
function PLUGIN:ExpireContract(contractID)
    local contract = self.activeContracts[contractID]
    if not contract or contract.status ~= "active" then return false end

    if IsValid(contract.client) and contract.client:GetCharacter() then
        contract.client:GetCharacter():GiveMoney(contract.bounty)
        contract.client:Notify("Контракт истёк! Деньги возвращены.")
    end

    contract.status = "expired"
    self.contractHistory[#self.contractHistory + 1] = contract
    self.activeContracts[contractID] = nil
end

-- Отмена контракта
function PLUGIN:CancelContract(contractID, reason)
    local contract = self.activeContracts[contractID]
    if not contract or contract.status ~= "active" then return false end

    if IsValid(contract.client) and contract.client:GetCharacter() then
        contract.client:GetCharacter():GiveMoney(contract.bounty)
        contract.client:Notify("Контракт отменён: " .. (reason or ""))
    end

    contract.status = "cancelled"
    contract.cancelReason = reason
    self.contractHistory[#self.contractHistory + 1] = contract
    self.activeContracts[contractID] = nil
end

if SERVER then
    util.AddNetworkString("PhoneDeliveryStart")
    util.AddNetworkString("PhoneDeliveryComplete")
    util.AddNetworkString("PhoneDeliveryFailed")
    util.AddNetworkString("PhoneBountyContract")
    util.AddNetworkString("BountyHunterListContracts")
    util.AddNetworkString("PhoneOpenBountyMenu")
    
    function PLUGIN:FindDeliveryPosition(caller)
        if not IsValid(caller) then return nil end
        
        local callerPos = caller:GetPos()
        local attempts = 0
        local maxAttempts = 50
        
        while attempts < maxAttempts do
            attempts = attempts + 1
            
            local randomAngle = math.random(0, 360)
            local randomDistance = math.random(self.config.minDistanceFromPlayer, self.config.maxDistanceFromPlayer)
            local randomPos = callerPos + Vector(
                math.cos(math.rad(randomAngle)) * randomDistance,
                math.sin(math.rad(randomAngle)) * randomDistance,
                0
            )
            
            local trace = util.TraceLine({
                start = randomPos + Vector(0, 0, 1000),
                endpos = randomPos - Vector(0, 0, 1000),
                mask = MASK_SOLID_BRUSHONLY
            })
            
            if trace.Hit and not trace.StartSolid then
                local surfacePos = trace.HitPos + Vector(0, 0, 5)
                
                local nearbyEnts = ents.FindInSphere(surfacePos, 100)
                local valid = true
                
                for _, ent in ipairs(nearbyEnts) do
                    if ent:IsPlayer() or ent:IsNPC() or ent:GetClass():find("prop_") then
                        valid = false
                        break
                    end
                end
                
                if valid then
                    return surfacePos
                end
            end
        end
        
        return nil
    end

    function PLUGIN:StartDelivery(caller)
        if not IsValid(caller) or not caller:GetCharacter() then return false end
        
        if table.Count(self.activeDeliveries) >= self.config.maxActiveDeliveries then
            caller:Notify("Все курьеры заняты, попробуйте позже!")
            return false
        end
        
        local character = caller:GetCharacter()
        if character:GetMoney() < self.config.deliveryCost then
            caller:Notify("Недостаточно денег для заказа доставки!")
            return false
        end
        
        character:TakeMoney(self.config.deliveryCost)
        
        local deliveryPos = self:FindDeliveryPosition(caller)
        if not deliveryPos then
            caller:Notify("Не удалось найти место для доставки!")
            character:GiveMoney(self.config.deliveryCost)
            return false
        end
        
        local deliveryID = tostring(os.time()) .. tostring(math.random(1000, 9999))
        local randomItem = table.Random(self.config.items)
        
        self.activeDeliveries[deliveryID] = {
            caller = caller,
            callerSteamID = caller:SteamID64(),
            position = deliveryPos,
            item = randomItem,
            startTime = CurTime(),
            endTime = CurTime() + self.config.deliveryTime,
            completed = false
        }
        
        caller:Notify("Заказ принят! Доставка будет через " .. self.config.deliveryTime .. " секунд.")
        
        net.Start("PhoneDeliveryStart")
        net.WriteString(deliveryID)
        net.WriteVector(deliveryPos)
        net.WriteString(randomItem)
        net.Send(caller)
        
        timer.Create("phone_delivery_" .. deliveryID, self.config.deliveryTime, 1, function()
            if self.activeDeliveries[deliveryID] and not self.activeDeliveries[deliveryID].completed then
                self:CompleteDelivery(deliveryID)
            end
        end)
        
        return true
    end

    function PLUGIN:CompleteDelivery(deliveryID)
        local delivery = self.activeDeliveries[deliveryID]
        if not delivery then return end
        
        local box = ents.Create("ix_delivery_box")
        if IsValid(box) then
            box:SetPos(delivery.position)
            box:SetAngles(Angle(0, math.random(0, 360), 0))
            box:SetDeliveryData(delivery.item, delivery.caller)
            box:Spawn()
            
            local phys = box:GetPhysicsObject()
            if IsValid(phys) then
                phys:Wake()
            end
        end
        
        if IsValid(delivery.caller) then
            delivery.caller:Notify("Доставка прибыла! Проверьте указанное место.")
            
            net.Start("PhoneDeliveryComplete")
            net.WriteString(deliveryID)
            net.WriteVector(delivery.position)
            net.Send(delivery.caller)
        end
        
        delivery.completed = true
        self.activeDeliveries[deliveryID] = nil
    end

    function PLUGIN:CancelDelivery(deliveryID)
        local delivery = self.activeDeliveries[deliveryID]
        if not delivery then return end
        
        if IsValid(delivery.caller) then
            delivery.caller:Notify("Доставка отменена!")
            
            net.Start("PhoneDeliveryFailed")
            net.WriteString(deliveryID)
            net.Send(delivery.caller)
        end
        
        self.activeDeliveries[deliveryID] = nil
        timer.Remove("phone_delivery_" .. deliveryID)
    end

    net.Receive("PhoneBountyContract", function(len, ply)
        print("=== DEBUG: Получен сетевой запрос PhoneBountyContract ===")
        local targetSteamID = net.ReadString()
        local bounty = net.ReadUInt(32)
        
        print("DEBUG: Запрос от игрока:", ply:Name(), "SteamID:", ply:SteamID())
        print("DEBUG: Ищем цель по SteamID:", targetSteamID)
        print("DEBUG: Награда:", bounty)
        
        -- Ищем игрока по SteamID
        local target
        for _, player in ipairs(player.GetAll()) do
            print("DEBUG: Проверяем игрока:", player:Name(), "SteamID:", player:SteamID())
            if player:SteamID() == targetSteamID then
                target = player
                print("DEBUG: Цель найдена:", target:Name())
                break
            end
        end
        
        if not IsValid(target) then
            print("DEBUG: ОШИБКА: Цель не найдена по SteamID:", targetSteamID)
            print("DEBUG: Все онлайн игроки:")
            for _, p in ipairs(player.GetAll()) do
                print("  ", p:Name(), "- SteamID:", p:SteamID())
            end
            ply:Notify("Цель не найдена!")
            return
        end
        
        if ply == target then
            print("DEBUG: ОШИБКА: Попытка создать контракт на себя")
            ply:Notify("Нельзя создать контракт на себя!")
            return
        end
        
        print("DEBUG: Создаем контракт - Клиент:", ply:Name(), "Цель:", target:Name(), "Награда:", bounty)
        PLUGIN:CreateBountyContract(ply, target, bounty)
    end)

    ix.phoneDelivery.StartDelivery = function(caller)
        return PLUGIN:StartDelivery(caller)
    end
    
    ix.phoneBounty = ix.phoneBounty or {}
    ix.phoneBounty.StartContract = function(caller, target, bounty)
        return PLUGIN:CreateBountyContract(caller, target, bounty)
    end

    ix.command.Add("OrderDelivery", {
        description = "Заказать доставку предметов",
        OnRun = function(self, client)
            return PLUGIN:StartDelivery(client)
        end
    })

    ix.command.Add("BountyContract", {
        description = "Создать контракт на игрока",
        arguments = {ix.type.player, ix.type.number},
        OnRun = function(_, client, target, bounty)
            return select(2, PLUGIN:CreateBountyContract(client, target, bounty))
        end
    })

    ix.command.Add("BountyList", {
        description = "Просмотреть активные контракты",
        OnRun = function(_, client)
            if not PLUGIN:IsBountyHunter(client) then
                return "Только для охотников"
            end

            net.Start("BountyHunterListContracts")
            local active = {}
            for _, contract in pairs(PLUGIN.activeContracts) do
                if contract.status == "active" then
                    active[#active + 1] = contract
                end
            end
            net.WriteUInt(#active, 16)
            for _, c in ipairs(active) do
                net.WriteString(c.id)
                net.WriteString(c.targetName)
                net.WriteUInt(c.bounty, 32)
                net.WriteFloat(c.expireTime - CurTime())
                net.WriteString(c.clientName)
            end
            net.Send(client)
        end
    })

    hook.Add("PlayerDisconnected", "PhoneDeliveryDisconnect", function(ply)
        for id, delivery in pairs(PLUGIN.activeDeliveries) do
            if delivery.callerSteamID == ply:SteamID64() then
                PLUGIN:CancelDelivery(id)
            end
        end
    end)

    hook.Add("PlayerDeath", "BountyHunterDeath", function(victim, inflictor, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() then return end
        if attacker == victim then return end

        for id, contract in pairs(PLUGIN.activeContracts) do
            if IsValid(contract.target) and contract.target == victim and contract.status == "active" then
                if PLUGIN:IsBountyHunter(attacker) then
                    PLUGIN:CompleteContract(id, attacker)
                end
            end
        end
    end)
end

if CLIENT then
    local activeDeliveries = {}
    local contracts = {}

    net.Receive("PhoneDeliveryStart", function()
        local deliveryID = net.ReadString()
        local position = net.ReadVector()
        local item = net.ReadString()
        
        activeDeliveries[deliveryID] = {
            position = position,
            item = item,
            startTime = CurTime(),
            markerVisible = true
        }
        
        hook.Add("PostDrawTranslucentRenderables", "PhoneDeliveryMarkers", function()
            for id, delivery in pairs(activeDeliveries) do
                if delivery.markerVisible then
                    local timeLeft = math.max(0, delivery.startTime + PLUGIN.config.deliveryTime - CurTime())
                    
                    render.SetColorMaterial()
                    render.DrawSphere(delivery.position, 30, 30, 30, Color(0, 255, 0, 100))
                    
                    local ang = EyeAngles()
                    ang:RotateAroundAxis(ang:Up(), -90)
                    ang:RotateAroundAxis(ang:Forward(), 90)
                    
                    cam.Start3D2D(delivery.position + Vector(0, 0, 50), ang, 0.1)
                        draw.SimpleText("Доставка", "DermaDefaultBold", 0, -20, Color(0, 255, 0), TEXT_ALIGN_CENTER)
                        draw.SimpleText("Предмет: " .. delivery.item, "DermaDefault", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                        draw.SimpleText("Осталось: " .. math.Round(timeLeft) .. "с", "DermaDefault", 0, 20, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                    cam.End3D2D()
                end
            end
        end)
    end)

    net.Receive("PhoneDeliveryComplete", function()
        local deliveryID = net.ReadString()
        local position = net.ReadVector()
        
        if activeDeliveries[deliveryID] then
            activeDeliveries[deliveryID].markerVisible = false
            activeDeliveries[deliveryID] = nil
        end
        
        surface.PlaySound("buttons/button14.wav")
    end)

    net.Receive("PhoneDeliveryFailed", function()
        local deliveryID = net.ReadString()
        
        if activeDeliveries[deliveryID] then
            activeDeliveries[deliveryID] = nil
        end
        
        surface.PlaySound("buttons/button10.wav")
    end)

    net.Receive("BountyHunterListContracts", function()
        contracts = {}
        local count = net.ReadUInt(16)
        for i = 1, count do
            contracts[i] = {
                id = net.ReadString(),
                targetName = net.ReadString(),
                reward = net.ReadUInt(32),
                timeLeft = net.ReadFloat(),
                clientName = net.ReadString()
            }
        end

        local frame = vgui.Create("DFrame")
        frame:SetSize(700, 400)
        frame:Center()
        frame:SetTitle("Контракты")
        frame:MakePopup()

        local list = vgui.Create("DListView", frame)
        list:Dock(FILL)
        list:AddColumn("ID")
        list:AddColumn("Цель")
        list:AddColumn("Награда")
        list:AddColumn("Осталось")
        list:AddColumn("Заказчик")

        for _, c in ipairs(contracts) do
            local mins = math.floor(c.timeLeft / 60)
            local secs = math.floor(c.timeLeft % 60)
            local timeText = string.format("%02d:%02d", mins, secs)
            list:AddLine(c.id, c.targetName, "☋" .. c.reward, timeText, c.clientName)
        end
    end)
end