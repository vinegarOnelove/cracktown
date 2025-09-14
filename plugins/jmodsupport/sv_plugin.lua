local entityToItem = {
    ["ent_aboot_gmod_ezarmor_jetmodule_admin"] = "Admin Jet Module",
	["ent_jack_gmod_ezarmor_backpack"] = "Backpack",
}

if SERVER then
    hook.Add("OnEntityCreated", "ConvertEntityToItem", function(ent)
        timer.Simple(0, function()
            if IsValid(ent) then
                local class = ent:GetClass()

                -- Проверяем, есть ли у нас соответствие для данной сущности
                if entityToItem[class] then
                    local position = ent:GetPos()
                    local angles = ent:GetAngles()

                    local uniqueID = entityToItem[class]

                    -- Создаем предмет из сущности на том же месте
                    ix.item.Spawn(uniqueID, position, function(item)
                        if IsValid(item) then
                            item:SetData("Owner", NULL) -- Устанавливаем владельца предмета или NULL
                        end
                    end, angles)

                    -- Удаляем сущность
                    ent:Remove()
                end
            end
        end)
    end)
end
