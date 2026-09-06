# Mac environment

Chezmoi owns configuration and `~/.Brewfile`. Homebrew owns package installation.
This shared setup targets Apple Silicon Macs and current available package versions.
Rift Native is the deliberate exception: its private formula fixes a source revision
and contains the native patches. The Brewfile is not a version lockfile.

## New Mac

1. Install Apple's Command Line Tools (`xcode-select --install`) and Homebrew using
   https://brew.sh. Complete any interactive installation steps.
2. Initialize Homebrew and install the bootstrap tools:

   ```sh
   eval "$(/opt/homebrew/bin/brew shellenv)"
   brew install chezmoi gh
   gh auth login --hostname github.com --git-protocol https
   gh auth setup-git
   ```

   Authenticate as an account with access to the dotfiles and private tap.
3. Run `chezmoi init --apply https://github.com/YifanJiang233/dotfiles.git`. Keep this terminal open
   until packages are installed; the restored shell configuration uses those tools.
4. Install the package selection explicitly:

   ```sh
   brew bundle install --file="$HOME/.Brewfile" --no-upgrade
   brew bundle check --file="$HOME/.Brewfile" --no-upgrade
   ```

5. Sign into applications and grant the required macOS permissions. Start only the
   services you want, for example `brew services start borders`, `sketchybar`, `mpd`,
   or `transmission-cli` (run each as a separate command with the same prefix).
   For Rift, follow `~/.config/rift/PATCHING.md`: use its built-in `rift service`
   workflow and authorize the linked binary. Do not also start a Homebrew Rift agent.

This does not restore accounts, secrets, application data, project environments,
Mac App Store purchases, or software installed outside Homebrew. GUI installers
may require interaction. Review `.config/rift/PATCHING.md` before changing Rift.

## Daily maintenance

```sh
chezmoi edit ~/.Brewfile
chezmoi apply ~/.Brewfile
brew bundle install --file="$HOME/.Brewfile" --no-upgrade
```

Add tools you intend to keep, grouped by purpose and alphabetized within each
section. Do not list transitive libraries unless your configuration uses them
directly. Python and nowplaying-cli are explicit dependencies of desktop scripts.
Commit the source changes with `chezmoi git -- add dot_Brewfile`, then
`chezmoi git -- commit -m "Update Mac packages"` and `chezmoi git -- push`.

Upgrades are deliberate: use `brew upgrade <package>` for selected tools, or
`brew bundle upgrade --file="$HOME/.Brewfile"` for the full list. `--no-upgrade`
skips routine upgrades, but does not freeze dependencies or package versions.

Removing a line does not uninstall the package. Review and uninstall selected
packages explicitly with `brew uninstall <package>`. Do not run blanket bundle
cleanup: this shared list intentionally excludes optional local applications.

## Audit installed software

```sh
snapshot_dir="$(mktemp -d)"
brew bundle dump --file="$snapshot_dir/Brewfile"
diff -u "$HOME/.Brewfile" "$snapshot_dir/Brewfile"
```

The diff is a review aid and includes formatting and package-type differences.
Promote useful additions manually; never dump with `--force` over the curated file.
The initial shared list excludes Steam, Heroic, HHKB, balenaEtcher, Antigravity,
Glide Browser, Qutebrowser, and the official Rift formula. Existing installations
are left alone. Other current requested tools and selected casks form the baseline.

## Maintaining the private Rift tap

The authoritative formula lives at https://github.com/YifanJiang233/homebrew-rift.
The registered tap remains `yifan/rift` with an explicit HTTPS Git URL. Chezmoi
must not track a second copy of its formula or the tap's Git metadata.

For development, clone the private repository to `~/.config/rift/homebrew-tap`
(the location used by the patch runbook). Update, validate, commit and push the
formula there. Then update the registered tap clone before rebuilding. Authentication
uses Git credentials configured by `gh auth setup-git`, not a token in the Brewfile.

References: https://docs.brew.sh/Brew-Bundle-and-Brewfile and https://www.chezmoi.io.
