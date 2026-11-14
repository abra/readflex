# Readflex — руководство для новой команды

Передача проекта · 4 ноября 2026 года

Это руководство объясняет текущую реализацию Readflex: как запустить приложение,
найти владельца поведения, проследить путь данных, внести изменение и проверить
результат. Оно рассчитано на Flutter/Dart-разработчиков; разделы Pagecraft,
хранилища и выпуска нужны также инженерам Rust и мобильных платформ.

Основа снимка — ревизия `0d6cad00`, актуализация документации и последующая
реализация поддержки DjVu. Версия приложения в `pubspec.yaml` — `1.0.0+1`;
она сама по себе не подтверждает готовность к публикации. PDF является снимком.
При расхождении с последующими изменениями источником истины остаётся код.

В проекте уже работают Library, импорт, чтение, выделения, перевод, словарь
и Practice. При этом production-аутентификация backend ещё не реализована.
Не следует воспринимать существующие интерфейсы, сохранённые таблицы или
заглушки как обещание полностью готовых пользовательских возможностей.

## 1. Как войти в проект

### Первые часы

Сначала прочитайте корневой README и восстановите окружение по разделу 3.
Затем откройте `lib/main.dart`, `starter.dart`, `composition.dart` и
`routing.dart`: здесь видны запуск, создание зависимостей и связь экранов.
Не начинайте знакомство с внутреннего CSS layout движка: он нужен для
изменений отображения книг, но не для обычной работы над приложением.

Следом проследите простой сценарий: нажатие книги в Library → маршрут Reader →
загрузка источника → сохранение позиции → обновление прогресса в Library.
Параллельно откройте `test/app/reader_route_test.dart` и
`test/ui/app_flows_test.dart`. Так становятся понятны и рабочий путь,
и способ его изолированной проверки.

### Первые несколько дней

| Направление | Что изучить | Практический результат |
| --- | --- | --- |
| Оболочка приложения | `lib/app`, root tests | Понимание владения зависимостями и навигации |
| UI конкретной функции | Screen, Bloc/Cubit, View, README пакета | Изменение без прямого доступа View к сервисам |
| Данные | Репозиторий, DAO, миграции | Понимание транзакций, файлов и доменных моделей |
| Чтение | README Reader, затем README Pagecraft | Разделение UI читателя и движка |
| Выпуск | Конфигурация, подпись, Makefile | Воспроизводимая сборка без передачи секретов в коде |

Новому участнику полезно сначала выполнить небольшую задачу в одном feature
с существующими тестами. Изменения якорей, миграций или layout книги требуют
более глубокого изучения совместимости и измерений.

### Карта документации

- [README](../README.md): краткий старт, основные проверки и команды сборки Android.
  Подробное восстановление окружения описано в разделе 3 этого руководства,
  конфигурация, подпись и ограничения выпуска — в разделе 15.
- [ARCHITECTURE](../ARCHITECTURE.md): правила, границы и технические детали.
- [C4_MODEL](../C4_MODEL.md): контекст системы и схемы основных сценариев.
- [Reader](../packages/features/reader/README.md): UI, владельцы состояния,
  восстановление позиций и взаимодействие с движком.
- [Pagecraft](../packages/pagecraft/README.md): форматы, layout, поиск,
  выделение и внутренние библиотеки движка.
- [UI verification](../test/ui/README.md),
  [ACCESSIBILITY](../ACCESSIBILITY.md): проверки интерфейса и semantics.
- [Benchmarks](../benchmarks/README.md): методика измерений и ограничения.

README каждого пакета описывает его публичный контракт. Руководство помогает
выбрать точку входа; при изменении конкретного API следует читать его код и тесты.

## 2. Продукт и границы системы

Readflex — Flutter-приложение для Android и iOS с локальной библиотекой книг,
комиксов, PDF и сохранённых статей. Пользователь импортирует файл или URL,
читает, сохраняет слова и выделения, затем повторяет их в Practice.

Library — домашний экран. Practice открывается поверх него; постоянной панели
вкладок нет. Reader открывается из Library и из учебных сценариев. Onboarding
является экраном первого входа, а не отдельной системой аккаунтов.

Активны восемь feature-пакетов: `library`, `practice`, `import_flow`, `reader`,
`highlight`, `translate`, `dictionary`, `onboarding`. Путь `features/library`
содержит pub-пакет `library_feature`: слово `library` зарезервировано Dart.

### Что находится вне мобильного checkout

Article Cleaner API извлекает содержание статьи. Contextual Translation API
переводит выбранный фрагмент в контексте. Readflex Dictionary API возвращает
словарные определения. Их клиентские контракты находятся в service-пакетах;
серверы, deployment, внутренние provider-вызовы и серверные кэши здесь отсутствуют.

Сайты издателей — отдельный внешний источник HTML и изображений. Приложение
может загрузить HTML для fallback-извлечения; эта загрузка проходит специальные
ограничения адресов, редиректов и объёма. Обычный backend HTTP-клиент для неё
не используется.

Платформенные возможности включают файловый picker, системный словарь,
яркость, удержание экрана, connectivity и ML Kit. PDFium, Rust MOBI backend
и C++ DjVuLibre decoder
поставляются с приложением как нативные зависимости движка чтения.

### Где живут пользовательские данные

Основные данные сохраняются в локальной SQLite и файлах приложения.
Описанного в этом checkout активного сценария облачной синхронизации нет.
Восстановление данных после удаления приложения нельзя обещать на основании
одного факта их локального сохранения.

Выбранный для перевода текст с контекстом отправляется translation backend;
URL или HTML статьи — extraction backend; запрос определения — словарному
сервису после попытки платформенного lookup. Не следует считать наличие
локальной библиотеки гарантией отсутствия сетевых обращений во всех действиях.

## 3. Окружение и первый запуск

### Версии и зависимости

Flutter закреплён в `.fvmrc` — `3.50.0` (Dart `3.14`). Используйте `fvm flutter` и `fvm dart`:
системная версия SDK может иначе анализировать код и рисовать golden images.
Диапазон Dart в pubspec не заменяет закреплённый Flutter SDK.

Rust закреплён в `packages/pagecraft/rust/rust-toolchain.toml` — `1.99.0`,
с целевыми платформами, Clippy и rustfmt. Версия генератора
`flutter_rust_bridge_codegen` должна быть `2.13.0`, если регенерируется мост.
Обычная сборка использует уже сохранённые bindings.

Android использует AGP `9.3.1`, wrapper Gradle `9.5.0`, Kotlin `2.4.20`, Java source compatibility
17. Gradle запускайте JDK, настроенным для Flutter; Java 21 поддерживается.
Случайный системный JDK более новой версии может не поддерживаться wrapper
или плагинами. Для iOS нужны Xcode, соответствующие SDK и CocoaPods.

UI использует отдельные `material_ui` и `cupertino_ui`, сохраняя одну дизайн-систему
в `component_library`. Core layout и нативный selection bridge используют Flutter
core APIs. Настройки хранят собственный `AppThemeMode`, а приложение преобразует
его в UI `ThemeMode`; сохранённые имена тем не изменены. Локализацию подключают
через `readflexLocalizationsDelegates`, а не legacy-список генератора SDK.
Android пока сохраняет `android.builtInKotlin=false` и `android.newDsl=false`:
это поддерживаемый AGP 9 путь совместимости для существующих плагинов.

Node.js не нужен для стандартной сборки, тестов или benchmark-оркестрации.
Он остаётся optional maintenance tool для регенерации committed данных:
ICU sentence reference, Unicode search-fold table и hyphenation patterns.
Генераторы находятся в `packages/pagecraft/`:
`test/fixtures/icu_sentence_breaks.mjs`, `tool/search_fold_table.mjs`,
`tool/hyphenation_patterns.mjs` (пути относительно пакета).
Обычный runtime и tests используют уже сохранённые результаты.

### Последовательность восстановления

1. Получите checkout и восстановите Flutter через FVM.
2. Установите rustup и платформенные toolchains для нужной цели.
3. Выполните команды ниже, затем проверьте доступные устройства.
4. Для iOS восстановите pods через `pod install`, не обновляя lockfile без задачи.
5. Создайте локальную конфигурацию и получите DEV-доступ к backend отдельно.

```sh
fvm install
make get
fvm flutter doctor -v
fvm flutter devices
./run.sh
```

