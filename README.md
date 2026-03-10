# ZELLIS FOSS Games learning

As a repository of learning game design through projects.

Relying on the [20 Games Challenge](https://20_games_challenge.gitlab.io/) and [Godot Roadmap](https://www.godotroadmap.com/roadmap) 
for both inspiration and guidance.

The hope is to make them all playable on web and through this repo.

## Web launcher

The root of the repo is now a Godot web launcher project. Its source lives in:

- `project.godot`
- `scenes/main.tscn`
- `scripts/main.gd`
- `data/games.json`

Add future web-playable games by exporting them into their own folders and adding a new entry to `data/games.json`, then re-export the root launcher.
