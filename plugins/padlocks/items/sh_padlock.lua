
ITEM.name = "Замок"
ITEM.description = "Металлический навесной замок, используемый для запирания дверей и калиток. При установке выдаст соответствующий ключ."
ITEM.model = "models/props_wasteland/prison_padlock001a.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Utility"

if (CLIENT) then
    function ITEM:PopulateTooltip(tooltip)
        local font = "ixSmallFont"

        local info = tooltip:AddRowAfter("description", "info")
        local text = "Название: " .. self:GetData("padlockName", "Замок")
        info:SetText(text)
        info:SetFont(font)
        info:SizeToContents()
    end
end

ITEM.functions.AName = {
    name = "Установить название замка",
    icon = "icon16/lock_edit.png",

    OnRun = function(item)
        local client = item.player
        client:RequestString("Установить название замка", "Название замка", function(text)
            item:SetData("padlockName", text)
            client:Notify("Замок назван " .. text .. ".")
        end, item:GetData("padlockName", "Замок"))
        return false
    end
}

ITEM.functions.BPlace = {
    name = "Повесить",
    icon = "icon16/lock_go.png",

    OnRun = function(item)
        local client = item.player
        local data = {}
            data.start = client:GetShootPos()
            data.endpos = data.start + client:GetAimVector() * 96
            data.filter = client
        local lock = scripted_ents.Get("ix_padlock"):SpawnFunction(client, util.TraceLine(data))
        local name = item:GetData("padlockName", "Замок")

        if IsValid(lock) then
            client:EmitSound("physics/metal/weapon_impact_soft2.wav", 75, 80)

            if !client:GetCharacter():GetInventory():Add("padlock_key", 1, {padlock = lock:GetPersistentID(), padlockName = name}) then
                ix.item.Spawn(uniqueID, client, nil, nil, {padlock = lock:GetPersistentID(), padlockName = name})
            end

            lock:SetDisplayName(name)

            return true
        else
            return false
        end
    end
}