На первом запуске `run.sh` создаёт `.local/run-defines.json` из
`config/run-defines.example.json` с правами только для владельца и завершает
работу. Заполните DEV-ключ и при необходимости GlitchTip DSN в этом локальном
файле, затем повторите запуск. Содержимое файла не следует копировать
в issue, PDF или общий чат.

```sh
./run.sh -d <device-id>
./run.sh --profile -d <physical-device-id>
```

Тесты UI используют изолированные зависимости и не требуют API-ключей.
Отсутствие backend-доступа не мешает начать знакомство с архитектурой и тестами.

### Какие файлы версий сохраняются

В version control находятся `.fvmrc`, корневой `pubspec.lock`, iOS Podfile.lock,
существующие SwiftPM `Package.resolved`, lockfiles окружения Pagecraft и Cargo.
У большинства библиотек самостоятельный test-environment lockfile локальный:
app lockfile фиксирует граф приложения, а не все dev dependencies каждого пакета.

Не передавайте через репозиторий `.local/run-defines.json`, `.env`, keystore,
`android/key.properties`, машинные SDK paths и caches. Наличие исходников
не восстанавливает ключ подписи уже опубликованного приложения.

## 4. Архитектура и правила зависимостей

Readflex использует набор локальных пакетов с явной композицией. Корневой app
собирает инфраструктуру и соединяет features; отдельный feature не импортирует
соседний feature. Глобального service locator нет.

```text
App shell: composition.dart + routing.dart
                    |
                    v
              Screen / Sheet
                    |
              creates Bloc / Cubit
                    |
        View <state, events, UI callbacks>
                    |
           repository / service
                    |
        SQLite / files / HTTP / platform
```

Схема показывает владение и доступ, а не последовательность всех вызовов.
Именно Bloc/Cubit обращается к репозиторию; View читает состояние и отправляет
события. Screen/Sheet получает зависимости через конструктор и создаёт state
owners. Передавать сервис в дочерний View для удобства означает нарушить эту
границу, даже если сам вызов выглядит небольшим.

### Куда помещать новый код

| Ответственность | Место |
| --- | --- |
| Экран или пользовательский сценарий | `packages/features/<feature>` |
| Хранение и жизненный цикл доменной сущности | `<name>_repository` |
| HTTP, платформа, инфраструктурный контракт | `<name>_service` или специализированный пакет |
| Общая доменная сущность | `domain_models` |
| Таблица, DAO, migration | `local_storage` |
| Тема, tokens, переиспользуемый UI | `component_library` |
| Межфункциональный UI/action контракт | `shared` |
| Формат книги, layout, CFI, selection | `pagecraft` |
| Соединение соседних features | `lib/app/routing.dart` |

`shared` намеренно узкий: например, `TextAction`, его payload и
`WordSaveStatus`. Это не место для произвольных utils, сервисов и моделей.
Обычные доменные сущности остаются в `domain_models`.

### Карта локальных пакетов

| Группа | Пакеты и назначение |
| --- | --- |
| Контракты | `domain_models`: сущности/исключения; `shared`: UI/action contracts |
| UI foundation | `component_library`: widgets/theme; `readflex_localizations`: строки/locale |
| Persistence | `local_storage`: Drift/SQLite; `preferences_service`: настройки/snapshots |
| Источники | `book_repository`, `article_repository`: files, metadata, reader state |
| Организация | `collection_repository`: collections/membership; `highlight_repository`: annotations |
| Слова и review | `dictionary_repository`: saved words; `fsrs_repository`: state/log; `review_scheduler`: FSRS |
| Remote import | `article_extraction_service`: cleaner client; `remote_content_policy`: guarded remote access |
| Backend transport | `bounded_http`: deadline, отмена запроса и лимит streamed response; без Flutter/domain dependencies |
| Языковые сервисы | `contextual_translation_service`: remote/cache/ML Kit; `dictionary_service`: system/backend lookup |
| Platform/UI infrastructure | `connectivity_service`, `screen_control_service`, `toast_service`, `monitoring` |
| Reader engine | `pagecraft`: форматы, layout, views и internal Rust crate |
| Feature entry | `library_feature`, `import_flow`, `reader`, `practice` |
| Feature actions | `highlight`, `translate`, `dictionary`, `onboarding` |
| Vendored dependencies | `third_party/fsrs`, `third_party/device_screen_brightness` |

Vendored packages требуют отдельного review локальных отличий от upstream.
Benchmarks с самостоятельными pubspec не входят в production app graph.
Публичные exports и точные зависимости смотрите в package pubspec/README;
не подключайте соседний feature ради переиспользования одного widget.
Production Dart-код библиотек остаётся внутри `lib/` своего пакета: imports,
exports и parts не должны подключать test, tool или build-hook файлы.

Выбор маршрутов и переходы между features принадлежат root router и передаются
через callbacks. Локальный Back/Close может закрыть собственный экран или sheet
через `Navigator.pop`/`maybePop`; если закрытием управляет родитель, используется
его callback.

UI строится классами widgets. Вспомогательные функции, методы и getters,
возвращающие Widget или список Widget, запрещены; override `build` и builder
closures допустимы. Проверка `scripts/check_widget_helpers.dart` входит
в `make analyze`. Небольшие UI-настройки имеют отдельные Cubit.

### Что проверяется автоматически

Анализатор, Rust fmt/Clippy и архитектурные проверки входят в `make analyze`.
Отдельно их можно запустить через `make check-architecture`: проверяются
production-зависимости и Dart directives пакетов, циклы, публичные границы,
зависимости `domain_models`, widget helpers и инфраструктурные типы в полях и
параметрах конструкторов feature View/State. Модели данных сервисов и UI callbacks
допустимы. Динамические типы, захваты замыканий, локальное получение сервисов и
UI-классы без суффикса `View` всё ещё требуют review. Pagecraft дополнительно
проверяет внутренние границы format-библиотек тестом
`library_boundaries_test.dart`. Workflow `.github/workflows/quality.yml`
запускает форматирование, `make analyze` и `make test` для pull request и push
в `main`; доступен ручной запуск. Локальный успех не доказывает успешность
удалённого запуска.

`make test-contracts` запускает одинаковые сценарии закладок и коллекций на
реальных SQLite-репозиториях и их частичных feature-fakes, а также проверки
взаимодействия Library, Reader, Practice и review session. Проверяются в том
числе ошибка observer после импорта, удаление уже показанного highlight,
поздняя оценка, Undo и согласованность счётчиков для книг/статей при обоих
значениях настройки повторения highlights. Эти тесты входят и в `make test`.

Среда goldens в CI: `macos-15` arm64, точная версия SDK из `.fvmrc`, UTC,
`en_US.UTF-8` и шрифты из репозитория. Application lockfile проверяется через
`--enforce-lockfile`; tracked Pagecraft lockfile не должен изменяться. Остальные
package test contexts по-прежнему имеют собственное разрешение зависимостей.
Rust использует существующий pin Pagecraft. Версии среды и логи сохраняются
вместе с golden differences на семь дней; expected PNG автоматически не
обновляются. GitHub может обновлять образ внутри `macos-15`, поэтому при
расхождении надо сопоставлять записанные версии. Device/FPS и screen reader
проверки в этот workflow не входят.

## 5. Запуск, владение ресурсами и навигация

### Путь запуска

`main.dart` вызывает `starter()`. Starter устанавливает error zone, Flutter
binding, обработчики ошибок и Bloc observer, затем запускает AppBootstrap.
Binding и `runApp` находятся в одной error zone.

AppBootstrap сначала проверяет конфигурацию, затем подготавливает monitoring
и зависимости. `composition.dart` создаёт одну AppDatabase, каталоги documents,
репозитории, PreferencesService и платформенные/сетевые сервисы.
DependenciesContainer хранит готовые объекты; AppScopes монтирует их в tree.
ReadflexApp сохраняет GoRouter и передаёт тему и locale в ReadflexPlatformApp.
На iOS и macOS оболочка использует CupertinoApp.router, на остальных платформах
— MaterialApp.router. Бизнес-состояние и зависимости от этого выбора не меняются.

Платформенные различия сосредоточены в component_library: AppScaffold,
AppNavigationBar, AppButton, AppTextField, AppChoiceControl и другие App-компоненты
выбирают соответствующие Cupertino или Material реализации. AppThemeScope хранит
общие смысловые роли цветов и текста, поэтому feature View не зависит от
Material ThemeData. На iOS элементы интерфейса используют системный шрифт,
группированные поверхности и нативные элементы управления; собственные настройки
шрифта и вёрстка текста книги в Pagecraft остаются отдельным контрактом.

