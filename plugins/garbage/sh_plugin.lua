local PLUGIN = PLUGIN

PLUGIN.name = "Trash Search System"
PLUGIN.author = "Your Name"
PLUGIN.description = "Система поиска предметов в мусорных баках"

-- Конфигурация системы мусорки
PLUGIN.trashConfig = {
    searchCooldown = 1, -- 60 секунд перезарядки
    maxSearches = 60, -- Максимум поисков за раз
    minItems = 1, -- Минимальное количество предметов
    maxItems = 1, -- Максимум предметов
    failChance = 0.3, -- Шанс ничего не найти
    rareItemChance = 0.1, -- Шанс найти редкий предмет
}

-- Список возможных предметов для поиска
PLUGIN.trashItems = {
    common = {
        {class = "paper", amount = {1, 3}, name = "Бумага."},
        {class = "can", amount = {1, 3}, name = "Банка."},
        {class = "bottle", amount = {1, 2}, name = "Бутылка."},
        {class = "carton_box", amount = {1, 1}, name = "Картонная коробка."},
        {class = "boot", amount = {1, 1}, name = "Ботинок."},
        {class = "screen", amount = {1, 1}, name = "Монитор."},
        {class = "lamp", amount = {1, 1}, name = "Лампа."},
        {class = "pan", amount = {1, 1}, name = "Сковородка."},
        {class = "briefcase", amount = {1, 1}, name = "Чемодан."},
    },
    rare = {
        {class = "crack", amount = {1, 1}, name = "Крэк."},
        {class = "vodka", amount = {1, 1}, name = "Водка."},
        {class = "human_brain", amount = {1, 1}, name = "Человеческий мозг."},
        {class = "phone", amount = {1, 1}, name = "Телефон."},
        {class = "padlock", amount = {1, 1}, name = "Замок."},
        {class = "crack_meat", amount = {1, 1}, name = "Мясной крэк."},
    }
}

-- Таблица перезарядки для игроков
PLUGIN.playerCooldowns = PLUGIN.playerCooldowns or {}

if SERVER then
    -- Добавляем сетевые строки
    util.AddNetworkString("TrashCanOpenMenu")
    util.AddNetworkString("TrashCanSearch")
    util.AddNetworkString("TrashCanResult")
    util.AddNetworkString("TrashCanCooldown")
    
    -- Регистрация entity для спавн меню
    list.Set("SpawnableEntities", "ix_trashbin", {
        PrintName = "Мусорный бак",
        Author = "Your Name",
        Category = "IX: HL2 RP",
        AdminOnly = false,
        Spawnable = true,
        NiceName = "Мусорный бак",
        Class = "ix_trashbin",
        Description = "Мусорный бак для поиска предметов"
    })
    
    -- Проверка перезарядки
    function PLUGIN:CanSearch(ply)
        if not IsValid(ply) then return false, "Недействительный игрок" end
        
        local steamID = ply:SteamID()
        local cooldown = self.playerCooldowns[steamID] or 0
        
        if cooldown > CurTime() then
            local timeLeft = math.ceil(cooldown - CurTime())
            return false, string.format("Подождите %d секунд", timeLeft)
        end
        
        return true, ""
    end
    
    -- Поиск в мусорке
    function PLUGIN:SearchTrash(ply)
        local canSearch, errorMsg = self:CanSearch(ply)
        if not canSearch then
            if IsValid(ply) then
                ply:Notify(errorMsg)
            end
            return false
        end
        
        -- Устанавливаем перезарядку
        self.playerCooldowns[ply:SteamID()] = CurTime() + self.trashConfig.searchCooldown
        
        -- Проверяем шанс неудачи
        if math.random() < self.trashConfig.failChance then
            ply:Notify("Вы ничего не нашли в мусорке.")
            
            net.Start("TrashCanResult")
            net.WriteBool(false)
            net.WriteString("Ничего не найдено")
            net.WriteUInt(0, 8)
            net.Send(ply)
            
            return true
        end
        
        -- Определяем количество предметов
        local itemCount = math.random(self.trashConfig.minItems, self.trashConfig.maxItems)
        local foundItems = {}
        
        for i = 1, itemCount do
            local isRare = math.random() < self.trashConfig.rareItemChance
            local itemPool = isRare and self.trashItems.rare or self.trashItems.common
            local randomItem = table.Random(itemPool)
            
            table.insert(foundItems, {
                class = randomItem.class,
                amount = math.random(randomItem.amount[1], randomItem.amount[2]),
                name = randomItem.name,
                rare = isRare
            })
        end
        
        -- Выдаем предметы игроку
        local character = ply:GetCharacter()
        if character then
            for _, itemData in ipairs(foundItems) do
                if itemData.class == "money" then
                    character:GiveMoney(itemData.amount)
                else
                    for i = 1, itemData.amount do
                        character:GetInventory():Add(itemData.class)
                    end
                end
            end
        end
        
        -- Формируем сообщение о находке
        local foundNames = {}
        for _, item in ipairs(foundItems) do
            local amountText = item.amount > 1 and string.format(" (%d шт.)", item.amount) or ""
            table.insert(foundNames, item.name .. amountText)
        end
        
        local resultText = table.concat(foundNames, ", ")
        ply:Notify("Вы нашли в мусорке: " .. resultText)
        
        -- Отправляем результат клиенту
        net.Start("TrashCanResult")
        net.WriteBool(true)
        net.WriteString(resultText)
        net.WriteUInt(itemCount, 8)
        net.Send(ply)
        
        return true
    end
    
    -- Обработка поиска
    net.Receive("TrashCanSearch", function(len, ply)
        PLUGIN:SearchTrash(ply)
    end)
    
    -- Обработка открытия меню
    net.Receive("TrashCanOpenMenu", function(len, ply)
        local canSearch, errorMsg = PLUGIN:CanSearch(ply)
        
        net.Start("TrashCanCooldown")
        net.WriteBool(canSearch)
        if not canSearch then
            net.WriteString(errorMsg)
        end
        net.Send(ply)
    end)
