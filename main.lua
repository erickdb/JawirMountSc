local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players        = game:GetService("Players")
local UIS            = game:GetService("UserInputService")
local RunService     = game:GetService("RunService")
local LP             = Players.LocalPlayer

local CFG = {
    walk       = 16,
    jump       = 50,
    fly        = false,
    flySpeed   = 20,
    antiFall   = true,
    flyKey     = Enum.KeyCode.F, -- toggle Fly
    uiToggle   = Enum.KeyCode.K, -- toggle UI Rayfield
}

local function getChar()
    return LP.Character or LP.CharacterAdded:Wait()
end

local function getHumanoid(char)
    char = char or getChar()
    return char:FindFirstChildOfClass("Humanoid")
        or char:FindFirstChild("Humanoid")
        or char:FindFirstChildWhichIsA("Humanoid", true)
end

local function getRoot(char)
    char = char or getChar()
    return char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("LowerTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChildWhichIsA("BasePart")
end

local function applyMovement()
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.WalkSpeed    = CFG.walk
        hum.JumpPower    = CFG.jump
    end
end

-- ====== Walk Speed ======
local walkSpeedValue = CFG.walk
local walkSpeedEnabled = false

-- ====== Infinite Jump ======
local InfJump = { enabled = false, conns = {} }

local function ij_unbind()
    for _,c in ipairs(InfJump.conns) do
        pcall(function() c:Disconnect() end)
    end
    InfJump.conns = {}
end

local function ij_doJump()
    local hum = getHumanoid()
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hum.Jump = true
    end
end

local function ij_bind()
    table.insert(InfJump.conns, UIS.JumpRequest:Connect(function() ij_doJump() end))
    table.insert(InfJump.conns, UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Space then
            ij_doJump()
        end
    end))
    table.insert(InfJump.conns, LP.CharacterAdded:Connect(function()
        task.wait(0.2)
        if InfJump.enabled then
            ij_unbind()
            ij_bind()
        end
    end))
end

local function setInfiniteJump(on)
    if on == InfJump.enabled then return end
    InfJump.enabled = on
    ij_unbind()
    if on then ij_bind() end
    pcall(function()
        Rayfield:Notify({
            Title = "Infinite Jump",
            Content = on and "Enabled" or "Disabled",
            Duration = 1.25
        })
    end)
end


-- ====== Fly System (mobile & PC: single-jump = naik; double-tap jump = turun) ======
local Fly = {
    enabled       = false,
    speed         = CFG.flySpeed,
    verticalSpeed = CFG.flySpeed,
    conns         = {},
    bodyGyro      = nil,
    bodyVel       = nil,
    ascend        = false,
    descend       = false,
    lastJumpTime  = 0,
    dtapWindow    = 0.25,
    pulseTime     = 0.45
}

local function fly_unbind()
    for _, c in ipairs(Fly.conns) do
        pcall(function() c:Disconnect() end)
    end
    Fly.conns = {}
    if Fly.bodyGyro then Fly.bodyGyro:Destroy() end
    if Fly.bodyVel  then Fly.bodyVel:Destroy()  end
    Fly.bodyGyro, Fly.bodyVel = nil, nil
    Fly.ascend, Fly.descend = false, false
end

local function fly_bind()
    local char = getChar()
    local root = getRoot(char)
    if not root then return end

    Fly.bodyGyro = Instance.new("BodyGyro")
    Fly.bodyGyro.P = 9e4
    Fly.bodyGyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    Fly.bodyGyro.CFrame = root.CFrame
    Fly.bodyGyro.Parent = root

    Fly.bodyVel = Instance.new("BodyVelocity")
    Fly.bodyVel.maxForce = Vector3.new(9e9, 9e9, 9e9)
    Fly.bodyVel.velocity = Vector3.zero
    Fly.bodyVel.Parent = root

    table.insert(Fly.conns, RunService.RenderStepped:Connect(function()
        local hum = getHumanoid()
        local r = getRoot()
        if not hum or not r then return end

        local horizontal = hum.MoveDirection * Fly.speed
        local vertical = Vector3.zero

        if Fly.ascend then
            vertical = Vector3.new(0,  Fly.verticalSpeed, 0)
        elseif Fly.descend then
            vertical = Vector3.new(0, -Fly.verticalSpeed, 0)
        end

        local cam = workspace.CurrentCamera
        if cam then Fly.bodyGyro.CFrame = cam.CFrame end

        local vel = horizontal + vertical

        if CFG.antiFall and not Fly.ascend and not Fly.descend and horizontal.Magnitude < 1e-3 then
            vel = Vector3.new(0, 0.01, 0)
        end

        Fly.bodyVel.velocity = vel
    end))

    local function handleJumpTap()
        local t = os.clock()
        if (t - Fly.lastJumpTime) <= Fly.dtapWindow then
            Fly.lastJumpTime = 0
            Fly.ascend  = false
            Fly.descend = true
            task.delay(Fly.pulseTime, function()
                if not Fly.ascend then
                    Fly.descend = false
                end
            end)
            return
        end

        Fly.lastJumpTime = t
        Fly.descend = false
        Fly.ascend  = true
        task.delay(Fly.pulseTime, function()
            if not Fly.descend and (os.clock() - Fly.lastJumpTime) >= Fly.pulseTime then
                Fly.ascend = false
            end
        end)
    end

    table.insert(Fly.conns, UIS.JumpRequest:Connect(function()
        if Fly.enabled then handleJumpTap() end
    end))

    table.insert(Fly.conns, LP.CharacterAdded:Connect(function()
        if Fly.enabled then
            task.wait(0.2)
            fly_unbind()
            fly_bind()
        end
    end))
