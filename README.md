# GitHub Issues for KDE Plasma 6

A Plasma widget that shows the open issues from your GitHub repositories on the desktop
or in a panel, so you can check them without opening a browser tab.

## Features

- Filters: all, assigned to me, created by me, mentioned, in my repos
- Local search by title, repo, label, author or number (several terms must all match)
- Two layouts: grouped by repository (collapsible, with counts and indented issues) or a
  single list sorted by recent activity with the repo shown on each row
- Highlights issues that are new or updated since you last looked
- Native desktop notification when a new issue arrives
- Click to open in the browser; right-click to open, copy the link or mark as seen
- Panel icon with a counter that changes color when something is new
- Label colors from GitHub, with automatic text contrast

## Requirements

- KDE Plasma 6
- [GitHub CLI](https://cli.github.com) (`gh`), logged in with `gh auth login`

The widget reads its token at runtime with `gh auth token`, or from the `GH_TOKEN`
environment variable, which takes priority. The token is never written to disk or logged.

## Installation

Run the installer. It downloads the latest release and installs it for your user, so
it needs no root:

```bash
curl -fsSL https://raw.githubusercontent.com/egionCode/plasma-github-issues/master/install.sh | bash
```

If you would rather read it first, it is a short script:
[install.sh](install.sh).

Then right-click the desktop or a panel, choose "Add Widgets" and look for
"GitHub Issues". If it does not show up, restart the shell with
`kquitapp6 plasmashell && kstart plasmashell`.

Installer options:

```bash
./install.sh                    # install or update to the latest release
./install.sh --version v0.1.0   # install a specific release
./install.sh --local            # install from this checkout instead of downloading
./install.sh --uninstall        # remove the widget
```

Running `install.sh` again updates an existing install.

### Manual install

Download the `.plasmoid` file from
[Releases](https://github.com/egionCode/plasma-github-issues/releases) and run:

```bash
kpackagetool6 -t Plasma/Applet -i github-issues-X.Y.Z.plasmoid   # first time
kpackagetool6 -t Plasma/Applet -u github-issues-X.Y.Z.plasmoid   # update
```

## Development

```bash
git clone https://github.com/egionCode/plasma-github-issues
cd plasma-github-issues
npm test                                                           # run the tests
plasmoidviewer -a ./com.egion.githubissues -f planar -s 560x900    # try it in a window
GH_TOKEN=invalid plasmoidviewer -a ./com.egion.githubissues        # see the error state
```

`plasmoidviewer` ships in the `plasma-sdk` package. Set `QT_FORCE_STDERR_LOGGING=1` to
see QML `console.log` output.

### Layout

```
install.sh                  # installer
com.egion.githubissues/
  metadata.json
  contents/
    code/github.mjs         # pure logic: URLs, normalizing, grouping, search, diffing, paging
    code/http.mjs           # XMLHttpRequest adapter that returns a Promise
    config/                 # main.xml (settings) and config.qml
    ui/                     # main.qml, full and compact views, delegates
tests/                      # Node tests plus a smoke test in the real QML engine (qml6)
```

### Design notes

- The code never uses `async/await`. The QML JavaScript engine can't parse it, and one
  `async` keyword is enough to make the whole module fail to load. Promises are chained
  instead. Node accepts the syntax without complaint, so `tests/qml-smoke.test.mjs` loads
  the modules in `qml6` to catch it. `Object.fromEntries` is missing from that engine too.
- Notifications never go through a shell. Issue titles can come from strangers (anyone can
  open an issue on a public repo), so the widget uses `org.kde.notification` and never
  builds a command out of them.
- The default filter is "All". "Assigned" shows almost nothing if you mostly work alone.
- The "new" highlight and the notification use different baselines. The highlight compares
  with what you have already seen, stored in the widget config. The notification compares
  with the previous refresh, kept in memory, so an issue alerts you at most once.

## Known limitations

- It uses `GET /issues`, so it only sees repos the token can access.
- Each refresh reads up to 5 pages of 100 issues.
- With organizations, the "All" filter includes subscribed items and can get noisy.
- The widget interface is currently in Portuguese (pt-BR). Strings go through KDE's
  `i18n()`, so translations are possible.

## License

[MIT](LICENSE)
