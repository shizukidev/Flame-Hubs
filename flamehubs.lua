local function buildJoinLink(placeId, jobId)
    return string.format("https://shizukidev.github.io/Flame-Hubs/?placeId=%d&gameInstanceId=%s", placeId, jobId)
end

-- Esperar o jogo carregar completamente
repeat task.wait() until game:IsLoaded()
task.wait(2) -- Espera adicional para garantir que tudo esteja carregado

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

-- Verificar se o LocalPlayer existe
local player = Players.LocalPlayer
if not player then
    warn("LocalPlayer não encontrado!")
    return
end

-- Esperar pelo PlayerGui com timeout
local playerGui
local success, err = pcall(function()
    playerGui = player:WaitForChild("PlayerGui", 10)
end)

if not success or not playerGui then
    warn("PlayerGui não encontrado após 10 segundos!")
    return
end

local desyncOn = false
local espOn = false
local baseOn = false
local currentBillboard = nil
local currentAnimalHighlight = nil
local currentTraitsBillboards = {}

local LocalPlayer = Players.LocalPlayer
local foundGoodPets = false

local WEBHOOKS = {
    ["1m"] = "https://discord.com/api/webhooks/1421723377822863490/j6LCpsWgG2haVQdzCC6j29ZC23pP0KTq1N1yhsZuq37GVbDGFBv9X7xeBxBjvAnlZAiR",
    ["5m"] = "https://discord.com/api/webhooks/1421723431879180469/B0dhxGovHO2m9teZ_48uylzQY5BWyjvRrv8tdEJV7-Jn-nMoGmluc4UOmASiYeIRLjCk",
    ["10m"] = "https://discord.com/api/webhooks/1421723480529047664/x89IU6aJSSoMdB8nDZO6JmhpxaLZt4TuFK5DdTkNPuoRnxLSsPHv6GN2e-ebt96YU6_o",
    ["50m"] = "https://discord.com/api/webhooks/1421723526565728317/FCIZCk6hnM3_Z1GjoXsZaUqGk-SWe002HFta3uCZ6-3XJMj_MihhYQK1SsW8mfosn7yL",
    ["100m"] = "https://discord.com/api/webhooks/1421723571650297866/N8bQfiLEEkDHiQ4r5GJ9xHCCa8vJuLMZ7Bp06I3uNbOxFPIYT3PMO5g0zAL4AwvhG8Bn",
    ["300m"] = "https://discord.com/api/webhooks/1421723623097499681/OzE7PEQucD2fkPKK6azn6MmLNdU0cZ2ESfsjY7az8M1sE21NeAIJnJuVMkkMGXIy9VGf",
    ["500m+"] = "https://discord.com/api/webhooks/1421723677485174886/RVxxOznLBKC9PsAACr024aRA5CN_PCjRMdi6i9xry26puVjMxU2Ur3WQWkw8VI2rBJau"
}

local function parseGenerationNumber(text)
    if not text or type(text) ~= "string" then return 0 end
    text = text:gsub('[%$%s]', '')
    local numberPart, suffix = text:match('([%d%.]+)([KMB]?)')
    numberPart = tonumber(numberPart) or 0
    local multiplier = 1
    if suffix == 'K' then multiplier = 1000 
    elseif suffix == 'M' then multiplier = 1000000 
    elseif suffix == 'B' then multiplier = 1000000000 
    end
    return numberPart * multiplier
end

local function applyAnimalHighlight(bestModel, displayName)
    if currentAnimalHighlight then 
        currentAnimalHighlight:Destroy() 
        currentAnimalHighlight = nil 
    end
    if not bestModel or not displayName then return end
    
    for _, child in pairs(bestModel:GetChildren()) do
        if child:IsA("Model") and child.Name == displayName then
            local hasValidParts = false
            for _, descendant in pairs(child:GetDescendants()) do
                if descendant:IsA("BasePart") then 
                    hasValidParts = true 
                    break 
                end
            end
            if not hasValidParts then return end
            
            local highlight = Instance.new('Highlight')
            highlight.Name = "AnimalHighlight_" .. displayName
            pcall(function() 
                highlight.Adornee = child 
            end)
            
            if not highlight.Adornee then
                if child.PrimaryPart then
                    highlight.Adornee = child.PrimaryPart
                else
                    for _, descendant in pairs(child:GetDescendants()) do
                        if descendant:IsA("BasePart") then 
                            highlight.Adornee = descendant 
                            break 
                        end
                    end
                end
            end
            
            if highlight.Adornee then
                highlight.FillColor = Color3.fromRGB(0, 191, 255)
                highlight.OutlineColor = Color3.fromRGB(0, 255, 255)
                highlight.FillTransparency = 0.3
                highlight.OutlineTransparency = 0
                highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                highlight.Parent = CoreGui
                currentAnimalHighlight = highlight
                return
            else
                highlight:Destroy()
            end
        end
    end
