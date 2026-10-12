local L = LibStub("AceLocale-3.0"):NewLocale("ReadyCheckReminder", "ruRU")
if not L then return end

-- Core.lua
L["Area IDs named \"%s\": %s"] = "ID зон с названием \"%s\": %s"
L["No area ID in %d-%d is named \"%s\"."] = "В диапазоне %d-%d нет зоны с названием \"%s\"."
L["Select a boss first."] = "Сначала выберите босса."
L["Nothing to show for %s with the current notes."] =
  "Босс %s: по текущим заметкам показывать нечего."
L["Instance ID: %s"] = "ID подземелья: %s"
L["Zone: %s"] = "Зона: %s"
L["Subzone: %s"] = "Подзона: %s"
L["(none)"] = "(нет)"
L["Matched boss: %s"] = "Найденный босс: %s"
L["Scanning area IDs %d-%d..."] = "Поиск ID зон %d-%d..."
L["/rcr - open the settings"] = "/rcr - открыть настройки"
L["Click to open the settings."] = "Нажмите, чтобы открыть настройки."
L["This reminder has no text to show."] = "У этого напоминания нет текста для показа."
L["No loaded reminders to show."] = "Нет загруженных напоминаний для показа."
L["/rcr reset - move the settings window back to the middle of the screen"] =
  "/rcr reset - вернуть окно настроек в центр экрана"

-- Database.lua
L["Encounter %d"] = "Босс %d"
L["Instance %d"] = "Подземелье %d"
L["Season %d"] = "Сезон %d"
L["Expansion %d"] = "Дополнение %d"

-- Display.lua
L["No text for line %d (%s)"] = "Нет текста для строки %d (%s)"
L["Text anchor"] = "Крепление текста"

-- ImportExport.lua
L["Boss: %s\nReminders: %d\n%s\n\nThis boss currently has %d reminder(s)."] =
  "Босс: %s\nНапоминаний: %d\n%s\n\nНапоминаний у этого босса сейчас: %d."
L["The import string is empty."] = "Строка импорта пуста."
L["This is not a Ready Check Reminder string."] = "Это не строка Ready Check Reminder."
L["The import string is damaged."] = "Строка импорта повреждена."
L["This string was made by an unsupported version."] =
  "Эта строка создана неподдерживаемой версией."
L["The boss in this string is not in the boss database."] =
  "Босса из этой строки нет в базе боссов."
L["A reminder in this string is invalid."] = "Одно из напоминаний в строке некорректно."
L["...and %d more"] = "...и ещё %d"
L["(unnamed)"] = "(без названия)"
L["Display and minimap settings"] = "Настройки отображения и миникарты"
L["- %s: %d reminder(s)"] = "- %s (напоминаний: %d)"
L["No reminders."] = "Нет напоминаний."
L["%d boss(es) not in the boss database were skipped."] =
  "Пропущено боссов, которых нет в базе: %d."
L["This string was made by an old version (%s) and can no longer be imported."] =
  "Эта строка создана старой версией (%s) и больше не может быть импортирована."
L["This string needs Ready Check Reminder %s or newer. You have %s."] =
  "Для этой строки нужна версия Ready Check Reminder %s или новее. У вас %s."
L["Made with a newer version (%s); you have %s."] = "Создано более новой версией (%s), у вас %s."
L["None of the bosses in this string are in the boss database."] =
  "Ни одного босса из этой строки нет в базе боссов."
L["Several bosses"] = "Несколько боссов"
L["Section: %s"] = "Раздел: %s"
L["%d of these bosses already have reminders."] = "Боссов, у которых уже есть напоминания: %d."

-- Options/Options.lua
L["Please confirm"] = "Подтверждение"
L["Export"] = "Экспорт"
L["Close"] = "Закрыть"
L["Import"] = "Импорт"
L["Replace all"] = "Заменить все"
L["Replace existing"] = "Заменить"
L["Add as new"] = "Добавить"
L["Cancel"] = "Отмена"
L["Some of this already exists. Replace it or add the import as new reminders?"] =
  "Часть напоминаний уже есть. Заменить их или добавить импорт как новые напоминания?"
L["All"] = "Все"
L["Copy this string (Ctrl+C) and share it."] = "Скопируйте эту строку (Ctrl+C) и поделитесь ею."
L["This boss has no reminders to export."] = "У этого босса нет напоминаний для экспорта."
L["Export reminders"] = "Экспорт напоминаний"
L["Choose the reminders of %s to export."] = "Выберите напоминания для экспорта (%s)."
L["Paste a reminder string (Ctrl+V)."] = "Вставьте строку напоминаний (Ctrl+V)."
L["This is a profile string. Import it in the Profiles tab."] =
  "Это строка профиля. Импортируйте её на вкладке \"Профили\"."
L["Export profile"] = "Экспорт профиля"
L["Display and minimap settings are always included. Choose the bosses whose reminders to include."] =
  "Настройки отображения и миникарты включаются всегда. Выберите боссов, чьи напоминания нужно добавить."
