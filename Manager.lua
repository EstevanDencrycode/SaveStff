-- 1.5 LAG FIX

local HttpService = game:GetService("HttpService")
local SaveManager = {}

SaveManager.Folder = "WindUISettings"
SaveManager.Options = {}
SaveManager.Parser = {}
SaveManager.Library = nil
SaveManager.AutoSave = false
SaveManager.CurrentConfig = nil

SaveManager.Parser = {
    Toggle = {
        Save = function(Obj) return {Type = "Toggle", Value = Obj.Value} end,
        Load = function(Obj, Data) Obj:Set(Data.Value) end,
    },
    Dropdown = {
        Save = function(Obj) return {Type = "Dropdown", Value = Obj.Value, Multi = Obj.Multi} end,
        Load = function(Obj, Data) Obj:Select(Data.Value) end,
    },
    Input = {
        Save = function(Obj) return {Type = "Input", Value = Obj.Value} end,
        Load = function(Obj, Data) Obj:Set(Data.Value) end,
    },
    Slider = {
        Save = function(Obj) return {Type = "Slider", Value = Obj.Value.Default} end,
        Load = function(Obj, Data) Obj:Set(Data.Value) end,
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
    if not name then return false end
    
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

    if self.Library and not ignoreNotify then
        self.Library:Notify({
            Title = "Save Manager",
            Content = "Saved config: " .. name,
            Duration = 3,
            Icon = "check"
        })
    end

    return true
end

function SaveManager:Load(name)
    if not name then return false end
    local fullPath = self.Folder .. "/settings/" .. name .. ".json"
    if not isfile(fullPath) then return false end
    
    local Success, Decoded = pcall(HttpService.JSONDecode, HttpService, readfile(fullPath))
    if not Success then return false end
    
    local count = 0
    for Name, Data in pairs(Decoded) do
        if self.Options[Name] and self.Parser[Data.Type] then
            pcall(function()
                self.Parser[Data.Type].Load(self.Options[Name].Element, Data)
            end)
            
            -- ANTI-CRASH: Espera cada 10 items para no congelar la pantalla
            count = count + 1
            if count % 10 == 0 then
                task.wait()
            end
        end
    end

    self.CurrentConfig = name

    if self.Library then
        self.Library:Notify({
            Title = "Save Manager",
            Content = "Loaded config: " .. name,
            Duration = 3,
            Icon = "check"
        })
    end

    return true
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
    
    local ConfigListDropdown = Section:Dropdown({
        Title = "Config List",
        Values = self:GetConfigList(),
        AllowNull = true,
        Callback = function() end
    })
    
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
        Title = "Delete Selected Config",
        Callback = function()
            local name = ConfigListDropdown.Value
            if not name then return end
            
            local path = self.Folder .. "/settings/" .. name .. ".json"
            if isfile(path) then
                delfile(path)
                ConfigListDropdown:Refresh(self:GetConfigList())
                if self.Library then
                    self.Library:Notify({
                        Title = "Save Manager",
                        Content = "Deleted config: " .. name,
                        Icon = "trash"
                    })
                end
            end
        end
    })

    Section:Button({
        Title = "Delete All Configs",
        Callback = function()
            self.Library:Popup({
                Title = "Delete All?",
                Icon = "alert-triangle",
                Content = "Are you sure you want to delete ALL configurations? This cannot be undone.",
                Buttons = {
                    {
                        Title = "Cancel",
                        Callback = function() end,
                        Variant = "Tertiary",
                    },
                    {
                        Title = "Delete All",
                        Icon = "trash",
                        Callback = function()
                            local list = listfiles(self.Folder .. "/settings")
                            for _, file in ipairs(list) do
                                if file:sub(-5) == ".json" then
                                    delfile(file)
                                end
                            end
                            ConfigListDropdown:Refresh(self:GetConfigList())
                            self.Library:Notify({Title="Manager", Content="All configs deleted", Icon="trash"})
                        end,
                        Variant = "Primary",
                    }
                }
            })
        end
    })

    Section:Button({
        Title = "Refresh List",
        Callback = function()
            ConfigListDropdown:Refresh(self:GetConfigList())
        end
    })
    
    local AutoloadFile = self.Folder .. "/settings/autoload.txt"
    
    local function GetAutoloadName()
        if isfile(AutoloadFile) then return readfile(AutoloadFile) end
        return "None"
    end

    local AutoloadButton
    AutoloadButton = Section:Button({
        Title = "Set as Autoload",
        Desc = "Autoloading: " .. GetAutoloadName(),
        Callback = function()
            local name = ConfigListDropdown.Value
            if not name then 
                if self.Library then self.Library:Notify({Title="Error", Content="Select a config first!", Icon="x"}) end
                return 
            end
            
            local current = GetAutoloadName()

            local function SetAutoload()
                writefile(AutoloadFile, name)
                AutoloadButton:SetDesc("Autoloading: " .. name)
                if self.Library then
                    self.Library:Notify({
                        Title = "Save Manager",
                        Content = "Set autoload to: " .. name,
                        Duration = 3,
                        Icon = "check"
                    })
                end
            end

            if current == "None" or current == name then
                SetAutoload()
            else
                self.Library:Popup({
                    Title = "Change Autoload?",
                    Icon = "info",
                    Content = "Switch autoload from '"..current.."' to '"..name.."'?",
                    Buttons = {
                        {
                            Title = "Cancel",
                            Callback = function() end,
                            Variant = "Tertiary",
                        },
                        {
                            Title = "Confirm",
                            Icon = "check",
                            Callback = function() SetAutoload() end,
                            Variant = "Primary",
                        }
                    }
                })
            end
        end
    })
    
    Section:Button({
        Title = "Reset Autoload",
        Desc = "Disable auto-loading",
        Callback = function()
            if isfile(AutoloadFile) then
                delfile(AutoloadFile)
                AutoloadButton:SetDesc("Autoloading: None")
                if self.Library then
                    self.Library:Notify({Title = "Manager", Content = "Autoload disabled", Icon = "trash"})
                end
            end
        end
    })

    Section:Toggle({
        Title = "Auto Save",
        Desc = "Automatically save current config every 1s",
        Value = false,
        Callback = function(val)
            self.AutoSave = val
        end
    })
    
    if isfile(AutoloadFile) then
        local name = readfile(AutoloadFile)
        self:Load(name)
    end

    task.spawn(function()
        while task.wait(1) do
            if self.AutoSave and self.CurrentConfig then
                self:Save(self.CurrentConfig, true)
            end
        end
    end)
end

return SaveManager