Общий showAppBottomSheet сохраняет результаты, draft guards, управление фокусом
и callback после завершения закрытия. На iOS он открывает Cupertino popup с
нативной пружинной анимацией и заголовком по центру; на Android — Material bottom
sheet. Настройки и команды остаются теми же, отдельные feature Cubit не нужны.

Внутри Cupertino-оболочки намеренно остаётся служебный адаптер Material Theme
и MaterialUiCompatibilityBridge: они нужны адаптивному SelectionArea и сторонним
пакетам. Это совместимость зависимостей, а не второй видимый интерфейс.

GoRouter сохраняется при изменениях настроек: смена темы не должна создавать
новый navigation stack. При неуспешной инициализации показывается recovery
screen с повторной попыткой, а не частично собранное приложение.

### Cleanup и ошибки

ResourceDisposer регистрирует cleanup по мере создания ресурсов, закрывает их
в обратном порядке и выполняется один раз. Неудачная сборка зависимостей
откатывает уже созданные ресурсы. Monitoring сохраняется между попытками,
чтобы диагностировать следующую; running container получает владение им после
успешного запуска.

Синхронная ошибка callback `onReady` ещё относится к bootstrap rollback.
Последующая ошибка Flutter build уже проходит через установленные обработчики
ошибок; это другой этап жизненного цикла.

App detach запускает best-effort disposal и является терминальным состоянием
этого runtime. Pause/resume не закрывают весь контейнер. Android и iOS могут
завершить процесс без такого callback: нельзя строить единственный механизм
сохранения пользовательского результата на финальном dispose приложения.

### Маршруты

| Путь | Назначение |
| --- | --- |
| `/`, `/library` | Вход и домашняя Library |
| `/onboarding` | Первый вход |
| `/practice` | Учебный hub |
| `/practice/words` | Сохранённые слова |
| `/practice/highlights` | Текстовые выделения |
| `/practice/review` | Сессия повторения |
| `/reader/:sourceId` | Чтение конкретного источника |

`routing.dart` соединяет TextAction с Highlight, Translate и Dictionary.
Reader не импортирует эти features. Аналогично LibraryImportEntry переводится
в ImportFlowEntry на уровне app shell.

Для Reader URL sourceId является главным. Preloaded Book из route arguments
игнорируется при несовпадении ID; deep link работает и без этого payload.
`initialCfi` позволяет открыть сохранённое слово или выделение после готовности
документа. Reader route использует fullscreenDialog, чтобы iOS edge back gesture
не конфликтовал с перелистыванием книги.

Ключевые проверки: `test/app/app_bootstrap_test.dart`,
`resource_disposer_test.dart`, `reader_route_test.dart`,
`readflex_app_test.dart`, `app_lifecycle_test.dart`.

## 6. Данные, файлы и миграции

### Единственное хранилище

AppDatabase — одна Drift/SQLite database `readflex.db` в app documents.
Подключение работает в background isolate, WAL mode и `synchronous=NORMAL`.
Это снижает стоимость частых commits позиции. При аварийном выключении питания
последние commits могут потеряться; WAL не означает гарантию сохранения
последнего действия на физическом носителе.

Текущая schemaVersion — 27. В базе находятся books, articles, highlights,
dictionary, dictionary anchors, collections и memberships, bookmarks,
review items и logs. Legacy flashcard table остаётся ради совместимости
миграций и не означает активного старого flashcard feature.

```text
App documents/
  readflex.db        (+ WAL / SHM while open)
  books/<source-id>/
    book.<format>
    cover.<image-ext> (if available)
  articles/<source-id>/
    article.json
    content.html
    images/
```

Repository получает базовый каталог через composition. DB хранит filenames
и нужные metadata; BookRepository разрешает пути относительно актуального
каталога, чтобы смена Documents UUID на iOS не разрушала ссылки на книги.
Article содержит полный plain_text также в SQLite, а не только файлы на диске.

### Разделение моделей

Domain model не должен зависеть от Flutter или Drift row. DAO работает
с storage representation; repository выполняет mapping, доменные операции
и преобразование storage errors в стабильные исключения.
Feature state содержит доменные модели и UI state, а не SQL row или HTTP JSON.

Не создавайте вторую production AppDatabase в feature. Cleanup общей базы
принадлежит composition, а не каждому использующему её repository.

### Частичные записи и транзакции

Чтение изменяет CFI/progress отдельным методом; markOpened изменяет только
opened timestamp. Запись ранее прочитанного полного Book snapshot могла бы
затереть параллельно изменённые metadata, поэтому для позиции используется
partial update. Порядок position writes обеспечивает ReaderBloc.

Удаление book/article и collection membership выполняется одной DB transaction.
Файловая очистка идёт после commit: SQLite transaction не делает filesystem
операции атомарными. При расследовании сбоя различайте DB consistency
и оставшиеся на диске файлы.

Word и его anchor/review row регистрируются согласованно при сохранении.
Saved word может пережить удаление источника; source anchor удаляется
или отсоединяется по соответствующему контракту. Режим keepLearningData
не должен оставлять collection membership удалённого источника.

У book deletion по умолчанию keepLearningData: text/image highlights и их
review state удаляются, saved words отсоединяются с сохранением word review
state, legacy flashcards сохраняются. DeleteEverything удаляет source-owned
learning content. Article deletion всегда каскадный и такого режима сохранения
не имеет. Append-only review logs остаются для activity statistics; это
история действий, а не признак наличия удалённого content в активной очереди.

### Как менять schema

Измените таблицу, поднимите schemaVersion, добавьте upgrade path и индексы,
регенерируйте Drift код штатным генератором. Для historical paths нужны
file-backed fixtures: старые статьи переносили и SQL данные, и файлы.
Нельзя заменить upgrade пересозданием базы ради зелёного теста.

Длинные поля должны оставаться вне горячего Library metadata query.
В v24 article plain_text перенесён в конец row: SQLite иначе проходил overflow
pages даже ради полей metadata. В v27 `word_key` нормализуется одним Dart
правилом для inserts, edits, lookup и migration; SQLite lowercase не заменяет
Unicode-семантику этого контракта.

### Резервное копирование

Готового пользовательского workflow backup/restore в активной архитектуре
не следует предполагать. Для инженерного копирования используйте согласованный
snapshot: остановите доступ или сделайте корректный SQLite checkpoint/backup,
учитывайте WAL и копируйте связанные files. Один открытый `readflex.db` без WAL
и content directories не является полным backup. Проверяйте восстановление
на отдельной копии, не на единственном экземпляре данных пользователя.

Подробности: [local_storage](../packages/local_storage/README.md),
[BookRepository](../packages/book_repository/README.md),
[ArticleRepository](../packages/article_repository/README.md).

## 7. Library, импорт и коллекции

### Library

LibraryBloc загружает books и облегчённую projection article metadata,
хранит общий список LibrarySource и кэширует visibleItems в состоянии.
Search и collection scope фильтруют загруженные модели; это не SQL pagination
всей библиотеки. Search debounce — 300 ms.

List и grid построены lazy slivers. Grid отображает обложки без отдельной
подписи снизу. Continue reading и Practice row находятся в общем scroll view.
Нормальная смена локальной настройки не должна читать весь storage заново.
Generation guards не позволяют старой async загрузке заменить более новые
данные. Failed collection read сохраняет последний корректный scope/selection.

При открытии Reader callback обновляет opened state, а завершённая запись
позиции обновляет один source в памяти Library. Дополнительное refresh после
возврата остаётся страховкой. Это позволяет видеть актуальный Continue reading
без полной загрузки списка на каждом перелистывании.

### Импорт файла

```text
Library / Onboarding
  -> routing adapter
  -> ImportFlowSheet / ImportFlowCubit
  -> file picker + metadata extraction with Pagecraft
  -> BookRepository: copy source, save cover, insert row
  -> onImported callback -> refresh Library
```

До первого импорта показывается версия условий, которой управляет app shell.
Format определяется по поддерживаемому расширению; архив с FB2 не равнозначен
обычному `.fb2` в текущем import workflow.

Progress-aware copy использует stream backpressure; путь без callback
сохраняет нативный File.copy. Временная копия picker удаляется app adapter
только внутри допустимого temp/cache каталога после завершения работы.

