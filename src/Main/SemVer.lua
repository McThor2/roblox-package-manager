
-- McThor2
-- See https://semver.org/#semantic-versioning-200

local SemVer = {}
do
	SemVer.__index = SemVer

    local PRE_RELEASE_PATTERN = "^[1-9%a%-][%w%-]*$"
    local BUILD_PATTERN = "^[%w%-]*$"

    local SEMVER_PATTERN = "^(%d+)%.(%d+)%.(%d+)(%-?[%w%.]*)(%+?[%w%.]*)$"

    local function checkVersion(a: number, name: string)
        -- Must be >= 0 and a whole number
        if a >=0 and a == (a - a%1) then
            return
        end
        error(`{name} value must be an integer >= 0`)
    end

    local function checkIdentifiers(a: string?, pattern: string, message: string)
        if a == nil then
            return
        end

        local identifiers = string.split(a, ".")

        local isValid = true

        for _, identifier in identifiers do
            if string.match(identifier, pattern) then
                continue
            end

            isValid = false
            break
        end

        if isValid then
            return
        end

        error(message)
    end

    local function ltPreRelease(a: string, b: string)

        if a == nil then
            return false
        end

        if b == nil then
            return true
        end

        local aIdentifiers = string.split(a, ".")
        local bIdentifiers = string.split(b, ".")

        for index, aIdent in aIdentifiers do
            local bIdent = bIdentifiers[index]

            if bIdent == nil then
                return false
            end

            local numA = tonumber(aIdent)
            local numB = tonumber(bIdent)
            if numA and numB then
                return numA < numB
            end
        end

        return a < b
    end

	function SemVer.new(
		major: number,
		minor: number,
		patch: number,
		preRelease: string?,
        build: string?
		)

        checkVersion(major, "Major")
        checkVersion(minor, "Minor")
        checkVersion(patch, "Patch")

        checkIdentifiers(
            preRelease,
            PRE_RELEASE_PATTERN,
            (
                "Pre-release must only contain dot-separated alphanumeric "..
                "characters or hyphens. Each identifier must not be empty "..
                `or have a leading zero (got '{preRelease}')`
            )
        )
        checkIdentifiers(
            build,
            BUILD_PATTERN,
            (
            "Build must only contain dot-separated alphanumeric "..
            "characters or hyphens. Each identifier must not be empty "..
            `(got '{build}')`
            )
        )

		local self = {}
        self.Major = major
        self.Minor = minor
        self.Patch = patch
        self.PreRelease = preRelease
        self.Build = build

		setmetatable(self, SemVer)

		return self
	end

    function SemVer.fromString(a: string, strict: boolean)

        strict = strict == nil and false or strict

        local major, minor, patch, preRelease, build = string.match(a, SEMVER_PATTERN)

        if not (major and minor and patch) then
            if not strict then
                return nil
            end
            error(`Invalid string input to SemVer - '{a}'`)
        end

        preRelease = string.sub(preRelease, 2, #preRelease)
        if preRelease == "" then
            preRelease = nil
        end

        build = string.sub(build, 2, #build)
        if build == "" then
            build = nil
        end

        major = tonumber(major)
        minor = tonumber(minor)
        patch = tonumber(patch)

        return SemVer.new(major, minor, patch, preRelease, build)
    end

    function SemVer:__tostring()
        local core = `{self.Major}.{self.Minor}.{self.Patch}`
        local preRelease = self.PreRelease and `-{tostring(self.PreRelease)}` or nil
        local build = self.Build and `+{self.Build}` or nil

        local verString = core
        if preRelease then
            verString ..= preRelease
        end
        if build then
            verString ..= build
        end
        return verString
    end

    function SemVer:__lt(other: SemVer)

        if self.Major ~= other.Major then
            return self.Major < other.Major
        end

        if self.Minor ~= other.Minor then
            return self.Minor < other.Minor
        end

        if self.Patch ~= other.Patch then
            return self.Patch < other.Patch
        end

        if self.PreRelease ~= other.PreRelease then
            return ltPreRelease(self.PreRelease, other.PreRelease)
        end

        -- Ignores build metadata
        -- All components are equal therefore return false

        return false
    end

    function SemVer:__le(other: SemVer)
        return self == other or self < other
    end

    function SemVer:__eq(other: SemVer)
        -- Ignores build metadata
        return (
            self.Major == other.Major and
            self.Minor == other.Minor and
            self.Patch == other.Patch and
            self.PreRelease == other.PreRelease
        )
    end

end

export type SemVer = typeof(SemVer.new(0,1,0,"a","b"))

return SemVer