ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "工件的工作台"
ENT.Category = "Helix"
ENT.Spawnable = true
ENT.AdminOnly = false

if (SERVER) then
    function ENT:Initialize()
        self:SetModel("models/props_combine/breenconsole.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local physics = self:GetPhysicsObject()
        if (physics:IsValid()) then
            physics:Wake()
        end
    end

    function ENT:Use(activator)
        if not activator:IsPlayer() then return end

        local character = activator:GetCharacter()
        if not character then return end

        local inventory = character:GetInventory()
        local requiredResource = "alien_resource"
        local requiredAmount = 12

        -- Проверяем, есть ли у игрока достаточно ресурсов
        if inventory:GetItemCount(requiredResource) >= requiredAmount then
            -- Находим и удаляем нужное количество предметов
            local items = inventory:GetItems()
            local removed = 0

            for _, item in pairs(items) do
                if item.uniqueID == requiredResource then
                    item:Remove()
                    removed = removed + 1
                    if removed >= requiredAmount then
                        break
                    end
                end
            end

            -- Выдаем случайный артефакт
            local artifacts = {
                "healart", -- Замени на идентификаторы твоих артефактов
                "jumpart",
                "runart",
				"teleart"				
            }
            local randomArtifact = table.Random(artifacts)
            inventory:Add(randomArtifact)

            -- Уведомление игроку
            activator:Notify("Вы создали артефакт: " .. randomArtifact)
        else
            activator:Notify("Недостаточно 资源! Нужно 12 единиц.")
        end
    end
end