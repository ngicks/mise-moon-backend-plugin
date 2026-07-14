-- metadata.lua
-- Backend plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html

PLUGIN = { -- luacheck: ignore
    -- Required: Plugin name (will be the backend name users reference)
    name = "moon",

    -- Required: Plugin version (not the tool versions)
    version = "0.0.2",

    -- Required: Brief description of the backend and tools it manages
    description = "A mise backend plugin that installs MoonBit executables from mooncakes.io via `moon install`",

    -- Required: Plugin author/maintainer
    author = "ngicks",

    -- Optional: Plugin homepage/repository URL
    homepage = "https://github.com/ngicks/mise-moon-backend-plugin",

    -- Optional: Plugin license
    license = "MIT",

    -- Optional: Important notes for users
    notes = {
        "Requires the MoonBit toolchain (`moon`) to be installed and on PATH",
        "Executables are built from source; native targets need a C compiler",
        "Tool format: moon:user/module installs every main package in the module,",
        "moon:user/module/path/to/pkg installs a single main package,",
        "moon:user/module/path/... installs all main packages under a path prefix,",
        "moon:https://host/repo installs from a git repository (version = tag, branch, or commit)",
        "moon:https://host/repo#path/in/repo installs from a path inside a git repository",
        "Git tools support tag_prefix and path_in_repo options in mise.toml",
    },
}
