(*
Trello → Things 3 GTD Importer
Version: 1.0.0
Author: Daniel Schnitterbaum
License: MIT

One-way importer for Trello board JSON exports into Things 3.
Designed for GTD-style workflows. No sync. No magic.
*)

(*
==================================================
USER CONFIGURATION
Edit this section only.
==================================================
*)

property MAP_LISTS : {¬
	{trello:"Inbox", things:"INBOX"}, ¬
	{trello:"Next Actions", things:"AREA:Next Actions"}, ¬
	{trello:"Waiting for", things:"AREA:Waiting for"}, ¬
	{trello:"Calendar", things:"AREA:Calendar"}, ¬
	{trello:"Projects", things:"PROJECTS"}, ¬
	{trello:"Someday/Maybe", things:"SOMEDAY"}, ¬
	{trello:"Done", things:"LOGBOOK"}, ¬
	{trello:"Reference material", things:"IGNORE"}, ¬
	{trello:"Agendas", things:"IGNORE"} ¬
}

property CREATE_MISSING_AREAS : true
property DEFAULT_PROJECT_FALLBACK_TASK : "Define next actions"

(*
==================================================
MAIN
==================================================
*)

on run
	set jsonFile to choose file with prompt "Select your Trello board export (JSON)."
	set jsonPath to POSIX path of jsonFile
	
	set tsvText to trelloJSONToTSV(jsonPath)
	
	with timeout of 1800 seconds -- allow long imports
		importTSV(tsvText)
	end timeout
	
	display dialog "Import finished. Check Things Areas, Projects, Inbox, and Logbook." buttons {"OK"} default button "OK"
end run

(*
==================================================
JSON → TSV (Python, safe)
==================================================
*)

on trelloJSONToTSV(jsonPath)
	set py to "
import json, sys
from pathlib import Path

p = Path(sys.argv[1])
data = json.loads(p.read_text(encoding='utf-8'))

lists = {l.get('id'): (l.get('name') or '') for l in data.get('lists', [])}

checklists = {}
for cl in data.get('checklists', []):
    cid = cl.get('idCard')
    if not cid:
        continue
    items = []
    for it in cl.get('checkItems', []):
        items.append((it.get('name') or '', it.get('state') or ''))
    checklists.setdefault(cid, []).extend(items)

def safe(x):
    if x is None:
        return ''
    if not isinstance(x, str):
        x = str(x)
    return x.replace('\\r','').replace('\\n','\\\\n').replace('\\t',' ')

rows = []
for c in data.get('cards', []):
    if c.get('closed'):
        continue

    list_name = lists.get(c.get('idList'), '') or ''
    title = c.get('name') or ''
    desc = c.get('desc') or ''
    url = c.get('url') or ''
    due = c.get('due') or ''

    tags = [lb.get('name') for lb in (c.get('labels') or []) if lb.get('name')]
    tags_csv = ','.join(tags)

    notes = ''
    if desc.strip():
        notes += desc.strip() + '\\n\\n'
    if url:
        notes += 'Trello: ' + url + '\\n'
    if due:
        notes += 'Due (Trello): ' + safe(due) + '\\n'

    kind = 'todo'
    checklist_csv = ''

    if list_name == 'Projects':
        kind = 'project'
        enc = []
        for nm, st in checklists.get(c.get('id'), []):
            enc.append(safe(nm) + '|' + safe(st))
        checklist_csv = ';;'.join(enc)

    rows.append('\\t'.join([
        safe(list_name),
        safe(kind),
        safe(title),
        safe(notes),
        safe(tags_csv),
        safe(checklist_csv),
    ]))

sys.stdout.write('\\n'.join(rows))
"
	
	set cmd to "/usr/bin/python3 - " & quoted form of jsonPath & " <<'PY'\n" & py & "\nPY"
	return do shell script cmd
end trelloJSONToTSV

(*
==================================================
TSV → Things
==================================================
*)

on importTSV(tsvText)
	set linesList to paragraphs of tsvText
	
	tell application "Things3"
		activate
	end tell
	
	set projectCacheKeys to {}
	set projectCacheRefs to {}
	
	repeat with L in linesList
		if L is "" then
			-- skip
		else
			set row to splitBy(L, tab)
			if (count of row) < 6 then
				-- skip malformed
			else
				set trelloList to item 1 of row
				set kind to item 2 of row
				set titleText to item 3 of row
				set notesText to item 4 of row
				set tagsCSV to item 5 of row
				set checklistEnc to item 6 of row
				
				set target to resolveTarget(trelloList)
				if target is "IGNORE" then
					-- noop
				else
					set tagList to splitBy(tagsCSV, ",")
					dispatchToThings(target, kind, titleText, notesText, tagList, checklistEnc, projectCacheKeys, projectCacheRefs)
				end if
			end if
		end if
	end repeat
