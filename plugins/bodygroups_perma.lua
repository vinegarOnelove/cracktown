PLUGIN.name = "Bodygroup and Skin Saver"
PLUGIN.author = "Linkz"
PLUGIN.description = "Automatically saves and loads player bodygroups and skin."
PLUGIN.license = [[
Copyright (c) 2025 Linkz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.]]

function PLUGIN:CharacterPreSave(character)
    local client = character:GetPlayer()
    if not IsValid(client) then return end

    -- Save bodygroups
    local groupsData = {}
    for _, v in pairs(client:GetBodyGroups()) do
        groupsData[v.id] = client:GetBodygroup(v.id)
    end
    character:SetData("groups", groupsData)

    -- Save skin
    local skin = client:GetSkin() or 0
    character:SetData("skin", skin)
end

function PLUGIN:PlayerLoadedCharacter(client, character, oldChar)
    -- Load bodygroups
    local groupsData = character:GetData("groups", {})
    for index, value in pairs(groupsData) do
        client:SetBodygroup(index, value)
    end

    -- Load skin
    local skin = character:GetData("skin", 0)
    client:SetSkin(skin)
end

ix.command.Add("SaveBodygroups", {
    description = "Manually save your current bodygroup and skin settings.",
    OnRun = function(self, client)
        local char = client:GetCharacter()
        if not char then return end

        local groupsData = {}
        for _, v in pairs(client:GetBodyGroups()) do
            groupsData[v.id] = client:GetBodygroup(v.id)
        end
        char:SetData("groups", groupsData)

        local skin = client:GetSkin() or 0
        char:SetData("skin", skin)

        char:Save()
        client:Notify("Bodygroups and skin saved.")
    end
})