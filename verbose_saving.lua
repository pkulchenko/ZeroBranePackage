return {
  name = "Verbose Saving",
  description = "Verbose File Saving, saves a copy of each file on save in a spereate directory with data and time appended to the file name.",
  author = "Rami Sabbagh",
  version = 1.0,
  
  splitFilePath = function(path)
    local p,n,e = path:match("(.-)([^\\/]-%.?([^%.\\/]*))$")
    n = n:sub(0,-(e:len()+2))
    return p,n,e
  end,
  
  onRegister = function(self)
    self.loc = ide:GetConfig().verbose_folder
    if not self.loc then
      error("Must set 'verbos_folder' in ZBS config inorder for verbose file saving plugin to work !")
    end
  end,
  
  onUnRegister = function(self)
    self.loc = nil
  end,
  
  onEditorSave = function(self,editor)
    if not self.loc then return end
    local filename = ide:GetDocument(editor):GetFilePath()
    filename = filename:gsub("\\","/")
    local path, name, extension = self.splitFilePath(filename)
    local data = editor:GetText()
    
    local time = os.date("%Y_%m_%d - %H.%M.%S",os.time())
    local savename = name.." - "..time.."."..extension
    local file, err = io.open(self.loc..savename,"wb")
    if not file then
      error(err)
    else
      file:write(data)
      file:flush()
      file:close()
    end
  end
}