local PLUGIN = PLUGIN

PLUGIN.name = "police_car_spawner"
PLUGIN.author = "Your Name"
PLUGIN.description = "Позволяет полицейским спавнить машины при нажатии на специальную энтити"

-- Конфигурация
PLUGIN.config = {
    policeFactions = {
        ["POLICE"] = true,      -- Используем строковые имена фракций
        ["CP"] = true,          
        ["OTA"] = true          
    },
    spawnCooldown = 60,               
    maxCarsPerPlayer = 2,             
    carModels = {
        "models/props_vehicles/shr/policemonaco_01glide.mdl",  -- Основная модель полицейской машины
        "models/tdmcars/ford_police.mdl",  -- Запасные модели
        "models/tdmcars/chev_impala_09_pol.mdl",
        "models/tdmcars/dodge_charger_08_pol.mdl"
    }
}

if SERVER then
    util.AddNetworkString("PoliceCarSpawnerOpenMenu")
    util.AddNetworkString("PoliceCarSpawnerSpawnCar")

    -- Функция проверки фракции игрока
    function PLUGIN:IsPoliceFaction(ply)
        if not IsValid(ply) or not ply:GetCharacter() then return false end
        
        local faction = ply:GetCharacter():GetFaction()
        return self.config.policeFactions[faction] or false
    end

    -- Функция безопасного спавна машины
    function PLUGIN:SafeSpawnVehicle(model, pos, ang, owner)
        -- Проверяем существование модели
        if not util.IsValidModel(model) then
            ErrorNoHalt("Модель " .. model .. " не существует или не загружена!")
            return nil
        end

        -- Пытаемся создать машину
        local car = ents.Create("monaco_police_glide")
        if not IsValid(car) then
            ErrorNoHalt("Не удалось создать энтити vehicle_jeep!")
            return nil
        end

        car:SetModel(model)
        car:SetKeyValue("vehiclescript", "scripts/vehicles/jeep_test.txt")  -- Базовый скрипт
        car:SetPos(pos)
        car:SetAngles(ang)
        car:Spawn()
        car:Activate()

        -- Настраиваем свойства машины
        car:SetColor(Color(0, 50, 200))
        car:SetNWEntity("PoliceCarOwner", owner)
        
        -- Сохраняем фракцию как строку
        local faction = owner:GetCharacter():GetFaction()
        car:SetNWString("PoliceCarFaction", faction)

        -- Делаем машину непереворачиваемой
        local phys = car:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetMass(5000)
            phys:EnableMotion(true)
        end

        return car
    end

    -- Обработка запроса на спавн машины
    net.Receive("PoliceCarSpawnerSpawnCar", function(len, ply)
        if not IsValid(ply) then return end
        
        -- Проверка прав доступа через функцию плагина
        if not PLUGIN:IsPoliceFaction(ply) then
            ply:Notify("Доступ запрещен! Только для полиции.")
            return
        end

        -- Проверка перезарядки
        local lastUse = ply:GetNetVar("policeCarLastUse", 0)
        if CurTime() - lastUse < PLUGIN.config.spawnCooldown then
            ply:Notify("Перезарядка!")
            return
        end

        -- Проверка лимита машин
        local carCount = ply:GetNetVar("policeCarCount", 0)
        if carCount >= PLUGIN.config.maxCarsPerPlayer then
            ply:Notify("Лимит машин достигнут!")
            return
        end

        -- Получаем выбранную модель
        local modelIndex = net.ReadUInt(8)
        local model = PLUGIN.config.carModels[modelIndex]
        
        if not model then
            ply:Notify("Неверная модель машины!")
            return
        end

        -- Спавним машину
        local trace = ply:GetEyeTraceNoCursor()
        local spawnPos = trace.HitPos + trace.HitNormal * 50
        spawnPos = spawnPos + ply:GetAimVector() * 200

        -- Проверяем, есть ли достаточно места
        local traceCheck = util.TraceHull({
            start = spawnPos,
            endpos = spawnPos,
            mins = Vector(-80, -180, 0),
            maxs = Vector(80, 180, 60),
            filter = ply
        })

        if traceCheck.Hit then
            ply:Notify("Недостаточно места для спавна машины!")
            return
        end

        -- Создаем машину с обработкой ошибок
        local car = PLUGIN:SafeSpawnVehicle(model, spawnPos, Angle(0, ply:EyeAngles().y, 0), ply)
        
        if not IsValid(car) then
            ply:Notify("Ошибка при создании машины! Попробуйте другую модель.")
            return
        end

        -- Обновляем счетчик машин игрока
        ply:SetNetVar("policeCarLastUse", CurTime())
        ply:SetNetVar("policeCarCount", carCount + 1)

        -- Сообщение об успехе
        ply:Notify("Полицейская машина '" .. model .. "' создана!")

        -- Хук для удаления машины при выходе игрока
        car:CallOnRemove("PoliceCarCleanup", function()
            local owner = car:GetNWEntity("PoliceCarOwner")
            if IsValid(owner) then
                local newCount = owner:GetNetVar("policeCarCount", 0) - 1
                owner:SetNetVar("policeCarCount", math.max(0, newCount))
            end
        end)
    end)

    -- Команда для спавна спавнера
    ix.command.Add("PoliceSpawnerCreate", {
        description = "Создать спавнер полицейских машин",
        adminOnly = true,
        OnRun = function(self, client)
            local trace = client:GetEyeTraceNoCursor()
            local pos = trace.HitPos + trace.HitNormal * 10
            
            local spawner = ents.Create("police_car_spawner")
            spawner:SetPos(pos)
            spawner:SetAngles(Angle(0, client:EyeAngles().y, 0))
            spawner:Spawn()
            
            return "Спавнер полицейских машин создан!"
        end
    })

