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
