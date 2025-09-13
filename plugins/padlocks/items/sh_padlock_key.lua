
ITEM.name = "Ключ от замка"
ITEM.description = "Ключ, подходящий под замок."
ITEM.model = "models/props_c17/TrapPropeller_Lever.mdl"
ITEM.width = 1
ITEM.height = 1
ITEM.category = "Utility"

function ITEM:GetName()
    if !self:GetData("padlockName", nil) then
        return self.name .. " (Blank)"
    else
        return self.name
    end
end

function ITEM:GetDescription()
    if !self:GetData("padlockName", nil) then
        return "Нетронутый ключ - можно скопировать шаблон с другого ключа, чтобы сделать дубликат.."
    else
        return self.description
    end
end

ITEM.functions.combine = {
    OnRun = function(cloned, data)
        local clonedTo = ix.item.instances[data[1]]
        if clonedTo:GetData("padlockName", nil) then return false end

        local name = cloned:GetData("padlockName", nil)

        clonedTo:SetData("padlockName", name)
        clonedTo:SetData("padlock", cloned:GetData("padlock", nil))

        cloned.player:Notify("Создана копия ключа '" .. name .. "'.")

        return false
    end,
    OnCanRun = function(item, data)
        return item:GetData("padlockName", nil) != nil and item:GetData("padlock", nil) != nil
    end
}

if (CLIENT) then
    function ITEM:PopulateTooltip(tooltip)
        local linked = self:GetData("padlockName", nil)

        if linked then
            local font = "ixSmallFont"

            local info = tooltip:AddRowAfter("description", "info")
            local text = "Открывает: " .. linked
            info:SetText(text)
            info:SetFont(font)
            info:SizeToContents()
        end
    end
end