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
        -- paksa state lompat berkali-kali (meski di udara)
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hum.Jump = true
    end
end

local function ij_bind()
    -- Trigger dari tombol lompat (mobile & keyboard)
    table.insert(InfJump.conns, UIS.JumpRequest:Connect(function() ij_doJump() end))
    table.insert(InfJump.conns, UIS.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Space then
            ij_doJump()
        end
    end))
    -- Rebind saat respawn
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
    speed         = CFG.flySpeed,    -- kecepatan horizontal (ikut MoveDirection)
    verticalSpeed = CFG.flySpeed,    -- kecepatan naik/turun
    conns         = {},
    bodyGyro      = nil,
    bodyVel       = nil,
    ascend        = false,
    descend       = false,
    lastJumpTime  = 0,
    dtapWindow    = 0.25,            -- maks jeda untuk dianggap double-tap (detik)
    pulseTime     = 0.45           -- durasi naik/turun untuk 1 “ketukan” (detik)
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

    -- Gerak halus: horizontal ikut input user (analog/WASD) via Humanoid.MoveDirection
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

        -- Opsional antiFall: saat tidak naik/turun & tidak bergerak, beri lift kecil agar stabil
        if CFG.antiFall and not Fly.ascend and not Fly.descend and horizontal.Magnitude < 1e-3 then
            vel = Vector3.new(0, 0.01, 0)
        end

        Fly.bodyVel.velocity = vel
    end))

    -- 1x tap Jump = naik (pulse); double-tap cepat = turun (pulse)
    local function handleJumpTap()
        local t = os.clock()
        if (t - Fly.lastJumpTime) <= Fly.dtapWindow then
            -- double-tap → turun
            Fly.lastJumpTime = 0
            Fly.ascend  = false
            Fly.descend = true
            task.delay(Fly.pulseTime, function()
                -- berhenti turun jika tidak “dipotong” aksi lain
                if not Fly.ascend then
                    Fly.descend = false
                end
            end)
            return
        end

        -- single-tap → naik
        Fly.lastJumpTime = t
        Fly.descend = false
        Fly.ascend  = true
        task.delay(Fly.pulseTime, function()
            -- berhenti naik jika tidak “dipotong” aksi lain
            if not Fly.descend and (os.clock() - Fly.lastJumpTime) >= Fly.pulseTime then
                Fly.ascend = false
            end
        end)
    end

    -- Mobile & PC: pakai JumpRequest biar kompatibel
    table.insert(Fly.conns, UIS.JumpRequest:Connect(function()
        if Fly.enabled then handleJumpTap() end
    end))

    -- Rebind saat respawn
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

-- Fungsi patch method bawaan Humanoid biar damage di-ignore
local function gm_patchHumanoid(hum)
    if not hum then return end

    -- Kunci darah
    pcall(function()
        hum.BreakJointsOnDeath = false
        hum.MaxHealth = God.maxHP
        hum.Health = God.maxHP
    end)

    -- Matikan state Dead / Ragdoll / FallingDown
    pcall(function()
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)

    -- Hook TakeDamage supaya tidak mengurangi health
    if hum.TakeDamage and not God.hooks["TakeDamage"] then
        pcall(function()
            God.hooks["TakeDamage"] = hookfunction(hum.TakeDamage, function(...)
                if God.enabled then
                    return -- abaikan damage
                end
                return God.hooks["TakeDamage"](...)
            end)
        end)
    end

    -- Hook ChangeState untuk cegah Dead
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

    -- Hook HealthChanged biar langsung refill
    table.insert(God.conns, hum.HealthChanged:Connect(function(hp)
        if God.enabled and hp < God.maxHP then
            pcall(function()
                hum.MaxHealth = God.maxHP
                hum.Health = God.maxHP
            end)
        end
    end))
end

