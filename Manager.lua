local HttpService = game:GetService("HttpService")
local SaveManager = {}

SaveManager.Folder = "WindUISettings"
SaveManager.Options = {}
SaveManager.Parser = {}

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
    }
}

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

function SaveManager:Save(name)
    if not name then return false end
    local fullPath = self.Folder .. "/settings/" .. name .. ".json"
    
    local Data = {}
    for Name, Option in pairs(self.Options) do
        if self.Parser[Option.Type] then
            Data[Name] = self.Parser[Option.Type].Save(Option.Element)
        end
    end
    
    local Success, Encoded = pcall(HttpService.JSONEncode, HttpService, Data)
    if not Success then return false end
    
    writefile(fullPath, Encoded)
    return true
end

function SaveManager:Load(name)
    if not name then return false end
    local fullPath = self.Folder .. "/settings/" .. name .. ".json"
    if not isfile(fullPath) then return false end
    
    local Success, Decoded = pcall(HttpService.JSONDecode, HttpService, readfile(fullPath))
    if not Success then return false end
    
    for Name, Data in pairs(Decoded) do
        if self.Options[Name] and self.Parser[Data.Type] then
            task.spawn(function()
                self.Parser[Data.Type].Load(self.Options[Name].Element, Data)
            end)
        end
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
    local Section = Tab:AddSection("Configuration")
    
    local ConfigNameInput = Section:AddInput("ConfigName", {
        Title = "Config Name",
        Placeholder = "Enter name...",
        Callback = function() end
    })
    
    local ConfigListDropdown = Section:AddDropdown("ConfigList", {
        Title = "Config List",
        Values = self:GetConfigList(),
        AllowNull = true,
        Callback = function() end
    })
    
    Section:AddButton({
        Title = "Create Config",
        Callback = function()
            local name = ConfigNameInput.Value
            if name:gsub(" ", "") == "" then return end
            self:Save(name)
            ConfigListDropdown:Refresh(self:GetConfigList())
        end
    })
    
    Section:AddButton({
        Title = "Load Config",
        Callback = function()
            local name = ConfigListDropdown.Value
            if name then self:Load(name) end
        end
    })
    
    Section:AddButton({
        Title = "Overwrite Config",
        Callback = function()
            local name = ConfigListDropdown.Value
            if name then self:Save(name) end
        end
    })
    
    Section:AddButton({
        Title = "Refresh List",
        Callback = function()
            ConfigListDropdown:Refresh(self:GetConfigList())
        end
    })
    
    local AutoloadFile = self.Folder .. "/settings/autoload.txt"
    Section:AddButton({
        Title = "Set as Autoload",
        Callback = function()
            local name = ConfigListDropdown.Value
            if name then
                writefile(AutoloadFile, name)
            end
        end
    })
    
    if isfile(AutoloadFile) then
        local name = readfile(AutoloadFile)
        self:Load(name)
    end
end

return SaveManager
