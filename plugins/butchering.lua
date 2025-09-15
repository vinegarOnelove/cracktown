PLUGIN.name = "Corpse Butchering"
PLUGIN.author = "Bilwin"
PLUGIN.schema = "Any"
PLUGIN.version = 1.1
PLUGIN.license = [[
    This is free and unencumbered software released into the public domain.
    Anyone is free to copy, modify, publish, use, compile, sell, or
    distribute this software, either in source code form or as a compiled
    binary, for any purpose, commercial or non-commercial, and by any
    means.
    In jurisdictions that recognize copyright laws, the author or authors
    of this software dedicate any and all copyright interest in the
    software to the public domain. We make this dedication for the benefit
    of the public at large and to the detriment of our heirs and
    successors. We intend this dedication to be an overt act of
    relinquishment in perpetuity of all present and future rights to this
    software under copyright law.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
    OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
    ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE.
    For more information, please refer to <http://unlicense.org/>
]]

PLUGIN.list = {
    --[[
    ['modelpath/modelname.mdl'] = {
        butcheringTime = 5,                                                                     -- How many seconds will the corpse be butchered
        impactEffect = "AntlionGib",                                                            -- What will be the effect when butchering a corpse
        slicingSound = {[1] = "soundpath/soundname.***", [2] = "soundpath/soundname.***"},      -- [1] This is the initial butchering sound; [2] this is the sound at which the corpse will already be butchered
        butcheringWeapons = {'weapon_class', 'weapon_class2'},                                  -- Weapons available for butchering a specific corpse
        animation = "Roofidle1",                                                                -- Animation that will be played when butchering
        items = {'item_uniqueID1', 'item_uniqueID2'}                                            -- Items to be issued for character after butchered
    }
    --]]
    ['models/criken/criken.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
    ['models/player/gpd/sheriff_ancient/male_04.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
    ['models/player/gpd/sheriff_ancient/male_06.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
    ['models/player/gpd/sheriff_ancient/male_07.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
    ['models/player/gpd/sheriff_ancient/male_08.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
    ['models/player/gpd/sheriff_ancient/male_gta_02.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
    ['models/arachnit/random/georgian_riot_police/georgian_riot_police_player.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
    ['models/charborg/charborg.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
	['models/humans/group03/chemsuit.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'human_part','human_brain'}
    },
    ['models/ebmage/newflesh/gnorts.mdl'] = {
        butcheringTime = 10,
        impactEffect = "AntlionGib",
        items = {'alien_part'}
    },
    ['models/animalia/bighorn.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'animal_part'}
    },
    ['models/animalia/chicken.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'bird_part'}
    },
    ['models/animalia/chicken1.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'bird_part'}
    },
    ['models/animalia/dog1.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'dog_part'}
    },
    ['models/animalia/dog2.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'dog_part'}
    },
    ['models/animalia/gazelle.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'animal_part'}
    },
    ['models/animalia/npc_dog.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'dog_part'}
    },
	['models/animalia/crow.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'bird_part'}
    },
	['models/animalia/pigeon.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'bird_part'}
    },
	['models/animalia/rat.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'rat_part'}
    },
	['models/animalia/seagull.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'bird_part'}
    },
	['models/animalia/champ.mdl'] = {
        butcheringTime = 10,
        impactEffect = "BloodImpact",
        items = {'dog_part'}
    },
    ['models/Lamarr.mdl'] = {
        butcheringTime = 5,
        items = {}
    },
    ['models/headcrabclassic.mdl'] = {
        butcheringTime = 5,
        items = {}
    },
    ['models/headcrabblack.mdl'] = {
        butcheringTime = 5,
        items = {}
    },
    ['models/headcrab.mdl'] = {
        butcheringTime = 5,
        items = {}
    },
    ['models/antlion.mdl'] = {
        impactEffect = 'AntlionGib',
        butcheringTime = 30,
        slicingSound = {[1] = 'ambient/machines/slicer2.wav', [2] = 'ambient/machines/slicer3.wav'},
        items = {}
    }
}

if (SERVER) then
    ix.log.AddType("playerButchered", function(client, corpse)
        return string.format("%s был разрублен %s.", client:Name(), corpse:GetModel())
    end)

    util.AddNetworkString('ixClearClientRagdolls')
	function PLUGIN:OnNPCKilled(npc, attacker, inflictor)
        if IsValid(npc) and self.list[npc:GetModel()] then
            local ragdoll = ents.Create("prop_ragdoll")
            ragdoll:SetPos( npc:GetPos() )
            ragdoll:SetAngles( npc:EyeAngles() )
            ragdoll:SetModel( npc:GetModel() )
            ragdoll:SetSkin( npc:GetSkin() )

            for i = 0, (npc:GetNumBodyGroups() - 1) do
                ragdoll:SetBodygroup(i, npc:GetBodygroup(i))
            end

            ragdoll:Spawn()
            ragdoll:SetCollisionGroup(COLLISION_GROUP_WEAPON)
            ragdoll:Activate()

            local velocity = npc:GetVelocity()

            for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
                local physObj = ragdoll:GetPhysicsObjectNum(i)

                if ( IsValid(physObj) ) then
                    physObj:SetVelocity(velocity)

                    local index = ragdoll:TranslatePhysBoneToBone(i)

                    if (index) then
                        local position, angles = npc:GetBonePosition(index)

                        physObj:SetPos(position)
                        physObj:SetAngles(angles)
                    end
                end
            end

            net.Start('ixClearClientRagdolls')
                net.WriteString(npc:GetModel())
            net.Broadcast()
        end
	end

    function PLUGIN:KeyPress(client, key)
        if ( client:GetCharacter() and client:Alive() ) then
            if ( key == IN_USE ) then
                local HitPos = client:GetEyeTraceNoCursor()
                local target = HitPos.Entity
                if target and IsValid(target) and target:IsRagdoll() and self.list[target:GetModel()] then
                    local allowedWeapons = self.list[target:GetModel()].butcheringWeapons or {'arc9_eft_melee_wycc','arc9_eft_melee_voodoo','arc9_eft_melee_kiba','arc9_eft_melee_cultist','arc9_eft_melee_camper','arc9_eft_melee_wycc'}
                    local canButch = hook.Run('CanButchEntity', client, target)
                    if ( table.HasValue(allowedWeapons, client:GetActiveWeapon():GetClass()) and !target:GetNetVar('cutting', false) and client:IsWepRaised() and canButch ) then
                        local butchAnim = self.list[target:GetModel()].animation or "Roofidle1"
                        client:ForceSequence(butchAnim, nil, 0)
                        target:SetNetVar('cutting', true)
						target:EmitSound('physics/flesh/flesh_bloody_break.wav')
 
                        local physObj, butcheringTime = target:GetPhysicsObject(), self.list[target:GetModel()].butcheringTime or 2
                        if (IsValid(physObj) and !isnumber(self.list[target:GetModel()].butcheringTime) ) then
                            butcheringTime = math.Round( physObj:GetMass() )
                        end

                        client:SetAction("Разделываем...", butcheringTime)
                        client:DoStaredAction(target, function()
                            if ( IsValid(client) ) then
                                client:LeaveSequence()

                                if IsValid(target) then
                                    target:SetNetVar('cutting', nil)

                                    local effect = EffectData()
                                        effect:SetStart(target:LocalToWorld(target:OBBCenter()))
                                        effect:SetOrigin(target:LocalToWorld(target:OBBCenter()))
                                        effect:SetScale(3)
                                    util.Effect(self.list[target:GetModel()].impactEffect or "BloodImpact", effect)

                                    local butcheringItems = self.list[target:GetModel()].items or {}
                                    if !table.IsEmpty(butcheringItems) then
                                        for _, item in ipairs(butcheringItems) do
                                            if !client:GetCharacter():GetInventory():Add(item) then
                                                ix.item.Spawn(item, client)
                                            end
                                        end
                                    end

                                    ix.log.Add(client, "playerButchered", target)
                                    hook.Run('OnButchered', client, target)
									target:EmitSound('physics/flesh/flesh_bloody_break.wav')
                                    target:Remove()
                                end
                            end
                        end, butcheringTime, function()
                            if ( IsValid(client) ) then
                                client:SetAction()
                                client:LeaveSequence()
                                target:SetNetVar('cutting', false)
                            end
                        end)
                    end
                end
            end
        end
    end

    function PLUGIN:CanButchEntity(client, target)
        return true
    end
end

if (CLIENT) then
    net.Receive('ixClearClientRagdolls', function(len)
        local model = net.ReadString()
        timer.Simple(FrameTime() * 2, function()
            for _, ragdoll in ipairs( ents.GetAll() ) do
                if (ragdoll:GetClass() == 'class C_ClientRagdoll' and ragdoll:GetModel() == model) then
                    ragdoll:Remove()
                end
            end
        end)
    end)
end