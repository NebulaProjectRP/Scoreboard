include("shared.lua")

local droneScreenMain = CreateMaterial("_droneScreen_RT", "UnlitGeneric", {
    ["$detail"] = "models/asapgaming/scoreboard/screen_dt",
    ["$detailtexturetransform"] = "center .5 .5 scale 16 16 rotate 0 translate 0 0",
    ["$detailscale"] = "1",
    ["$detailblendmode"] = "0",
    ["$translucent"] = "1",
    ["$detailblendfactor"] = ".1",
    ["$basetexture"] = "models/asapgaming/scoreboard/screen_main_b",
})

local rtb = "_droneScreenSecondary_RT" .. os.time()
local screenART = GetRenderTargetEx("RT_Drone_" .. CurTime(), 1024, 1024, 7, 2, 2, 0, 16)
local screenBRT = GetRenderTargetEx(rtb, 1024, 256, 7, 2, 2, 0, 16)

local droneSecondary = CreateMaterial(rtb, "UnlitGeneric", {
    ["$basetexturetransform"] = "center .5 .5 scale 1 1 rotate 0 translate 0 0",
    ["$detail"] = "models/asapgaming/scoreboard/screen_dt",
	["$detailtexturetransform"] = "center .5 .5 scale 32 8 rotate 0 translate 0 0",
    ["$detailblendfactor"] = .1,
    ["$basetexture"] = screenBRT:GetName(),
    ["$scale"] = "[1 .07]",
    ["$translate"] = "[0 0]",
    ["$num"] = "0",
    ["$num2"] = "0",
    ["Proxies"] = {
        ["LinearRamp"] = {
            ["rate"] = ".1",
            ["initialValue"] = "0",
            ["resultVar"] = "$num2",
        },
        ["Add"] = {
            ["srcVar1"] = "$num",
            ["srcVar2"] = "$num2",
            ["resultvar"] = "$translate[0]"
        },
        ["TextureTransform"] = {
            ["translateVar"] = "$translate",
            ["scaleVar"] = "$scale",
            ["resultVar"] = "$basetexturetransform"
        }	
    }
})

function ENT:Initialize()
    self.Drone = ClientsideModel("models/asapgaming/scoreboard/scoreboard.mdl")
    self.Drone:SetParent(self)
    self.Drone:SetNoDraw(true)
    self.Drone:SetLocalPos(Vector(0, 0, 0))
    self.Drone:ResetSequence("idle")
    self.Drone:SetModelScale(1.6, 0)
    self.Drone:SetSkin(1)
    self.Drone:SetSubMaterial(3, "!_droneScreen_RT")
    self.Drone:SetSubMaterial(4, "!" .. rtb)
    self:SetRenderBounds(Vector(-512, -512, -2048), Vector(512, 512, 512))
end

function ENT:OnRemove()
    SafeRemoveEntity(self.Drone)
end

ENT.TotalMoney = 0
ENT.ShouldAnimate = false
ENT.HasInitialized = false
ENT.Players = {}
ENT.Avatars = {}
ENT.NextUpdate = 0
ENT.DisplayMode = 0

local green = Color(150, 255, 50)
local blue = Color(50, 100, 255)