Закрытие import sheet не отменяет уже начатый import. Future открытия sheet
означает закрытие UI; callback onImported означает успешную persistence.
Позднее успешное завершение обновит Library, пока она существует.
Cancel без успешного сохранения не вызывает лишнее чтение списка.

### Импорт статьи

```text
URL -> ArticleExtractionService
       server extraction / guarded HTML fallback
    -> ExtractedArticle
    -> ArticleRepository
       DB metadata + plain_text + HTML/JSON + body images
    -> Reader: ArticleTextSource + TextScrollView
```

Body images скачиваются репозиторием с ограничениями. `og:image` остаётся
remote imageUrl и не означает автоматически скачанный offline asset.
Удалённые URLs считаются недоверенными: проверяются resolution, redirects,
private/local IP, byte/request/asset limits, используется pinning проверенных IP.
Эти ограничения находятся в data-loading layers, а не в UI и typography.

### Коллекции

Manual collections и protected Favourites сохраняются. Author/site smart
collections вычисляются Library и отдельными коллекциями в DB не являются.
Selection UI предоставляет отдельную cancel FAB и capsule действий;
Add to collection открывает modal bottom sheet.

Multi-collection membership изменяется через CollectionRepository; удаление
источника очищает memberships в source-owned transaction. UI draft закрытой
панели не должен случайно стать сохранённым результатом. Для изменений picker
проверяйте и отмену, и явное подтверждение, и ошибки persistence.

Точки входа: [Library README](../packages/features/library/README.md),
[ImportFlow README](../packages/features/import_flow/README.md),
[CollectionRepository](../packages/collection_repository/README.md),
`test/source_deletion_transaction_test.dart`.

## 8. Reader — состояние и жизненный цикл

### UI читателя и движок

Reader feature отвечает за приложение вокруг чтения: источник, toolbar,
Appearance, Contents, Search, bookmarks, highlights, текстовые действия,
сохранение и платформенное управление экраном. Pagecraft открывает форматы,
строит layout и предоставляет views/controllers. Движок не знает о
BookRepository, feature Cubit и бизнес-навигации Readflex.

ReaderScreen создаёт state owners. Внутренний `_ReaderView` и остальные widgets
работают через state, events и callbacks. ReaderSurface передаёт команды
документной поверхности; page body переводит engine callbacks в события UI.

`reader_screen.dart` и его `part`-файлы образуют **одну Dart library**
с общим private namespace. Это организация исходников, а не набор независимых
модулей. Читайте lifecycle/content раньше chrome/drawers/context panel.
Отдельные format bodies отвечают за text, article, comic, PDF и DjVu.

### Владельцы состояния

| Владелец | Ответственность |
| --- | --- |
| ReaderBloc | Source load, persisted position, TOC, bookmarks, highlights |
| ReaderUiCubit | Chrome, drawers, overlays и transient UI |
| ReaderArticleProgressCubit | Live scroll fraction статьи |
| ReaderSearchCubit | Query, search stream, results, navigation anchors |
| ReaderSelectionCubit | Активная text selection и UI adjustment |
| ReaderImageSelectionCubit | Image-area selection |
| ReaderImageHighlightCubit | State операций image highlights |
| ReaderHighlightFocusCubit | Фокус сохранённого выделения |
| ReaderAppearanceCubit | Source appearance и global defaults |
| ReaderBrightnessCubit | Настройка и platform brightness override |
| ReaderKeepAwakeCubit | Удержание включённого экрана |
| ReaderSelectionTipCubit | Политика одноразовой подсказки selection |
| ReaderPageThumbnailCubit | Очередь и cache previews в Pages/Highlights tabs |

Последний Cubit создаётся локально в каждой вкладке с previews; остальные относятся
к композиции открытого Reader. Не объединяйте их в единый глобальный Reader
state только ради меньшего количества providers: они имеют разную частоту
обновления и разные lifecycle.

Яркость применяется к платформе до ожидания записи preferences. Проверки intent
и lifecycle не позволяют старому System action, platform read или activation
перезаписать более новое значение slider.

### Позиция и восстановление

После готовности документа Reader применяет initial или сохранённую позицию.
Text CFI описывает место в документе; visual page index зависит от pagination.
Размер шрифта или окна может изменить число страниц без изменения CFI.

ReaderBloc сериализует position writes и использует trailing debounce 500 ms.
Закрытие bloc дожидается queued/active writes. Live article progress обновляется
отдельно, раз в кадр; частота записи в DB не определяет плавность верхней линии.

Если section из CFI найдена, но node offset больше не разрешается,
Reader открывает начало этой section. Если отсутствует сама section,
он использует сохранённую fraction, а затем первую linear section.
Versioned bookmarks сохраняют word anchor собственной страницы и переживают
repagination; legacy anchors используют старый visual-page fallback.
CBZ page order также versioned: новым imports присваивается natural order,
старым нельзя автоматически менять page indices с сохранёнными highlights.

### Selection, actions, highlights

В текстовых книгах и статьях selection реализована Flutter SelectionArea
с адаптивными handles и magnifier. У PDF собственный PdfTextOverlay с handles
и painter; это не SelectionArea и не нативный PDF viewer. DjVu использует
собственный DjvuTextOverlay по сохранённым word zones.
Pagecraft преобразует selection в text/CFI/context. Action контракты
передаются app shell, затем открывается нужный feature sheet.

У text highlights используется CFI range; у comic/image-area highlights —
page index и нормализованный rectangle. Color/note обновляются частично,
чтобы старый UI snapshot не затёр другое поле. Mutation effects сообщают
успех после результата repository, а не сразу после enqueue события.

Area selection в комиксах и scan-only DjVu обрабатывается в Pagecraft:
один палец владеет жестом, синие треугольные области с диагональными стрелками
в углах служат для изменения размера без линий и рамки. Их увеличенные зоны захвата
выходят за выделение и адаптируются у края страницы.
Reader получает начало/конец adjustment и
итоговые координаты; движение каждого пикселя не перестраивает app UI.
Меню скрывается на время изменения области, сохраняя выбранный цвет.
Cancel, тап снаружи и Back снимают выделение в движке и Cubit согласованно;
note sheet удерживает draft непосредственно в движке, без временной защиты
от следующего clear.

Undo удаления highlight использует domain snapshot и transaction восстановления
с исходным ID и review state. Удалённый source не должен создаваться заново
через Undo. Проверяйте `test/reader_highlight_review_undo_test.dart` и тесты
repository при изменении этих контрактов.

### Платформа и dispose

Brightness/keep-awake делегируются ScreenControlService; widget UI не вызывает
platform adapter напрямую. Thumbnail previews запрашивают только видимые tiles,
очередь ограничена; закрытие tab освобождает cache. Closing reader должен
закрыть документ/controllers и native sessions, не закрывая app database.

Native selection handle dragging, VoiceOver/TalkBack и физические жесты
требуют device-проверок: наличие widget semantics и synthetic drag не доказывает
нативное поведение.

## 9. Pagecraft — форматы, Dart и Rust

Pagecraft — самостоятельный Flutter/Dart reader package с публичными
format-библиотеками, views и моделями движка. Он не зависит от доменных
пакетов Readflex, но его native build prerequisites остаются требованиями
для другого приложения-потребителя.

### Реальные границы реализации

| Контент | Открытие / тяжёлая часть | Отображение |
| --- | --- | --- |
| EPUB | Dart ZIP/container, metadata, XHTML/CSS | TextPagesView |
| FB2 | Dart: полное чтение XML-файла или FB2 entry | TextPagesView |
| MOBI / AZW3 / KF8 | Dart parser + Rust text-record I/O/decoding | TextPagesView |
| CBZ | Dart ZIP, image bytes по запросу | FixedPagesView |
| PDF | PDFium через pdfrx_engine | FixedPagesView |
| DjVu | C++ DjVuLibre через Dart FFI | FixedPagesView |
| Saved article | Dart HTML loading/normalization | TextScrollView |

Не все форматы читаются одинаково. ZIP читает central directory и нужные
entries по offsets вместо распаковки всего архива. MOBI имеет record offsets.
FB2 reader читает XML-файл или выбранный FB2 ZIP entry целиком перед XML
processing. Это возможность format reader; import UI по-прежнему ожидает plain FB2.
Формат файла
и дальнейшая lazy pagination — разные уровни; наличие offset I/O не означает,
что любой parse или layout выполняется без полной подготовки section.

### Что делает Rust