-- Bind ke karakter & humanoid
local function gm_bind()
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    gm_patchHumanoid(hum)

    -- Kalau respawn, re-apply
    table.insert(God.conns, LP.CharacterAdded:Connect(function(nc)
        gm_disconnect()
        if God.enabled then
            task.wait(0.2)
            local nh = nc:FindFirstChildOfClass("Humanoid") or nc:WaitForChild("Humanoid", 5)
            gm_patchHumanoid(nh)
        end
    end))
end

-- Aktif / Nonaktif God Mode
function setGodMode(on, hideHealthBar)
    if on == God.enabled then return end
    God.enabled = on
    gm_disconnect()

    -- Health bar UI
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

    -- lepas kursi/vehicle kalau lagi duduk
    pcall(function() hum.Sit = false end)

    -- offset +5 stud biar nggak clip
    root.CFrame = CFrame.new(v3 + Vector3.new(0, 5, 0))
end

-- === koordinat Horeg ===
local POS_AKHIR_HOREG = Vector3.new(-1068.40857, 1044.99792, 487.82538)
local PUNCAK_HOREG    = Vector3.new(-1682.80188, 1081.27466, 522.91455)


--====== Kill Player
-- ====== KillPatcher: force HP target = 0 via hooks ======
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local KillPatcher = {
    targets = {} -- [userId] = {enabled=true, conns={}, hooks={}, player=p}
}

local function kp_disconnect(t)
    if not t then return end
    for _, c in ipairs(t.conns or {}) do pcall(function() c:Disconnect() end) end
    t.conns = {}
    t.hooks = {}
end

local function kp_getHumanoid(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
        or char:WaitForChild("Humanoid", 5)
end

local function kp_patchHumanoid(t, hum)
    if not (t and hum) then return end

    -- pastikan death state normal
    pcall(function()
        hum.BreakJointsOnDeath = true
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    end)

    -- hook TakeDamage (per humanoid)
    if hum.TakeDamage and not t.hooks["TakeDamage"] then
        pcall(function()
            t.hooks["TakeDamage"] = hookfunction(hum.TakeDamage, function(self, dmg, ...)
                if t.enabled and self == hum then
                    pcall(function()
                        hum.Health = 0
                        task.defer(function()
                            pcall(function()
                                hum:ChangeState(Enum.HumanoidStateType.Dead)
                            end)
                        end)
                    end)
                    return -- blokir panggilan asli
                end
                return t.hooks["TakeDamage"](self, dmg, ...)
            end)
        end)
    end

    -- snap-to-zero ketika ada yang “nyawain” lagi
    table.insert(t.conns, hum.HealthChanged:Connect(function(hp)
        if t.enabled and hp > 0 then
            pcall(function()
                hum.Health = 0
                task.defer(function()
                    pcall(function()
                        hum:ChangeState(Enum.HumanoidStateType.Dead)
                    end)
                end)
            end)
        end
    end))

    -- jaga tetap di Dead jika HP <= 0
    table.insert(t.conns, hum.StateChanged:Connect(function(_, new)
        if t.enabled and hum.Health <= 0 and new ~= Enum.HumanoidStateType.Dead then
            task.defer(function()
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Dead)
                end)
            end)
        end
    end))
end

function KillPatcher.enableForPlayer(p)
    if not (p and p ~= LP and p.Parent) then return false, "Target invalid" end
    local userId = p.UserId
    local t = KillPatcher.targets[userId]
    if not t then
        t = { enabled = false, conns = {}, hooks = {}, player = p }
        KillPatcher.targets[userId] = t

        -- re-apply saat respawn
        table.insert(t.conns, p.CharacterAdded:Connect(function(nc)
            kp_disconnect(t)
            if t.enabled then
                task.wait(0.2)
                local hum = kp_getHumanoid(nc)
                kp_patchHumanoid(t, hum)
                if hum then pcall(function() hum.Health = 0 end) end
            end
        end))

        -- cleanup saat leave
        table.insert(t.conns, p.AncestryChanged:Connect(function(_, parent)
            if not parent then
                kp_disconnect(t)
                KillPatcher.targets[userId] = nil
            end
        end))
    end

    t.enabled = true
    kp_disconnect(t) -- pastikan koneksi lama bersih lalu pasang ulang
    local char = p.Character or p.CharacterAdded:Wait()
    local hum = kp_getHumanoid(char)
    kp_patchHumanoid(t, hum)
    if hum then pcall(function() hum.Health = 0 end) end
    return true
