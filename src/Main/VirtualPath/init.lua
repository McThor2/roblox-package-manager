
local zzlib = require(script:WaitForChild("zzlib"))

local VirtualPath = {}
VirtualPath.__index = VirtualPath

export type VirtualPath = typeof(VirtualPath.new())

function VirtualPath.new(path: string, content: string?)
	local self = {}
	self.parent = nil
	self.exists = false
	self.path = path
	self.content = content
	self.children = {}
	self.children_map = {}
	
	return setmetatable(self, VirtualPath)
end

function VirtualPath:IsFile()
	return self.exists and self.content ~= nil
end

function VirtualPath:IsDir()
	return self.exists and self.content == nil
end

function VirtualPath:Read()
	if not self:IsFile() then
		error("Cannot read a non-file VirtualPath")
	end
	
	return self.content
end

function VirtualPath:Write(content: string)
	if #self.children ~= 0 then
		error("Cannot write to directory")
	end
	
	self.content = content
	self:Make()
end

function VirtualPath:GetChildren()
	if self:IsFile() then
		return
	end
	local children = {}
	for _, child in self.children do
		if child.exists then
			table.insert(children, child)
		end
	end
	return children
end

function VirtualPath:AddChild(child: VirtualPath)
	self.children_map[child.path] = child
	table.insert(self.children, child)
	child.parent = self
	self:Make()
end

function VirtualPath:GetAbsolutePath()
	
	local parent = self.parent
	local absolutePath = self.path
	
	while parent do
		absolutePath = parent.path .. "/" .. absolutePath
		parent = parent.parent
	end
	
	return absolutePath
end

function VirtualPath:Make()
	self.exists = true
end

function VirtualPath:__tostring()

	local pathString = self:GetAbsolutePath()

	for _, child in self.children do
		pathString = pathString .. "\n" .. child:GetAbsolutePath()
		if child:IsDir() then
			pathString ..= "/"
		end
	end

	pathString = "<VirtualPath>\n" .. pathString .. "\n</VirtualPath>"

	return pathString
end

function VirtualPath:__div(other)
	
	if self:IsFile() then
		error("Files have no sub directories")
	end
	
	local dir, subDirs = string.match(other, "^([^/]+)/?(.*)$")
	
	local child = self.children_map[dir]
	
	if not child then
		child = VirtualPath.new(dir)
		self:AddChild(child)
	end
	
	if subDirs ~= "" then
		return child / subDirs
	end

	return child
end

function VirtualPath.fromZip(rawZip: string)
	
	local files = {}
	for _, name, offset, size, packed, crc in zzlib.files(rawZip) do
		local content
		if packed then
			content = zzlib.unzip(rawZip, offset, crc)
		else
			content = rawZip:sub(offset,offset+size-1)
		end
		
		table.insert(files, {name = name, content = content})
	end
	
	-- selene: allow (multiple_statements)
	table.sort(files, function(a, b) return #a.name > #b.name end)
	
	local root = VirtualPath.new(".")
	root:Make()
	
	for i = #files, 1, -1 do
		local fileInfo = files[i]
		local name = fileInfo.name
		local content = fileInfo.content	
		local path = root / name

		if #content > 0 then
			path:Write(content)
		end
		
	end

	return root
end

return VirtualPath
