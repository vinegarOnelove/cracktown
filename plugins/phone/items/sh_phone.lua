ITEM.name = "Телефон"
ITEM.model = "models/props_trainstation/payphone_reciever001a.mdl"
ITEM.description = "Стационарный телефон с перерезанным проводом, кто знает как он работает?"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Электроника"

ITEM.functions.Call = {
    name = "Позвонить курьеру",
    OnRun = function(item)
        local client = item.player
        if not IsValid(client) then return false end
        
        -- Проверяем доступность доставки
        if not ix.phoneDelivery or not ix.phoneDelivery.StartDelivery then
            client:Notify("Служба доставки временно недоступна!")
            return false
        end
        
        -- Заказываем доставку
        local success = ix.phoneDelivery.StartDelivery(client)
        
        if not success then
            client:Notify("Не удалось заказать доставку!")
        end
        
        return false -- Не удаляем предмет
    end,
    
    OnCanRun = function(item)
        local client = item.player
        return IsValid(client) and client:GetCharacter() ~= nil
    end
}