end

if CLIENT then
    -- Безопасная проверка класса entity
    local function SafeGetClass(ent)
        if not IsValid(ent) then return "invalid" end
        if not isfunction(ent.GetClass) then return "no_getclass" end
        return ent:GetClass() or "unknown"
    end

    -- Обработка перезарядки
    net.Receive("TrashCanCooldown", function()
        local canSearch = net.ReadBool()
        local errorMsg = canSearch and "" or net.ReadString()
        
        OpenTrashMenu(canSearch, errorMsg)
    end)
    
    -- Обработка результата поиска
    net.Receive("TrashCanResult", function()
        local success = net.ReadBool()
        local resultText = net.ReadString()
        local itemCount = net.ReadUInt(8)
        
        if success then
            LocalPlayer():Notify("Найдено: " .. resultText)
        end
    end)
    
    -- Хук для tooltip мусорки (ТОЛЬКО ОДИН ХУК!)
    hook.Add("PopulateEntityInfo", "ixTrashBinInfo", function(tooltip, ent)
        -- Защитные проверки
        if not IsValid(ent) then return end
        if SafeGetClass(ent) ~= "ix_trashbin" then return end
        
        -- Заголовок
        local name = tooltip:AddRow("name")
        name:SetText("Мусорный бак")
        name:SetBackgroundColor(Color(50, 50, 50))
        name:SetImportant()
        name:SizeToContents()
        
        -- Описание
        local desc = tooltip:AddRow("description")
        desc:SetText("Контейнер для отходов и мусора")
        desc:SetBackgroundColor(Color(40, 40, 40))
        desc:SizeToContents()
        
        -- Инструкция
        local info = tooltip:AddRow("info")
        info:SetText("Нажмите E для поиска предметов")
        info:SetBackgroundColor(Color(60, 60, 60))
        info:SizeToContents()
        
        -- Перезарядка
        local cooldown = tooltip:AddRow("cooldown")
        cooldown:SetText("Перезарядка: 60 секунд")
        cooldown:SetBackgroundColor(Color(80, 60, 0))
        cooldown:SizeToContents()
        
        -- Шансы
        local chances = tooltip:AddRow("chances")
        chances:SetText("Шанс найти: 70% | Редкое: 10%")
        chances:SetBackgroundColor(Color(70, 50, 30))
        chances:SizeToContents()
    end)
    
    -- Открытие меню мусорки
    function OpenTrashMenu(canSearch, errorMsg)
        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 300)
        frame:SetTitle("Мусорный бак")
        frame:Center()
        frame:MakePopup()
        
        local infoLabel = vgui.Create("DLabel", frame)
        infoLabel:SetPos(20, 40)
        infoLabel:SetSize(360, 60)
        infoLabel:SetText("Вы можете поискать полезные предметы в мусорке.\nШанс найти что-то ценное есть, но можно и ничего не найти.")
        infoLabel:SetWrap(true)
        
        local statsLabel = vgui.Create("DLabel", frame)
        statsLabel:SetPos(20, 110)
        statsLabel:SetSize(360, 40)
        statsLabel:SetText(string.format("Шанс неудачи: %d%%\nШанс редкой находки: %d%%", 
            PLUGIN.trashConfig.failChance * 100, 
            PLUGIN.trashConfig.rareItemChance * 100))
        statsLabel:SetWrap(true)
        
        if not canSearch then
            local errorLabel = vgui.Create("DLabel", frame)
            errorLabel:SetPos(20, 160)
            errorLabel:SetSize(360, 30)
            errorLabel:SetText("Ошибка: " .. errorMsg)
            errorLabel:SetTextColor(Color(255, 50, 50))
        end
        
        local searchButton = vgui.Create("DButton", frame)
        searchButton:SetPos(20, 200)
        searchButton:SetSize(360, 40)
        searchButton:SetText("Обыскать мусорку")
        searchButton:SetEnabled(canSearch)
        searchButton.DoClick = function()
            net.Start("TrashCanSearch")
            net.SendToServer()
            frame:Close()
        end
        
        local closeButton = vgui.Create("DButton", frame)
        closeButton:SetPos(20, 250)
        closeButton:SetSize(360, 30)
        closeButton:SetText("Закрыть")
        closeButton.DoClick = function()
            frame:Close()
        end
    end
    
    -- Обработка открытия меню
    net.Receive("TrashCanOpenMenu", function()
        net.Start("TrashCanOpenMenu")
        net.SendToServer()
    end)
end

