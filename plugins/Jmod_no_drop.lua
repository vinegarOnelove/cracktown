function PLUGIN:CanPlayerDropItem(client, itemID)
    local item = ix.item.instances[itemID]

    if item then
        if item:GetData("garmor_wearing", false) then
            client:Notify("nuh uh")
            return false 
        else
            return true
        end
    else
        client:Notify("no item")
        return false
    end
end