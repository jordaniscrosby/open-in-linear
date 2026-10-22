# Open in Linear

Someone pastes `ENG-1234` in a chat. You copy it, switch to Linear, hit ⌘K, paste, wait, click. Five steps for one ticket.

Now it's one: **highlight the text and press ⌃⌥⌘L.** It works anywhere on your Mac.

- If you highlighted a ticket ID, it goes straight to that issue in the Linear app.
- Anything else becomes a Linear search (archived issues included, because the ticket you need is always the archived one).

| You highlight | You get |
|---|---|
| `ENG-1234`, ` eng-42 ` | issue ENG-1234 / ENG-42 |
| `you/eng-1234-fix-the-thing` (a branch name) | issue ENG-1234 |
| `https://linear.app/acme/issue/PRI-99/some-title` | issue PRI-99 |
| `checkout button broken again` | a search for "checkout button broken again" |

No app to install, nothing running in the background, no API keys. It's a plain macOS Service and a ~40-line shell script.

## Install

```bash
git clone https://github.com/jordaniscrosby/open-in-linear.git
cd open-in-linear
./install.sh
```

Setup asks two things:

1. **Your Linear workspace:** the part after `linear.app/` in your URLs (`acme` in `https://linear.app/acme/...`). Pasting any Linear URL works too.
2. **Your shortcut:** keep the default ⌃⌥⌘L, or pick **Custom** and press the combo you want in the little window that pops up.

Run `./install.sh` again any time to change either one. It remembers your current settings.

To skip the questions:

```bash
./install.sh --workspace acme                          # default shortcut
./install.sh --workspace acme --shortcut ctrl+shift+k  # your own
```

Apps that were already open may need a restart before the shortcut works in them.

## Uninstall

```bash
./uninstall.sh
```

## How it works

`install.sh` puts a Quick Action at `~/Library/Services/Open in Linear.workflow` with your workspace baked in, then binds your shortcut to it. When you press the shortcut, macOS hands it the highlighted text, and [`open-in-linear.sh`](open-in-linear.sh) decides between an issue and a search:

- Issue: `https://linear.app/<workspace>/issue/<ID>`
- Search: `https://linear.app/<workspace>/search?q=<text>&includeArchived=true`

The link opens in the Linear desktop app, or in your browser if you don't have the app.

[`record-shortcut.js`](record-shortcut.js) is the "press your shortcut" window. Terminals can't see the ⌘ key, so it records the keys in a tiny native window instead (JavaScript for Automation, built into macOS).

You can try the logic without opening anything:

```bash
echo "eng-123" | DRY_RUN=1 ./open-in-linear.sh
```

## Notes

- **Shortcut does nothing in some app?** That app probably uses the same combo itself, and the app wins. Pick another one with `./install.sh`.
- **Electron apps** (Slack, VS Code, Linear itself) sometimes don't pass the selection to macOS Services. If the shortcut does nothing there, that's why.
- **False matches:** a single word shaped like a ticket ID, such as `UTF-8`, gets treated as one. Text with a space in it always searches.

Not affiliated with Linear. Just a fan of fewer clicks.

## License

[MIT](LICENSE)
