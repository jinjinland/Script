---------------------------------------------------------------------------------------------------
-- 高兼容性WASD/QE飞行脚本（带升降、加速、脚本开关、可拖拽GUI，PlatformStand支持，自动切换目标）--
---------------------------------------------------------------------------------------------------

-- 使用说明：
-- 按F切换飞行/取消飞行
-- 按住WASD控制方向，E/Space升高，Q/左Ctrl下降，Shift加速，按钮可开关整个脚本
-- 支持玩家和载具座位自动切换，玩家飞行模式下无法坐上任何座位

-- 参数
local Speed = 50     -- 普通速度
local BoostSpeed = 999  -- 加速速度
local Enable = true   -- 脚本总开关


local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")

-- 防止多次加载
local function destroyDuplicateGui(Parents, GuiName)
    for _, parent in ipairs(Parents) do
        local Gui = parent:FindFirstChild(GuiName)
        if Gui and Gui:IsA("ScreenGui") then
            local dragBox = Gui:FindFirstChild("DragBox")
            if dragBox then
                dragBox:Destroy()
            end
            Gui:Destroy()
        end
    end
end
pcall(destroyDuplicateGui, {PlayerGui}, "SpeedFlyGui")

-- GUI
local Gui = Instance.new("ScreenGui")
Gui.Name = "SpeedFlyGui"
Gui.Parent = PlayerGui
Gui.ResetOnSpawn = false

local Move = Instance.new("TextLabel")
Move.Name = "DragBox"
Move.Parent = Gui
Move.Text = "拖拽"
Move.TextScaled = true
Move.AnchorPoint = Vector2.new(0.5, 0.5)
Move.Position = UDim2.new(0.5, 0, 0.5, 0)
Move.Size = UDim2.new(0, 20, 0, 20)
Move.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

local UIDragDetector = Instance.new("UIDragDetector")
UIDragDetector.Parent = Move

local Button = Instance.new("TextButton")
Button.Name = "SwitchButton"
Button.Parent = Move
Button.Text = "飞行脚本:开"
Button.TextScaled = true
Button.Position = UDim2.new(1, 0, 1, 0)
Button.Size = UDim2.new(0, 120, 0, 50)
Button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)

Button.MouseButton1Click:Connect(function()
    Enable = not Enable
    if Enable then
        Button.Text = "飞行脚本:开"
        Button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    else
        Button.Text = "飞行脚本:关"
        Button.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        flying = false
        if bodyGyro then pcall(function() bodyGyro:Destroy() end) bodyGyro = nil end
        if bodyVel then pcall(function() bodyVel:Destroy() end) bodyVel = nil end
        currentRoot = nil
        currentMode = "none"
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.PlatformStand = false
        end
    end
end)

-- 方向与状态变量
local flying = false
local bodyGyro, bodyVel
local moveDir = Vector3.new(0,0,0)
local boosting = false
local currentRoot = nil
local currentMode = "none" -- "seat" or "player"

local keyMap = {
    [Enum.KeyCode.W] = Vector3.new(0,0,-1),
    [Enum.KeyCode.S] = Vector3.new(0,0,1),
    [Enum.KeyCode.A] = Vector3.new(-1,0,0),
    [Enum.KeyCode.D] = Vector3.new(1,0,0),
}

