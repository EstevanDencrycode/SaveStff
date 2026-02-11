--! Test
local HttpService = game:GetService("HttpService")
local SaveManager = {}

SaveManager.Folder = "WindUISettings"
SaveManager.Options = {}
SaveManager.Parser = {}
SaveManager.Library = nil
SaveManager.AutoSave = true
SaveManager.CurrentConfig = nil
SaveManager.IsLoading = false

local function tableMatch(t1, t2)
    if type(t1) ~= "table" or type(t2) ~= "table" then return t1 == t2 end
    for i, v in pairs(t1) do if t2[i] ~= v then return false end end
    for i, v in pairs(t2) do if t1[i] ~= v then return false end end
    return true
end

SaveManager.Parser = {
    Toggle = {
        Save = function(Obj) return {Type = "Toggle", Value = Obj.Value} end,
        Load = function(Obj, Data) 
            if Obj.Value ~= Data.Value then
                Obj:Set(Data.Value)
            end
        end,
    },
    Dropdown = {
        Save = function(Obj) return {Type = "Dropdown", Value = Obj.Value, Multi = Obj.Multi} end,
        Load = function(Obj, Data) 
            if not tableMatch(Obj.Value, Data.Value) then
                Obj:Select(Data.Value)
            end
        end,
    },
    Input = {
        Save = function(Obj) return {Type = "Input", Value = Obj.Value} end,
        Load = function(Obj, Data) 
            if Obj.Value ~= Data.Value then
                Obj:Set(Data.Value)
            end
        end,
    },
    Slider = {
        Save = function(Obj) 
            local val = Obj.Value
            if type(val) == "table" and val.Default then val = val.Default end
            return {Type = "Slider", Value = val} 
        end,
        Load = function(Obj, Data) 
            local current = (type(Obj.Value) == "table") and Obj.Value.Default or Obj.Value
            if current ~= Data.Value then
                Obj:Set(Data.Value)
            end
        end,
    }
}

function SaveManager:SetLibrary(Library)
    self.Library = Library
end

function SaveManager:SetFolder(folder)
    self.Folder = folder
    self:BuildFolderTree()
end

function SaveManager:BuildFolderTree()
    local paths = { self.Folder, self.Folder .. "/settings" }
    for _, path in ipairs(paths) do
        if not isfolder(path) then makefolder(path) end
    end
end

function SaveManager:Add(Element, Name, Type)
    if not Element then return end
    self.Options[Name] = {Element = Element, Type = Type}
end

function SaveManager:Save(name, ignoreNotify)
    if self.IsLoading or not name then return false end
    name = name:gsub("[^%w%-%_]", "") 
    if name == "" then return false end

    local fullPath = self.Folder .. "/settings/" .. name .. ".json"
    local Data = {}
    for Name, Option in pairs(self.Options) do
        if self.Parser[Option.Type] then
            pcall(function()
                Data[Name] = self.Parser[Option.Type].Save(Option.Element)
            end)
        end
    end
    
    local Success, Encoded = pcall(HttpService.JSONEncode, HttpService, Data)
    if not Success then return false end
    
    writefile(fullPath, Encoded)
    self.CurrentConfig = name
    return true
end

function SaveManager:Load(name)
    if not name then return false end
    local fullPath = self.Folder .. "/settings/" .. name .. ".json"
    if not isfile(fullPath) then return false end
    
    local Success, Decoded = pcall(HttpService.JSONDecode, HttpService, readfile(fullPath))
    if not Success then return false end
    
    self.IsLoading = true
    self.CurrentConfig = name

    local loadCount = 0
    for Name, Data in pairs(Decoded) do
        if self.Options[Name] and self.Parser[Data.Type] then
            loadCount = loadCount + 1
            task.spawn(function()
                pcall(function()
                    self.Parser[Data.Type].Load(self.Options[Name].Element, Data)
                end)
            end)
            if loadCount % 10 == 0 then task.wait() end
        end
    end

    task.delay(0.5, function()
        self.IsLoading = false
    end)

    return true