В production Rust используется только внутри MOBI/KF8 text backend:
record I/O, trailing-entry removal, PalmDOC и HUFF/CDIC decompression.
MOBI headers, combined-file selection, metadata, resources, реконструкция
глав, DOM/CSS preparation и layout остаются Dart.

FRB `2.13.0` связывает Dart wrapper с crate `pagecraft_mobi_native`
внутри единого пакета Pagecraft. MOBI 6 читает text batch; KF8 сохраняет
on-demand reads и Dart range caches. Native session открывается лениво,
сериализует операции и дожидается их перед освобождением handle.
Ошибка native read становится PagecraftException; silent fallback отсутствует.
HUFF/CDIC имеет общий бюджет 64 MiB на packed/decoded dictionary, metadata
записей и временный recursive output. Повторяющиеся offsets не обходят лимит;
ошибка расширения восстанавливает packed entry для корректного освобождения.

Dart implementation сохраняется как explicit parity reference:
`MobiContainer.open(..., useDartTextReader: true)` или диагностический define
`PAGECRAFT_MOBI_USE_DART=true`. Это инструмент сравнения, не настройка UI.
Rust XML/HTML/ZIP кандидаты в benchmarks остаются экспериментами;
их наличие не означает использование в приложении.

### Как открывается PDF

После repository source load PDF adapter открывает файл через PDFium,
получает page metadata и предоставляет страницы движку FixedPagesView.
Изображение страницы rasterize-ится по необходимости; PDF не конвертируется
в EPUB или HTML целиком. Zoom повышает render density в pixel budget,
а затем использует sharp tiles для видимой области.

Text extraction используется для search/selection и synthetic anchors.
PDF capabilities зависят от содержимого: скан без text layer нельзя считать
поисковым только потому, что файл имеет расширение PDF. PDFium здесь
не является OCR workflow. Previews имеют отдельную ограниченную очередь.

### Как открывается DjVu

DjVu использует готовый C++ decoder DjVuLibre 3.5.30 с узким C API и Dart FFI.
Для него не добавлялся Rust/FRB слой. DjvuBook владеет worker isolate и native
document: opening, rendering и чтение hidden text выполняются последовательно
в worker, не блокируя UI isolate. Close дожидается принятых операций и закрывает
document один раз.

DjvuPages реализует FixedPageSource, поэтому переиспользуются перелистывание,
Slide/Cover, zoom, spreads и thumbnails. На open читаются page headers и
navigation; bitmaps и текст запрашиваются по мере необходимости. Full-page
render ограничен шестью миллионами pixels; при сильном zoom декодируется
нужный region. Whole-document bitmap cache не создаётся.

Stored hidden text задаёт word zones; по ним работают search, selection,
text actions и сохранённые text highlights. Это отдельный формат якорей с
маркером pagecraft-djvu, а не PDF text anchors. Page без hidden text имеет
только image-area selection и не получает текст через OCR автоматически.
Если source содержит только line/page zones, selection сохраняет эту более
грубую точность; выдуманные word/glyph coordinates не создаются.

Поддерживаются single-page и bundled multi-page documents. Indirect документы
из нескольких файлов и standalone external includes отклоняются. Optional
JPEG-in-DjVu codec в этой сборке выключен. C++ sources поставляются в checkout
и собираются platform toolchain, установленная системная DjVuLibre не нужна.
В vendored release применено upstream исправление ограничения вложенности INCL;
циклические bundled includes проверены regression test и завершаются typed error.
Нативный компонент имеет GPLv2-or-later license; при распространении linked
build необходимо учитывать её условия отдельно от MIT notices остального кода.

### Layout и направление чтения

Text book pipeline: формат → sections/resources → normalized document →
styles → box tree → paragraph/column layout → pagination → Flutter rendering.
Articles используют scrolling path; image/PDF sources — fixed pages.
Publisher JavaScript не исполняется. WebView и локального reader server
в текущем runtime нет; старые anchors поддерживаются для compatibility.
При новом импорте статьи sentence spans сохраняют исходную пунктуацию и
пробелы. Уже сохранённый HTML не пересоздаётся, чтобы не сдвинуть reading
positions и привязки highlights/bookmarks.

Page progression определяется metadata книги и bounded content sample,
независимо от locale интерфейса. RTL UI и RTL source — отдельные случаи.
Нельзя делать направление перелистывания только по языку телефона.

Slide/Cover — стратегии page transition, выбранные в Library Display.
Source appearance не владеет глобальным выбором анимации. Новая стратегия
должна сохранять physical/logical direction, cancellation и selection continuity.

Вертикальный текст и sources с fixed-layout flag, включая EPUB и KF8,
сейчас отклоняются TextBookUnsupported. Не следует обещать полный browser CSS
или весь EPUB spec по факту использования собственного layout engine.
ZIP CRC verification остаётся описанным ограничением.

### Native build и standalone использование

`packages/pagecraft/hook/build.dart` собирает locked Rust crate в release mode
и включает native library через Native Assets. PDFium подключается как platform
native library:
через native assets на Android и XCFramework на Apple. Hook также компилирует
vendored C++ DjVuLibre и включает её через native assets.
Эти зависимости собираются/пакуются даже у потребителя, который импортирует
другой формат Pagecraft. Установка только Dart dependency не устраняет
необходимость rustup и соответствующего platform toolchain.

Bindings и lockfiles versioned; вручную bindings не редактируют.
Для изменения Rust API сначала меняется исходный API, затем генерация
закреплённым инструментом, после неё Rust tests и parity/adapter tests.

```sh
make analyze-pagecraft-mobi-rust
make test-pagecraft-mobi-rust
# Только когда менялся bridge API:
make generate-pagecraft-mobi-native
```

Подробности и tests: [Pagecraft README](../packages/pagecraft/README.md),
[native backend](../packages/pagecraft/doc/mobi_native.md),
`integration_test/mobi_native_test.dart`.

## 10. Перевод, словарь и модели offline

### Контекстный перевод

TranslateCubit создаёт versioned request: selected text, surrounding context,
source anchor, languages и mode. Короткий lexical selection и перевод целого
фрагмента используют разные modes. Request/response validation проверяет
schema, enums, request ID, mode и структуру ответа.

ContextualTranslationCoordinator сначала проверяет memory cache, затем remote
provider. Default LRU — 128 результатов, 30 минут от записи. Cache не
сохраняется на диск. Offline cache hit сначала пробует remote, чтобы восстановить
контекстный результат после возврата сети; уже открытый sheet сам не обновляется.

Fallback ML Kit включается при typed network/unavailable failures и HTTP
408/429/5xx. Authentication, validation и malformed response не маскируются
offline переводом. Отмена запроса также не запускает fallback.

### Загрузка языковых моделей

Native ML Kit engine находится в APK/IPA. Языковые модели — отдельные
on-demand downloads. Нужен конкретный source language; адаптер проверяет
готовность source/target через ML Kit SDK. Количество физических файлов
и загрузок определяет SDK. Если модели отсутствуют, требуется явное согласие на загрузку
и connectivity. На новой установке в airplane mode offline перевод
не гарантирован.

Поддерживаемые адаптером языки ограничены десятью языками приложения,
а не всеми языками SDK. Нативный translator переиспользуется для текущей пары,
закрывается при смене пары, ошибке, dispose и двух минутах без запросов,
дожидаясь завершения уже выполняемой операции.

HTTP запрос можно abort-ить при закрытии sheet или смене языка, но это не
гарантирует остановку server-side provider job. Запущенную ML Kit translation
API не позволяет прервать: stale result отбрасывается и не кэшируется.

### Ошибки и языковые исходы

Same-language — нормальный исход «Nothing to translate», а не повод запускать
другой provider. Языки сравниваются по primary subtag. Response с неверным
target language получает invalidResponse; клиент не умеет надёжно доказать,
что backend написал текст на заявленном языке.

Pronunciation/reading и contextual expression являются optional hints
translation response. Они не означают отдельный гарантированный dictionary
lookup или проверенные словарём сведения.

### Dictionary

Платформенный system lookup пробуется до Readflex Dictionary API.
Нативный dictionary UI не содержит нашего Save; Readflex fallback sheet
может сохранять слово через DictionaryRepository. Сохранение учебных слов
есть также в translation UI. Не смешивайте HTTP dictionary service
и persistence repository только из-за похожего имени.