end

function setFly(on)
    if on == Fly.enabled then return end
    Fly.enabled = on
    fly_unbind()
    if on then fly_bind() end
    pcall(function()
        Rayfield:Notify({
            Title = "Fly",
            Content = on and "Enabled" or "Disabled",
            Duration = 1.25
        })
    end)
end

-- ====== God Mode dengan Damage Patch ======
local God = {
    enabled = false,
    conns = {},
    maxHP = 9e9,
    hooks = {}
}

local function gm_disconnect()
    for _, c in ipairs(God.conns) do pcall(function() c:Disconnect() end) end
    God.conns = {}
    God.hooks = {}
end

local function gm_patchHumanoid(hum)
    if not hum then return end

    pcall(function()
        hum.BreakJointsOnDeath = false
        hum.MaxHealth = God.maxHP
        hum.Health = God.maxHP
    end)

    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)

    if hum.TakeDamage and not God.hooks["TakeDamage"] then
        pcall(function()
            God.hooks["TakeDamage"] = hookfunction(hum.TakeDamage, function(...)
                if God.enabled then
                    return
                end
                return God.hooks["TakeDamage"](...)
            end)
        end)
    end

    table.insert(God.conns, hum.StateChanged:Connect(function(_, new)
        if God.enabled and new == Enum.HumanoidStateType.Dead then
            task.defer(function()
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                    hum.Health = God.maxHP
                end)
            end)
        end
    end))

    table.insert(God.conns, hum.HealthChanged:Connect(function(hp)
        if God.enabled and hp < God.maxHP then
            pcall(function()
                hum.MaxHealth = God.maxHP
                hum.Health = God.maxHP
            end)
        end
    end))
end

local function gm_bind()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    gm_patchHumanoid(hum)

    table.insert(God.conns, LP.CharacterAdded:Connect(function(nc)
        gm_disconnect()
        if God.enabled then
            task.wait(0.2)
            local nh = nc:FindFirstChildOfClass("Humanoid") or nc:WaitForChild("Humanoid", 5)
            gm_patchHumanoid(nh)
        end
    end))
end

function setGodMode(on, hideHealthBar)
    if on == God.enabled then return end
    God.enabled = on
    gm_disconnect()

    pcall(function()
        game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Health, not hideHealthBar)
    end)

    if on then
        gm_bind()
        Rayfield:Notify({ Title="God Mode", Content="Enabled", Duration=1.25 })
    else
        Rayfield:Notify({ Title="God Mode", Content="Disabled", Duration=1.25 })
    end
end

-- util teleport aman
local function tpTo(v3)
    local plr  = game.Players.LocalPlayer
    local char = plr.Character or plr.CharacterAdded:Wait()
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and root) then return end

    pcall(function() hum.Sit = false end)
    root.CFrame = CFrame.new(v3 + Vector3.new(0, 5, 0))
end

-- === koordinat Horeg ===
local POS_AKHIR_HOREG = Vector3.new(-1068.40857, 1044.99792, 487.82538)
local PUNCAK_HOREG    = Vector3.new(-1682.80188, 1081.27466, 522.91455)

-- Fungsi teleport
local function teleportPlayerToMe(targetName)
    local localPlayer = game.Players.LocalPlayer
    local target = game.Players:FindFirstChild(targetName)

    if localPlayer and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") and
       target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then

        local myHRP = localPlayer.Character.HumanoidRootPart
        local targetHRP = target.Character.HumanoidRootPart

        -- Teleport target ke posisi kita
        targetHRP.CFrame = myHRP.CFrame + Vector3.new(2, 0, 0) -- offset biar ga nempel
    else
        Rayfield:Notify({
            Title = "Error",
            Content = "Player tidak valid atau HumanoidRootPart tidak ditemukan",
            Duration = 3
        })
    end
