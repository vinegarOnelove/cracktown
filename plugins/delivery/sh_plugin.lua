local PLUGIN = PLUGIN

PLUGIN.name = "Phone Delivery System"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система заказа доставки предметов по телефону"

ix.phoneDelivery = ix.phoneDelivery or {
    config = {
        deliveryCost = 450, -- Стоимость звонка
        deliveryTime = 60, -- Время доставки в секундах
        maxActiveDeliveries = 3, -- Максимальное количество активных доставок
        deliveryRadius = 1500, -- Радиус поиска места доставки
        minDistanceFromPlayer = 500, -- Минимальное расстояние от игрока
        maxDistanceFromPlayer = 2000, -- Максимальное расстояние от игрока
        items = {
            "crack",
			"ether",
			"moonshine",
			"melee_akula",
			"vodka",
			"whiskey",
			"cocaine",
			"hoellenfeuer"
			
        } -- Список предметов для доставки
    }
}

PLUGIN.config = ix.phoneDelivery.config
PLUGIN.activeDeliveries = PLUGIN.activeDeliveries or {}

if SERVER then
    util.AddNetworkString("PhoneDeliveryStart")
    util.AddNetworkString("PhoneDeliveryComplete")
    util.AddNetworkString("PhoneDeliveryFailed")

    -- Функция для поиска подходящего места доставки
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

    -- Функция начала доставки
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
        
        -- Генерация уникального ID
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

    ix.command.Add("OrderDelivery", {
        description = "Заказать доставку предметов",
        OnRun = function(self, client)
            return PLUGIN:StartDelivery(client)
        end
    })

    hook.Add("PlayerDisconnected", "PhoneDeliveryDisconnect", function(ply)
        for id, delivery in pairs(PLUGIN.activeDeliveries) do
            if delivery.callerSteamID == ply:SteamID64() then
                PLUGIN:CancelDelivery(id)
            end
        end
    end)

    -- Связка для телефона
    ix.phoneDelivery.StartDelivery = function(caller)
        return PLUGIN:StartDelivery(caller)
    end
end

if CLIENT then
    local activeDeliveries = {}

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
end
