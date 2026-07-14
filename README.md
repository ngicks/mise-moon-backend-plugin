# mise-moon-backend-plugin

A [mise](https://mise.jdx.dev) backend plugin that installs [MoonBit](https://www.moonbitlang.com/) executables from the [mooncakes.io](https://mooncakes.io) registry using `moon install`.

## Prerequisites

- The MoonBit toolchain (`moon`, `moonc`) must be installed and on `PATH` — see the [MoonBit download page](https://www.moonbitlang.com/download/)
- Executables are built from source, so native targets also need a C compiler

## Installation

```bash
mise plugin install moon https://github.com/ngicks/mise-moon-backend-plugin
```

## Usage

### Registry tools (mooncakes.io)

Tools are referenced as `moon:<user>/<module>[/<path/to/pkg>]`, mirroring `moon install`'s registry source format:

| Tool spec | What it installs |
|-----------|------------------|
| `moon:user/module` | Every main package in the module (equivalent to `moon install user/module/...`) |
| `moon:user/module/path/to/pkg` | A single main package |
| `moon:user/module/path/...` | All main packages under a path prefix |

Versions are the module's versions on mooncakes.io.

```bash
# List available versions
mise ls-remote moon:moonbit-community/moongrep

# Install
mise install moon:moonbit-community/moongrep@latest

# Use
mise use -g moon:moonbit-community/moongrep@latest
moongrep --help
```

Or in `mise.toml`:

```toml
[tools]
"moon:moonbit-community/moongrep" = "latest"
```

### Git repositories

A tool whose name is an `https://` (or `git://`) URL is installed from that git repository. Like the `go:` backend, the version part may be a tag, a branch name, or a commit hash — the plugin figures out which:

```bash
mise install "moon:https://github.com/owner/repo@1.2.3"     # tag (also matches v1.2.3)
mise install "moon:https://github.com/owner/repo@main"      # branch
mise install "moon:https://github.com/owner/repo@abc1234"   # commit hash
mise install "moon:https://github.com/owner/repo@latest"    # newest tag, or HEAD commit if untagged
```

`mise ls-remote` lists the repository's tags; a leading `v` on tags like `v1.2.3` is stripped from the listed version (mise convention) and resolved back to the tag on install. If the repository has no (matching) tags, the current HEAD commit hash is listed instead, so `@latest` still resolves to a reproducible pin.

To install from a path inside the repository (moon's `PATH_IN_REPO`), append a `#path` fragment to the URL:

```toml
[tools]
"moon:https://github.com/owner/repo#cmd/tool-a" = "main"
"moon:https://github.com/owner/repo#cmd/tool-b" = "main"
"moon:https://github.com/owner/repo#tools/..." = "main"   # all main packages under tools/
```

Because the fragment is part of the tool name, tools sharing one repository stay distinct to mise and get separate install directories.

Git tools also support options in `mise.toml`:

```toml
[tools]
"moon:https://github.com/owner/repo" = { version = "1.2.3", tag_prefix = "v", path_in_repo = "cmd/mytool" }
```

| Option | Effect |
|--------|--------|
| `tag_prefix` | Only tags starting with this prefix are listed, with the prefix stripped from the version; it is re-added when resolving the tag on install. A plain leading `v` is already handled without this option — use it for prefixes like `tool-v` in monorepos |
| `path_in_repo` | Same as the `#path` fragment. Prefer the fragment: mise identifies a tool by name and version only, so two entries that differ only in `path_in_repo` would share one install directory and silently shadow each other |

SCP-style ssh URLs (`git@host:owner/repo`) are not supported because mise splits the tool name from the version at `@`.

## How it works

- **Version listing** (`hooks/backend_list_versions.lua`): for registry tools, queries `https://mooncakes.io/api/v0/modules/<user>/<module>` and returns the module's non-yanked versions. For git tools, runs `git ls-remote --tags` (falling back to the HEAD commit hash when there are no matching tags).
- **Installation** (`hooks/backend_install.lua`): runs `moon install <source> --bin <install_path>/bin`, which fetches and compiles the executables from source. A bare `user/module` registry spec gets a `/...` suffix appended so every main package in the module is installed. For git tools, one `git ls-remote --tags --heads` call classifies the version into `--tag` (trying `tag_prefix` + version, the verbatim version, then `v` + version), `--branch`, or `--rev`.
- **Environment** (`hooks/backend_exec_env.lua`): adds `<install_path>/bin` to `PATH`.

Note that the executable name comes from the package's `moon.pkg.json` (usually the last path segment of its main package), which may differ from the module name. Also note that installs compile from source — a large tool can sit for a minute or two at mise's install step with no output while the C compiler runs.

## Development

### Setup

```bash
mise install       # install dev tools (lua, stylua, hk, ...)
hk install         # optional: pre-commit hooks for linting/formatting
```

### Local testing

```bash
# Link this checkout as the `moon` backend plugin
mise plugin link --force moon .

# Exercise the hooks
mise ls-remote moon:moonbit-community/moongrep
mise install moon:moonbit-community/moongrep@latest
mise exec moon:moonbit-community/moongrep@latest -- moongrep --help

# Run the test suite / linters / everything CI runs
mise run test
mise run lint
mise run ci
```

### Debugging

```bash
mise --debug install moon:<user>/<module>@<version>
```

## Files

- `metadata.lua` – Backend plugin metadata and configuration
- `hooks/backend_list_versions.lua` – Lists module versions from the mooncakes.io API
- `hooks/backend_install.lua` – Installs executables via `moon install --bin`
- `hooks/backend_exec_env.lua` – Adds the install's `bin/` to `PATH`
- `.github/workflows/ci.yml` – GitHub Actions CI/CD pipeline
- `mise.toml` – Development tools and configuration
- `mise-tasks/` – Task scripts for testing
- `hk.pkl` – Linting and pre-commit hook configuration
- `stylua.toml` – Lua formatting configuration

## Documentation

- [Backend Plugin Development](https://mise.jdx.dev/backend-plugin-development.html)
- [Lua modules reference](https://mise.jdx.dev/plugin-lua-modules.html)
- [mooncakes.io](https://mooncakes.io) – MoonBit package registry
- [`moon install` docs](https://docs.moonbitlang.com/) – MoonBit toolchain

## License

MIT
