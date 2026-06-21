loadstring(game:HttpGet("https://scripts.wabisabi.mom/wabi-sabi-ui-lib.lua"))()
local Library = WabiSabi
local Window = Library:CreateWindow({ Title = "Touchline", SubTitle = "prediction", Size = Vector2.new(560, 500), Resize = true, ToggleKey = Enum.KeyCode.End })
local BallsTab = Window:AddTab({ Title = "Balls", Icon = "soccer" })
local GoalieTab = Window:AddTab({ Title = "Goalie", Icon = "goal" })
local StrikerTab = Window:AddTab({ Title = "Striker", Icon = "target" })

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local ws = workspace
local rs = game:GetService("RunService")
local GRAVITY = Vector3.new(0, -196.2, 0)

local cachedBalls = {}
local lastPos = {}
local frameCount = 0

local predictionEnabled = false
local goalPredictionEnabled = false

local trailLines = {}
for i = 1, 40 do
    local l = Drawing.new("Line")
    l.Thickness = 2 + (i / 40) * 2
    l.Color = Color3.fromRGB(0, 200 + math.floor(i / 40 * 55), 255)
    l.Visible = false
    trailLines[i] = l
end

local predCircle = Drawing.new("Circle")
predCircle.Thickness = 2; predCircle.NumSides = 36; predCircle.Visible = false

local aimLine = Drawing.new("Line")
aimLine.Thickness = 1; aimLine.Color = Color3.fromRGB(0, 200, 255); aimLine.Visible = false

local goalCircle = Drawing.new("Circle")
goalCircle.Thickness = 2; goalCircle.NumSides = 24; goalCircle.Filled = true
goalCircle.Color = Color3.fromRGB(50, 255, 50); goalCircle.Transparency = 0.5; goalCircle.Visible = false

local diveArrow = Drawing.new("Triangle")
diveArrow.Thickness = 2; diveArrow.Color = Color3.fromRGB(255, 200, 0); diveArrow.Visible = false
diveArrow.Filled = true; diveArrow.Transparency = 0.4

local goalHeightDot = Drawing.new("Circle")
goalHeightDot.Thickness = 1; goalHeightDot.NumSides = 12; goalHeightDot.Filled = true
goalHeightDot.Color = Color3.fromRGB(255, 255, 255); goalHeightDot.Transparency = 0.3; goalHeightDot.Visible = false
goalHeightDot.Radius = 4

local goalTimeText
local ok, _ = pcall(function() goalTimeText = Drawing.new("Text") end)
if ok and goalTimeText then
    goalTimeText.Size = 14; goalTimeText.Center = true; goalTimeText.Outline = true
    goalTimeText.Color = Color3.fromRGB(255, 255, 255); goalTimeText.Visible = false
end

local urgencyText
local ok4, _ = pcall(function() urgencyText = Drawing.new("Text") end)
if ok4 and urgencyText then
    urgencyText.Size = 18; urgencyText.Center = true; urgencyText.Outline = true
    urgencyText.Color = Color3.fromRGB(255, 50, 50); urgencyText.Visible = false
end

local diveHelperEnabled = false

local Prediction = BallsTab:AddSection("Ball Prediction")
Prediction:AddToggle({ Id = "pred_enable", Title = "Enable", Default = false, Description = "Ball trajectory trail and landing point", Callback = function(v) predictionEnabled = v end })

local GoalPred = GoalieTab:AddSection("Goal Prediction")
GoalPred:AddToggle({ Id = "gp_enable", Title = "Enable", Default = false, Description = "Predicted entry point, height dot, and time to goal", Callback = function(v) goalPredictionEnabled = v end })

local DiveSection = GoalieTab:AddSection("Dive Helper")
DiveSection:AddToggle({ Id = "dh_enable", Title = "Enable", Default = false, Description = "Yellow triangle showing dive direction based on ball aim", Callback = function(v) diveHelperEnabled = v end })