end


-- ====== Windows ======
local Window = Rayfield:CreateWindow({
   Name = "JAWIR ACADEMY | MOUNT SC",
   Icon = 0,
   LoadingTitle = "JAWIR ACADEMY | MOUNT SC",
   LoadingSubtitle = "Made by JAWIR ACADEMY",
   ShowText = "JAWIR ACADEMY",
   Theme = "DarkBlue",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = true,
   DisableBuildWarnings = true,
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil,
      FileName = "JAWIR ACADEMY"
   },
   Discord = {
      Enabled = false,
      Invite = "noinvitelink",
      RememberJoins = true
   },
   KeySystem = false,
   KeySettings = {
      Title = "JAWIR ACADEMY | Key",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided",
      FileName = "Key",
      SaveKey = true,
      GrabKeyFromSite = false,
      Key = {"Hello"}
   }
})

local MainTab = Window:CreateTab("🏠 Main", nil)

local Section = MainTab:CreateSection("Walk And Jump Section")

local WalkSpeedSlider = MainTab:CreateSlider({
    Name = "Walk Speed Value",
    Range = {1, 100},
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = walkSpeedValue,
    Callback = function(v)
        walkSpeedValue = v
        if walkSpeedEnabled then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = walkSpeedValue end
        end
    end,
})

local ToggleWalkSpeed = MainTab:CreateToggle({
   Name = "Walk Speed",
   CurrentValue = false,
   Callback = function(v)
        walkSpeedEnabled = v
        local hum = getHumanoid()
        if hum then
            if v then
                hum.WalkSpeed = walkSpeedValue
            else
                hum.WalkSpeed = CFG.walk
            end
        end
   end,
})

local Toggle = MainTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Callback = function(v)
        setInfiniteJump(v)
    end,
})

local Section = MainTab:CreateSection("Fly Section")

local VerticalSlider = MainTab:CreateSlider({
    Name = "Jarak per Tap",
    Range = {1, 100},
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = Fly.verticalSpeed,
    Callback = function(v)
        Fly.verticalSpeed = v
        Rayfield:Notify({ Title = "Fly", Content = "Vertical Speed: "..tostring(v), Duration = 0.8 })
    end,
})

local PulseSlider = MainTab:CreateSlider({
    Name = "Durasi Tap",
    Range = {0.10, 1.50},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Fly.pulseTime,
    Callback = function(v)
        Fly.pulseTime = v
        Rayfield:Notify({ Title = "Fly", Content = "Pulse Time: "..string.format("%.2f", v).."s", Duration = 0.8 })
    end,
})

local HSpeedSlider = MainTab:CreateSlider({
    Name = "Fly Speed",
    Range = {5, 100},
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = Fly.speed,
    Callback = function(v)
        Fly.speed = v
        CFG.flySpeed = v
        Rayfield:Notify({ Title = "Fly", Content = "Horizontal Speed: "..tostring(v), Duration = 0.8 })
    end,
})

local Toggle = MainTab:CreateToggle({
   Name = "Fly",
   CurrentValue = false,
   Callback = function(v)
        setFly(v)
    end,
})

local Section = MainTab:CreateSection("Health Section")

local Toggle = MainTab:CreateToggle({
   Name = "God Mode",
   CurrentValue = false,
   Callback = function(v)
        setGodMode(v, true)
    end,
})

local TeleTab = Window:CreateTab("🚀 Teleport", nil)
local Section = TeleTab:CreateSection("Teleport Section Section")

local Button = TeleTab:CreateButton({
    Name = "Teleport Pos Akhir (Horeg)",
    Callback = function()
        tpTo(POS_AKHIR_HOREG)
    end,
})

local Button = TeleTab:CreateButton({
    Name = "Teleport Puncak (Horeg)",
    Callback = function()
        tpTo(PUNCAK_HOREG)
    end,
})

-- ====== Players Tab ======
local PlayerTab = Window:CreateTab("👥 Players", nil)

local optionToPlayer = {}
local selectedLabel  = nil

local function makeLabel(p)
    if p == LP then
        return string.format("%s (You) [%d]", p.Name, p.UserId)
    else
        return string.format("%s [%d]", p.Name, p.UserId)
    end
end

local function buildOptions()
    optionToPlayer = {}
    local opts = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local label = makeLabel(p)
        optionToPlayer[label] = p
        table.insert(opts, label)
    end
    return opts