end

function SaveManager:LoadAutoloadConfig()
    local AutoloadFile = self.Folder .. "/settings/autoload.txt"
    if isfile(AutoloadFile) then
        local name = readfile(AutoloadFile)
        if name and isfile(self.Folder .. "/settings/" .. name .. ".json") then
            self:Load(name)
        end
    end
end

function SaveManager:GetConfigList()
    local list = listfiles(self.Folder .. "/settings")
    local out = {}
    for _, file in ipairs(list) do
        if file:sub(-5) == ".json" then
            local name = file:match("([^\\/]+)%.json$")
            table.insert(out, name)
        end
    end
    return out
end

function SaveManager:BuildConfigSection(Tab)
    local Section = Tab:Section({
        Title = "Configuration",
        Opened = true
    })
    
    local ConfigNameInput = Section:Input({
        Title = "Config Name",
        Placeholder = "Enter name...",
        Callback = function() end
    })
    
    local configs = self:GetConfigList()
    local ConfigListDropdown = Section:Dropdown({
        Title = "Config List",
        Values = configs,
        AllowNull = true,
        Callback = function() end
    })

    if #configs == 0 or (not table.find(configs, "autosaved")) then
        self:Save("autosaved", true)
        ConfigListDropdown:Refresh(self:GetConfigList())
    end
    
    if not ConfigListDropdown.Value or ConfigListDropdown.Value == "" then
        ConfigListDropdown:Select("autosaved")
    end
    
    Section:Button({
        Title = "Create Config",
        Callback = function()
            local name = ConfigNameInput.Value
            if name:gsub(" ", "") == "" then return end
            self:Save(name)
            ConfigListDropdown:Refresh(self:GetConfigList())
        end
    })
    
    Section:Button({
        Title = "Load Config",
        Callback = function()
            local name = ConfigListDropdown.Value
            if name then self:Load(name) end
        end
    })
    
    Section:Button({
        Title = "Overwrite Config",
        Callback = function()
            local name = ConfigListDropdown.Value
            if name then self:Save(name) end
        end
    })
    
    Section:Button({
        Title = "Refresh List",
        Callback = function()
            ConfigListDropdown:Refresh(self:GetConfigList())
        end
    })

    local AutoloadFile = self.Folder .. "/settings/autoload.txt"
    
    local AutoLoadToggle = Section:Toggle({
        Title = "Enable Auto Load",
        Value = false,
        Callback = function(val)
            local name = ConfigListDropdown.Value
            if val then
                if name then
                    writefile(AutoloadFile, name)
                end
            else
                if isfile(AutoloadFile) then delfile(AutoloadFile) end
            end
        end
    })

    local AutoSaveToggle = Section:Toggle({
        Title = "Auto Save",
        Value = true,
        Callback = function(val)
            self.AutoSave = val
        end
    })

    task.spawn(function()
        while task.wait(1) do
            local current = (ConfigListDropdown.Value and ConfigListDropdown.Value ~= "") and ConfigListDropdown.Value or "autosaved"
            AutoLoadToggle:SetDesc("Auto loading file: " .. current)
            AutoSaveToggle:SetDesc("Auto saving to file: " .. current)
            
            if self.AutoSave and not self.IsLoading then
                self:Save(current, true)
                if not isfile(AutoloadFile) or readfile(AutoloadFile) ~= current then
                    writefile(AutoloadFile, current)
                end
            end
        end
    end)

    task.spawn(function()
        while task.wait(0.5) do
            local currentAuto = isfile(AutoloadFile) and readfile(AutoloadFile) or nil
            local selected = ConfigListDropdown.Value
            if currentAuto and selected == currentAuto then
                if not AutoLoadToggle.Value then AutoLoadToggle:Set(true) end
            else
                if AutoLoadToggle.Value then 
                    AutoLoadToggle:Set(false) 
                end
            end
        end
    end)
end

return SaveManager