local shotSpeedEnabled = false
local shotSpeedText
local ok2, _ = pcall(function() shotSpeedText = Drawing.new("Text") end)
if ok2 and shotSpeedText then
    shotSpeedText.Size = 13; shotSpeedText.Center = true; shotSpeedText.Outline = true
    shotSpeedText.Color = Color3.fromRGB(255, 200, 50); shotSpeedText.Visible = false
end

local openGoalEnabled = false
local coneLines = {}
for i = 1, 4 do
    local l = Drawing.new("Line")
    l.Thickness = 1; l.Color = Color3.fromRGB(100, 255, 100); l.Transparency = 0.35; l.Visible = false
    coneLines[i] = l
end
local angleText
local ok5, _ = pcall(function() angleText = Drawing.new("Text") end)
if ok5 and angleText then
    angleText.Size = 13; angleText.Center = true; angleText.Outline = true
    angleText.Color = Color3.fromRGB(150, 255, 150); angleText.Visible = false
end
local strikerDistText
local ok6, _ = pcall(function() strikerDistText = Drawing.new("Text") end)
if ok6 and strikerDistText then
    strikerDistText.Size = 13; strikerDistText.Center = true; strikerDistText.Outline = true
    strikerDistText.Color = Color3.fromRGB(150, 255, 150); strikerDistText.Visible = false
end

local ShotSpeedSection = StrikerTab:AddSection("Shot Speed")
ShotSpeedSection:AddToggle({ Id = "ss_enable", Title = "Enable", Default = false, Description = "Shot speed in st/s near the ball", Callback = function(v) shotSpeedEnabled = v end })

local OpenGoalSection = StrikerTab:AddSection("Open Goal")
OpenGoalSection:AddToggle({ Id = "og_enable", Title = "Enable", Default = false, Description = "Shooting angle, distance, and cone lines", Callback = function(v) openGoalEnabled = v end })

local goalieVisionEnabled = false
local keeperLine = Drawing.new("Line")
keeperLine.Thickness = 1; keeperLine.Color = Color3.fromRGB(255, 255, 100); keeperLine.Transparency = 0.5; keeperLine.Visible = false
local distText
local ok3, _ = pcall(function() distText = Drawing.new("Text") end)
if ok3 and distText then
    distText.Size = 13; distText.Center = true; distText.Outline = true
    distText.Color = Color3.fromRGB(200, 200, 255); distText.Visible = false
end
local GoalieSection = GoalieTab:AddSection("Goalie Vision")
GoalieSection:AddToggle({ Id = "gv_enable", Title = "Enable", Default = false, Description = "Keeper line and distance to goal", Callback = function(v) goalieVisionEnabled = v end })

Window:BuildInterfaceSection(BallsTab, GoalieTab, StrikerTab)
Window:BuildConfigSection(BallsTab, GoalieTab, StrikerTab)
Library:LoadAutoloadConfig()
Library:Notify({ Title = "Loaded", Content = "Touchline ready.", Duration = 3 })

local function getCharPos(char)
    if not char then return nil end
    local ok, pp = pcall(function() return char.PrimaryPart end)
    if ok and pp then local ok2, p = pcall(function() return pp.Position end); if ok2 and p then return p end end
    local ok, cf = pcall(function() return char:GetPivot() end)
    if ok and cf then return cf.Position end
    local ok, pos = pcall(function() return char.Position end)
    if ok and pos then return pos end
    return nil
end