function ENT:RenderTime()
    draw.SimpleText("PlayTimes", NebulaUI:Font(42, true), 256, 108, color_white, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawRect(16, 164, 512 - 32, 2)

    if not self.HasInitialized then
        self.HasInitialized = true
        
        for k, v in pairs(self.Avatars) do
            v:Remove()
        end

        for k, v in pairs(_DronePlayTimes or {}) do
            if not IsValid(v.ent) then continue end
            local av = vgui.Create("AvatarImage")
            local y = 28 * (k - 1) + 182
            av:SetPlayer(v.ent, 64)
            av:SetPos(-128, y)
            av:SetSize(24, 24)
            av:SetPaintedManually(true)
            av.Name = v.ent:Nick()
            av.Time = v.playtime

            av:MoveTo(16, y, .5, 0, 1, function()
                self.NextUpdate = RealTime() + 10
                self.HasInitialized = false
                self.DisplayMode = 0
            end)

            table.insert(self.Avatars, av)
        end
    else
        local found = false
        for k, v in pairs(self.Avatars) do
            if not IsValid(v) then continue end
            found = true
            v:PaintManual()
            local tx, _ = draw.SimpleText(v.Name, NebulaUI:Font(26), v:GetX() + v:GetWide() + 8, v:GetY() + v:GetTall() / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.NicePlayTime(v.Time), NebulaUI:Font(32), 512 - v:GetX(), v:GetY() + v:GetTall() / 2, green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        if (not found) then
            self.NextUpdate = RealTime()
            self.HasInitialized = false
            self.DisplayMode = 0
            net.Start("NebulaDrone.RequestTime")
            net.SendToServer()
        end
    end
end

function ENT:RenderMoney()
    draw.SimpleText("Leaderboard", NebulaUI:Font(42, true), 256, 108, color_white, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawRect(16, 164, 512 - 32, 2)

    if not self.HasInitialized then
        self.HasInitialized = true
        local targets = {}

        for k, v in pairs(player.GetAll()) do
            self.TotalMoney = self.TotalMoney + v:getDarkRPVar("money")
            if k > 8 then continue end
            targets[v] = v:getDarkRPVar("money")
        end

        local sorted = {}

        for k, v in SortedPairsByValue(targets, true) do
            table.insert(sorted, {k, v})
        end

        for k, v in pairs(self.Avatars) do
            if IsValid(v) then
                v:Remove()
            end
        end

        self.Avatars = {}

        for k, v in pairs(sorted) do
            local av = vgui.Create("AvatarImage")
            local y = 28 * (k - 1) + 182
            av:SetPlayer(v[1], 64)
            av:SetPos(-128, y)
            av:SetSize(24, 24)
            av:SetPaintedManually(true)
            av.Money = v[2]
            av.Target = v[1]:Nick()

            av:MoveTo(16, y, .5, 0, 1, function()
                self.NextUpdate = RealTime() + 5
                self.HasInitialized = false
                self.DisplayMode = 1
            end)

            table.insert(self.Avatars, av)
        end
    else
        for k, v in pairs(self.Avatars) do
            v:PaintManual()
            local tx, _ = draw.SimpleText(v.Target, NebulaUI:Font(26), v:GetX() + v:GetWide() + 8, v:GetY() + v:GetTall() / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(math.Round((v.Money / self.TotalMoney) * 100, 1) .. "%", NebulaUI:Font(26), v:GetX() + v:GetWide() + 16 + tx, v:GetY() + v:GetTall() / 2, blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(DarkRP.formatMoney(v.Money), NebulaUI:Font(26), 512 - v:GetX(), v:GetY() + v:GetTall() / 2, green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end

local validSettings = {"score", "money", "xp", "kills", "deaths"}

function ENT:RenderGangs()
    draw.SimpleText("Gangs - " .. (self.DisplayType or ""), NebulaUI:Font(42, true), 256, 108, color_white, TEXT_ALIGN_CENTER)
    surface.SetDrawColor(255, 255, 255, 50)
    surface.DrawRect(16, 164, 512 - 32, 2)

    if not self.HasInitialized then
        for k, v in pairs(self.Avatars or {}) do
            if IsValid(v) then
                v:Remove()
            end
        end

        self.HasInitialized = true
        self.DisplayType = nil
        local class = table.Random(validSettings)

        http.Fetch(NebulaAPI.HOST .. "gangs/leaderboard/" .. class, function(data)
            self.DisplayData = util.JSONToTable(data)
            self.DisplayType = class
            self.ForceRedraw = true
            self:RenderGangs()
        end)
    elseif self.ForceRedraw then
        self.ForceRedraw = false

        for k, v in pairs(self.Avatars or {}) do
            if IsValid(v) then
                v:Remove()
            end
        end

        self.Avatars = {}
        for k = 1, 8 do
            local slot = self.DisplayData[k]
            if not slot then break end
            local av = vgui.Create("nebula.imgur")
            local y = 28 * (k - 1) + 182
            av:SetImage(slot.imgur)
            av:SetPos(-128, y)
            av:SetSize(24, 24)
            av:SetPaintedManually(true)
            av.name = slot.name
            av.data = slot[self.DisplayType]

            av:MoveTo(16, y, .5, 0, 1, function()
                self.NextUpdate = RealTime() + 5
                self.HasInitialized = false
                self.DisplayMode = 2
            end)

            table.insert(self.Avatars, av)
        end
    else
        for k, v in pairs(self.Avatars) do
            if not IsValid(v) then continue end
            v:PaintManual()
            draw.SimpleText(v.name, NebulaUI:Font(26), v:GetX() + v:GetWide() + 8, v:GetY() + v:GetTall() / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(self.DisplayType == "money" and DarkRP.formatMoney(v.data) or v.data, NebulaUI:Font(26), 512 - v:GetX(), v:GetY() + v:GetTall() / 2, green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end

ENT.NextUpdateB = 0

local phrases = {
    "Welcome to Nebula Roleplay",
    "eat doritos",
    "there are drills hidden behind the walls",
    "you can't see the walls",
    "dog food is the best",
    "nobody likes you",
    "qwertyuiopasdfghjklzxcvbnm",
    "eat a bag of chips",
    "use the hammer",
    "open the door",
    "a door is a door",
    "hello darkness my old friend",
    "xD",
    "cant touch this",
    "bitch please",
    "mar de las pompas"
}
function ENT:RenderSubScreen(msg)
    if self.NextUpdateB > RealTime() then return end
    local phrase = msg or phrases[math.random(1, #phrases)]
    render.PushRenderTarget(screenBRT)
    cam.Start2D()
    render.ClearDepth()
    render.Clear(0, 0, 0, 0, true, true)
    surface.SetDrawColor(70, 27, 46)
    surface.DrawRect(0, 0, 512, 280)
    draw.SimpleText(phrase, NebulaUI:Font(32), 0, 256, color_white, 1, 1)
    draw.SimpleText(phrase, NebulaUI:Font(32), 512, 256, color_white, 1, 1)
    cam.End2D()
    render.PopRenderTarget(screenBRT)
    droneSecondary:SetTexture("$basetexture", screenBRT:GetName())
    self.NextUpdateB = RealTime() + (msg and 30 or 10)
end

function ENT:DoMessage(msg)
    self.NextUpdateB = 0
    self:RenderSubScreen(msg)
end

function ENT:RenderScreen()
    if self.NextUpdate > RealTime() then return end
    render.PushRenderTarget(screenART)
    cam.Start2D()
    render.Clear(0, 0, 0, 1, true, true)
    surface.SetDrawColor(36, 36, 36)
    surface.DrawRect(0, 0, 1024, 1024)

    if self.DisplayMode == 0 then
        self:RenderMoney()
    elseif self.DisplayMode == 1 then
        self:RenderGangs()
    elseif self.DisplayMode == 2 then
        self:RenderTime()
    end

    cam.End2D()
    render.PopRenderTarget(screenART)
    self.Drone:SetSubMaterial(4, "!" .. rtb)
    droneScreenMain:SetTexture("$basetexture", screenART:GetName())
end

function ENT:Draw()
    self:SetPos(Vector(-1900, -1560, 500))
    local height = math.cos(RealTime() / 2) * 64
    if not IsValid(self.Drone) then
        self:Initialize()
        return
    end
    self.Drone:SetParent(self)
    self.Drone:SetLocalPos(Vector(0, 0, height))
    self.Drone:SetLocalAngles(Angle(0, (RealTime() * 8) % 360))
    self.Drone:SetCycle((RealTime() / 4) % 1)
    self:RenderScreen()
    self:RenderSubScreen()
    self.Drone:DrawModel()
end

net.Receive("NebulaDrone.SendTimes", function()
    _DronePlayTimes = {}
    local count = net.ReadUInt(4)
    for k = 1, count do
        table.insert(_DronePlayTimes, {
            ent = net.ReadEntity(),
            playtime = net.ReadUInt(24)
        })
    end
end)

net.Receive("NebulaDrone.SendAdvert", function()
    local drone = net.ReadEntity()
    local message = net.ReadString()

    if IsValid(drone) then
        drone:DoMessage(message)
    end
end)