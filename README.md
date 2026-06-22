# ZELLIS FOSS Games learning

A repository for learning game design through small, web-playable Godot projects.

Relying on the [20 Games Challenge](https://20_games_challenge.gitlab.io/) and [Godot Roadmap](https://www.godotroadmap.com/roadmap)
for both inspiration and guidance.

The hope is to make them all playable on web and through this repo.

## Web launcher

The root of the repo serves a static HTML launcher page instead of booting a Godot scene.

- `index.html`
- `data/games.json`

Add future web-playable games by exporting them into their own folders and adding a new entry to `data/games.json`.

## Games

Each game is its own Godot 4 project in a top-level folder.

| Game | Folder | Type |
|------|--------|------|
| Flappy | `flappy/` | 2D |
| Brickbreaker | `brickbreaker/` | 2D |
| Bricktris | `bricktris/` | 3D / WebXR |
| Wordle | `wordle/` | 2D / UI |
| Tic Tac Toe | `tic_tac_toe/` | 2D / UI |
| Pai-Do | `pai-do/` | 2D / UI |

## Agent tooling (let a model see and drive the games)

`tools/godot-agent-mcp/` is a small MCP server that lets a local model see and
control any of these games - 2D or 3D, on web, desktop, or mobile - to
iteratively build and debug gameplay. Each project carries one tiny `AgentLink`
autoload (in `addons/agent_link/`) that dials out to the server; the game is a
no-op unless launched with the `--agent` flag.

```bash
cd tools/godot-agent-mcp
npm install && npm run build
npm run sync-godot     # installs/updates AgentLink in every project
```

See [docs/godot-agent-mcp.md](docs/godot-agent-mcp.md) for the architecture and tool reference.

## Code formatting

All GDScript files are formatted using [GDScript-formatter](https://github.com/GDQuest/GDScript-formatter) (v0.20.1).

### Setup

1. Download the pre-built binary for your platform from
   [GitHub Releases](https://github.com/GDQuest/godot-gdscript-formatter-tree-sitter/releases):
   ```bash
   # macOS arm64
   curl -L "https://github.com/GDQuest/godot-gdscript-formatter-tree-sitter/releases/download/0.20.1/gdscript-formatter-0.20.1-macos-aarch64.zip" -o gdformat.zip
   unzip gdformat.zip && mv gdscript-formatter-* tools/gdscript-formatter && chmod +x tools/gdscript-formatter
   ```

2. A pre-commit hook is included (`.git/hooks/pre-commit`). It formats all staged `.gd` files automatically.
   If formatting changes were applied, the commit is aborted — fix and re-stage, then commit again.

3. For VSCode: install the [godot-format](https://marketplace.visualstudio.com/items?itemName=DoHe.godot-format) extension.
   It auto-discovers the formatter binary if it's on your system PATH (copy `tools/gdscript-formatter` to a PATH location).

### Manual use

```bash
# Format all .gd files in-place
./tools/gdscript-formatter --use-spaces --safe .

# Check if files need formatting (exit 0 = clean, exit 1 = changes needed)
./tools/gdscript-formatter --use-spaces --check .
```

## Documentation

All design and tooling docs live in `docs/` (kept with the code, not in a sibling repo):

- [docs/godot-agent-mcp.md](docs/godot-agent-mcp.md) - the agent MCP tool (architecture, tools, web/desktop/mobile).
- [docs/component-design-principles.md](docs/component-design-principles.md) - component/signal architecture used across games.
- [docs/bricktris.md](docs/bricktris.md) - Bricktris design notes and lessons learned.
- [docs/flappy-rearrangement-summary.md](docs/flappy-rearrangement-summary.md) - the flappy refactor.

Bricktris also keeps a few forward-looking design plans alongside its project: `bricktris/PLAN.md`, `bricktris/mobile-interface-plan.md`, `bricktris/stacking-simplification-plan.md`.

# Acknowledgements and Citations
Pai-Do is inspired by Pai-Sho and the many open fan made games. In particular
> Designs created by artist Coeur De Lion (https://www.coeurdelionmusic.com/) and SkudPaiSho. Play Vagabond Pai Sho online at The Garden Gate - https://SkudPaiSho.com.
