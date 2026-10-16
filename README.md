# lumide_muse

[![pub package](https://img.shields.io/pub/v/lumide_muse.svg)](https://pub.dev/packages/lumide_muse) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**M.U.S.E.** (Music Utility for Software Engineers) plays your local music inside [Lumide IDE](https://lumide.dev).

No browser tab, no Electron app. Point M.U.S.E. at a music folder and control playback from the status bar, the command palette, or a player panel with synced lyrics.

![The M.U.S.E. player panel](https://raw.githubusercontent.com/simonpham/lumide_muse/refs/heads/develop/doc/player.png)

<img alt="Lyrics in the status bar" src="https://raw.githubusercontent.com/simonpham/lumide_muse/refs/heads/develop/doc/status_bar.png" width="328">

## Features

- **Status bar controls**: a play/pause button that opens the controls menu, and the current lyric line (or track title) next to it. Click it to pick a track from the playlist.
- **Synced lyrics**: put a `.lrc` file next to a track (`song.mp3` + `song.lrc`) and its lyrics follow playback in the status bar and the player panel.
- **Player panel**: album-style view with scrolling lyrics, a seek bar, and previous/play/next buttons. It adapts to wide, tall, and short panes.
- **Shuffle and repeat**: shuffle plays every track once per cycle; repeat cycles through off, all, and one.
- **Your library, remembered**: the scanned playlist is cached, and changing the library folder in Settings rescans it.
- **Light on the editor**: audio is decoded by [libmpv](https://mpv.io) in the plugin's own process, and the engine only loads when you press play.

<img alt="The controls menu" src="https://raw.githubusercontent.com/simonpham/lumide_muse/refs/heads/develop/doc/controls.png" width="260"> <img alt="The playlist, with the track that is playing" src="https://raw.githubusercontent.com/simonpham/lumide_muse/refs/heads/develop/doc/playlist.png" width="260">

<img alt="The player panel in a narrow pane" src="https://raw.githubusercontent.com/simonpham/lumide_muse/refs/heads/develop/doc/player_narrow.png" width="280">

Supported formats: MP3, FLAC, WAV, M4A, AAC, OGG, and Opus.

## Getting Started

1. Open the **Plugins** pane in Lumide, search for **lumide_muse**, and install it.
2. Run **MUSE: Scan Music Library** from the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`) and choose your music folder.
3. Playback starts and the player panel opens. Use the status bar or the shortcuts below from then on.

### Audio engine

| Platform | Setup |
| --- | --- |
| macOS | Nothing to do. On first play, M.U.S.E. downloads an audio-only libmpv build (about 8 MB) from [media-kit/libmpv-darwin-build](https://github.com/media-kit/libmpv-darwin-build) into its private storage and signs it locally. |
| Linux | Install libmpv: `sudo apt install libmpv2` (Debian, Ubuntu), `sudo dnf install mpv-libs` (Fedora), or `sudo pacman -S mpv` (Arch). |
| Windows | Experimental. Put `libmpv-2.dll` on your `PATH`, or set `muse.libmpvPath`. |

If libmpv can't be loaded, M.U.S.E. tells you what to install when you press play.

## Commands

| Command | Shortcut | Purpose |
| --- | --- | --- |
| `MUSE: Play/Pause` | `Cmd/Ctrl+Alt+Shift+P` | Play or pause; starts the playlist if nothing is loaded |
| `MUSE: Next Track` | `Cmd/Ctrl+Alt+Shift+Right` | Skip to the next track |
| `MUSE: Previous Track` | `Cmd/Ctrl+Alt+Shift+Left` | Go back one track |
| `MUSE: Open Player` | | Open the player panel |
| `MUSE: Show Playlist` | | Pick a track to play |
| `MUSE: Show Controls` | | Playback, shuffle, repeat, and library actions in one menu |
| `MUSE: Toggle Shuffle` | | Shuffle on or off |
| `MUSE: Cycle Repeat Mode` | | Repeat off → all → one |
| `MUSE: Toggle Lyrics in Status Bar` | | Show or hide the now-playing item |
| `MUSE: Scan Music Library` | | Choose a folder (first time) and rescan it |

Shortcuts can be changed in **Settings → Keymap**.

## Configuration

Set these under **Settings → Plugins → M.U.S.E. Player**.

| Key | Default | Description |
| --- | --- | --- |
| `muse.libraryPath` | `''` | Folder to load music from, scanned recursively. If empty, M.U.S.E. asks for a folder the first time you scan. |
| `muse.libmpvPath` | `''` | A libmpv library to use instead of the downloaded (macOS) or system (Linux, Windows) one. |

## Permissions

Lumide asks you to approve these when the plugin is installed:

| Permission | Why |
| --- | --- |
| File system: `${home}/**` | Read your music folder and the `.lrc` files next to your tracks. Libraries outside your home folder can't be scanned. |
| Network: `github.com/media-kit` | macOS only: download libmpv once. |
| Shell: `cp`, `install_name_tool`, `codesign` | macOS only: install that libmpv build into the plugin's storage and ad-hoc sign it so macOS will load it. |

The playlist cache and the macOS engine live in the plugin's private storage (`~/.sofluffy/lumide/plugins/lumide_muse`). Nothing else is written, and nothing is sent anywhere.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