end importTSV

(*
==================================================
Target resolution & dispatch
==================================================
*)

on resolveTarget(trelloListName)
	repeat with m in MAP_LISTS
		if trelloListName is (trello of m) then return things of m
	end repeat
	return "AREA:" & trelloListName
end resolveTarget

on dispatchToThings(target, kind, titleText, notesText, tagList, checklistEnc, projKeys, projRefs)
	if target is "INBOX" then
		createTodo({container:"INBOX", title:titleText, notes:notesText, tags:tagList})
	else if target is "PROJECTS" and kind is "project" then
		createProject(titleText, notesText, tagList, checklistEnc, projKeys, projRefs)
	else if target is "SOMEDAY" then
		createTodo({container:"SOMEDAY", title:titleText, notes:notesText, tags:tagList})
	else if target is "LOGBOOK" then
		createCompletedTodo(titleText, notesText, tagList)
	else if target starts with "AREA:" then
		set areaName to text 6 thru -1 of target
		createTodo({container:"AREA", area:areaName, title:titleText, notes:notesText, tags:tagList})
	end if
end dispatchToThings

(*
==================================================
Things helpers
==================================================
*)

on createTodo(opts)
	tell application "Things3"
		if (container of opts) is "INBOX" then
			set t to make new to do with properties {name:title of opts, notes:notes of opts}
		else if (container of opts) is "SOMEDAY" then
			set t to make new to do with properties {name:title of opts, notes:notes of opts, status:someday}
		else
			set a to getOrCreateArea(area of opts)
			set t to make new to do with properties {name:title of opts, notes:notes of opts, area:a}
		end if
	end tell
	applyTags(t, tags of opts)
end createTodo

on createCompletedTodo(titleText, notesText, tagList)
	tell application "Things3"
		set t to make new to do with properties {name:titleText, notes:notesText}
		set status of t to completed
	end tell
	applyTags(t, tagList)
end createCompletedTodo

on createProject(pName, notesText, tagList, checklistEnc, projKeys, projRefs)
	set idx to indexOf(projKeys, pName)
	if idx ≠ 0 then return
	
	tell application "Things3"
		set areaRef to getOrCreateArea("Projects")
		set p to make new project with properties {name:pName, notes:notesText, area:areaRef}
	end tell
	
	applyTags(p, tagList)
	
	set end of projKeys to pName
	set end of projRefs to p
	
	if checklistEnc ≠ "" then
		repeat with enc in splitBy(checklistEnc, ";;")
			if enc ≠ "" then
				set parts to splitBy(enc, "|")
				set itName to item 1 of parts
				tell application "Things3"
					set td to make new to do with properties {name:itName, project:p}
					if (count of parts) ≥ 2 and (item 2 of parts) is "complete" then
						set status of td to completed
					end if
				end tell
			end if
		end repeat
	else
		tell application "Things3"
			make new to do with properties {name:DEFAULT_PROJECT_FALLBACK_TASK, project:p}
		end tell
	end if
end createProject

on getOrCreateArea(aName)
	tell application "Things3"
		try
			return area aName
		on error
			if CREATE_MISSING_AREAS then
				return make new area with properties {name:aName}
			else
				error "Missing area: " & aName
			end if
		end try
	end tell
end getOrCreateArea

on applyTags(objRef, tagList)
	if tagList is {} then return
	tell application "Things3"
		repeat with t in tagList
			if t ≠ "" then
				try
					set tag t to tag t
				on error
					make new tag with properties {name:t}
				end try
				try
					set tag names of objRef to (tag names of objRef) & {t}
				end try
			end if
		end repeat
	end tell
end applyTags

(*
==================================================
Utility
==================================================
*)

on splitBy(t, delim)
	set AppleScript's text item delimiters to delim
	set parts to text items of t
	set AppleScript's text item delimiters to ""
	return parts
end splitBy

on indexOf(theList, theItem)
	repeat with i from 1 to count of theList
		if item i of theList is theItem then return i
	end repeat
	return 0
end indexOf
