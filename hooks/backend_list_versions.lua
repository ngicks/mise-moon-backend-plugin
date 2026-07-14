--- @param tool string Registry tool spec (user/module[/path/to/pkg])
--- @return string[] versions Versions in ascending order
local function list_registry_versions(tool)
    local user, module = tool:match("^([^/]+)/([^/]+)")
    if not user or not module then
        error("Invalid tool name '" .. tool .. "': expected user/module[/path/to/pkg] or a git URL")
    end

    local http = require("http")
    local json = require("json")

    local api_url = "https://mooncakes.io/api/v0/modules/" .. user .. "/" .. module

    local resp, err = http.get({ url = api_url })
    if err then
        error("Failed to fetch versions for " .. user .. "/" .. module .. ": " .. err)
    end
    if resp.status_code == 404 then
        error("Module " .. user .. "/" .. module .. " not found on mooncakes.io")
    end
    if resp.status_code ~= 200 then
        error("mooncakes.io returned status " .. resp.status_code .. " for " .. user .. "/" .. module)
    end

    local data = json.decode(resp.body)
    local versions = {}

    -- The API returns versions newest-first; mise expects oldest-first.
    if data.versions then
        for i = #data.versions, 1, -1 do
            local v = data.versions[i]
            if not v.yanked then
                table.insert(versions, v.version)
            end
        end
    end

    if #versions == 0 then
        error("No versions found for " .. user .. "/" .. module)
    end

    return versions
end

--- @param url string Git repository URL, possibly with a `#path/in/repo` fragment
--- @param options table Tool options from mise.toml
--- @return string[] versions Versions in ascending order
local function list_git_versions(url, options)
    local cmd = require("cmd")
    local semver = require("semver")

    -- Versions belong to the repository; a `#path/in/repo` fragment only
    -- selects packages, so strip it before talking to git.
    url = url:match("^([^#]*)#") or url

    local tag_prefix = options.tag_prefix or ""

    local ok, out = pcall(cmd.exec, 'git ls-remote --tags "' .. url .. '"')
    if not ok then
        error("Failed to list git tags for " .. url .. ": " .. tostring(out))
    end

    local versions = {}
    local seen = {}
    for line in out:gmatch("[^\n]+") do
        local tag = line:match("refs/tags/(.+)$")
        -- skip peeled entries (`tag^{}`) that ls-remote emits for annotated tags
        if tag and not tag:match("%^{}$") then
            if tag_prefix == "" or tag:sub(1, #tag_prefix) == tag_prefix then
                local version = tag:sub(#tag_prefix + 1)
                -- mise convention: list `v1.2.3` tags as `1.2.3`; the install
                -- hook resolves the version back to the prefixed tag
                if tag_prefix == "" then
                    version = version:match("^v(%d.*)$") or version
                end
                if not seen[version] then
                    seen[version] = true
                    table.insert(versions, version)
                end
            end
        end
    end

    if #versions > 0 then
        local sorted_ok, sorted = pcall(semver.sort, versions)
        return sorted_ok and sorted or versions
    end

    -- No (matching) tags: fall back to the current HEAD commit so that
    -- `@latest` resolves to something installable and reproducible.
    local head_ok, head = pcall(cmd.exec, 'git ls-remote "' .. url .. '" HEAD')
    local sha = head_ok and head:match("^(%x+)") or nil
    if not sha then
        error("No git tags or HEAD commit found for " .. url)
    end
    return { sha:sub(1, 12) }
end

--- Lists available versions for a tool in this backend
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendlistversions
---
--- Registry tools (`user/module[/path/to/pkg]`): versions live on the module, so
--- the first two path segments are resolved against the mooncakes.io registry API.
---
--- Git tools (`https://...`): versions are the repository's git tags, optionally
--- filtered and stripped by the `tag_prefix` option. When the repository has no
--- matching tags, the current HEAD commit hash is returned so `@latest` still
--- resolves to a reproducible pin.
--- @param ctx {tool: string, options: table} Context (tool = the tool name requested)
--- @return {versions: string[]} Table containing list of available versions
function PLUGIN:BackendListVersions(ctx)
    local tool = ctx.tool

    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end

    if tool:match("^https?://") or tool:match("^git://") then
        return { versions = list_git_versions(tool, ctx.options or {}) }
    end

    return { versions = list_registry_versions(tool) }
end
