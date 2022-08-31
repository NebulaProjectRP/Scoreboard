AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("NebulaDrone.SendTimes")
util.AddNetworkString("NebulaDrone.SendAdvert")

function ENT:SpawnFunction( ply, tr, cs )
    if ( !tr.Hit ) then return end
    local ent = ents.Create( cs )
    ent:SetPos( Vector(-1900, -1560, 500) )
    ent:Spawn()
    ent:Activate()
    return ent
end

function ENT:Initialize()
    self:SetModel("models/hunter/blocks/cube8x8x4.mdl")
    self:PhysicsInitStatic(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:DrawShadow(false)
    self:PhysicsInitBox(Vector(-600,-600,-50), Vector(600, 600, 50))

    hook.Add("PlayerInitialSpawn", self, function(s, ply)
        ply:Wait(10, function()
            self:NetworkTimes()
        end)
    end)

    hook.Add("PlayerDisconnected", self, function(s, ply)
        timer.Simple(0, function()
            self:NetworkItems()
        end)
    end)

    hook.Add("onChatCommand", self, function(s, ply, cmd, args)
        if (cmd == "advert") then
            net.Start("NebulaDrone.SendAdvert")
            net.WriteEntity(self)
            net.WriteString(args)
            net.SendPVS(self:GetPos() - Vector(0, 0, 96))
        end
    end)

    self:NetworkTimes()
end

function ENT:OnTakeDamage(dmg)
    local att = dmg:GetAttacker()
    if (att:IsPlayer()) then
        net.Start("NebulaDrone.SendAdvert")
        net.WriteEntity(self)
        net.WriteString("Obliterating " .. att:Nick())
        net.SendPVS(self:GetPos() - Vector(0, 0, 96))
        self:Wait(.5, function()
            self:EmitSound("npc/turret_floor/deploy.wav", 165, 75, 1, CHAN_AUTO)
            self:Wait(1.5, function()
                local bullet = {
                    Src = self:GetPos(),
                    Dir = (att:GetPos() - self:GetPos() + att:OBBCenter()):GetNormal(),
                    Spread = Vector(.025, .025, .025),
                    Tracer = 1,
                    TracerName = "AirboatGunHeavyTracer",
                    Force = 100,
                    Damage = 800,
                }
                for k = 1, 5 do
                    self:FireBullets(bullet)
                end
            end)
        end)
    end
end

function ENT:NetworkTimes(ply)
    local data = {}
    for k, v in pairs(player.GetAll()) do
        data[v] = v:getPlayTime()
    end

    table.sort(data, function(a, b)
        return a > b
    end)

    local max = math.min(player.GetCount(), 8)
    net.Start("NebulaDrone.SendTimes")
    net.WriteUInt(max, 4)
    local ent_index, v
    for k = 1, max do
        v, ent_index = next(data, ent_index)
        net.WriteEntity(v)
        net.WriteUInt(data[v], 24)
    end

    if (ply) then
        net.Send(ply)
        return
    end
    net.SendPVS(self:GetPos() - Vector(0, 0, 64))
end

hook.Add("InitPostEntity", "SpawnDrone", function()
    local ent = ents.Create( "neb_drone" )
    ent:SetPos( Vector(-1900, -1560, 500) )
    ent:Spawn()
    ent:Activate()
end)