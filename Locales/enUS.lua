local L = LibStub("AceLocale-3.0"):NewLocale("ReadyCheckReminder", "enUS", true)
if not L then return end

-- Core.lua
L["Area IDs named \"%s\": %s"] = true
L["No area ID in %d-%d is named \"%s\"."] = true
L["Ready Check Reminder"] = true
L["Select a boss first."] = true
L["Nothing to show for %s with the current notes."] = true
L["Instance ID: %s"] = true
L["Zone: %s"] = true
L["Subzone: %s"] = true
L["(none)"] = true
L["Matched boss: %s"] = true
L["Scanning area IDs %d-%d..."] = true
L["/rcr - open the settings"] = true
L["Click to open the settings."] = true
L["This reminder has no text to show."] = true
L["No loaded reminders to show."] = true
L["/rcr reset - move the settings window back to the middle of the screen"] = true

-- Database.lua
L["Encounter %d"] = true
L["Instance %d"] = true
L["Season %d"] = true
L["Expansion %d"] = true

-- Display.lua
L["No text for line %d (%s)"] = true
L["Text anchor"] = true

-- ImportExport.lua
L["Boss: %s\nReminders: %d\n%s\n\nThis boss currently has %d reminder(s)."] = true
L["The import string is empty."] = true
L["This is not a Ready Check Reminder string."] = true
L["The import string is damaged."] = true
L["This string was made by an unsupported version."] = true
L["The boss in this string is not in the boss database."] = true
L["A reminder in this string is invalid."] = true
L["...and %d more"] = true
L["(unnamed)"] = true
L["Display and minimap settings"] = true
L["- %s: %d reminder(s)"] = true
L["No reminders."] = true
L["%d boss(es) not in the boss database were skipped."] = true
L["This string was made by an old version (%s) and can no longer be imported."] = true
L["This string needs Ready Check Reminder %s or newer. You have %s."] = true
L["Made with a newer version (%s); you have %s."] = true
L["None of the bosses in this string are in the boss database."] = true
L["Several bosses"] = true
L["Section: %s"] = true
L["%d of these bosses already have reminders."] = true

-- Options/Options.lua
L["Please confirm"] = true
L["Export"] = true
L["Close"] = true
L["Import"] = true
L["Replace all"] = true
L["Replace existing"] = true
L["Add as new"] = true
L["Cancel"] = true
L["Some of this already exists. Replace it or add the import as new reminders?"] = true
L["All"] = true
L["Copy this string (Ctrl+C) and share it."] = true
L["This boss has no reminders to export."] = true
L["Export reminders"] = true
L["Choose the reminders of %s to export."] = true
L["Paste a reminder string (Ctrl+V)."] = true
L["This is a profile string. Import it in the Profiles tab."] = true
L["Export profile"] = true
L["Display and minimap settings are always included. Choose the bosses whose reminders to include."] = true
L["Import profile"] = true
L["Paste a profile string (Ctrl+V)."] = true
L["This is a reminder string. Import it in the Reminders tab."] = true
L["Enter a profile name."] = true
L["The profile \"%s\" already exists. Overwrite it?"] = true
L["Overwrite"] = true
L["Import into a new profile, or into the current profile \"%s\" (its settings and the reminders of the bosses above are replaced)."] =
  true
L["There is nobody else online in your group."] = true
L["Send to"] = true
L["Choose the players. Everyone online in your group is selected."] = true
L["New profile name"] = true
L["Imported"] = true
L["Create profile"] = true
L["Into current"] = true
L["Overwrite the settings of \"%s\"?"] = true
L["Send to group"] = true
L["Refresh"] = true

-- Options/DisplayTab.lua
L["None"] = true
L["Outline"] = true
L["Thick outline"] = true
L["Left"] = true
L["Center"] = true
L["Right"] = true
L["Anchor"] = true
L["Unlock anchor"] = true
L["Reset position"] = true
L["Text"] = true
L["Font"] = true
L["Font size"] = true
L["Text alignment"] = true
L["Line spacing"] = true
L["Behaviour"] = true
L["Display duration (seconds)"] = true
L["Show minimap button"] = true
L["Test"] = true
L["Display"] = true
L["Down"] = true
L["Up"] = true
L["All bosses"] = true
L["X"] = true
L["Y"] = true
L["Offsets of the anchor's center from the screen center."] = true
L["Text growth"] = true
L["Shows every loaded reminder with a test note that puts you on each of its lines. Zone and difficulty are ignored."] = true

