# Сборка под Android: пошаговая инструкция

Пресет экспорта уже лежит в проекте (`export_presets.cfg`, пресет «Android»): пакет `com.arturan.ruins`, архитектура arm64-v8a, ориентация альбомная, в сборку включены карты комнат `rooms/*.txt`, исключены тесты и документы. Осталось один раз настроить компьютер. Все шаги ниже делаете вы: они требуют скачиваний и ваших паролей.

## Что уже есть на этом компьютере

- Android SDK: `C:\Users\artur\AppData\Local\Android\Sdk` (build-tools 36.1.0, platform android-36, platform-tools с `adb`).
- Android Studio с встроенным JDK 21: `C:\Program Files\Android\Android Studio\jbr`.
- Системная Java версии 8: для Godot она слишком старая, её не используем.

## Чего не хватает

1. Шаблонов экспорта Godot 4.7.2 (папка `%APPDATA%\Godot\export_templates` пустая).
2. JDK 17 (Godot официально требует OpenJDK 17).
3. Ключа подписи (debug-ключ для тестов, свой ключ для выпуска).

## Шаг 1. Шаблоны экспорта

1. Откройте проект в Godot.
2. Меню **Editor → Manage Export Templates…**
3. Нажмите **Download and Install** (около 1 ГБ). Дождитесь конца установки.

## Шаг 2. JDK 17

1. Скачайте «Eclipse Temurin 17 (LTS)», установщик `.msi` для Windows x64: <https://adoptium.net/temurin/releases/?version=17>.
2. Установите с настройками по умолчанию. Путь будет похож на `C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot`.

Можно сначала попробовать JDK из Android Studio (`C:\Program Files\Android\Android Studio\jbr`): для экспорта без Gradle он часто подходит. Если Godot напишет, что версия Java неверная, ставьте Temurin 17.

## Шаг 3. Пути в настройках редактора

1. **Editor → Editor Settings…**, слева раздел **Export → Android**.
2. **Java SDK Path**: папка JDK из шага 2.
3. **Android SDK Path**: `C:\Users\artur\AppData\Local\Android\Sdk`.

Если Godot сообщит, что не хватает компонентов SDK: откройте Android Studio → **More Actions → SDK Manager** → вкладка **SDK Tools** → отметьте **Android SDK Command-line Tools (latest)** и **Android SDK Build-Tools**, вкладка **SDK Platforms** → платформу, которую назовёт Godot (обычно Android 14 или 15) → **Apply**.

## Шаг 4. Ключ для отладочной сборки

Откройте PowerShell и выполните одной строкой (подставьте путь к JDK из шага 2):

```
& "C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot\bin\keytool.exe" -genkeypair -v -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
```

Затем в **Editor Settings → Export → Android**:

- **Debug Keystore**: `C:\Users\artur\.android\debug.keystore`
- **Debug Keystore User**: `androiddebugkey`
- **Debug Keystore Pass**: `android`

Этот ключ стандартный и не секретный, им подписывают только тестовые сборки.

## Шаг 5. Сборка и установка на телефон

Вариант А, по кабелю (самый быстрый для тестов):

1. На телефоне: **Настройки → О телефоне** → 7 раз нажать на «Номер сборки» → появится раздел «Для разработчиков» → включить **Отладка по USB**.
2. Подключите телефон кабелем, на телефоне разрешите отладку с этого компьютера.
3. В Godot справа вверху появится значок Android (**Remote Debug**). Нажмите его: игра соберётся, установится и запустится на телефоне.

Вариант Б, файл APK:

1. **Project → Export…** → пресет **Android** → **Export Project…**
2. Снимите галочку **Export With Debug** только для выпускной сборки; для тестов оставьте.
3. Сохраните как `build/ruins.apk`, перенесите файл на телефон и установите (нужно разрешить установку из неизвестных источников).

То же из консоли: `godot --headless --path . --export-debug "Android" build/ruins.apk`.

## Шаг 6. Свой ключ для выпуска (когда понадобится раздавать игру)

```
& "<путь к JDK>\bin\keytool.exe" -genkeypair -v -keystore "C:\Users\artur\keys\ruins-release.keystore" -alias ruins -keyalg RSA -keysize 2048 -validity 10000
```

Пароль и ответы на вопросы придумываете сами. В **Project → Export… → Android → Keystore** укажите файл, alias `ruins` и пароль в полях **Release**. Пароли Godot хранит отдельно от проекта (`.godot/export_credentials.cfg`), в git они не попадают. Сам файл ключа держите вне папки проекта и сделайте его копию: без него нельзя выпустить обновление игры. В `.gitignore` файлы `*.keystore`, `*.jks` и папка `build/` уже исключены.

## Что проверить на телефоне

Управление:

- [ ] Джойстик появляется под большим пальцем в левой половине экрана (ниже полосы HUD), персонаж идёт медленнее при слабом наклоне.
- [ ] Кнопка атаки, переключения оружия и навыка работают, пока левый палец держит джойстик (два пальца сразу).
- [ ] Лук: удержание кнопки атаки натягивает, отпускание стреляет; короткий тап даёт слабую стрелу.
- [ ] Блок: удержание кнопки навыка держит щит; рывок срабатывает по тапу.
- [ ] Кнопка паузы «II» справа вверху нажимается вторым пальцем; системная кнопка «Назад» ставит паузу, в меню — выходит из игры.
- [ ] После паузы с зажатым джойстиком персонаж не идёт сам.
- [ ] Размер кнопок удобен; кнопки не перекрываются вырезом камеры или скруглением экрана.

Картинка и скорость:

- [ ] Ориентация альбомная, при повороте телефона на 180° картинка переворачивается.
- [ ] Пиксели чёткие (без размытия), по краям узкие чёрные полосы на вытянутых экранах — это нормально (соотношение `keep`).
- [ ] 60 кадров в секунду в комнате со стаей жуков и на самом большом участке (5 комнат). Счётчик: **Debug → Visible FPS** недоступен на телефоне, поэтому проще включить монитор в удалённой отладке (вкладка Debugger → Monitors) при запуске по кабелю.
- [ ] Переход между участками (затемнение) занимает меньше секунды.

Забег:

- [ ] Меню → выбор оружия и навыка → забег → смерть → экран итогов → меню.
- [ ] Скрытая панель эксперимента открывается удержанием заголовка RUINS 1,5 с; режим и seed применяются.
- [ ] После забега на телефоне появился лог: `Android/data/com.arturan.ruins/files/logs/<сессия>.jsonl` (на новых версиях Android папку видно через кабель и `adb`: `adb shell run-as com.arturan.ruins ls files/logs` для отладочной сборки, или `adb pull /sdcard/Android/data/com.arturan.ruins/files/logs`).
- [ ] Сворачивание игры и возврат не ломают управление.