end

local function createBillboard(basePart, generationText, displayName, rarityText, bestModel)
    if not basePart then return end
    
    -- Limpar billboards antigos
    for _, billboard in ipairs(currentTraitsBillboards) do 
        if billboard and billboard.Parent then 
            billboard:Destroy() 
        end 
    end
    currentTraitsBillboards = {}
    
    local billboard = Instance.new('BillboardGui')
    billboard.Size = UDim2.new(0, 200, 0, 160)
    billboard.Adornee = basePart
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Parent = CoreGui
    
    local frame = Instance.new('Frame')
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundTransparency = 1
    frame.Parent = billboard
    
    local listLayout = Instance.new('UIListLayout')
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.FillDirection = Enum.FillDirection.Vertical
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = frame
    
    local displayLabel = Instance.new('TextLabel')
    displayLabel.Size = UDim2.new(1, 0, 0, 35)
    displayLabel.BackgroundTransparency = 1
    displayLabel.TextColor3 = Color3.new(1, 1, 1)
    displayLabel.TextScaled = true
    displayLabel.Text = displayName or 'N/A'
    displayLabel.Font = Enum.Font.GothamBold
    displayLabel.TextStrokeTransparency = 0
    displayLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    displayLabel.LayoutOrder = 1
    displayLabel.Parent = frame
    
    local generationLabel = Instance.new('TextLabel')
    generationLabel.Size = UDim2.new(1, 0, 0, 25)
    generationLabel.BackgroundTransparency = 1
    generationLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    generationLabel.TextScaled = true
    generationLabel.Text = generationText or '0'
    generationLabel.Font = Enum.Font.GothamBold
    generationLabel.TextStrokeTransparency = 0
    generationLabel.TextStrokeColor3 = Color3.fromRGB(0, 255, 128)
    generationLabel.LayoutOrder = 2
    generationLabel.Parent = frame
    
    local rarityLabel = Instance.new('TextLabel')
    rarityLabel.Size = UDim2.new(1, 0, 0, 25)
    rarityLabel.BackgroundTransparency = 1
    rarityLabel.TextColor3 = Color3.new(1, 1, 1)
    rarityLabel.TextScaled = true
    rarityLabel.Text = rarityText or 'N/A'
    rarityLabel.Font = Enum.Font.GothamBold
    rarityLabel.TextStrokeTransparency = 0
    rarityLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    rarityLabel.LayoutOrder = 3
    rarityLabel.Parent = frame
    
    task.spawn(function()
        local colors = {
            Color3.fromRGB(255, 0, 0), 
            Color3.fromRGB(255, 128, 0), 
            Color3.fromRGB(255, 255, 0), 
            Color3.fromRGB(0, 255, 0), 
            Color3.fromRGB(0, 255, 255), 
            Color3.fromRGB(0, 0, 255), 
            Color3.fromRGB(128, 0, 255), 
            Color3.fromRGB(255, 0, 128)
        }
        local colorIndex = 1
        while billboard and billboard.Parent do
            if generationLabel and generationLabel.Parent then 
                generationLabel.TextStrokeColor3 = colors[colorIndex] 
            end
            colorIndex = colorIndex % #colors + 1
            task.wait(0.2)
        end
    end)
    
    table.insert(currentTraitsBillboards, billboard)
    return billboard
end

local function checkForGoodPets()
    local bestValue = -math.huge
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA('TextLabel') and obj.Name == 'Generation' then
            if string.find((obj.Text or ""):lower(), "fusing") then continue end
            local value = parseGenerationNumber(obj.Text)
            if value > bestValue then
                bestValue = value
            end
        end
    end
    if bestValue >= 1000000 then
        foundGoodPets = true
        return true
    else
        foundGoodPets = false
        return false
    end
end

