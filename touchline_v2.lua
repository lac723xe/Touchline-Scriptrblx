loadstring(game:HttpGet("https://scripts.wabisabi.mom/wabi-sabi-ui-lib.lua"))()
local Library = WabiSabi
local Window = Library:CreateWindow({ Title = "Touchline", SubTitle = "prediction", Size = Vector2.new(560, 500), Resize = true, ToggleKey = Enum.KeyCode.End })
local BallsTab = Window:AddTab({ Title = "Balls", Icon = "soccer" })

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

--== Drawings ==--
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

local goalCircle = Drawing.new("Circle")
goalCircle.Thickness = 2; goalCircle.NumSides = 24; goalCircle.Filled = true
goalCircle.Color = Color3.fromRGB(50, 255, 50); goalCircle.Transparency = 0.5; goalCircle.Visible = false

--== UI ==--
local Prediction = BallsTab:AddSection("Ball Prediction")
Prediction:AddToggle({ Id = "pred_enable", Title = "Enable", Default = false, Callback = function(v) predictionEnabled = v end })

local GoalPred = BallsTab:AddSection("Goal Prediction")
GoalPred:AddToggle({ Id = "gp_enable", Title = "Enable", Default = false, Callback = function(v) goalPredictionEnabled = v end })

Window:BuildInterfaceSection(BallsTab)
Window:BuildConfigSection(BallsTab)
Library:LoadAutoloadConfig()
Library:Notify({ Title = "Loaded", Content = "Touchline ready.", Duration = 3 })

--== Helpers ==--
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

local cachedGoals = {}
local lastGoalScan = 0
local function findGoals()
    if frameCount - lastGoalScan < 100 and #cachedGoals > 0 then return cachedGoals end
    local goals = {}
    local ok, parts = pcall(function() local r = {}; for _, v in ipairs(ws:GetDescendants()) do r[#r+1] = v end; return r end)
    if ok then
        for _, v in ipairs(parts) do
            local ok, isBP = pcall(function() return v.IsA and v:IsA("BasePart") end)
            if ok and isBP then
                local ok, nm = pcall(function() return v.Name end)
                if ok and nm and nm:lower():find("goal") then
                    local ok, pos = pcall(function() return v.Position end)
                    local ok2, sz = pcall(function() return v.Size end)
                    if ok and pos and ok2 and sz then goals[#goals+1] = { pos = pos, size = sz } end
                end
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

--== Prediction ==--
local lastBestBall = nil
local lastBestBallId = nil
local ballOffFrames = 0
local function doPrediction()
    if #cachedBalls == 0 then return end
    local cam = ws.CurrentCamera
    if not cam then return end
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
        if bestBall then lastBestBall = bestBall; lastBestBallId = tostring(bestBall) else return end
    end

    local pos = bestBall.Position
    if not pos then return end
    local vel = getBallVel(bestBall)
    if not vel or vel.Magnitude < 0.5 then return end
    local spd = math.min(vel.Magnitude, 100)

    local pts = {}
    for i = 0, 20 do
        local t = i * 0.05
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

--== Goal Prediction & Dive Assist ==--
local function doGoalPrediction()
    if #cachedBalls == 0 then goalCircle.Visible = false; diveArrow.Visible = false; return end
    local goals = findGoals()
    if #goals == 0 then goalCircle.Visible = false; diveArrow.Visible = false; return end

    local bestBall, bestScore, bestGoal
    for _, ball in ipairs(cachedBalls) do
        local pos = ball.Position
        if pos then
            local vel = getBallVel(ball)
            if vel and vel.Magnitude > 1 then
                for _, g in ipairs(goals) do
                    local d = (pos - g.pos).Magnitude
                    if d < 40 then
                        local s = vel.Magnitude * 10 - d
                        if not bestScore or s > bestScore then bestScore = s; bestBall = ball; bestGoal = g end
                    end
                end
            end
        end
    end
    if not bestBall then goalCircle.Visible = false; diveArrow.Visible = false; return end

    local bp = bestBall.Position
    local gp = bestGoal.pos
    local bv = getBallVel(bestBall)
    if not bv or bv.Magnitude < 1 then goalCircle.Visible = false; diveArrow.Visible = false; return end

    local dir = (gp - bp).Unit
    local dist = (gp - bp).Magnitude
    local timeToGoal = dist / bv.Magnitude
    local hitPos = bp + bv * timeToGoal + 0.5 * GRAVITY * timeToGoal * timeToGoal

    local sp, on = WorldToScreen(hitPos)
    if on then
        goalCircle.Position = sp
        goalCircle.Radius = 12
        goalCircle.Color = timeToGoal < 0.5 and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(50, 255, 50)
        goalCircle.Visible = true
    else
        goalCircle.Visible = false; diveArrow.Visible = false; return
    end

    local gpSp, gpOn = WorldToScreen(gp)
    if gpOn then
        local diff = sp - gpSp
        local dist = diff and diff.Magnitude
        if dist and dist > 10 then
            local dirVec = diff.Unit
            local arrowSize = math.min(dist * 0.4, 25)
            local tip = gpSp + dirVec * dist * 0.5
            local perp = Vector2.new(-dirVec.Y, dirVec.X)
            local base1 = gpSp + dirVec * (dist * 0.5 - arrowSize * 0.6) + perp * arrowSize * 0.3
            local base2 = gpSp + dirVec * (dist * 0.5 - arrowSize * 0.6) - perp * arrowSize * 0.3
            diveArrow.PointA = tip; diveArrow.PointB = base1; diveArrow.PointC = base2
            diveArrow.Color = timeToGoal < 0.5 and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 200, 0)
            diveArrow.Visible = true
        else
            diveArrow.Visible = false
        end
    else
        diveArrow.Visible = false
    end
end

--== Heartbeat ==--
rs.Heartbeat:Connect(function()
    if predictionEnabled or goalPredictionEnabled then scanBalls() end
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
        goalCircle.Visible = false; diveArrow.Visible = false
    end
end)

print("Made By Vxx.lua")
print("Loaded")
print("End is menu key")
print("@vxx.lua for info")
