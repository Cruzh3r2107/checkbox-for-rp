# Adding a new board

This document describes what to submit when you test a new board and want to add
it to this repo - the folder layout, file naming convention, and what each file
should contain.

---

## Folder layout

Each board gets its own top-level folder. Inside it, each OS gets its own
subfolder. The layout is:

```
<board-slug>/
├── README.md                          # one-line index: board name, OS folders, board-level quirks
└── <os-slug>/
    ├── <board>-<os>-env-setup.yaml    # Envicorn provisioning YAML for this board + OS
    ├── launcher-<board>-<os>          # Checkbox launcher for this board + OS
    ├── run-<board>.sh                 # helper script (provision / test / collect)
    ├── .local.env.example             # template for secrets (IP, user, password, WiFi)
    ├── README.md                      # run notes, board facts, known quirks
    └── reports/
        ├── RESULT.md                  # pass/fail summary and triage notes
        └── <board>-<os>-run-<date>.<ext>   # submission artifact from the run
```

Only one OS per subfolder. If you tested both Core and Server, add both
subfolders (`core24/` and `server24.04/`).

---

## Naming conventions

| Thing | Convention | Examples |
|-------|-----------|---------|
| Board folder | lowercase, hyphens, no version numbers | `raspberry-pi-4`, `xilinx-kria`, `rubik-pi-3` |
| OS folder | `core<UbuntuCoreVersion>` or `server<UbuntuServerVersion>` | `core24`, `server24.04` |
| Env-setup YAML | `<board-short>-<os>-env-setup.yaml` | `rubikpi3-core24-env-setup.yaml` |
| Launcher | `launcher-<board-short>-<os>` | `launcher-rubikpi3-core24` |
| Helper script | `run-<board-short>.sh` | `run-rubikpi3.sh` |
| Run log / junit | `<board-short>-<os>-run-<YYYY-MM-DD>.<ext>` | `rubikpi3-core24-run-2026-07-01.log` |

Keep names short but unambiguous. Hyphens between words, no underscores in
folder names.

---

## What each file must contain

### README.md (index)

One short paragraph: what the board is, which OS subfolders exist, and any
board-level quirk worth knowing before diving in.

- Board facts table: watchdog module, WiFi/BT present, RTC count, any other
  manifest items that differ from a generic board.
- How the run went: date, pass / fail / cannot_start counts.
- Known issues and workarounds specific to this board + OS combination.

### env-setup.yaml

Start from [`template/core-env-setup.yaml`](../template/core-env-setup.yaml)
or [`template/server-env-setup.yaml`](../template/server-env-setup.yaml) and
change the `CHANGE-ME` lines for your board (watchdog module, machine manifest).

### launcher

Start from [`template/core-launcher`](../template/core-launcher) or
[`template/server-launcher`](../template/server-launcher). Fill in `WPA_*`
fields if the board has WiFi, set `TOTAL_RTC_NUM` to the number of RTC devices.

### run-<board>.sh

Copy the helper script from an existing board folder and update the variable
names at the top (`BOARD_IP`, launcher path, env-setup path) to match your
`.local.env` and filenames.

### .local.env.example

Copy from [`template/.local.env.example`](../template/.local.env.example).
The variable names stay the same. This file is committed; the real `.local.env`
(with actual IP and passwords) is gitignored.

### /report/RESULT.md

Summarise the run in three sections:

1. **Counts** - pass / fail / cannot_start total.
2. **Expected non-starts** - hardware the board does not have (WiFi, BT, RTC),
   correctly gated by the manifest.
3. **Failures triage** - structural (boot method, hardware constraint),
   environmental (no AP, no ping target), or real (worth investigating).

### /reports/<run-artifact>

Commit the lightweight artifact only (the `.junit.xml` or a `.log` file). Do
not commit the full `.tar.xz`, `.html`, or `.json` - those are gitignored.

---

## Example: Rubik Pi 3 being added

Suppose someone ran Checkbox on a Rubik Pi 3 on both Ubuntu Core 24 and Ubuntu
Server 24.04. This is what the submission looks like:

```
rubik-pi-3/
├── README.md
├── core24/
│   ├── rubikpi3-core24-env-setup.yaml
│   ├── launcher-rubikpi3-core24
│   ├── run-rubikpi3.sh
│   ├── .local.env.example
│   ├── README.md
│   └── reports/
│       ├── RESULT.md
│       └── rubikpi3-core24-run-2026-07-01.junit.xml
└── server24.04/
    ├── rubikpi3-server2404-env-setup.yaml
    ├── launcher-rubikpi3-server2404
    ├── run-rubikpi3.sh
    ├── .local.env.example
    ├── README.md
    └── reports/
        ├── RESULT.md
        └── rubikpi3-server2404-run-2026-07-01.junit.xml
```

If only one OS was tested, submit only that subfolder.