Одна app-owned HTTP connection pool используется article cleaner API,
translation и dictionary. Connect timeout 10 s позволяет недоступному host
дать network outcome; default idle timeout 15 s. Untrusted publisher pages
имеют отдельный pinned client.
`bounded_http` ограничивает фактически полученные, в том числе распакованные,
байты backend response: 1 MiB для translation/dictionary и 16 MiB для cleaner.
Один deadline покрывает headers и body. Превышение лимита или timeout отменяет
конкретный запрос и body subscription, сохраняя shared client для следующего.
JSON cleaner response от 256 KiB разбирается и маппится в отдельном isolate;
для малых ответов сохраняется прямой путь без запуска isolate.

Контракты: [translation service](../packages/contextual_translation_service/README.md),
[dictionary service](../packages/dictionary_service/README.md),
[dictionary repository](../packages/dictionary_repository/README.md).

## 11. Practice и FSRS v6

### Content отдельно от schedule

DictionaryRepository хранит слово/meaning/anchors. HighlightRepository хранит
текстовое выделение. FsrsRepository хранит stability, difficulty, due time,
reps/lapses и review log; FSRS v6 алгоритм находится в review_scheduler.
Сохранение content регистрирует review item в той же transaction.

```text
Save word / text highlight
     -> content row + review row
     -> Practice loads review queue
     -> hydrate content through its repository
     -> user rating
     -> FSRS v6 calculates next state
     -> persist state and log
```

Активные типы — saved words и text highlights. Image-area highlights
не участвуют в review. Legacy flashcard enum/table оставлены ради compatibility.
Review table keyed по itemId, поэтому IDs разных reviewable content должны
быть глобально уникальны.

PracticeItemLoader получает content batches по типам. Первые word anchors
читаются через DictionaryRepository SQL-пакетами до 500 IDs, как и в Vocabulary:
отдельного запроса на каждое слово нет. Выбирается самый ранний anchor,
при одинаковом createdAt — первый вставленный. Hydration и scheduler — разные
затраты. Vocabulary прекращает дальнейшие чтения после устаревания load.

### Время и due badge

FSRS рассчитывает nextReviewAt после rating. Library не запускает scheduler
каждую минуту: repository одним snapshot читает due count и earliest future
deadline для разрешённых типов. Foreground Library ставит один таймер
на следующий deadline и после срабатывания перечитывает narrow queue status.
Так число может измениться с 1 на 2 без взаимодействия пользователя.

При уходе в background таймер отменяется, при resume status читается сразу.
Ошибка status read сохраняет старый count и планирует retry через минуту,
пока приложение активно. Это retry ошибки, а не обычный периодический polling.
Notification scheduling в ОС этим механизмом не реализовано.

Practice floating icon показывается только при наличии destination
и положительного due count. Badge показывает `99+` начиная со 100,
полное число остаётся в semantics и текстовых областях. Review highlights
preference влияет и на очередь, и на Library count.

### Сессии и известное ограничение Remove

Practice имеет due sessions, Review ahead и source-scoped sessions. FSRS
интервалы и подписи ratings зависят от desired retention. Статистика использует
study day с границей 04:00; due instants и отображение локального времени
не следует заменять сравнением только календарных дат.
События карточки несут ID и revision показанного экземпляра. Rating, Remove,
Reveal и restart обрабатываются одной последовательной очередью; повторный
tap не оценивает следующую карточку. На время записи controls отключены,
а для word rating требуется раскрытый ответ.

Команда Remove в review session удаляет review row, сохраняя content.
Для text highlights существует legacy backfill при последующей загрузке:
он может снова зарегистрировать такой highlight. Это существующее поведение,
а не полноценный persistent suspend workflow. Решение о его изменении
требует отдельной продуктовой задачи и тестов, а не правки документации.

Practice settings обновляются в памяти через PreferencesService.
Disk-write failure сервис логирует, сохраняя и публикуя in-memory snapshot;
нельзя обещать rollback выбора при любой ошибке диска. Ошибка, реально
проброшенная операцией update, обрабатывается Cubit отдельно.

Новый reviewable type требует не только enum: нужны content lifecycle,
save/delete registration, storage handling, hydration и UI в Practice.
TTS Listen и daily reminders сейчас не реализованы.

Подробнее: [Practice](../packages/features/practice/README.md),
[FSRS repository](../packages/fsrs_repository/README.md),
[scheduler](../packages/review_scheduler/README.md).

## 12. UI, планшеты, локализация и доступность

### Единая система компонентов

ComponentLibrary содержит Theme, tokens, typography и reusable controls.
Bottom sheets используют общие компоненты и layout contracts. Новому экрану
не нужен собственный набор случайных радиусов, цветов и motion durations.
Сначала найдите существующий компонент и договорённости его README.

Appearance, layout и другие UI preferences могут иметь отдельные Cubit.
View не должен обращаться к PreferencesService напрямую. Source reader
appearance накладывается на global defaults; reset удаляет source override,
а не переопределяет глобальную page animation.

### Планшеты и размер окна

Адаптация зависит от constraints окна, включая Split View, а не только от
названия устройства. AppWindowSize.isWide — минимум 840 × 480 logical pixels.
Library content frame ограничен 1200dp, empty-state actions — 480dp;
list может отображаться в две колонки, grid добавляет columns вместо чрезмерного
растягивания covers. Сохранён cover-only grid.

Popup/overlay должен позиционироваться относительно content/control geometry
и system insets. Оверлей яркости, contextual actions и keyboard sheets
проверяйте в portrait, landscape и узком tablet window.

### Локализация и RTL

UI strings находятся в readflex_localizations, не в пустых per-feature l10n
каталогах. Меняйте source localization files и используйте установленную
в пакете генерацию; generated Dart вручную не исправляйте.

Проверяйте короткую и длинную строку, 2× text scale, compact phone,
landscape, light/dark и phone RTL. Tablet RTL screenshot не заменяет phone RTL:
на телефоне другие constraints и overflow. Directional geometry используйте
для UI; source progression книги определяется отдельно.

### Доступность

Встроенные Flutter semantics предпочтительны. Custom interactive surfaces
должны сообщать label, role, enabled/selected state и действие без
дублирующихся focus nodes. Icon-only control требует понятного tooltip/label.
Не уменьшайте touch target до размера glyph ради плотности.

Widget tests проверяют semantic tree, но не запускают VoiceOver/TalkBack.
Настоящую навигацию, чтение selection и system context menus проверяют
на устройстве с соответствующим OS screen reader.

Источники: [ComponentLibrary](../packages/component_library/README.md),
[ACCESSIBILITY](../ACCESSIBILITY.md), [UI checklist](../test/ui/README.md).

## 13. Проверки и тестовые окружения

### Основные команды

| Команда | Что проверяет |
| --- | --- |
| `make format-check` | Dart formatting без переписывания файлов |
| `make analyze` | Root/packages analyzer, архитектурные проверки, Rust fmt/Clippy |
| `make check-architecture` | Граф production-пакетов, widget helpers и зависимости View |
| `make test` | Rust и normal Dart/Flutter suites, tooling tests |
| `make verify` | Formatting + analyze + test |
| `make test-tools` | Изолированные Dart development tools |
| `make test-ui-contracts` | Shared UI contracts и representative flows |
| `make test-ui` | Root flows и exact golden comparisons |
| `make test-performance` | Repeatable host workloads |
| `make profile-ui DEVICE=<id>` | Profile-only UI timings с проверкой устройства и отсутствия личной установки |

Для focused изменения сначала допустим package-level flutter test;
shared contract, schema, composition и reader changes требуют более широкого
набора. Не заменяйте проверку поведения наличием успешно скомпилированного UI.

### Изоляция тестов

Root UI tests монтируют production AppScopes и router с реальными repositories,
но memory SQLite, временными files и deterministic external services.
Production composition и API keys не используются. Test-only fakes не должны
попадать в обычный entry point или создавать второй production data path.

Native suites используют те же принципы изоляции и реальные views движка.
Fixtures — собственный текст, generated CBZ/PDF; книги пользователя не входят
в общую test suite. Установка test build всё же может заменить приложение
с тем же bundle ID: выделенный simulator/emulator удобнее устройства
с единственной копией важных данных.

```sh
make test-device DEVICE=<id>
make test-phone DEVICE=<phone-id>
make test-tablet DEVICE=<tablet-id>
make test-tablet-layout DEVICE=<tablet-id> ROTATION=1
```

Диагностика и screenshots сохраняются в `.local/ui-device/run-*/`.
Они не являются cross-device pixel goldens. Для актуальных prerequisites
и отдельных native сценариев используйте test/ui README.

### Goldens

