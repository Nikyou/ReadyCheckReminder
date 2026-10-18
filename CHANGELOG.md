#### 12.1.7
### Sharing
* Big shares (like all reminders at once) could fail to arrive without any message. If part of a share doesn't go out, the share is now sent again.
* Sending now opens a status window with every player and how it went: sending, waiting for confirmation, received, not imported (with the reason), could not send or no confirmation. It updates as soon as each player answers. Players need 12.1.7 or newer to confirm.
### Reminder check
* New "Sorting" section: sort players by response, reminder count, player name, class and raid group. Tick the rules you want, choose the direction and use the arrows to change their order.
### Import / export
* New "Tie to boss" option when exporting a boss's reminders or a single reminder. Untick it to get a string without a boss, it is imported to whichever boss is selected (the import tells you so). These strings need 12.1.7 or newer.
#### 12.1.6
### Sharing
* Reminder check results now list players with no response first.
#### 12.1.5
### Sharing
* New option "Use NSRT nicknames" (Sharing tab, on by default): players are shown by their Northern Sky Raid Tools nickname in the player list, the reminder check and share messages.
#### 12.1.4
### Display
* New option "Cyrillic Friz Quadrata" (Display tab, on by default): reminders in Friz Quadrata now show Cyrillic on non-Russian clients. Some accented letters like é or ö may not show with it, turn it off if you need them.
* Test in the Display tab now shows a few sample reminders, to check the font, size and position.
### Reminders
* Test is now "Test with current note" and shows the selected boss the way the next ready check would.
* New "Test with test note" button next to it: shows the boss's reminders with a fake note that has you on every line (used to be in the Display tab).
#### 12.1.3
### Kith'ix
* Update icon.
#### 12.1.2
### New boss
* The Unbinding of Kith'ix: Kith'ix.
### Sharing
* You can now send reminders to individual players instead of the whole raid.
* New reminder check in the Sharing tab: check how many reminders the whole group or picked players have, for all bosses, a raid or a single boss.
### Keywords
* Keywords keep their spaces, including trailing ones, so `P1 Soak ` matches lines like `P1 Soak 1: names`. The editor points out a trailing space since it's easy to miss.
* Strings and shares with such keywords need 12.1.2 to import, everything else still imports on 12.1.1.
#### 12.1.1
### Text replacements
* Reminder texts now use `{...}` replacements instead of `%` wildcards:
  * `{spell:<id>}` - spell icon
  * `{spellname:<id>}` - spell name
  * `{npc:<id>}` - NPC name
  * `{icon:<id or path>}` / `{texture:<id or path>}` - any icon or texture
  * `{rt1}`-`{rt8}` and raid marker names in every client language, like `{diamond}` or `{ромб}`
  * English class and spec names as icons, like `{Mage}`, `{Arms}` or `{Frost Mage}`
  * `{tank}`, `{healer}`, `{dps}` - role icons
  * `{line}` and `{pos}`
* Hover a reminder text box in the editor to see examples, including a colour code.
#### 12.1.0
### First release
* Shows your own assignments from the MRT note (and NSRT, if you use it) when a ready check starts.
* Three reminder types: keyword line, keyword group and raid group.
* Wildcards for spell and NPC names, line number and your position in the line.
* Load conditions: difficulty, class, specialisation, role and melee/ranged.
* Export and import single reminders, whole bosses or a full profile.
* Send reminders straight to your group, with trust and guild filters.
