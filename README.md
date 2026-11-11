# BrewBar

![Swift](https://img.shields.io/badge/Swift-6-orange.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A tiny native macOS menu bar app that tells you when Homebrew has something to upgrade.

## Preview

```
       📦 3
┌────────────────────────────────────────────────┐
│ 3 Packages Outdated                            │
│ ────────────────────────────────────────────── │
│ Formulae                                       │
│   awscli  2.39.4 → 2.39.5                      │
│ 🔒 node  22.1.0 → 22.2.0                       │
│   yq  4.54.1 → 4.54.2                          │
│ Casks                                          │
│   intellij-idea  2026.2.4 → 2026.3             │
│ ────────────────────────────────────────────── │
│ Upgrade All                                    │
│ Refresh                                     ⌘R │
│ Settings                                     ▸ │
│ ────────────────────────────────────────────── │
│ Homebrew Updated 10:41                         │
│ Quit BrewBar (0.1.0)                        ⌘Q │
└────────────────────────────────────────────────┘
```

## Features

- **Always Visible**: The number of outdated packages right next to the icon, hidden when everything is up to date
- **Stays Current**: Runs `brew outdated` every minute and `brew update` every 15 minutes, so changes you make in the terminal show up quickly. Also after waking from sleep, or on demand
- **Upgrade in Terminal**: Click a package to run `brew upgrade` for it in Terminal, or use **Upgrade All**
- **Formulae and Casks**: Both are listed, grouped, with installed and new version
- **Pinned Packages**: Shown with a lock, greyed out, and not counted
- **Auto-Updating Casks**: Casks that update themselves are hidden by default. Turn on *Include Auto-Updating Casks* under **Settings** to list them with `· Auto-Updates`, count them, and include them in **Upgrade All**
- **Native Menu**: A regular macOS menu, no custom window
- **Starts at Login**: Runs as a Homebrew service, no Dock icon
- **Lightweight**: Native Swift and SwiftUI, no dependencies

## Installation

### Via Homebrew

```bash
brew tap tomhuettmann/tap
brew trust tomhuettmann/tap
brew install tomhuettmann/tap/brew-bar
brew services start brew-bar
```

### From Source

```bash
swift build -c release
.build/release/BrewBar
```

## Usage

### Upgrading

Click a package in the list to open Terminal with `brew upgrade` for it.
**Upgrade All** runs `brew upgrade` for everything, with `--greedy` if auto-updating casks are included.
BrewBar does not run upgrades itself, so you see the output and can enter your password if a cask asks for it.

Tip: In **Terminal → Settings → Profiles → Shell**, set *When the shell exits* to *Close if the shell exited cleanly*.
Then the window closes after a successful upgrade and stays open if something fails.

The list is checked every minute, so it catches up shortly after you upgrade, install or remove something.
BrewBar starts upgrades with `--yes`, so Homebrew does not ask before it continues.
Turn off *Skip Upgrade Confirmation* under **Settings** if you want to see what it is about to upgrade, including dependents, and confirm it yourself.

Only one Homebrew command runs at a time.
If an update is already running, for example your own `brew upgrade`, BrewBar waits for the next check instead of reporting an error.

### Commands

| Command | Action |
|---------|--------|
| `brew services start brew-bar` | Start now and at every login |
| `brew services run brew-bar` | Start now only |
| `brew services restart brew-bar` | Restart, e.g. after `brew upgrade` |
| `brew services stop brew-bar` | Stop and disable start at login |
| `brew uninstall brew-bar` | Uninstall |

Logs are written to `$(brew --prefix)/var/log/brew-bar.log`.

### Uninstall

```bash
brew services stop brew-bar
brew uninstall brew-bar
```

BrewBar keeps its two settings in the user defaults.
Remove them with `defaults delete BrewBar`.

## Requirements

- macOS 14 or later, arm64 (Apple Silicon)
- Homebrew in `/opt/homebrew`
- Terminal.app, which BrewBar opens for upgrades

## How It Works

1. Every 15 minutes it runs `brew update` to fetch the latest package definitions
2. Every minute it runs `brew outdated --json=v2` and the same with `--greedy`. Packages that only show up with `--greedy` update themselves
3. Shows the number of outdated packages in the menu bar
4. **Refresh** and waking from sleep run both, one after the other

## Development

```bash
swift run
swift test
swift build -c release
```

Release a new version with `./create-release.sh <version>`.

## License

MIT — see [LICENSE](LICENSE).

## Author

- Tom Hüttmann — [@tomhuettmann](https://github.com/tomhuettmann)