Baselines проверены на macOS arm64 с Flutter 3.50.0: при миграции сопоставлены
568 полноэкранных снимков со старой версией. Exact equality зависит
от engine и rasterizer; смена SDK/host требует осмысленного baseline review.
`make test-goldens` сравнивает, `make update-goldens` намеренно обновляет.
Нельзя регенерировать картинки, чтобы скрыть непонятный failure.

Changed control проверяют в default, selected, disabled, loading и error
states, где применимо. Нужны overflowing content, large text и phone RTL.
Screenshots должны иметь одинаковые viewport, locale, theme и text scale
для сравнения before/after.

### Coverage

`make coverage` собирает Dart line/branch coverage в новом `.local/coverage/`
report. Native run с `COVERAGE=1` даёт Dart line hits после interaction tests.
Merge возможен только при совпадении input hashes; это union hits, а не
среднее процентов. Native plugin Swift/Kotlin/Rust execution не превращается
от этого в Dart coverage.

### Что остаётся проверять на устройствах

Native selection handles и edge dragging; VoiceOver/TalkBack; process death
и app switching; GPU/context loss; реальные permissions/file picker;
system dictionary; model downloads; airplane mode; backend authentication
и качество provider; physical-device release performance. Synthetic lifecycle
и widget semantics не доказывают эти свойства.

VoiceOver/TalkBack в текущей UI-проверке отложены; успешные widget и emulator
сценарии не означают, что эти ручные проверки выполнены.

## 14. Производительность и измерения

### Сначала определите измеряемый этап

Startup, import, opening, parse/layout, frame timing, peak memory и APK size —
разные метрики. Например, host XML parse не отвечает на вопрос времени первого
нарисованного кадра на Android, а размер AAB upload не равен download size
конкретного устройства.

В normal suites есть структурные guardrails: bounded mounted Library tiles
при 20k items, cached projections, bounded search emissions/copies,
ограниченные очереди previews. Они защищают от определённых регрессий,
но не обещают FPS или memory budget.

### Сравнение Dart и Rust

Используйте frozen dataset с hashes, одинаковые inputs и output parity,
одинаковый SDK/build mode/device. Сохраняйте raw samples, warmups, median/p95,
memory definition и сведения о системе. Запускайте сравнение без параллельных
builds, coverage и emulator workloads.

`benchmarks/mobi_rust` — исторический изолированный FRB experiment.
`benchmarks/reader_native` сравнивает ZIP/XML/HTML кандидаты и production
MOBI backend с explicit Dart reference. Переносить эксперимент в runtime
только по одному удачному microbenchmark нельзя: нужны parity, startup,
bridge costs, allocation/memory и end-to-end влияние.

FB2/XML и остальные экспериментальные Rust parts сейчас не заменяют Dart.
Решение о сохранении текущей реализации отражено в production graph;
новому участнику не нужно «доделывать» перенос только из-за наличия benchmark.

### Native harness и его границы

`native_books_open_test.dart` измеряет production import metadata/copy/insert,
Library tap → mounted first page и turn. База в этом harness in-memory,
files настоящие временные; durable DB fsync и OS picker не измеряются.
Readiness polling и caches влияют на результат; mounted не равнозначен
физическому первому pixel и полному image decoding.

`pagecraft_text_engine_test.dart` разбивает preparation/layout/pagination,
`article_performance_test.dart` проверяет fixture article. Сохраняйте
recorded build mode, viewport и raw rows. На физическом устройстве используйте
profile mode. iOS Simulator поддерживает debug, поэтому его timings
не предсказывают physical release latency.

Для UI есть отдельный `make profile-ui DEVICE=<id>`: host проверяет точный ID
и physical/emulator status через закреплённый Flutter, затем запускает
`native_ui_performance_test.dart` в profile mode. На физическом устройстве
наличие Readflex или неопределённый результат проверки установки блокирует
запуск до сборки: обычный `flutter drive` может заменить и удалить приложение.
Используйте выделенное тестовое устройство; сохранение существующей личной
установки — отдельный workflow из [UI verification](../test/ui/README.md).

Harness прогревает Search с системной клавиатурой, Reader chrome, Appearance
и прокрутку длинного Highlight, затем измеряет по 12 циклов. Он сохраняет
raw `FrameTiming`, временные окна и nominal display refresh rate. Метаданные
устройства — `.local/performance/native-ui/run-*/device.json`, измерения —
`.local/ui-device/run-*/results.json`; храните их вместе. `ALLOW_EMULATOR=1`
разрешает только диагностический emulator run с `physicalDevice: false`.
Flutter build/raster durations не включают отрисовку системной клавиатуры
и compositor; это не end-to-end FPS. Физический FPS текущей UI-проверкой
не установлен.

Полный process startup текущие специальные harnesses не измеряют. Для engine
startup есть Flutter trace; сохраняйте файлы до повторного запуска:

```sh
fvm flutter run --profile --trace-startup -d <physical-device-id>
```

Engine-entry → frame не включает весь OS launch и не гарантирует готовность
Library data. Подробная методика и команды — [benchmarks README](../benchmarks/README.md).

## 15. Конфигурация, Android/iOS и выпуск

### Environment и секреты

ENVIRONMENT принимает DEV, STAGING или PROD. Без explicit value debug
использует DEV, release — PROD. Но локальный run.sh template явно выбирает
DEV, в том числе при `./run.sh --release`: build mode и environment независимы.

READFLEX_API_KEY разрешён только для DEV. Статический ключ внутри APK/IPA
не является секретом; конфигурация отклоняет его в STAGING/PROD.
Production short-lived server-issued auth/attestation ещё не реализована.
Эта задача блокирует безопасную production интеграцию с backend.

Public production endpoint в config не является credential. Staging endpoint
задаётся явно. Contextual translation и dictionary по умолчанию используют
тот же base host, что article cleaner. Legacy ARTICLE_CLEANER_API_KEY
остаётся development alias, а не новой auth-схемой.

GlitchTip использует Sentry-compatible SDK: GLITCHTIP_DSN, fallback SENTRY_DSN.
Без DSN работает NoopErrorReporter; analytics остаётся NoopAnalyticsReporter.
Trace sample rate управляет sampling созданных transactions и сам не
инструментирует все пользовательские действия.

### Android artifacts и подпись

Для release нужен upload keystore. Настройте ignored key.properties из
versioned example или READFLEX_ANDROID_* variables по Gradle contract.
Получите доступ и backup ключа у владельца отдельно; не создавайте другой
ключ под видом восстановления существующей подписи.

```sh
make build
make build-apk
make build-apk ARGS='--target-platform android-arm64'
```

`make build` создаёт signed AAB для Play; `make build-apk` — separate APKs
по ABI с icon-font subsetting. Обычный `flutter run --release` предназначен
для запуска и сохраняет полные icon fonts. Не используйте его APK как
единственный показатель оптимизированного store artifact.

Список APK: `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`,
`app-x86_64-release.apk` в `build/app/outputs/flutter-apk/`.
Собираются только запрошенные architectures. Gradle согласует native libraries
с target-platform; default AAB сохраняет все необходимые ABIs.

```sh
make analyze-apk \
  APK=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
  ARGS='--expect-abi arm64-v8a --output .local/reports/apk.json'
```

APK analysis проверяет ZIP metadata, compressed/uncompressed contributions
и native ABI; он не измеряет installed size или качество runtime.
Весь ML Kit native engine, PDFium, SQLite и Rust MOBI code остаются
функциональными зависимостями. Downloaded translation models не следует
считать заранее упакованными только из-за размера native ML Kit library.

Make targets не загружают private run-defines автоматически. Для локального
оптимизированного DEV APK их передают явно, как описано в README;
такой build не предназначен для публичного распространения.

### Symbols и iOS

Release Make targets сохраняют Dart symbols в
`.local/symbols/android/<UTC timestamp>/`. Архивируйте matching symbols
вместе с exact APK/AAB и revision в долговременном release storage;
ignored `.local/` не является таким архивом. Obfuscation этими targets
не включена.

Для iOS нужны signing team, provisioning и App Store Connect access,
а не только Podfile.lock. Flutter release build требует обычной Apple signing
процедуры. Simulator build не подтверждает device provisioning или App Store
готовность. Владельцы Apple/Google аккаунтов и права доступа не установлены
по этому checkout и передаются отдельно.

### Условие готовности выпуска

