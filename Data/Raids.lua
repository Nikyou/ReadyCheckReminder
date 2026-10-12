-- expansion > season > raid > boss. names aren't stored, they come from the journal.
--
-- raid:
--   key
--   instanceID         8th return of GetInstanceInfo()
--   journalInstanceID  EJ instance ID, for the raid name
--   uiMapID            only needed to look up the EJ instance when journalInstanceID is nil
-- boss:
--   key                reminders are saved under this, don't rename
--   areaID             boss room subzone, compared via C_Map.GetAreaInfo
--   encounterID        dungeon encounter ID (ENCOUNTER_START, NSRT personal notes)
--   journalEncounterID EJ encounter ID for the name; nil = looked up by encounterID at runtime
--   icon               texture path or file ID next to the boss name, nil = question mark
--
local _, ns = ...

ns.Raids = {
    {
        key = "midnight",
        expansionID = 11, -- EXPANSION_NAME11
        seasons = {
            {
                key = "midnight_s2",
                season = 2,
                raids = {
                    {
                        key = "venomous_abyss",
                        instanceID = 3004,
                        journalInstanceID = 1320,
                        uiMapID = 2606,
                        bosses = {
                            {
                                key = "nekzali_the_soulcoiler",
                                areaID = 17680,
                                encounterID = 3470,
                                journalEncounterID = 2888,
                                icon = 7966621,
                            },
                            {
                                key = "entombed_sentinels",
                                areaID = 17688,
                                encounterID = 3445,
                                journalEncounterID = 2874,
                                icon = 7966620,
                            },
                            {
                                key = "the_lost_explorers",
                                areaID = 17682,
                                encounterID = 3497,
                                journalEncounterID = 2894,
                                icon = 7966622,
                            },
                            {
                                key = "vashnik_the_malignant",
                                areaID = 17715,
                                encounterID = 3455,
                                journalEncounterID = 2882,
                                icon = 7966618,
                            }, {key = "sszorak", areaID = 17686, encounterID = 3420, journalEncounterID = 2871, icon = 7966619},
                            {
                                key = "the_twin_fangs",
                                areaID = 17681,
                                encounterID = 3421,
                                journalEncounterID = 2887,
                                icon = 7966623,
                            },
                            {
                                key = "the_coiled_altar",
                                areaID = 17701,
                                encounterID = 3429,
                                journalEncounterID = 2883,
                                icon = 7966625,
                            }, {key = "ulatek", areaID = 17702, encounterID = 3492, journalEncounterID = 2895, icon = 7966624},
                        },
                    }, {
                        key = "tidebound_grotto",
                        instanceID = 2987,
                        journalInstanceID = 1317,
                        uiMapID = 2632,
                        bosses = {
                            {
                                key = "nymrissa_wavecaller",
                                areaID = 16671,
                                encounterID = 3379,
                                journalEncounterID = 2849,
                                icon = 3012069,
                            },
                        },
                    },
                },
            },
        },
    },
}