L["Import profile"] = "Импорт профиля"
L["Paste a profile string (Ctrl+V)."] = "Вставьте строку профиля (Ctrl+V)."
L["This is a reminder string. Import it in the Reminders tab."] =
  "Это строка напоминаний. Импортируйте её на вкладке \"Напоминания\"."
L["Enter a profile name."] = "Введите название профиля."
L["The profile \"%s\" already exists. Overwrite it?"] =
  "Профиль \"%s\" уже существует. Перезаписать его?"
L["Overwrite"] = "Перезаписать"
L["Import into a new profile, or into the current profile \"%s\" (its settings and the reminders of the bosses above are replaced)."] =
  "Импортировать в новый профиль или в текущий профиль \"%s\" (его настройки и напоминания перечисленных боссов будут заменены)."
L["New profile name"] = "Название нового профиля"
L["Imported"] = "Импортированный"
L["Create profile"] = "Создать профиль"
L["Into current"] = "В текущий"
L["Overwrite the settings of \"%s\"?"] = "Перезаписать настройки профиля \"%s\"?"
L["Send to group"] = "Отправить группе"

-- Options/DisplayTab.lua
L["None"] = "Нет"
L["Outline"] = "Контур"
L["Thick outline"] = "Толстый контур"
L["Left"] = "Слева"
L["Center"] = "Центр"
L["Right"] = "Справа"
L["Anchor"] = "Крепление"
L["Unlock anchor"] = "Разблокировать крепление"
L["Reset position"] = "Сбросить позицию"
L["Text"] = "Текст"
L["Font"] = "Шрифт"
L["Font size"] = "Размер шрифта"
L["Text alignment"] = "Выравнивание текста"
L["Line spacing"] = "Расстояние между строками"
L["Behaviour"] = "Поведение"
L["Display duration (seconds)"] = "Время показа (сек.)"
L["Show minimap button"] = "Кнопка у миникарты"
L["Test"] = "Тест"
L["Display"] = "Отображение"
L["Down"] = "Вниз"
L["Up"] = "Вверх"
L["All bosses"] = "Все боссы"
L["X"] = "X"
L["Y"] = "Y"
L["Offsets of the anchor's center from the screen center."] =
  "Смещение центра крепления относительно центра экрана."
L["Text growth"] = "Направление роста"
L["Shows every loaded reminder with a test note that puts you on each of its lines. Zone and difficulty are ignored."] =
  "Показывает все загруженные напоминания по тестовой заметке, где вы есть в каждой строке. Зона и сложность не учитываются."

-- Options/RemindersTab.lua
L["No reminders yet. Click \"New\" to create one."] =
  "Напоминаний пока нет. Нажмите \"Создать\", чтобы добавить."
L["Delete the reminder \"%s\"?"] = "Удалить напоминание \"%s\"?"
L["Keyword line"] = "Ключевая строка"
L["Keyword group"] = "Ключевой блок"
L["Group-based"] = "По группам"
L["Select a boss on the left."] = "Выберите босса слева."
L["%s (copy)"] = "%s (копия)"
L["Delete"] = "Удалить"
L["New"] = "Создать"
L["Drag to reorder. This is the display order."] =
  "Перетащите, чтобы изменить порядок показа."
L["Reminders"] = "Напоминания"
L["Right-click to send or export"] = "ПКМ: отправить или экспортировать"
L["There are no reminders in this section."] = "В этом разделе нет напоминаний."

-- Options/Editor.lua
L["Name"] = "Название"
L["Enabled"] = "Включено"
L["Duplicate"] = "Копия"
L["Matching"] = "Поиск в заметке"
L["Keyword (a line starts with it, optionally followed by a number: soak, soak1, soak2...)"] =
  "Ключевое слово (с него начинается строка, после может идти номер: soak, soak1, soak2...)"
L["Start keyword"] = "Начальное слово"
L["End keyword"] = "Конечное слово"
L["Texts"] = "Тексты"
L["One text per line"] = "Свой текст для каждой строки"
L["Add line"] = "Добавить строку"
L["Remove last line"] = "Убрать последнюю"
L["Raid groups"] = "Группы рейда"
L["Select the groups for each text. Groups without a text show nothing."] =
  "Выберите группы для каждого текста. Группы без текста ничего не показывают."
L["Add mapping"] = "Добавить текст"
L["Load conditions"] = "Условия загрузки"
L["Nothing selected means any."] = "Ничего не выбрано - подходит любое."
L["LFR"] = "Поиск рейда"
L["Normal"] = "Обычный"
L["Heroic"] = "Героический"
L["Mythic"] = "Эпохальный"
L["Tank"] = "Танк"
L["Healer"] = "Лекарь"
L["Damage"] = "Боец"
L["Melee"] = "Ближний бой"
L["Ranged"] = "Дальний бой"
L["Class"] = "Класс"
L["Specialization"] = "Специализация"
L["Preview"] = "Предпросмотр"
L["Your result with the current notes and group (load conditions are ignored)."] =
  "Ваш результат по текущим заметкам и группе (условия загрузки не учитываются)."