-- 玩家/载具双模式
local function getFlyRoot()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        local seat = char.Humanoid.SeatPart
        if seat and (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then
            return seat, "seat"
        end
        if char:FindFirstChild("HumanoidRootPart") then
            return char.HumanoidRootPart, "player"
        end
    end
    return nil, "none"
end

local function recomputeDir()
    moveDir = Vector3.new(0,0,0)
    for key, vec in pairs(keyMap) do
        if UserInputService:IsKeyDown(key) then
            moveDir = moveDir + vec
        end
    end
end

local function updateMoveDir(key, down)
    if keyMap[key] then
        local delta = keyMap[key]
        if down then
            moveDir = moveDir + delta
        else
            moveDir = moveDir - delta
        end
    elseif key == Enum.KeyCode.LeftShift then
        boosting = down
    end
end

local function stopFly()
    flying = false
    if bodyGyro then pcall(function() bodyGyro:Destroy() end) bodyGyro = nil end
    if bodyVel then pcall(function() bodyVel:Destroy() end) bodyVel = nil end
    currentRoot = nil
    currentMode = "none"
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.PlatformStand = false
    end
end

local function setGyroToCamera(gyro)
    local cam = workspace.CurrentCamera
    local pos = cam.CFrame.Position
    local look = cam.CFrame.LookVector
    local up = cam.CFrame.UpVector
    gyro.CFrame = CFrame.lookAt(pos, pos + look, up)
end

local function startFly()
    if flying then return end
    local root, mode = getFlyRoot()
    if not root or mode == "none" then return end
    flying = true
    recomputeDir()
    currentRoot = root
    currentMode = mode
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("Humanoid") then
        if mode == "player" then
            char.Humanoid.PlatformStand = true
        else
            char.Humanoid.PlatformStand = false
        end
    end
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 50000
    bodyGyro.D = 500
    setGyroToCamera(bodyGyro)
    bodyGyro.Parent = root
    bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVel.Velocity = Vector3.new(0,0,0)
    bodyVel.Parent = root
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.F and Enable then
        if flying then
            stopFly()
        else
            startFly()
        end
    end
    updateMoveDir(input.KeyCode, true)
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    updateMoveDir(input.KeyCode, false)
end)

-- 实时飞行与模式切换
local flyConn
flyConn = RunService.RenderStepped:Connect(function()
    if not Enable then
        if flyConn then flyConn:Disconnect() flyConn = nil end
        stopFly()
        return
    end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChild("Humanoid")
    -- 自动检测切换模式
    if flying then
        local root, mode = getFlyRoot()
        if root ~= currentRoot or mode ~= currentMode then
            -- 切换模式（如跳下座位/上座位）
            if bodyGyro then pcall(function() bodyGyro:Destroy() end) bodyGyro = nil end
            if bodyVel then pcall(function() bodyVel:Destroy() end) bodyVel = nil end
            if root and mode ~= "none" then
                currentRoot = root
                currentMode = mode
                if humanoid then
                    if mode == "player" then
                        humanoid.PlatformStand = true
                    else
                        humanoid.PlatformStand = false
                    end
                end
                bodyGyro = Instance.new("BodyGyro")
                bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                bodyGyro.P = 50000
                bodyGyro.D = 500
                setGyroToCamera(bodyGyro)
                bodyGyro.Parent = root
                bodyVel = Instance.new("BodyVelocity")
                bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bodyVel.Velocity = Vector3.new(0,0,0)
                bodyVel.Parent = root
            else
                stopFly()
                return
            end
        end
    end

    -- 实时检测所有方向键和升降键
    moveDir = Vector3.new(0,0,0)
    for key, vec in pairs(keyMap) do
        if UserInputService:IsKeyDown(key) then
            moveDir = moveDir + vec
        end
    end
    local vert = 0
    if UserInputService:IsKeyDown(Enum.KeyCode.E) then
        vert = 1
    elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
        vert = -1
    end

    if flying and bodyGyro and bodyVel then
        setGyroToCamera(bodyGyro)
        local cam = workspace.CurrentCamera
        local dir = cam.CFrame:VectorToWorldSpace(moveDir)
        local velocity = Vector3.new(0,0,0)
        if dir.Magnitude > 0 then
            velocity = dir.Unit * (boosting and BoostSpeed or Speed)
        end
        if vert ~= 0 then
            velocity = velocity + Vector3.new(0, vert * (boosting and BoostSpeed or Speed), 0)
        end
        bodyVel.Velocity = velocity

        -- 每帧强制PlatformStand
        if humanoid then
            if currentMode == "player" then
                if not humanoid.PlatformStand then
                    humanoid.PlatformStand = true
                end
            else
                if humanoid.PlatformStand then
                    humanoid.PlatformStand = false
                end
            end
        end

        -- 玩家模式禁止坐上座位
        if currentMode == "player" and humanoid and humanoid.SeatPart then
            humanoid.Sit = false
        end
    elseif (not flying or not Enable) and (bodyGyro or bodyVel) then
        stopFly()
    end
end)

-- 角色刷新时自动关闭飞行，防止残留
LocalPlayer.CharacterAdded:Connect(function(char)
    stopFly()
end)