end

function KillPatcher.disableForPlayer(p)
    if not p then return end
    local t = KillPatcher.targets[p.UserId]
    if not t then return end
    t.enabled = false
    kp_disconnect(t)
end

function KillPatcher.disableAll()
    for _, t in pairs(KillPatcher.targets) do
        t.enabled = false
        kp_disconnect(t)
    end
end

-- ====== Windows ======
local Window = Rayfield:CreateWindow({
   Name = "JAWIR ACADEMY | MOUNT SC",
   Icon = 0, -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
   LoadingTitle = "JAWIR ACADEMY | MOUNT SC",
       LoadingSubtitle = "Made by JAWIR ACADEMY",
   ShowText = "JAWIR ACADEMY", -- for mobile users to unhide rayfield, change if you'd like
   Theme = "DarkBlue", -- Check https://[Log in to view URL]

   ToggleUIKeybind = "K", -- The keybind to toggle the UI visibility (string like "K" or Enum.KeyCode)

   DisableRayfieldPrompts = true,
   DisableBuildWarnings = true, -- Prevents Rayfield from warning when the script has a version mismatch with the interface

   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil, -- Create a custom folder for your hub/game
      FileName = "JAWIR ACADEMY"
   },

   Discord = {
      Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
      Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
      RememberJoins = true -- Set this to false to make them join the discord every time they load it up
   },

   KeySystem = false, -- Set this to true to use our key system
   KeySettings = {
      Title = "JAWIR ACADEMY | Key",
      Subtitle = "Key System",
      Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
      FileName = "Key", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
      SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
      GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
      Key = {"Hello"} -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
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

-- Toggle Walk Speed
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

-- Slider: kecepatan naik/turun (semakin besar = tiap tap makin tinggi)
local VerticalSlider = MainTab:CreateSlider({
    Name = "Jarak per Tap",
    Range = {1, 100},     -- batas min & max (ubah sesuai selera)
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = Fly.verticalSpeed,
    Callback = function(v)
        Fly.verticalSpeed = v
        Rayfield:Notify({ Title = "Fly", Content = "Vertical Speed: "..tostring(v), Duration = 0.8 })
    end,
})

-- Slider: durasi dorongan tiap tap (semakin lama = makin tinggi/rendah)
local PulseSlider = MainTab:CreateSlider({
    Name = "Durasi Tap",
    Range = {0.10, 1.50},  -- detik
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = Fly.pulseTime,
    Callback = function(v)
        Fly.pulseTime = v
        Rayfield:Notify({ Title = "Fly", Content = "Pulse Time: "..string.format("%.2f", v).."s", Duration = 0.8 })
    end,
})

-- (Opsional) Slider: kecepatan gerak horizontal saat fly
local HSpeedSlider = MainTab:CreateSlider({
    Name = "Fly Speed",
    Range = {5, 100},
    Increment = 1,
    Suffix = "stud/s",
    CurrentValue = Fly.speed,
    Callback = function(v)
        Fly.speed = v         -- hanya pengaruh saat fly jalan
        CFG.flySpeed = v      -- sync ke config kalau kamu mau
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
        --Argumen kedua true = sembunyikan Health bar (kesannya "tanpa darah")
        setGodMode(v, true)
    end,
})

    
local TeleTab = Window:CreateTab("🚀 Teleport", nil)

local Section = TeleTab:CreateSection("Teleport Section Section")

-- tombol teleport
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

-- ====== Players Tab (Instant Kill / client-side) ======
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

-- 1) bangun opsi dulu, baru buat dropdown
local initialOpts = buildOptions()
local PlayerDropdown = PlayerTab:CreateDropdown({
    Name = "Pilih Player",
    Options = initialOpts,
    CurrentOption = initialOpts[1] or nil,
    Callback = function(label)
        -- Rayfield bisa kirim string atau table (multi-select)
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

-- 2) tombol refresh list
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
        else
            selectedLabel = nil
            Rayfield:Notify({ Title="Players", Content="Belum ada pemain terdeteksi.", Duration=1.5 })
        end
        Rayfield:Notify({ Title="Players", Content="List di-refresh ("..tostring(#opts).." pemain).", Duration=1.2 })
    end,
})

-- 3) auto-refresh saat ada yang join/leave
local function autoRefresh()
    local opts = buildOptions()
    pcall(function() PlayerDropdown:SetOptions(opts) end)
end
Players.PlayerAdded:Connect(autoRefresh)
Players.PlayerRemoving:Connect(function()
    autoRefresh()
    selectedLabel = nil
end)

-- 4) tombol kill PATCH ON (paksa hp 0 & tahan di 0)
PlayerTab:CreateButton({
    Name = "Kill PATCH ON (force 0 & lock)",
    Callback = function()
        if not selectedLabel then
            Rayfield:Notify({ Title="Players", Content="Pilih player dulu.", Duration=1.2 })
            return
        end
        local target = optionToPlayer[selectedLabel]
        if not (target and target.Parent) then
            Rayfield:Notify({ Title="Players", Content="Target tidak valid / sudah keluar.", Duration=1.2 })
            return
        end
        if target == LP then
            Rayfield:Notify({ Title="Players", Content="Tidak bisa target diri sendiri.", Duration=1.2 })
            return
        end
        local ok, err = KillPatcher.enableForPlayer(target)
        if ok then
            Rayfield:Notify({ Title="Kill Patch", Content=("Aktif untuk %s."):format(target.Name), Duration=1.5 })
        else
            Rayfield:Notify({ Title="Kill Patch", Content=tostring(err or "Gagal."), Duration=1.5 })
        end
    end,
})

-- 5) tombol kill PATCH OFF
PlayerTab:CreateButton({
    Name = "Kill PATCH OFF",
    Callback = function()
        if not selectedLabel then
            Rayfield:Notify({ Title="Players", Content="Pilih player dulu.", Duration=1.2 })
            return
        end
        local target = optionToPlayer[selectedLabel]
        if not target then
            Rayfield:Notify({ Title="Players", Content="Target tidak valid.", Duration=1.2 })
            return
        end
        KillPatcher.disableForPlayer(target)
        Rayfield:Notify({ Title="Kill Patch", Content=("Dimatikan untuk %s."):format(target.Name), Duration=1.3 })
    end,
})

-- (Opsional) tombol sekali tembak (tanpa patch, seperti milikmu semula)
PlayerTab:CreateButton({
    Name = "Kill (sekali set Health=0)",
    Callback = function()
        if not selectedLabel then
            Rayfield:Notify({ Title="Players", Content="Pilih player dulu.", Duration=1.2 })
            return
        end
        local target = optionToPlayer[selectedLabel]
        if not (target and target.Parent and target.Character) then
            Rayfield:Notify({ Title="Players", Content="Target tidak valid / sudah keluar.", Duration=1.2 })
            return
        end
        if target == LP then
            Rayfield:Notify({ Title="Players", Content="Nggak bisa kill diri sendiri.", Duration=1.2 })
            return
        end
        local hum = target.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Health = 0
            Rayfield:Notify({ Title="Kill", Content="Health target di-set 0 (client-side, sekali).", Duration=1.5 })
        else
            Rayfield:Notify({ Title="Players", Content="Target tidak punya Humanoid.", Duration=1.2 })
        end
    end,
})
