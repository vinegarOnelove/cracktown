local PLUGIN = PLUGIN

PLUGIN.name = "Simple Brewing"
PLUGIN.author = "ChatGPT"
PLUGIN.description = "Простая система варки алкоголя с шансом взрыва."

-- Рецепты: ингредиенты + результат + время (секунды) + шанс взрыва (%)
PLUGIN.recipes = {
    ["vodkawater"] = {
        input = {"vodka", "water"},
        output = "moonshine",
        time = 220,
        risk = 20
    },
    ["ginwater"] = {
        input = {"gin", "water"},
        output = "moonshine",
        time = 240,
        risk = 15
    },
	["whiskeywater"] = {
        input = {"whiskey", "water"},
        output = "moonshine",
        time = 240,
        risk = 10
    },
	["ginsparkling"] = {
        input = {"gin", "sparklingwater"},
        output = "moonshine",
        time = 180,
        risk = 25
    },
	["vodkasparkling"] = {
        input = {"vodka", "sparklingwater"},
        output = "moonshine",
        time = 160,
        risk = 30
    },
	["whiskeysparkling"] = {
        input = {"whiskey", "sparklingwater"},
        output = "moonshine",
        time = 180,
        risk = 20
    },
	["ginspecial"] = {
        input = {"gin", "energetic"},
        output = "moonshine",
        time = 120,
        risk = 35
    },
	["vodkaspecial"] = {
        input = {"vodka", "energetic"},
        output = "moonshine",
        time = 110,
        risk = 40
    },
    ["whiskeyspecial"] = {
        input = {"whiskey", "energetic"},
        output = "moonshine",
        time = 120,
        risk = 30
    }
}

-- Локализованные статусы
PLUGIN.statusText = {
    ["Idle"] = "Пустая",
    ["Brewing"] = "Варка идёт...",
    ["Finished"] = "Готово!"
}

if CLIENT then
    function PLUGIN:PopulateEntityInfo(ent, tooltip)
        if ent:GetClass() ~= "ix_brewbarrel" then return end

        -- Заголовок
        local name = tooltip:AddRow("name")
        name:SetText("Бочка для варки")
        name:SetBackgroundColor(Color(100, 50, 20))
        name:SetImportant()
        name:SizeToContents()

        -- Статус (безопасно получаем)
        local state = "Idle"
        if isfunction(ent.GetStatus) then
            state = ent:GetStatus() or "Idle"
        end
    end
end