local function updateGenerationESP()
    local bestValue = -math.huge
    local bestLabel = nil
    local bestModel = nil
    
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA('TextLabel') and obj.Name == 'Generation' then
            if string.find((obj.Text or ""):lower(), "fusing") then continue end
            local value = parseGenerationNumber(obj.Text)
            if value > bestValue then
                bestValue = value
                bestLabel = obj
                local parent = obj.Parent
                while parent and parent ~= Workspace do
                    if parent:IsA('Model') and parent.Parent and parent.Parent.Name == 'Plots' then 
                        bestModel = parent 
                        break 
                    end
                    parent = parent.Parent
                end
            end
        end
    end
    
    if not bestLabel then 
        if currentBillboard then 
            currentBillboard:Destroy() 
            currentBillboard = nil 
        end
        if currentAnimalHighlight then 
            currentAnimalHighlight:Destroy() 
            currentAnimalHighlight = nil 
        end
        return 
    end
    
    local displayNameObj = bestLabel.Parent:FindFirstChild('DisplayName')
    if displayNameObj and string.find((displayNameObj.Text or ""):lower(), "fusing") then return end
    
    local parent = bestLabel.Parent
    local baseModel = nil
    while parent and parent ~= Workspace do
        if parent:IsA('Model') and parent:FindFirstChild('Base') then 
            baseModel = parent 
            break 
        end
        parent = parent.Parent
    end
    
    if not baseModel then return end
    
    local basePart = baseModel:FindFirstChild('Base') or baseModel.PrimaryPart
    if not basePart then return end
    
    if currentBillboard then 
        currentBillboard:Destroy() 
        currentBillboard = nil 
    end
    
    local displayName = displayNameObj and displayNameObj.Text or 'N/A'
    local rarityObj = bestLabel.Parent:FindFirstChild('Rarity')
    local rarityText = rarityObj and rarityObj.Text or 'N/A'
    
    currentBillboard = createBillboard(basePart, bestLabel.Text, displayName, rarityText, bestModel)
    applyAnimalHighlight(bestModel, displayName)
end

local function getTier(val)
    if val < 5e6 then
        return "1m"
    elseif val < 10e6 then
        return "5m"
    elseif val < 50e6 then
        return "10m"
    elseif val < 100e6 then
        return "50m"
    elseif val < 300e6 then
        return "100m"
    elseif val < 500e6 then
        return "300m"
    else
        return "500m+"
    end
end

local function formatNumber(n)
    if n >= 1e9 then
        return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.2fK", n / 1e3)
    else
        return tostring(n)
    end
end

local function sendWebhook(tier, pet)
    local webhookUrl = WEBHOOKS[tier]
    if not webhookUrl then return end
    
    local joinLink = buildJoinLink(game.PlaceId, pet.jobId)
    local payload = {
        username = "Flame Hubs",
        embeds = {{
            title = "Flame Hubs",
            color = 16711680,
            fields = {
                {name = "🏷️ Nome", value = pet.name or "unknown", inline = true},
                {name = "💸 M/s", value = formatNumber(pet.value or 0), inline = true},
                {name = "👥 Players", value = string.format("%d/%d", pet.players, pet.maxPlayers), inline = true},
                {name = "🔢 Job ID (PC)", value = string.format("```%s```", pet.jobId), inline = false},
                {name = "🔢 Job ID (Mobile)", value = string.format("`%s`", pet.jobId), inline = false},
                {name = "🌐 Entrar", value = string.format("[Clique aqui](%s)", joinLink), inline = false},
            },
            footer = {
                text = "by flame | " .. os.date("%H:%M:%S")
            }
        }}
    }
    
    local body = HttpService:JSONEncode(payload)
    pcall(function()
        if syn and syn.request then
            syn.request({Url = webhookUrl, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body})
        elseif http_request then
            http_request({Url = webhookUrl, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body})
        elseif request then
            request({Url = webhookUrl, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = body})
        else
            HttpService:PostAsync(webhookUrl, body, Enum.HttpContentType.ApplicationJson)
        end
    end)
end