else
    -- Клиентская часть
    net.Receive("PoliceCarSpawnerOpenMenu", function()
        PLUGIN:OpenCarMenu()
    end)

    function PLUGIN:OpenCarMenu()
        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 300)
        frame:SetTitle("Выбор полицейской машины")
        frame:Center()
        frame:MakePopup()

        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)

        for i, model in ipairs(PLUGIN.config.carModels) do
            local btn = scroll:Add("DButton")
            btn:Dock(TOP)
            btn:DockMargin(5, 5, 5, 0)
            btn:SetTall(60)
            btn:SetText("")

            btn.Paint = function(self, w, h)
                surface.SetDrawColor(0, 50, 100, 200)
                surface.DrawRect(0, 0, w, h)
                
                surface.SetDrawColor(0, 100, 200, 255)
                surface.DrawOutlinedRect(0, 0, w, h)
                
                draw.SimpleText("Полицейская машина #" .. i, "DermaDefaultBold", 10, 10, Color(255, 255, 255))
                draw.SimpleText(model, "DermaDefault", 10, 30, Color(200, 200, 200))
            end

            btn.DoClick = function()
                frame:Close()
                net.Start("PoliceCarSpawnerSpawnCar")
                net.WriteUInt(i, 8)
                net.SendToServer()
            end
        end

        -- Информация о лимитах
        local info = frame:Add("DPanel")
        info:Dock(BOTTOM)
        info:SetTall(40)
        info:DockMargin(5, 5, 5, 5)

        info.Paint = function(self, w, h)
            draw.SimpleText("Лимит: " .. LocalPlayer():GetNetVar("policeCarCount", 0) .. "/" .. PLUGIN.config.maxCarsPerPlayer, "DermaDefault", 10, 10, Color(255, 255, 255))
            
            local lastUse = LocalPlayer():GetNetVar("policeCarLastUse", 0)
            if lastUse > 0 then
                local timeLeft = math.ceil(PLUGIN.config.spawnCooldown - (CurTime() - lastUse))
                if timeLeft > 0 then
                    draw.SimpleText("Перезарядка: " .. timeLeft .. "с", "DermaDefault", 10, 25, Color(255, 100, 100))
                else
                    draw.SimpleText("Готово к использованию", "DermaDefault", 10, 25, Color(100, 255, 100))
                end
            end
        end
    end

    -- Отображение информации о машинах при наведении
    hook.Add("HUDPaint", "PoliceCarInfo", function()
        local trace = LocalPlayer():GetEyeTrace()
        if not IsValid(trace.Entity) then return end
        
        local car = trace.Entity
        if car:GetClass() == "monaco_police_glide" and IsValid(car:GetNWEntity("PoliceCarOwner")) then
            local owner = car:GetNWEntity("PoliceCarOwner")
            local faction = car:GetNWString("PoliceCarFaction", "Неизвестно")
            
            if IsValid(owner) then
                local text = "Полицейская машина\nВладелец: " .. owner:Name() .. "\nФракция: " .. faction
                local pos = trace.HitPos:ToScreen()
                
                draw.SimpleText(text, "DermaDefault", pos.x, pos.y - 50, Color(255, 255, 255), TEXT_ALIGN_CENTER)
            end
        end
    end)
end