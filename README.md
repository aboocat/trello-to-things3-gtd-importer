# Trello → Things 3 GTD Importer

One-way importer that converts Trello board exports (JSON) into **Things 3** using a **GTD-friendly structure**.

Designed for Apple-only users who want to move from Trello to Things without subscriptions, sync complexity, or data loss.

---

## What this does

- Imports Trello JSON exports into Things 3
- Maps Trello lists to:
  - Inbox
  - Areas
  - Projects
  - Someday
  - Logbook
- Converts Trello checklist items into project to-dos
- Preserves Trello labels as Things tags
- Ignores reference / agenda lists by design
- One-way, non-destructive import

---

## What this does NOT do

- No syncing (by design)
- No two-way updates
- No comments or activity history
- No automatic GTD interpretation

This script makes **Things 3 the single source of truth**.

---

## Requirements

- macOS
- Things 3
- Trello board export (JSON)
- Script Editor (built into macOS)

---

## Usage

1. Export your Trello board as JSON
2. Open `trello_to_things3_import.applescript` in Script Editor
3. Adjust the **USER CONFIGURATION** section if needed
4. Run the script
5. Select your Trello JSON file when prompted

Large boards may take several minutes to import.

---

## Configuration

Mapping Trello lists to Things is controlled via:

```applescript
property MAP_LISTS : {
    {trello:"Inbox", things:"INBOX"},
    {trello:"Projects", things:"PROJECTS"},
    {trello:"Done", things:"LOGBOOK"}
}

### Supported targets
INBOX
AREA:
PROJECTS
SOMEDAY
LOGBOOK
IGNORE

### Known limitations

- Completed tasks are imported into the Logbook
- Due dates are not imported by default
- Import speed depends on Things’ AppleScript performance

> Always test on a copy of your Trello board.