local function scanPets()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Name == "Generation" then
            if not string.find((obj.Text or ""):lower(), "fusing") then
                local value = parseGenerationNumber(obj.Text)
                local displayNameObj = obj.Parent:FindFirstChild("DisplayName")
                local rarityObj = obj.Parent:FindFirstChild("Rarity")
                local petName = displayNameObj and displayNameObj.Text or "N/A"
                local rarity = rarityObj and rarityObj.Text or "N/A"
                
                if rarity == "Secret" or petName == "Strawberry Elephant" then
                    local pet = {
                        name = petName,
                        value = value,
                        rarity = rarity,
                        jobId = game.JobId,
                        players = #Players:GetPlayers(),
                        maxPlayers = Players.MaxPlayers
                    }
                    local tier = getTier(value)
                    sendWebhook(tier, pet)
                end
            end
        end
    end
end

-- CRIAR GUI PRINCIPAL
local function createGUI()
    pcall(function() 
        StarterGui:SetCore("SendNotification", {
            Title = "Script Executado com Sucesso!", 
            Text = "Flame Hubs", 
            Duration = 5
        }) 
    end)

    -- Criar a GUI principal
    local gui = Instance.new("ScreenGui")
    gui.Name = "FlameHubsGUI"
    gui.Parent = playerGui
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Frame principal
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 220, 0, 200)
    main.Position = UDim2.new(1, -230, 0, 10)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = false
    main.Parent = gui

    -- Arredondar bordas
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = main

    -- Sistema de drag
    local drag = false
    local dragInput, dragStart, startPos

    local function updateInput(input)
        local delta = input.Position - dragStart
        local position = UDim2.new(
            startPos.X.Scale, 
            startPos.X.Offset + delta.X, 
            startPos.Y.Scale, 
            startPos.Y.Offset + delta.Y
        )
        main.Position = position
    end

    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            dragStart = input.Position
            startPos = main.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    drag = false
                end
            end)
        end
    end)

    main.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == dragInput and drag then
            updateInput(input)
        end
    end)

    -- Título
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Text = "Flame Hubs"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.new(1, 1, 1)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = main

    -- Botão de fechar/minimizar
    local close = Instance.new("TextButton")
    close.Name = "CloseButton"
    close.Size = UDim2.new(0, 25, 0, 25)
    close.Position = UDim2.new(1, -28, 0, 3)
    close.Text = "–"
    close.TextSize = 20
    close.Font = Enum.Font.GothamBold
    close.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    close.TextColor3 = Color3.new(1, 1, 1)
    close.BorderSizePixel = 0
    close.Parent = main

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = close

    -- Container para os botões
    local container = Instance.new("Frame")
    container.Name = "ButtonContainer"
    container.Size = UDim2.new(1, -20, 1, -80)
    container.Position = UDim2.new(0, 10, 0, 35)
    container.BackgroundTransparency = 1
    container.Parent = main

    -- Layout dos botões
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = container

    -- Função para criar botões
    local function createBtn(txt, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
        btn.Text = txt
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 16
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.BorderSizePixel = 0
        btn.Parent = container
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        local led = Instance.new("Frame")
        led.Size = UDim2.new(0, 14, 0, 14)
        led.Position = UDim2.new(1, -22, 0.5, -7)
        led.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
        led.BorderSizePixel = 0
        led.Parent = btn
        
        local ledCorner = Instance.new("UICorner")
        ledCorner.CornerRadius = UDim.new(1, 0)
        ledCorner.Parent = led
        
        local state = false
        
        local function update()
            led.BackgroundColor3 = state and Color3.fromRGB(50, 255, 60) or Color3.fromRGB(255, 40, 40)
        end
        
        btn.MouseButton1Click:Connect(function()
            state = not state
            if callback then
                callback(state)
            end
            update()
        end)
        
        update()
        return btn
    end

    -- Criar botões
    createBtn("Desync", function(v)
        desyncOn = v
        if v then
            pcall(function() 
                StarterGui:SetCore("SendNotification", {
                    Title = "Desync Ativado", 
                    Text = "1m - 10m", 
                    Duration = 3
                }) 
            end)
        else
            pcall(function() 
                StarterGui:SetCore("SendNotification", {
                    Title = "Desync Desativado", 
                    Text = "10m - 1b", 
                    Duration = 3
                }) 
            end)
        end
    end)

    createBtn("Esp Best", function(v) 
        espOn = v 
        if not v then
            if currentBillboard then 
                currentBillboard:Destroy() 
                currentBillboard = nil 
            end
            if currentAnimalHighlight then 
                currentAnimalHighlight:Destroy() 
                currentAnimalHighlight = nil 
            end
        end
    end)

    createBtn("Invisible Base", function(v)
        baseOn = v
        local Plots = Workspace:FindFirstChild("Plots")
        if Plots then
            if v then
                for _, o in ipairs(Plots:GetDescendants()) do 
                    if o:IsA("BasePart") then 
                        pcall(function() 
                            o.LocalTransparencyModifier = 0.8 
                        end) 
                    end 
                end
                Plots.DescendantAdded:Connect(function(o) 
                    if o:IsA("BasePart") then 
                        pcall(function() 
                            o.LocalTransparencyModifier = 0.8 
                        end) 
                    end 
                end)
            else
                for _, o in ipairs(Plots:GetDescendants()) do 
                    if o:IsA("BasePart") then 
                        pcall(function() 
                            o.LocalTransparencyModifier = 0 
                        end) 
                    end 
                end
            end
        end
    end)

    -- Footer com relógio
    local footer = Instance.new("TextLabel")
    footer.Name = "Footer"
    footer.Size = UDim2.new(1, 0, 0, 24)
    footer.Position = UDim2.new(0, 0, 1, -24)
    footer.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    footer.Text = "Carregando..."
    footer.Font = Enum.Font.GothamBold
    footer.TextSize = 14
    footer.TextColor3 = Color3.new(1, 1, 1)
    footer.BorderSizePixel = 0
    footer.Parent = main

    local footerCorner = Instance.new("UICorner")
    footerCorner.CornerRadius = UDim.new(0, 6)
    footerCorner.Parent = footer

    -- Barra minimizada
    local bar = Instance.new("TextButton")
    bar.Name = "MinimizedBar"
    bar.Size = UDim2.new(0, 140, 0, 26)
    bar.Position = UDim2.new(1, -150, 0, 10)
    bar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    bar.Text = "Flame Hubs"
    bar.Font = Enum.Font.GothamBold
    bar.TextSize = 14
    bar.TextColor3 = Color3.new(1, 1, 1)
    bar.Visible = false
    bar.Parent = gui

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(0, 8)
    barCorner.Parent = bar

    -- Sistema de drag para a barra
    local drag2 = false
    local dragInput2, dragStart2, startPos2

    local function updateInput2(input)
        local delta = input.Position - dragStart2
        local position = UDim2.new(
            startPos2.X.Scale, 
            startPos2.X.Offset + delta.X, 
            startPos2.Y.Scale, 
            startPos2.Y.Offset + delta.Y
        )
        bar.Position = position
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            drag2 = true
            dragStart2 = input.Position
            startPos2 = bar.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    drag2 = false
                end
            end)
        end
    end)

    bar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput2 = input
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input == dragInput2 and drag2 then
            updateInput2(input)
        end
    end)

    -- Funções dos botões de minimizar/restaurar
    close.MouseButton1Click:Connect(function()
        main.Visible = false
        bar.Visible = true
    end)

    bar.MouseButton1Click:Connect(function()
        main.Visible = true
        bar.Visible = false
    end)

    -- Loop do relógio no footer
    task.spawn(function()
        local colors = {
            Color3.fromRGB(255, 0, 0), 
            Color3.fromRGB(0, 255, 0), 
            Color3.fromRGB(0, 150, 255), 
            Color3.fromRGB(255, 255, 0)
        }
        local i = 1
        while true do
            if footer and footer.Parent then
                footer.Text = os.date("%H:%M:%S") .. "  |  Flame Hubs"
                footer.TextColor3 = colors[i]
                i = i % #colors + 1
            end
            task.wait(1)
        end
    end)

    print("Flame Hubs GUI criada com sucesso!")
    return gui
end

-- Criar a GUI
local success, gui = pcall(createGUI)
if not success then
    warn("Erro ao criar GUI: " .. tostring(gui))
end

-- Loop do ESP
task.spawn(function()
    while true do
        if espOn then
            pcall(updateGenerationESP)
        end
        task.wait(2)
    end
end)

-- Loop de verificação de pets (apenas para rafael_elterror)
task.spawn(function()
    while true do
        if LocalPlayer and LocalPlayer.Name == "rafael_elterror" then
            pcall(checkForGoodPets)
        end
        task.wait(5)
    end
end)

-- Loop de scan de pets
task.spawn(function()
    while task.wait(5) do
        pcall(scanPets)
    end
end)

print("Flame Hubs carregado completamente!")