L["Text for lines without a number"] = "Текст для строк без номера"
L["Text for all lines"] = "Текст для всех строк"
L["Line %d"] = "Строка %d"
L["Wildcards: %npc:<id>, %spell:<id>, %line, %pos. Write %% to show a literal %. Colour codes and raid markers like {rt1} work too."] =
  "Подстановки: %npc:<id>, %spell:<id>, %line, %pos. %% выводит знак %. Также работают цветовые коды и метки целей вроде {rt1}."
L["Wildcards: %npc:<id>, %spell:<id>. Write %% to show a literal %. Colour codes and raid markers like {rt1} work too."] =
  "Подстановки: %npc:<id>, %spell:<id>. %% выводит знак %. Также работают цветовые коды и метки целей вроде {rt1}."
L["%line and %pos only work in keyword reminders; here they are shown as written."] =
  "%line и %pos работают только в напоминаниях по ключевым словам, здесь они выводятся как есть."
L["Nothing to show for you with the current note."] = "По текущей заметке для вас ничего нет."
L["Select or create a reminder."] = "Выберите или создайте напоминание."
L["Instance Difficulty"] = "Сложность подземелья"
L["Spec Role"] = "Роль специализации"
L["Spec Position"] = "Позиция специализации"
L["%s (%d selected)"] = "%s (выбрано: %d)"
L["Select a class to choose its specializations."] =
  "Выберите класс, чтобы выбрать его специализации."
L["Send"] = "Отправить"

-- Options/ProfilesTab.lua
L["Overwrite the current profile with \"%s\"?"] =
  "Перезаписать текущий профиль профилем \"%s\"?"
L["Delete the profile \"%s\"?"] = "Удалить профиль \"%s\"?"
L["Current profile"] = "Текущий профиль"
L["New profile"] = "Новый профиль"
L["Create"] = "Создать"
L["Copy from"] = "Скопировать из"
L["Copies the settings and reminders of another profile into the current one."] =
  "Копирует настройки и напоминания другого профиля в текущий."
L["Copy"] = "Копировать"
L["Delete a profile"] = "Удалить профиль"
L["Reset"] = "Сброс"
L["Reset current profile"] = "Сбросить текущий профиль"
L["Reset the current profile to defaults? Its reminders will be deleted."] =
  "Сбросить текущий профиль к настройкам по умолчанию? Его напоминания будут удалены."
L["Profiles"] = "Профили"
L["Share"] = "Поделиться"
L["Export the current profile's settings and the reminders of the bosses you choose, or import such a string."] =
  "Экспортируйте настройки текущего профиля и напоминания выбранных боссов или импортируйте такую строку."
L["Select a profile"] = "Выберите профиль"

-- Options/SharingTab.lua
L["Only trusted"] = "Только доверенные"
L["Receive reminder updates only from the raid leader or raid officers."] =
  "Получать напоминания только от лидера рейда или его помощников."
L["Only guild"] = "Только гильдия"
L["Receive reminder updates only from guild members."] =
  "Получать напоминания только от членов гильдии."
L["Overwrite by default"] = "Перезаписывать без подтверждения"
L["Automatically overwrite reminders when received from other players. When off, you are asked first."] =
  "Автоматически перезаписывать напоминания, полученные от других игроков. Если отключено, сначала будет задан вопрос."
L["Receiving"] = "Получение"
L["Group members can send you reminders from their export window or the reminder editor (\"Send\")."] =
  "Участники группы могут отправить вам напоминания из окна экспорта или редактора напоминаний (\"Отправить\")."
L["Sharing"] = "Обмен"

-- Comms.lua
L["You are not in a group."] = "Вы не состоите в группе."
L["Addon messages are restricted right now. Try again after the encounter."] =
  "Сообщения модификаций сейчас ограничены. Повторите после боя с боссом."
L["Sent %d reminder(s) to your group."] = "Отправлено напоминаний группе: %d."
L["Received %d reminder(s) for %s from %s."] = "Получено напоминаний: %d (%s) от %s."
L["Reminders shared by %s"] = "Напоминания от %s"
L["Ignore"] = "Игнорировать"
L["Newer version"] = "Новая версия"
L["%s shared reminders you cannot import yet:\n%s\n\nPlease update Ready Check Reminder."] =
  "%s поделился напоминаниями, которые вы пока не можете импортировать:\n%s\n\nОбновите Ready Check Reminder."
L["Ignored reminders from %s: %s"] = "Напоминания от %s проигнорированы: %s"
L["%s uses a newer version of Ready Check Reminder (%s); you have %s.\n\nTheir reminders are still imported when nothing conflicts. Consider updating."] =
  "%s использует более новую версию Ready Check Reminder (%s), у вас %s.\n\nЕго напоминания всё равно импортируются, если нет конфликтов. Рекомендуем обновиться."
