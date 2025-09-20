ITEM.name = "Телефон"
ITEM.model = "models/props_trainstation/payphone_reciever001a.mdl"
ITEM.description = "Стационарный телефон с перерезанным проводом, кто знает как он работает?"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Электроника"

if SERVER then
    util.AddNetworkString("PhoneOpenBountyMenu")
    util.AddNetworkString("PhoneBountyContract")
end

if CLIENT then
    function OpenBountyContractMenu()
        print("=== DEBUG: OpenBountyContractMenu вызвана! ===")
        
        local frame = vgui.Create("DFrame")
        frame:SetSize(400, 300)
        frame:SetTitle("Заказ контракта через телефон")
        frame:Center()
        frame:MakePopup()
        
        local playerList = vgui.Create("DComboBox", frame)
        playerList:SetPos(20, 40)
        playerList:SetSize(360, 30)
        playerList:SetValue("Выберите цель")
        
        print("DEBUG: Доступные игроки для контракта:")
        for _, ply in ipairs(player.GetAll()) do
            if ply ~= LocalPlayer() then
                local steamID = ply:SteamID()
                print("DEBUG: Игрок:", ply:Name(), "SteamID:", steamID)
                playerList:AddChoice(ply:Name() .. " (" .. steamID .. ")", steamID)
            end
        end
        
        local bountySlider = vgui.Create("DNumSlider", frame)
        bountySlider:SetPos(20, 90)
        bountySlider:SetSize(360, 50)
        bountySlider:SetText("Награда")
        bountySlider:SetMin(100)
        bountySlider:SetMax(10000)
        bountySlider:SetDecimals(0)
        bountySlider:SetValue(1000)
        
        local orderButton = vgui.Create("DButton", frame)
        orderButton:SetPos(20, 160)
        orderButton:SetSize(360, 40)
        orderButton:SetText("Заказать контракт")
        orderButton.DoClick = function()
            local choiceText, targetSteamID = playerList:GetSelected()
            local bounty = bountySlider:GetValue()
            
            print("DEBUG: Выбор игрока - Текст:", choiceText, "SteamID:", targetSteamID)
            
            if not targetSteamID then
                LocalPlayer():Notify("Выберите цель!")
                print("DEBUG: Ошибка - цель не выбрана")
                return
            end
            
            print("DEBUG: Отправка контракта на сервер - SteamID цели:", targetSteamID, "Награда:", bounty)
            
            net.Start("PhoneBountyContract")
            net.WriteString(targetSteamID)
            net.WriteUInt(bounty, 32)
            net.SendToServer()
            
            frame:Close()
            print("DEBUG: Меню закрыто, запрос отправлен")
        end
        
        local feeLabel = vgui.Create("DLabel", frame)
        feeLabel:SetPos(20, 220)
        feeLabel:SetSize(360, 30)
        feeLabel:SetText("Стоимость услуги: ☋200")
        feeLabel:SetFont("DermaDefaultBold")
        
        print("DEBUG: Меню контракта создано успешно")
    end

    net.Receive("PhoneOpenBountyMenu", function()
        print("=== DEBUG: Получен сетевой запрос PhoneOpenBountyMenu ===")
        OpenBountyContractMenu()
    end)
end

ITEM.functions.Call = {
    name = "Позвонить курьеру",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        
        if not ix.phoneDelivery or not ix.phoneDelivery.StartDelivery then
            client:Notify("Служба доставки временно недоступна!")
            return false
        end
        
        local success = ix.phoneDelivery.StartDelivery(client)
        
        if not success then
            client:Notify("Не удалось заказать доставку!")
        end
        
        return false
    end,
    
    OnCanRun = function(item)
        local client = item.player
        return IsValid(client) and client:GetCharacter() ~= nil
    end
}

ITEM.functions.Bounty = {
    name = "Заказать контракт",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        
        print("=== DEBUG: Функция Bounty.OnRun вызвана на сервере ===")
        print("DEBUG: Игрок:", client:Name(), "SteamID:", client:SteamID())
        
        if SERVER then
            print("DEBUG: Отправка запроса PhoneOpenBountyMenu клиенту")
            net.Start("PhoneOpenBountyMenu")
            net.Send(client)
        end
        
        return false
    end,
    
    OnCanRun = function(item)
        local client = item.player
        local canRun = IsValid(client) and client:GetCharacter() ~= nil
        print("DEBUG: OnCanRun для контракта:", canRun, "Игрок:", client:Name())
        return canRun
    end
}