Сборка artifact — один шаг. До публичного выпуска нужны production auth,
проверенная конфигурация, matching signatures/symbols, real-device smoke,
model consent/offline scenarios и review текущих продуктовых ограничений.
Список ниже описывает действующие пробелы, а не новые реализованные функции.

## 16. Ограничения и незавершённые контракты

| Область | Текущее состояние | Последствие |
| --- | --- | --- |
| Production backend auth | Short-lived flow отсутствует | Release integration blocker |
| Analytics | NoopAnalyticsReporter | Нет ожидаемой product telemetry |
| Error reporting | Реально только с DSN | Без настройки нет remote error capture |
| Text layout | Нет vertical/fixed-layout text books | Соответствующий source даёт open error |
| Native assets | Rust/PDFium/DjVuLibre пакуются для Pagecraft | Нужны native toolchains, есть size cost |
| DjVu decoder | Нет indirect documents и JPEG-in-DjVu | Такие источники отклоняются |
| FB2 | Полное чтение файла | Нельзя обещать offset-based I/O для всех formats |
| ZIP integrity | CRC verification не реализована | Ограничение контейнерной проверки |
| Practice | Нет TTS/daily reminder | Не обещать эти сценарии |
| Review Remove | Text highlight может backfill-иться | Нет постоянного suspend semantics |
| Preferences | Disk failures логируются | In-memory выбор может не пережить restart |
| CI | Quality workflow: форматирование, анализ, тесты и goldens | Remote результат проверяется отдельно; device/FPS вне CI |

Legacy flashcard/profile/subscription/auth/AI/notification surfaces находятся
вне активного графа. Последняя legacy revision — `189e2cc1`.
Не восстанавливайте их автоматически из таблиц, старых enum или истории:
это отдельное продуктовое решение. Текущая Practice — активный сценарий
на централизованном FSRS, а не подключённый старый flashcard screen.

No-op/false callbacks и platform limitations необходимо читать вместе
с короткими комментариями и tests. Документационная актуализация не является
разрешением незаметно реализовать отсутствующую интеграцию.

## 17. Передача доступов и эксплуатационной информации

Репозиторий объясняет клиентские контракты, но не устанавливает владельцев
внешних систем. Передача проекта завершена только после того, как новая команда
может воспроизвести окружение и понимает, у кого получить нужный доступ.

| Что передать | Где/как подтвердить | Что не хранить в PDF |
| --- | --- | --- |
| Backend repos и deploy environments | URL репозиториев, release/runbook, ответственный | Tokens и private deploy credentials |
| DEV API access | Проверенный local request и scope ключа | Сам API key |
| Production auth plan | Backend/client contract и владелец задачи | Несуществующий flow как готовый |
| Android signing | Certificate identity, secure backup, доступ | Keystore/password |
| Apple signing и store access | Team, роли, provisioning, renewal owner | Private keys и recovery codes |
| Google Play | App ownership, upload flow, release roles | Service account secret |
| GlitchTip | Project, dashboards, alert ownership | Private access tokens |
| Domains и API hosting | DNS/TLS renewal, incident contact | DNS/provider passwords |
| Release archive | Revision, artifacts, symbols, signing identity | DEV-configured публичный APK |
| Test corpus | Право использования и место private fixtures | Книги пользователя без разрешения |

Эта таблица — перечень для передачи; она не утверждает, что доступы уже
проверены или что соответствующий backend deployment доступен новой команде.
Передавайте секреты через установленное защищённое хранилище организации.

### Практическое принятие проекта

Новая команда должна получить clean checkout, восстановить toolchains,
запустить анализ и тесты, открыть fixture book/article и выполнить local
device build. Затем — с согласованными доступами — проверить реальные backend
контракты и signing. Храните результаты с revision и environment,
чтобы отличать проблему окружения от регрессии исходников.

## 18. Типовые изменения и поиск неисправностей

### Изменить UI или новый control

Найдите owning feature и существующий компонент. Передавайте результат
через event/callback, переиспользуйте tokens, semantics и Cubit boundaries.
Проверьте states, content overflow, large text, light/dark и phone RTL.
Shared UI change требует test-ui-contracts плюс relevant feature/golden tests.
Baseline изменяется после объяснения и визуального review.

### Добавить repository field

Пройдите весь путь: domain model → schema/upgrade/index → mapper → repository
API → Bloc/state → UI. Сохраните partial update semantics у независимых
операций. Для миграции добавьте representative historical fixture и проверьте
не только новую установку. Обновите README owning packages.

### Изменить Pagecraft или Rust

Сначала воспроизведите на минимальном допустимом source и заморозьте inputs.
Изменение anchors должно сохранять старые CFI/article anchors, source order
и bookmarks. Rust API change требует regenerated bindings и parity через FRB,
а не только cargo unit test. Измеряйте production path с bridge, не отдельную
функцию в изоляции как окончательное доказательство ускорения приложения.

### Неполадки запуска и сборки

| Симптом | С чего начать |
| --- | --- |
| Bootstrap recovery screen | Config validation и bootstrap logs; не feature View |
| Backend unauthorized | DEV key/environment; auth failure не запускает offline fallback |
| Gradle/Java parse или class-version error | Flutter-selected JDK, wrapper, installed SDK; полный stacktrace |
| Native library отсутствует | Rust target, build hook, packaged ABI, Native Assets logs |
| Устройство отвергло APK | Signing/OS install confirmation; успешная сборка не равна установке |
| Зелёный widget test, плохой device gesture | Native selection/OS overlays, device screenshots |
| Golden failure на другой машине | Pinned Flutter, host/rasterizer, registered fonts |
| Огромный APK | ABI list, split APK vs universal, fonts, compressed native contributions |
| Badge не соответствует ожиданию | Stored due instant, eligible types, foreground/resume и queue errors |

При отладке не публикуйте raw private defines, access keys и provider response
bodies. Сохраняйте минимальный воспроизводимый case и diagnostics под `.local/`.
Секреты могут попасть в process arguments и verbose logs; перед передачей
диагностики проверяйте её содержимое.

## 19. Индекс исходников и сопровождение руководства

### Оболочка и инфраструктура

- [starter.dart](../lib/app/starter.dart),
  [app_bootstrap.dart](../lib/app/app_bootstrap.dart): запуск и recovery.
- [composition.dart](../lib/app/composition.dart),
  [resource_disposer.dart](../lib/app/resource_disposer.dart): создание и cleanup.
- [routing.dart](../lib/app/routing.dart),
  [application_config.dart](../lib/app/config/application_config.dart): wiring/config.
- [Makefile](../Makefile), [run.sh](../run.sh): команды и private DEV setup.
- [AGENTS.md](../AGENTS.md): operational conventions для coding agents.

### Хранение и сценарии

- [local_storage README](../packages/local_storage/README.md): schema и migration.
- [Library README](../packages/features/library/README.md): список, scopes, selection.
- [ImportFlow README](../packages/features/import_flow/README.md): этапы импорта.
- [Reader README](../packages/features/reader/README.md): state/lifecycle map.
- [Pagecraft README](../packages/pagecraft/README.md): engine libraries/algorithms.
- [Practice README](../packages/features/practice/README.md): sessions и queue hydration.
- [Preferences README](../packages/preferences_service/README.md): snapshot/persistence.
- [Remote content policy](../packages/remote_content_policy/README.md): guarded fetch.

### Проверки

- [test/ui README](../test/ui/README.md): commands, profiles, manual gaps.
- [benchmarks README](../benchmarks/README.md): measurements and evidence.
- [native MOBI notes](../packages/pagecraft/doc/mobi_native.md): setup/parity.
- [UI contracts](../packages/component_library/README.md),
  [accessibility](../ACCESSIBILITY.md): component/semantics rules.

### Как поддерживать актуальность

Этот файл — редактируемый источник русского handoff PDF. При изменении
package boundaries, core flows, build prerequisites или production gaps
обновляйте его вместе с ARCHITECTURE, C4 и owning README. Мелкая внутренняя
перестановка widgets обычно не требует пересказа всего руководства.

Экспорт хранится в `.local/handoff/Readflex-Team-Handoff.pdf`, рядом с ним
можно хранить manifest revision и rendering diagnostics. Их не следует
считать автоматически опубликованными или versioned release artifacts.
Команда воспроизведения и отдельные PDF dependencies описаны в
[инструкции экспорта](README.md); генератор — `scripts/render_handoff.py`.
Перед передачей PDF проверьте дату, source revision, links и отсутствие
секретов; передавайте соответствующий checkout или ссылку на revision.