end

-- helper: if selected label nil
local function getSelected()
    if selectedLabel and optionToPlayer[selectedLabel] then
        return selectedLabel
    end
    local opts = buildOptions()
    if #opts > 0 then
        selectedLabel = opts[1]
        return selectedLabel
    end
    return nil
end

-- option for dropdown
local initialOpts = buildOptions()
local PlayerDropdown = PlayerTab:CreateDropdown({
    Name = "Pilih Player",
    Options = initialOpts,
    CurrentOption = initialOpts[1] or nil,
    Callback = function(label)
        if typeof(label) == "table" then
            label = label[1]
        end
        selectedLabel = label
        local target = optionToPlayer[label]
        if target then
            Rayfield:Notify({
                Title = "Target Dipilih",
                Content = string.format("-> %s (%d)", target.Name, target.UserId),
                Duration = 1.25
            })
        end
    end,
})
-- set selectedLabel ke opsi pertama setelah dibuat
if initialOpts[1] then
    selectedLabel = initialOpts[1]
end

-- tombol refresh list
PlayerTab:CreateButton({
    Name = "Refresh List",
    Callback = function()
        local opts = buildOptions()
        pcall(function() PlayerDropdown:SetOptions(opts) end)
        if #opts > 0 then
            pcall(function()
                if PlayerDropdown.SetOption then
                    PlayerDropdown:SetOption(opts[1])
                elseif PlayerDropdown.Set then
                    PlayerDropdown:Set(opts[1])
                end
            end)
            -- penting: ikut set selectedLabel
            selectedLabel = opts[1]
        else
            selectedLabel = nil
            Rayfield:Notify({ Title="Players", Content="Belum ada pemain terdeteksi.", Duration=1.5 })
        end
        Rayfield:Notify({ Title="Players", Content="List di-refresh ("..tostring(#opts).." pemain).", Duration=1.2 })
    end,
})

-- auto refresh saat ada yang join/leave
local function autoRefresh()
    local opts = buildOptions()
    pcall(function() PlayerDropdown:SetOptions(opts) end)
    if #opts > 0 then
        selectedLabel = selectedLabel and optionToPlayer[selectedLabel] and selectedLabel or opts[1]
    else
        selectedLabel = nil
    end
end
Players.PlayerAdded:Connect(autoRefresh)
Players.PlayerRemoving:Connect(function()
    autoRefresh()
    if selectedLabel and not optionToPlayer[selectedLabel] then
        selectedLabel = nil
    end
end)


-- teleport to player
PlayerTab:CreateButton({
    Name = "Teleport To Player",
    Callback = function()
        local label = getSelected()
        if not label then
            Rayfield:Notify({ Title="Players", Content="Tidak ada pemain yang dipilih.", Duration=1.5 })
            return
        end
        local target = optionToPlayer[label]
        if not target or target == LP then
            Rayfield:Notify({ Title="Players", Content="Tidak bisa teleport ke diri sendiri.", Duration=1.5 })
            return
        end
        local char = target.Character or target.CharacterAdded:Wait()
        local root = getRoot(char)
        if root then
            tpTo(root.Position)
            Rayfield:Notify({ Title="Teleport", Content="Berhasil teleport ke "..label, Duration=1.5 })
        else
            Rayfield:Notify({ Title="Teleport", Content="Gagal teleport, karakter tidak ditemukan.", Duration=1.5 })
        end
    end,
})

-- teleport player to me
PlayerTab:CreateButton({
    Name = "Teleport Player To Me",
    Callback = function()
        local label = getSelected()
        if not label then
            Rayfield:Notify({ Title="Players", Content="Tidak ada pemain yang dipilih.", Duration=1.5 })
            return
        end
        local target = optionToPlayer[label]
        if not target or target == LP then
            Rayfield:Notify({ Title="Players", Content="Tidak bisa teleport ke diri sendiri.", Duration=1.5 })
            return
        end
        local myChar = LP.Character or LP.CharacterAdded:Wait()
        local myRoot = getRoot(myChar)
        local char = target.Character or target.CharacterAdded:Wait()
        local root = getRoot(char)

        if myRoot and root then
            root.CFrame = myRoot.CFrame * CFrame.new(2, 0, 0) -- offset biar ga nempel
            Rayfield:Notify({ Title="Teleport", Content="Berhasil teleport "..label.." ke kamu", Duration=1.5 })
        else
            Rayfield:Notify({ Title="Teleport", Content="Gagal teleport, karakter tidak ditemukan.", Duration=1.5 })
        end
    end,
})