local function scanBalls()
    frameCount = frameCount + 1
    if frameCount % 5 ~= 0 and #cachedBalls > 0 then return end
    local folder = ws:FindFirstChild("Footballs")
    if not folder then cachedBalls = {}; lastBestBall = nil; lastBestBallId = nil; return end
    local new = {}
    for _, c in ipairs(folder:GetChildren()) do
        if c:IsA("BasePart") then new[#new+1] = c end
    end
    cachedBalls = new
    if lastBestBallId then
        local stillHere = false
        for _, ball in ipairs(new) do
            if tostring(ball) == lastBestBallId then stillHere = true; break end
        end
        if not stillHere then lastBestBall = nil; lastBestBallId = nil; ballOffFrames = 0 end
    end
end

local function getBallVel(ball)
    if not (ball and ball.Parent) then return Vector3.new() end
    local v = ball.Velocity
    if v and v.Magnitude > 0.1 then return v end
    v = ball.AssemblyLinearVelocity
    if v and v.Magnitude > 0.1 then return v end
    local addr = tostring(ball)
    local pos = ball.Position
    if lastPos[addr] then
        local dt = tick() - lastPos[addr].t
        if dt > 0 and dt < 0.5 then
            local dv = (pos - lastPos[addr].pos) / dt
            if dv and dv.Magnitude > 0.5 then lastPos[addr] = { pos = pos, t = tick() }; return dv end
        end
    end
    lastPos[addr] = { pos = pos, t = tick() }
    return Vector3.new()
end

local function getNearestBall()
    if #cachedBalls == 0 then return nil end
    local cam = ws.CurrentCamera
    local myPos = getCharPos(lp and lp.Character)
    local best, bestDist
    for _, ball in ipairs(cachedBalls) do
        local pos = ball.Position
        if pos then
            local vel = getBallVel(ball)
            if vel and vel.Magnitude > 1 then
                local d = myPos and (pos - myPos).Magnitude or (cam and (pos - cam.Position).Magnitude or 9999)
                if not bestDist or d < bestDist then
                    bestDist = d; best = ball
                end
            end
        end
    end
    return best
end

local cachedGoals = {}
local lastGoalScan = 0
local function findGoals()
    if frameCount - lastGoalScan < 100 and #cachedGoals > 0 then return cachedGoals end
    local goals = {}
    local ok, parts = pcall(function() local r = {}; for _, v in ipairs(ws:GetDescendants()) do r[#r+1] = v end; return r end)
    if ok then
        -- collect all parts with "goal" in the name and cluster by proximity
        local goalParts = {}
        for _, v in ipairs(parts) do
            local ok, isBP = pcall(function() return v.IsA and v:IsA("BasePart") end)
            if ok and isBP then
                local ok, nm = pcall(function() return v.Name end)
                if ok and nm and nm:lower():find("goal") then
                    local ok, pos = pcall(function() return v.Position end)
                    local ok2, sz = pcall(function() return v.Size end)
                    local ok3, cf = pcall(function() return v.CFrame end)
                    if ok and pos and ok2 and sz and ok3 and cf then
                        goalParts[#goalParts+1] = { pos = pos, size = sz, cf = cf }
                    end
                end
            end
        end
        if #goalParts > 0 then
            -- cluster by proximity: group parts within 15 studs
            local clusters = {}
            for _, gp in ipairs(goalParts) do
                local added = false
                for _, cl in ipairs(clusters) do
                    local dx = gp.pos.X - cl.cx
                    local dy = gp.pos.Y - cl.cy
                    local dz = gp.pos.Z - cl.cz
                    if dx*dx + dy*dy + dz*dz < 225 then
                        -- expand bounding box
                        local h = gp.size / 2
                        local nx, xx = gp.pos.X - h.X, gp.pos.X + h.X
                        local ny, xy = gp.pos.Y - h.Y, gp.pos.Y + h.Y
                        local nz, xz = gp.pos.Z - h.Z, gp.pos.Z + h.Z
                        if nx < cl.minX then cl.minX = nx end; if xx > cl.maxX then cl.maxX = xx end
                        if ny < cl.minY then cl.minY = ny end; if xy > cl.maxY then cl.maxY = xy end
                        if nz < cl.minZ then cl.minZ = nz end; if xz > cl.maxZ then cl.maxZ = xz end
                        cl.cx = (cl.minX + cl.maxX) / 2
                        cl.cy = (cl.minY + cl.maxY) / 2
                        cl.cz = (cl.minZ + cl.maxZ) / 2
                        added = true; break
                    end
                end
                if not added then
                    local h = gp.size / 2
                    local nx, xx = gp.pos.X - h.X, gp.pos.X + h.X
                    local ny, xy = gp.pos.Y - h.Y, gp.pos.Y + h.Y
                    local nz, xz = gp.pos.Z - h.Z, gp.pos.Z + h.Z
                    clusters[#clusters+1] = { minX=nx, maxX=xx, minY=ny, maxY=xy, minZ=nz, maxZ=xz, cx=gp.pos.X, cy=gp.pos.Y, cz=gp.pos.Z }
                end
            end
            for _, cl in ipairs(clusters) do
                local sw = cl.maxX - cl.minX; local sh = cl.maxY - cl.minY; local sd = cl.maxZ - cl.minZ
                goals[#goals+1] = { pos = Vector3.new(cl.cx, cl.cy, cl.cz), size = Vector3.new(sw, sh, sd) }
            end
        end
        if #goals == 0 then
            local pitch
            for _, v in ipairs(parts) do
                local ok, isBP = pcall(function() return v.IsA and v:IsA("BasePart") end)
                if ok and isBP then
                    local ok, nm = pcall(function() return v.Name end)
                    local ok2, sz = pcall(function() return v.Size end)
                    local ok3, p = pcall(function() return v.Position end)
                    if ok and ok2 and ok3 and nm and sz and p then
                        local nl = nm:lower()
                        if (nl:find("pitch") or nl:find("grass") or nl:find("field") or nl:find("ground")) and sz.X > 50 and sz.Z > 50 then
                            pitch = { pos = p, size = sz }; break
                        end
                    end
                end
            end
            if pitch then
                local hz = pitch.size.Z / 2
                goals = {
                    { pos = pitch.pos + Vector3.new(0, 1.5, -hz), size = Vector3.new(8, 3, 1) },
                    { pos = pitch.pos + Vector3.new(0, 1.5, hz), size = Vector3.new(8, 3, 1) },
                }
            end
        end
    end
    cachedGoals = goals; lastGoalScan = frameCount
    return goals
end

local lastBestBall = nil
local lastBestBallId = nil
local ballOffFrames = 0
local function hidePred()
    for i = 1, 40 do trailLines[i].Visible = false end
    predCircle.Visible = false; aimLine.Visible = false
end

local function doPrediction()
    if #cachedBalls == 0 then hidePred(); return end
    local cam = ws.CurrentCamera
    if not cam then hidePred(); return end
    local myPos = getCharPos(lp and lp.Character)

    local bestBall
    if lastBestBall and lastBestBall.Parent then
        local pos = lastBestBall.Position
        if pos then
            local _, bon = WorldToScreen(pos)
            if bon then
                local vel = getBallVel(lastBestBall)
                if vel and vel.Magnitude >= 0.5 then
                    bestBall = lastBestBall; ballOffFrames = 0
                end
            end
        end
        if not bestBall then
            ballOffFrames = ballOffFrames + 1
            if ballOffFrames < 5 then bestBall = lastBestBall end
        end
    end
    if not bestBall then
        ballOffFrames = 0; lastBestBall = nil; lastBestBallId = nil
        local bestDist
        for _, ball in ipairs(cachedBalls) do
            local pos = ball.Position
            if pos then
                local _, bon = WorldToScreen(pos)
                if bon then
                    local vel = getBallVel(ball)
                    if vel and vel.Magnitude >= 0.5 then
                        local dist = myPos and (pos - myPos).Magnitude or (pos - cam.Position).Magnitude
                        if not bestDist or dist < bestDist then bestDist = dist; bestBall = ball end
                    end
                end
            end
        end
        if bestBall then lastBestBall = bestBall; lastBestBallId = tostring(bestBall) else hidePred(); return end
    end

    local pos = bestBall.Position
    if not pos then hidePred(); return end
    local vel = getBallVel(bestBall)
    if not vel or vel.Magnitude < 0.5 then hidePred(); return end
    local spd = math.min(vel.Magnitude, 150)

    local pts = {}
    for i = 0, 40 do
        local t = i * 0.06
        local cv = spd > 0.1 and vel.Unit * spd or Vector3.new()
        pts[i+1] = pos + cv * t + 0.5 * GRAVITY * t * t
    end
    for i = 2, #pts do
        local p, c = pts[i-1], pts[i]
        if p and c and p.Y >= 0 and c.Y < 0 then
            local frac = -p.Y / (c.Y - p.Y)
            pts[i] = Vector3.new(p.X + frac * (c.X - p.X), 0, p.Z + frac * (c.Z - p.Z))
            for j = i+1, #pts do pts[j] = nil end; break
        end
    end

    local screenPts = {}
    for i = 1, #pts do
        local sp, on = WorldToScreen(pts[i])
        if on then screenPts[#screenPts+1] = sp end
    end

    if #screenPts >= 2 then
        for i = 1, 40 do
            local l = trailLines[i]
            if i < #screenPts then
                l.From, l.To = screenPts[i], screenPts[i+1]
                l.Transparency = 0.1 + (i / #screenPts) * 0.6
                l.Visible = true
            else
                l.Visible = false
            end
        end
    else
        for i = 1, 40 do trailLines[i].Visible = false end
    end

    local bp, ballOn = WorldToScreen(pos)
    if ballOn then
        predCircle.Position = bp
        predCircle.Radius = 8
        predCircle.Visible = true
        if #screenPts >= 2 then
            aimLine.From = bp; aimLine.To = screenPts[#screenPts]; aimLine.Visible = true
        else
            aimLine.Visible = false
        end
    else
        predCircle.Visible = false; aimLine.Visible = false
    end
end

local function hideGoal()
    goalCircle.Visible = false; goalHeightDot.Visible = false
    if goalTimeText then goalTimeText.Visible = false end
    if urgencyText then urgencyText.Visible = false end
end

local function doGoalPrediction()
    if #cachedBalls == 0 then hideGoal(); return end
    local goals = findGoals()
    if #goals == 0 then hideGoal(); return end

    local bestBall = getNearestBall()
    if not bestBall then hideGoal(); return end
    local bp = bestBall.Position; local vel = getBallVel(bestBall)
    local bestGoal, bestHit, bestTime, bestDist
    if vel and vel.Magnitude > 1 then
        for _, g in ipairs(goals) do
            local d = (bp - g.pos).Magnitude
            local dir = (g.pos - bp).Unit
            if dir:Dot(vel.Unit) > 0 then
                local t = d / vel.Magnitude
                local hit = bp + vel * t + 0.5 * GRAVITY * t * t
                if not bestDist or d < bestDist then
                    bestDist = d; bestGoal = g; bestHit = hit; bestTime = t
                end
            end
        end
    end
    if not bestGoal then hideGoal(); return end

    local gp = bestGoal.pos
    local hitPos = bestHit
    local timeToGoal = bestTime or 0

    local sp, on = WorldToScreen(hitPos)
    if on then
        goalCircle.Position = sp
        goalCircle.Radius = 14
        local nearPost = false
        local gh = bestGoal.size.Y; local gw = bestGoal.size.X
        if gh > 0.1 and gw > 0.1 then
            local dh = math.min(math.abs(hitPos.Y - (gp.Y - gh/2)), math.abs(hitPos.Y - (gp.Y + gh/2)))
            local dw = math.min(math.abs(hitPos.X - (gp.X - gw/2)), math.abs(hitPos.X - (gp.X + gw/2)))
            if dh < 1.5 or dw < 1.5 then nearPost = true end
        end
        local dist = bestGoal and (bestBall.Position - bestGoal.pos).Magnitude or 99
        local urgent = timeToGoal < 0.8 or dist < 15
        if nearPost then
            goalCircle.Color = Color3.fromRGB(255, 100, 0)
            goalCircle.Transparency = 0.3
        else
            goalCircle.Transparency = 0.5
            goalCircle.Color = urgent and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
        end
        if urgencyText then
            urgencyText.Position = Vector2.new(960, 1000)
            urgencyText.Visible = urgent
            if urgent then
                local msg
                if dist < 10 then
                    msg = "CLOSE RANGE!"
                elseif timeToGoal < 0.3 then
                    msg = "ON TOP OF YOU!"
                elseif timeToGoal < 0.5 then
                    msg = "INCOMING!"
                elseif timeToGoal < 0.8 then
                    msg = "GET READY!"
                else
                    msg = "BALL NEAR!"
                end
                urgencyText.Text = msg
            end
        end
        goalCircle.Visible = true

        if gh > 0.1 then
            local hFrac = (hitPos.Y - (gp.Y - gh/2)) / gh
            if hFrac < 0 then hFrac = 0 elseif hFrac > 1 then hFrac = 1 end
            goalHeightDot.Position = Vector2.new(sp.X, sp.Y + 10 - hFrac * 20)
            goalHeightDot.Visible = true
        else
            goalHeightDot.Visible = false
        end

        if goalTimeText then
            goalTimeText.Position = Vector2.new(sp.X + 20, sp.Y - 6)
            goalTimeText.Text = string.format("%.1fs", timeToGoal)
            goalTimeText.Visible = true
        end
    else
        hideGoal(); return
    end

end

local function doOpenGoal()
    if #cachedBalls == 0 then
        for i = 1, 4 do coneLines[i].Visible = false end
        if angleText then angleText.Visible = false end
        if strikerDistText then strikerDistText.Visible = false end
        return
    end
    local goals = findGoals()
    if #goals == 0 then
        for i = 1, 4 do coneLines[i].Visible = false end
        if angleText then angleText.Visible = false end
        if strikerDistText then strikerDistText.Visible = false end
        return
    end

    local bestBall = getNearestBall()
    if not bestBall then
        for i = 1, 4 do coneLines[i].Visible = false end
        if angleText then angleText.Visible = false end
        if strikerDistText then strikerDistText.Visible = false end
        return
    end
    local bp = bestBall.Position; local vel = getBallVel(bestBall)
    local bestGoal, bestDist
    if vel and vel.Magnitude > 1 then
        for _, g in ipairs(goals) do
            local d = (bp - g.pos).Magnitude
            local dir = (g.pos - bp).Unit
            if dir:Dot(vel.Unit) > 0.3 then
                if not bestDist or d < bestDist then
                    bestDist = d; bestGoal = g
                end
            end
        end
    end
    if not bestGoal then
        for i = 1, 4 do coneLines[i].Visible = false end
        if angleText then angleText.Visible = false end
        if strikerDistText then strikerDistText.Visible = false end
        return
    end

    local g = bestGoal
    local half = g.size / 2
    local corners = {
        g.pos + Vector3.new(-half.X, half.Y, 0),
        g.pos + Vector3.new(half.X, half.Y, 0),
        g.pos + Vector3.new(-half.X, -half.Y, 0),
        g.pos + Vector3.new(half.X, -half.Y, 0),
    }

    local bs, bon = WorldToScreen(bestBall.Position)

    -- cone lines from ball to each corner
    for i = 1, 4 do
        local sp, on = WorldToScreen(corners[i])
        if bon and on then
            coneLines[i].From = bs; coneLines[i].To = sp; coneLines[i].Visible = true
        else
            coneLines[i].Visible = false
        end
    end

    -- shooting angle (degrees between left and right posts)
    if angleText then
        local lp = g.pos + Vector3.new(-half.X, 0, 0)
        local rp = g.pos + Vector3.new(half.X, 0, 0)
        local v1 = (lp - bestBall.Position).Unit
        local v2 = (rp - bestBall.Position).Unit
        local dot = v1:Dot(v2)
        if dot < -1 then dot = -1 elseif dot > 1 then dot = 1 end
        local angleDeg = math.deg(math.acos(dot))
        if bon then
            angleText.Position = Vector2.new(bs.X - 60, bs.Y - 40)
            angleText.Text = math.floor(angleDeg + 0.5) .. " deg"
            angleText.Visible = true
        else
            angleText.Visible = false
        end
    end

    -- distance to goal
    if strikerDistText then
        local d = (bestBall.Position - g.pos).Magnitude
        if bon then
            strikerDistText.Position = Vector2.new(bs.X + 60, bs.Y - 40)
            strikerDistText.Text = math.floor(d + 0.5) .. " st"
            strikerDistText.Visible = true
        else
            strikerDistText.Visible = false
        end
    end
end

local function doShotSpeed()
    if #cachedBalls == 0 then
        if shotSpeedText then shotSpeedText.Visible = false end
        return
    end
    local bestBall = getNearestBall()
    if not bestBall then
        if shotSpeedText then shotSpeedText.Visible = false end
        return
    end
    if shotSpeedText then
        local vel = getBallVel(bestBall)
        local bs, bon = WorldToScreen(bestBall.Position)
        if bon then
            shotSpeedText.Position = Vector2.new(bs.X, bs.Y - 70)
            shotSpeedText.Text = tostring(math.floor(vel.Magnitude + 0.5)) .. " st/s"
            shotSpeedText.Visible = true
        else
            shotSpeedText.Visible = false
        end
    end
end

local function doDiveHelper()
    if #cachedBalls == 0 then diveArrow.Visible = false; return end
    local goals = findGoals()
    if #goals == 0 then diveArrow.Visible = false; return end

    local bestBall = getNearestBall()
    if not bestBall then diveArrow.Visible = false; return end
    local bp = bestBall.Position; local vel = getBallVel(bestBall)
    local bestGoal, bestHit, bestDist
    if vel and vel.Magnitude > 1 then
        for _, g in ipairs(goals) do
            local d = (bp - g.pos).Magnitude
            local dir = (g.pos - bp).Unit
            if dir:Dot(vel.Unit) > 0.3 then
                local t = d / vel.Magnitude
                local hit = bp + vel * t + 0.5 * GRAVITY * t * t
                if not bestDist or d < bestDist then
                    bestDist = d; bestGoal = g; bestHit = hit
                end
            end
        end
    end
    if not bestGoal then diveArrow.Visible = false; return end

    local halfW = bestGoal.size.X / 2
    if halfW < 0.1 then halfW = 4 end
    local aimFrac = (bestHit.X - bestGoal.pos.X) / halfW
    if aimFrac < -1 then aimFrac = -1 elseif aimFrac > 1 then aimFrac = 1 end

    local bs, bon = WorldToScreen(bestBall.Position)
    if not bon then diveArrow.Visible = false; return end

    diveArrow.PointA = Vector2.new(bs.X + aimFrac * 60, bs.Y + 60)
    diveArrow.PointB = Vector2.new(bs.X + aimFrac * 60 - 16, bs.Y + 90)
    diveArrow.PointC = Vector2.new(bs.X + aimFrac * 60 + 16, bs.Y + 90)
    diveArrow.Visible = true
end

local function doGoalieVision()
    if #cachedBalls == 0 then
        keeperLine.Visible = false
        if distText then distText.Visible = false end; return
    end
    local goals = findGoals()
    if #goals == 0 then
        keeperLine.Visible = false
        if distText then distText.Visible = false end; return
    end

    local bestBall = getNearestBall()
    if not bestBall then
        keeperLine.Visible = false
        if distText then distText.Visible = false end; return
    end
    local bp = bestBall.Position; local vel = getBallVel(bestBall)
    local bestGoal, bestHit, bestDist
    if vel and vel.Magnitude > 1 then
        for _, g in ipairs(goals) do
            local d = (bp - g.pos).Magnitude
            local dir = (g.pos - bp).Unit
            if dir:Dot(vel.Unit) > 0.3 then
                local t = d / vel.Magnitude
                local hit = bp + vel * t + 0.5 * GRAVITY * t * t
                if not bestDist or d < bestDist then
                    bestDist = d; bestGoal = g; bestHit = hit
                end
            end
        end
    end
    if not bestGoal then
        keeperLine.Visible = false
        if distText then distText.Visible = false end; return
    end

    local g = bestGoal; local half = g.size / 2
    local lp3d = g.pos + Vector3.new(-half.X, 0, 0)
    local rp3d = g.pos + Vector3.new(half.X, 0, 0)
    local lps, lpon = WorldToScreen(lp3d)
    local rps, rpon = WorldToScreen(rp3d)
    local hs, hon = WorldToScreen(bestHit)

    local barVisible = false
    local barStart, barEnd

    if lpon and rpon then
        barStart = lps; barEnd = rps; barVisible = true
    elseif lpon and not rpon then
        barStart = lps; barEnd = lps + Vector2.new(200, 0); barVisible = true
    elseif not lpon and rpon then
        barStart = rps - Vector2.new(200, 0); barEnd = rps; barVisible = true
    end

    local bs, bon = WorldToScreen(bestBall.Position)
    if bon and barVisible then
        local bw = barEnd.X - barStart.X
        local tx, ty
        if hon and math.abs(bw) > 1 then
            local frac = (hs.X - barStart.X) / bw
            if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
            tx = barStart.X + bw * frac
            ty = barStart.Y + (barEnd.Y - barStart.Y) * frac
        else
            tx = bs.X; ty = (barStart.Y + barEnd.Y) / 2
        end
        keeperLine.From = Vector2.new(bs.X, bs.Y)
        keeperLine.To = Vector2.new(tx, ty)
        keeperLine.Visible = true
    else
        keeperLine.Visible = false
    end

    if distText then
        local d = (bestBall.Position - g.pos).Magnitude
        if barVisible then
            local bw = barEnd.X - barStart.X
            local dx, dy
            if hon and math.abs(bw) > 1 then
                local frac = (hs.X - barStart.X) / bw
                if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
                dx = barStart.X + bw * frac
                dy = barStart.Y + (barEnd.Y - barStart.Y) * frac
            else
                dx = (barStart.X + barEnd.X) / 2
                dy = (barStart.Y + barEnd.Y) / 2
            end
            distText.Position = Vector2.new(dx, dy - 20)
            distText.Text = tostring(math.floor(d + 0.5)) .. " st"
            distText.Visible = true
        else
            distText.Visible = false
        end
    end
end

rs.Heartbeat:Connect(function()
    if predictionEnabled or goalPredictionEnabled or diveHelperEnabled or goalieVisionEnabled or shotSpeedEnabled or openGoalEnabled then scanBalls() end
    if predictionEnabled then
        local ok, err = pcall(doPrediction)
        if not ok then warn("pred err:", err) end
    else
        for i = 1, 40 do trailLines[i].Visible = false end
        predCircle.Visible = false; aimLine.Visible = false
    end

    if goalPredictionEnabled then
        local ok, err = pcall(doGoalPrediction)
        if not ok then warn("gp err:", err) end
    else
        hideGoal()
    end

    if diveHelperEnabled then
        local ok, err = pcall(doDiveHelper)
        if not ok then warn("dh err:", err) end
    else
        diveArrow.Visible = false
    end

    if shotSpeedEnabled then
        local ok, err = pcall(doShotSpeed)
        if not ok then warn("ss err:", err) end
    else
        if shotSpeedText then shotSpeedText.Visible = false end
    end

    if openGoalEnabled then
        local ok, err = pcall(doOpenGoal)
        if not ok then warn("og err:", err) end
    else
        for i = 1, 4 do coneLines[i].Visible = false end
        if angleText then angleText.Visible = false end
        if strikerDistText then strikerDistText.Visible = false end
    end

    if goalieVisionEnabled then
        local ok, err = pcall(doGoalieVision)
        if not ok then warn("gv err:", err) end
    else
        keeperLine.Visible = false
        if distText then distText.Visible = false end
    end
end)

print("Made By Vxx.lua")
print("Loaded")
print("End is menu key")
print("@vxx.lua for info")
