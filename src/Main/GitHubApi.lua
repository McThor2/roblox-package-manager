
local HttpService = game:GetService("HttpService")

local GH_PATTERN = "^(%a+)/(%a+)$"

local GitHubApi = {}

GitHubApi.RootPath = "https://api.github.com"

-- <OWNER>/<REPO>
GitHubApi.RepoPath = "/repos/%s/%s"

GitHubApi.RepoTagsPath = "/repos/%s/%s/tags"

-- <OWNER>/<REPO> / - /<PATH>
GitHubApi.RepoContentsPath = "/repos/%s/%s/contents/%s"

function GitHubApi:GetTags(owner, repo)
	
	local apiPath = GitHubApi.RootPath .. GitHubApi.RepoTagsPath

	local formattedPath = string.format(apiPath, owner, repo)

	local response = HttpService:RequestAsync({
		Method = "GET",
		Url = formattedPath,
		Headers = {}
	})

	local headers = response.Headers

	if headers["content-type"] ~= "application/json; charset=utf-8" then
		return
	end
	
	local decoded = HttpService:JSONDecode(response.Body)
	
	print(decoded)
	
	local tags = {}
	
	for _, tagInfo in ipairs(decoded) do
		table.insert(tags, tagInfo["name"])
	end
	
	return tags
end

function GitHubApi:GetContents(owner, repo, path, ref)
	
	path = path or ""
	
	local apiPath = GitHubApi.RootPath .. GitHubApi.RepoContentsPath
	
	local formattedPath = string.format(apiPath, owner, repo, path)
	
	local response = HttpService:RequestAsync({
		Method = "GET",
		Url = formattedPath,
		Headers = {}
	})
	
	local headers = response.Headers
	
	if headers["content-type"] == "application/json; charset=utf-8" then
		
		local decoded = HttpService:JSONDecode(response.Body)
		
		print(decoded)
	end
	
end

return GitHubApi
