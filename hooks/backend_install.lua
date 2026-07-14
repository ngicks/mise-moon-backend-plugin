--- Builds the `moon install` source arguments for a registry tool.
--- @param tool string Registry tool spec (user/module[/path/to/pkg])
--- @param version string Version to install
--- @return string args Quoted source arguments for `moon install`
local function registry_source_args(tool, version)
    if not tool:match("^[^/]+/[^/]+") then
        error("Invalid tool name '" .. tool .. "': expected user/module[/path/to/pkg] or a git URL")
    end

    -- A bare `user/module` spec would require the module root to be a main
    -- package; the `/...` suffix installs every main package in the module.
    local spec = tool
    local _, depth = spec:gsub("/", "")
    if depth == 1 then
        spec = spec .. "/..."
    end

    return '"' .. spec .. "@" .. version .. '"'
end

--- Builds the `moon install` source arguments for a git tool. The version is
--- classified go-style with one `git ls-remote` call: a tag (with `tag_prefix`,
--- verbatim, or with an implicit `v` prefix), then a branch, then a commit hash.
--- @param url string Git repository URL, possibly with a `#path/in/repo` fragment
--- @param version string Version to install (tag, branch, or commit hash)
--- @param options table Tool options from mise.toml
--- @return string args Quoted source arguments for `moon install`
local function git_source_args(url, version, options)
    local cmd = require("cmd")

    -- A `#path/in/repo` fragment in the tool name selects packages inside the
    -- repository, like the path_in_repo option, while keeping tools that share
    -- a repository distinct to mise (separate install directories).
    local fragment
    if url:match("#") then
        local base, frag = url:match("^([^#]*)#(.*)$")
        if not base or base == "" or not frag or frag == "" then
            error("Invalid git tool name '" .. url .. "': expected url#path/in/repo")
        end
        url, fragment = base, frag
    end

    local path_in_repo = options.path_in_repo
    if path_in_repo == "" then
        path_in_repo = nil
    end
    if fragment and path_in_repo and fragment ~= path_in_repo then
        error(
            "Conflicting paths for "
                .. url
                .. ": tool name fragment '#"
                .. fragment
                .. "' vs path_in_repo option '"
                .. path_in_repo
                .. "'"
        )
    end
    path_in_repo = fragment or path_in_repo

    local ok, out = pcall(cmd.exec, 'git ls-remote --tags --heads "' .. url .. '"')
    if not ok then
        error("Failed to list git refs for " .. url .. ": " .. tostring(out))
    end

    local tags, heads = {}, {}
    for line in out:gmatch("[^\n]+") do
        local tag = line:match("refs/tags/(.+)$")
        if tag then
            tags[tag:gsub("%^{}$", "")] = true
        end
        local head = line:match("refs/heads/(.+)$")
        if head then
            heads[head] = true
        end
    end

    local tag_prefix = options.tag_prefix or ""

    local ref
    if tags[tag_prefix .. version] then
        ref = '--tag "' .. tag_prefix .. version .. '"'
    elseif tags[version] then
        ref = '--tag "' .. version .. '"'
    elseif version:match("^%d") and tags["v" .. version] then
        ref = '--tag "v' .. version .. '"'
    elseif heads[version] then
        ref = '--branch "' .. version .. '"'
    elseif version:match("^%x+$") and #version >= 7 and #version <= 40 then
        ref = '--rev "' .. version .. '"'
    else
        error(
            "Cannot resolve version '"
                .. version
                .. "' for "
                .. url
                .. ": not a tag, branch, or commit hash of the repository"
        )
    end

    local source = '"' .. url .. '"'
    if path_in_repo then
        source = source .. ' "' .. path_in_repo .. '"'
    end

    return source .. " " .. ref
end

--- Installs a specific version of a tool
--- Documentation: https://mise.jdx.dev/backend-plugin-development.html#backendinstall
--- Runs `moon install <source> --bin <install_path>/bin`, which fetches the tool
--- from mooncakes.io or a git repository and builds its main package(s) from source.
--- @param ctx {tool: string, version: string, install_path: string, options: table} Context
--- @return table Empty table on success
function PLUGIN:BackendInstall(ctx)
    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end
    if not version or version == "" then
        error("Version cannot be empty")
    end
    if not install_path or install_path == "" then
        error("Install path cannot be empty")
    end

    local source_args
    if tool:match("^https?://") or tool:match("^git://") then
        source_args = git_source_args(tool, version, ctx.options or {})
    else
        source_args = registry_source_args(tool, version)
    end

    local cmd = require("cmd")
    local file = require("file")
    local bin_dir = file.join_path(install_path, "bin")

    local install_cmd = "moon install " .. source_args .. ' --bin "' .. bin_dir .. '"'
    local ok, output = pcall(cmd.exec, install_cmd)
    if not ok then
        error(
            "Failed to run `"
                .. install_cmd
                .. "` (is the MoonBit toolchain installed and on PATH?): "
                .. tostring(output)
        )
    end

    return {}
end
