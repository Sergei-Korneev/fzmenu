# fzmenu

A tiny, dependency-light **command menu**: describe commands in a plain text
config, then pick and run them with arrow keys (and fuzzy search) powered by
[`fzf`](https://github.com/junegunn/fzf).

```
 cmdmenu :: Disks  |  ctrl-r reload  ctrl-o edit
> ▸ Show disks
    Date and time
    Free memory
    ↩ back
────────────────────────────────────────────
$ lsblk -f
```

## Features

- **Arrow-key + fuzzy selection** — type to filter a long menu.
- **Nested submenus** — indentation in the config = nesting.
- **Any shell command** — a menu leaf is just a shell line (pipes, redirects,
  `&&`, functions, … all work).
- **Preview panel** — shows the full command before you run it.
- **Reload / edit on the fly** — `Ctrl-R` re-reads the config, `Ctrl-O` opens it
  in `$EDITOR`.
- **Run history** — every executed command is appended to `fzmenu.history`
  next to the config.
- **No dependencies beyond `fzf`** — plain `bash`.

## Requirements

- `bash` 4+ (associative arrays)
- [`fzf`](https://github.com/junegunn/fzf)

## Files

| File                 | Purpose                                             |
| -------------------- | --------------------------------------------------- |
| `cmdmenu.sh`         | The engine. Reads a config and runs a menu.         |
| `run.sh`             | Launcher: runs the engine with `menu.conf` here.    |
| `menu.conf`          | Your working config (edit this).                    |
| `menu.conf.example`  | A small annotated example config.                   |

## Quick start

```sh
cd /path/to/fzmenu
./run.sh
```

Run the engine directly:

```sh
./cmdmenu.sh -c menu.conf                 # use a specific config
./cmdmenu.sh -c menu.conf -s ~/myfuncs.sh # source a setup file first
./cmdmenu.sh -c menu.conf -d              # print the parsed tree and exit
```

### Options

| Option | Meaning                                                            |
| ------ | ------------------------------------------------------------------ |
| `-c`   | Config file (default `~/.config/cmdmenu/menu.conf`).               |
| `-s`   | Script sourced once before any command runs (e.g. your functions). |
| `-d`   | Dump the parsed tree and exit (debug).                             |
| `-h`   | Help.                                                              |

## Config format

Plain text, one item per line. Blank lines and lines starting with `#` are
ignored. **Indentation defines nesting** — use 4 spaces or 1 tab per level.

```
Menu name
    Item name => shell command
    Another submenu
        Deeper item => echo hi
```

- A line **with** `=>` is a **leaf**: the text after `=>` is the shell command.
- A line **without** `=>` is a **submenu**.
- The command is stored verbatim and run with `eval`, so quoting, pipes and
  shell operators work as-is.

### Examples

Show the date and time, and inspect disks:

```
Date and time       => date
Disk usage (df)     => df -h
List block devices  => lsblk -f
```

Group related commands into submenus:

```
System
    Date and time   => date
    Who am I        => id
    Uptime          => uptime
    Free memory     => free -h

Disks
    List devices    => lsblk -f
    Usage            => df -h
    Mounted (crypt) => lsblk | grep crypt
```

Pipes, redirection and multiple commands are fine:

```
Top 10 processes by memory  => ps aux --sort=-%mem | head
Largest files in $HOME      => du -ah ~ | sort -rh | head
Reload shell config         => source ~/.bashrc && echo reloaded
Copy logs to /tmp           => cp -v /var/log/syslog /tmp/ && echo done
```

Iterate over the whole submenu with the arrow keys; type to filter. Pressing
`Enter` on a leaf runs it, on a submenu it opens that submenu.

## Keys

| Key      | Action                                   |
| -------- | ---------------------------------------- |
| arrows   | move the highlight                       |
| type     | fuzzy-filter the list                    |
| `Enter`  | run the command / enter the submenu      |
| `Ctrl-R` | reload the config                        |
| `Ctrl-O` | open the config in `$EDITOR`             |
| `Esc`    | quit                                     |

After a command finishes, the menu shows its output and exit code and waits for
a key press.

## Using your own shell functions

Commands are run in the same shell as the menu. If you have functions defined in
a file and want them available to your menu items, pass that file with `-s`:

```sh
./cmdmenu.sh -c menu.conf -s ~/myfuncs.sh
```

Then a menu item can simply call the function:

```
Backup home    => backup_home
Cleanup caches => cleanup_caches
```

## Install (optional)

To use it from anywhere:

```sh
mkdir -p ~/.local/bin ~/.config/cmdmenu
cp cmdmenu.sh ~/.local/bin/fzmenu
cp menu.conf  ~/.config/cmdmenu/menu.conf
```

Then add an alias under `~/.bashrc.d/`:

```sh
alias m='fzmenu -c ~/.config/cmdmenu/menu.conf'
# or, if your menu items use your own functions:
alias m='fzmenu -c ~/.config/cmdmenu/menu.conf -s ~/myfuncs.sh'
```

## Notes

- `cmdmenu.sh -d` is handy for sanity-checking a config without opening the UI.
- The history file is written best-effort and ignored on failure.
