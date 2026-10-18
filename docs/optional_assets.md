# Optional assets and the public checkout

The public source checkout runs without background music or the restricted village environment. Optional files on the author's workstation stay local and are not deleted by the Git configuration.

## Background music

The entire `art/music/` directory, including `.import` sidecars, is ignored. `BackgroundMusic` loads available tracks at runtime and creates no player for a missing track. Without music, world exploration, battles, results, and saves continue normally. Effects and character voices use their existing systems.

To add music you have the right to use:

1. Put your MP3 files in the local `art/music/` directory.
2. Set the `TRACKS` paths in [`features/audio/background_music.gd`](../features/audio/background_music.gd) to those files. Keep the route keys if you want the existing location-based transitions.
3. Allow Godot to import the files, then run the game.
4. Check your own distribution rights before packaging the music. Git ignores do not replace an export or licensing review.

The `web_no_bgm` export feature still disables BGM even when local tracks exist. The [BGM contract](../specs/background_music.md) describes routing and fades. The existing full playback test expects the six configured local tracks; without any tracks it checks silent routing and the actual director lifecycle instead.

## EmacEArt village environment

| Item | Source record |
| --- | --- |
| Author | Maciej EmacArt / EmacEArt |
| Pack | Free Fantasy Medieval Houses |
| Download | [Author's asset page](https://emaceart.itch.io/free-fantasy-medieval-houses-and-props-pack) |
| Archive used on the author's workstation | `SlavicWorldFree_Godot_2026-09-06.zip` |
| Source SHA-256 | `fa1617aa00b73a35d08e0e1b2eafc102b2faf6e473a55d100fb66c2a85416374` |

The supplied EmacEArt Asset License permits use and modification in games or applications, but prohibits redistributing the assets as standalone files or asset packs. Consequently, Git excludes:

```text
features/monkey/assets/emaceart/
features/monkey/village_*.tscn
```

The excluded scene pattern includes the environment scene and its difficulty wrappers. The adapted village and original local assets remain in place on the author's workstation. Do not upload them in a fork, source archive, or public asset bundle. Obtain any additional permissions required for your distribution directly from the rights holder.

### Use the included garden

No external asset download is required for this mode. [`MonkeyProfile.resolved_scene()`](../features/monkey/monkey_profile.gd) uses `features/monkey/garden.tscn` when the configured village scene is absent. The ordinary, hard, mania, and despair encounters keep their own profiles and snapshot target counts.

The garden differs from the village in terrain, routes, and hazards. Shared difficulty parameters do not make the two layouts equally difficult. Test your chosen configuration on the actual level you distribute.

### Install your own licensed environment

1. Download the asset pack directly from its author and read the license bundled with that version.
2. Import it into your own Godot project or the ignored local `features/monkey/assets/emaceart/` directory.
3. Use the included [`garden.tscn`](../features/monkey/garden.tscn) as the gameplay starting point. Integrate your legally obtained environment while retaining the root script, `LevelLayout`, spawn marker, monkey home/route markers, collision, and navigation.
4. Set the relevant `MonkeyProfile.scene` under `features/monkey/data/` to your finished scene. Use an ignored `village_*.tscn` name for a local adaptation that depends on the restricted pack, or add an appropriate ignore rule for another private scene name.
5. Test entry, movement, capture, hazards, timeout, retreat, and return before exporting.

Importing the downloaded archive does not automatically recreate the author's adapted village. This repository supplies neither the restricted asset pack nor a redistributable adapted-village bundle. If the existing local village scenes and their dependencies are already installed, the scene resolver continues to prefer them.

## MIT and third-party boundaries

The [root MIT License](../LICENSE) covers original project work owned by the project author. It does not change the terms of downloaded models, fonts, recordings, reference images, or other third-party material. Keep the original license files and copyright notices when redistribution is permitted.

Repository-level notices and known source information are in [CREDITS.md](../CREDITS.md). Material whose ownership or reuse terms are not established there is not automatically covered by MIT. For a new release, use assets you own or assets with documented terms permitting the intended use.
