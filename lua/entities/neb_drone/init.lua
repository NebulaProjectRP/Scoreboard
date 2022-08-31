AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("NebulaDrone.SendTimes")
util.AddNetworkString("NebulaDrone.SendAdvert")
util.AddNetworkString("NebulaDrone.RequestTime")

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
    self.HealthValue = 50000000

    hook.Add("OnPlayerStart", self, function(s, ply)
        ply:Wait(5, function()
            self:NetworkTimes()
        end)
    end)

    hook.Add("PlayerDisconnected", self, function(s, ply)
        timer.Simple(0, function()
            self:NetworkTimes()
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

end

function ENT:Think()
    self:SetPos( Vector(-1900, -1560, 500) )
    self:SetAngles( Angle(0, 0, 0) )
    self:NextThink(CurTime() + 5)
    return true
end

ENT.HealthValue = 10
function ENT:OnTakeDamage(dmg)
    self.HealthValue = self.HealthValue - dmg:GetDamage()
    if (self.HealthValue <= 0) then
        local eff = EffectData()
        eff:SetOrigin(self:GetPos())
        util.Effect("Explosion", eff, true, true)

        local att = dmg:GetAttacker()
        if IsValid(att) and att:IsPlayer() then
            att:giveItem("case_suits1", 1)
        end

        timer.Simple(math.random(250, 520), function()
            local ent = ents.Create( "neb_drone" )
            ent:SetPos( Vector(-1900, -1560, 500) )
            ent:Spawn()
            ent:Activate()
        end)
        self:Remove()
    end
    local att = dmg:GetAttacker()
    if (att:IsPlayer()) then
        net.Start("NebulaDrone.SendAdvert")
        net.WriteEntity(self)
        net.WriteString("Obliterating " .. att:Nick())
        net.SendPVS(self:GetPos() - Vector(0, 0, 96))
        self:Wait(.3, function()
            self:EmitSound("npc/turret_floor/deploy.wav", 165, 75, 1, CHAN_AUTO)
            self:Wait(.7, function()
                local normal = (att:GetPos() - self:GetPos() + att:OBBCenter()):GetNormal()
                local bullet = {
                    Src = self:GetPos() + normal * 96,
                    Dir = normal,
                    Spread = Vector(.0325, .0325, .0325),
                    Tracer = 1,
                    TracerName = "AirboatGunHeavyTracer",
                    Force = 100,
                    IgnoreEntity = self,
                    Num = 3,
                    Damage = 1,
                    Callback = function(_att, tr, _dmg)
                        if (IsValid(tr.Entity) and tr.Entity == att) then
                            _dmg:SetDamage(800)
                        end
                    end
                }
                /*
                local tr = util.TraceLine({
                    start = self:GetPos(),
                    endpos = self:GetPos() + bullet.Dir * 10000 + VectorRand() * bullet.Spread,
                    filter = self
                })

                if (IsValid(tr.Entity) and tr.Entity == att) then
                    tr.Entity:TakeDamage(750, att, self)
                end
                */
                self:FireBullets(bullet)
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
    local i = 1
    for ply, time in pairs(data) do
        if (i >= max) then break end
        net.WriteEntity(tply)
        net.WriteUInt(time, 24)
        i = i + 1
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


net.Receive("NebulaDrone.RequestTime", function(l, ply)
    if not ply.lastTimeAsk then
        ply.lastTimeAsk = 0
    end

    if (ply.lastTimeAsk < CurTime()) then
        ply.lastTimeAsk = CurTime() + 10
        ents.FindByClass("neb_drone")[1]:NetworkTimes(ply)
    end
end)