-- Options/RemindersTab.lua
L["No reminders yet. Click \"New\" to create one."] = true
L["Delete the reminder \"%s\"?"] = true
L["Keyword line"] = true
L["Keyword group"] = true
L["Group-based"] = true
L["Select a boss on the left."] = true
L["%s (copy)"] = true
L["Delete"] = true
L["New"] = true
L["Drag to reorder. This is the display order."] = true
L["Reminders"] = true
L["Right-click to send or export"] = true
L["There are no reminders in this section."] = true

-- Options/Editor.lua
L["Name"] = true
L["Enabled"] = true
L["Duplicate"] = true
L["Matching"] = true
L["Keyword (a line starts with it, optionally followed by a number: soak, soak1, soak2...)"] = true
L["Start keyword"] = true
L["End keyword"] = true
L["Texts"] = true
L["One text per line"] = true
L["Add line"] = true
L["Remove last line"] = true
L["Raid groups"] = true
L["Select the groups for each text. Groups without a text show nothing."] = true
L["Add mapping"] = true
L["Load conditions"] = true
L["Nothing selected means any."] = true
L["LFR"] = true
L["Normal"] = true
L["Heroic"] = true
L["Mythic"] = true
L["Tank"] = true
L["Healer"] = true
L["Damage"] = true
L["Melee"] = true
L["Ranged"] = true
L["Class"] = true
L["Specialization"] = true
L["Preview"] = true
L["Your result with the current notes and group (load conditions are ignored)."] = true
L["Text for lines without a number"] = true
L["Text for all lines"] = true
L["Line %d"] = true
L["Reminder text"] = true
L["Some text replacements are supported, for example:"] = true
L["NPC name"] = true
L["line number"] = true
L["your position in the line"] = true
L["Raid marker names work in every client language."] = true
L["{line} and {pos} only work in keyword reminders; here they are shown as written."] = true
L["Nothing to show for you with the current note."] = true
L["Select or create a reminder."] = true
L["Instance Difficulty"] = true
L["Spec Role"] = true
L["Spec Position"] = true
L["%s (%d selected)"] = true
L["Select a class to choose its specializations."] = true
L["Send"] = true
L["Note: the keyword ends with a space, the note needs that space too."] = true

-- Options/ProfilesTab.lua
L["Overwrite the current profile with \"%s\"?"] = true
L["Delete the profile \"%s\"?"] = true
L["Current profile"] = true
L["New profile"] = true
L["Create"] = true
L["Copy from"] = true
L["Copies the settings and reminders of another profile into the current one."] = true
L["Copy"] = true
L["Delete a profile"] = true
L["Reset"] = true
L["Reset current profile"] = true
L["Reset the current profile to defaults? Its reminders will be deleted."] = true
L["Profiles"] = true
L["Share"] = true
L["Export the current profile's settings and the reminders of the bosses you choose, or import such a string."] = true
L["Select a profile"] = true

-- Options/SharingTab.lua
L["Only trusted"] = true
L["Receive reminder updates only from the raid leader or raid officers."] = true
L["Only guild"] = true
L["Receive reminder updates only from guild members."] = true
L["Overwrite by default"] = true
L["Automatically overwrite reminders when received from other players. When off, you are asked first."] = true
L["Receiving"] = true
L["Group members can send you reminders from their export window or the reminder editor (\"Send\")."] = true
L["Sharing"] = true
L["%d of %d checked."] = true
L["Checking: %d of %d"] = true
L["reminders: %d"] = true
L["no response"] = true
L["Reminder check"] = true
L["Check how many reminders players have for each boss. Only players with the addon can be checked."] = true
L["Check"] = true

-- Comms.lua
L["You are not in a group."] = true
L["Addon messages are restricted right now. Try again after the encounter."] = true
L["Sent %d reminder(s) to your group."] = true
L["Received %d reminder(s) for %s from %s."] = true
L["Reminders shared by %s"] = true
L["Ignore"] = true
L["Newer version"] = true
L["%s shared reminders you cannot import yet:\n%s\n\nPlease update Ready Check Reminder."] = true
L["Ignored reminders from %s: %s"] = true
L["%s uses a newer version of Ready Check Reminder (%s); you have %s.\n\nTheir reminders are still imported when nothing conflicts. Consider updating."] =
  true
L["Sent %d reminder(s) to %d player(s)."] = true
