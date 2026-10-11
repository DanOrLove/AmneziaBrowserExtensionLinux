# Amnezia Browser VPN for Linux

A Chromium extension and local Linux Native Messaging host for using an AmneziaWG/WireGuard profile in the browser. The host runs AmneziaWG in a userspace network stack and exposes a SOCKS5 proxy on `127.0.0.1:1080`. Chromium web traffic uses that proxy; Linux system routes and other applications are not changed.


### Windows
 Отдельный репозиторий для Windows-версии: https://github.com/DanOrLove/AmneziaBrowserExtensionWindows
 ### macOS 
 Отдельный репозиторий для macOS-версии: https://github.com/DanOrLove/AmneziaBrowserExtensionMacOS

> **Status:** early prototype. Build and connection behavior still need confirmation on real Linux distributions and browser packages. TCP web traffic is supported; UDP traffic is not tunneled. Review [Limitations and security](#limitations-and-security) before relying on it.

## Русский

### Возможности

- Импорт конфигурации AmneziaWG/WireGuard из файла `.conf` или вставкой текста.
- Локальное хранение нескольких профилей, выбор и удаление профиля.
- Подключение и отключение из всплывающего окна расширения.
- Веб-трафик Chrome, Chrome for Testing, Chromium, Edge, Brave и Vivaldi направляется через локальный SOCKS5 и userspace-туннель AmneziaWG.
- Системные маршруты Linux и трафик остальных приложений не меняются.
- При подключении расширение запрещает WebRTC UDP, который не проходит через SOCKS5.

### Требования

- Linux и Go 1.25 или новее.
- Chrome, Chrome for Testing, Chromium, Microsoft Edge, Brave или Vivaldi.
- Конфиг AmneziaWG в формате WireGuard INI (`[Interface]`, `[Peer]`).
- Подключение к интернету во время сборки, чтобы Go загрузил `github.com/amnezia-vpn/amneziawg-go/v3`.

Native Messaging host собирается для текущей архитектуры Linux и регистрируется только для текущего пользователя. Для другого пользователя установку нужно повторить из его учётной записи. Установщик регистрирует host в стандартном пользовательском каталоге XDG; изолированные версии Snap или Flatpak могут требовать дополнительных настроек доступа к host.

### Установка

1. Скачайте ZIP этого репозитория и распакуйте его в постоянную папку. Не перемещайте и не удаляйте эту папку после установки: манифест Native Messaging хранит полный путь к программе.
2. Откройте терминал и перейдите в корневую папку распакованного проекта. Например:

   ```sh
   cd ~/Downloads/AmneziaBrowserExtensionLinux
   ```

3. Запустите установщик:

   ```sh
   chmod +x ./install.sh
   ./install.sh
   ```

   Скрипт соберёт `native/AmneziaBrowserVpnHost` для текущей архитектуры, зарегистрирует Native Messaging для Chrome, Chrome for Testing, Chromium, Edge, Brave и Vivaldi в пользовательском каталоге конфигурации (`$XDG_CONFIG_HOME` или `~/.config`) и откроет страницу расширений, если найдёт установленный браузер. Права администратора не нужны.

4. Откройте `chrome://extensions` в Chrome или Chromium, `edge://extensions` в Edge, `brave://extensions` в Brave либо `vivaldi://extensions` в Vivaldi.
5. Включите **Режим разработчика**, нажмите **Загрузить распакованное расширение** и выберите папку `extension` внутри проекта.
6. Подтвердите разрешения расширения для управления прокси, настройкой приватности браузера и Native Messaging.

Если браузер был открыт во время регистрации Native Messaging, перезапустите его или перезагрузите расширение на странице расширений.

### Первое подключение и использование

1. Нажмите значок **Amnezia Browser VPN** на панели расширений.
2. В разделе добавления конфига выберите `.conf`-файл или вставьте текст профиля. Укажите имя и нажмите **Сохранить конфиг**.
3. Выберите профиль и нажмите **Подключить**.
4. Откройте веб-сайт в Chromium. AmneziaWG выполняет рукопожатие при первом сетевом запросе; запуск локального SOCKS-прокси сам по себе не подтверждает доступность VPN-сервера.
5. Проверьте внешний IP в браузере до и после подключения. Другие приложения Linux должны продолжать использовать обычное соединение.
6. Для отключения нажмите **Отключить VPN**. Расширение остановит туннель и восстановит прежние настройки прокси и WebRTC.

### Сборка из исходников и обновление

После изменения кода повторно запустите установщик, чтобы пересобрать и зарегистрировать компонент:

```sh
./install.sh
```

Затем откройте страницу расширений и перезагрузите расширение. Профили остаются в локальном хранилище браузера при перезагрузке расширения. При удалении расширения браузер может удалить его локальные данные, поэтому храните исходные конфиги отдельно.

### Удаление

1. Если VPN включён, нажмите **Отключить VPN** в расширении.
2. Удалите расширение на странице расширений браузера.
3. Из корневой папки проекта удалите регистрацию Native Messaging:

   ```sh
   bash ./native/install.sh --uninstall
   ```

4. После проверки, что туннель отключён, при желании удалите `~/.config/AmneziaBrowserVPN` (либо `$XDG_CONFIG_HOME/AmneziaBrowserVPN`, если `XDG_CONFIG_HOME` задан). В этой папке временно хранятся рабочий конфиг с приватным ключом, PID-файл и журнал.
5. Удалите папку проекта, если она больше не нужна.

### Устранение неполадок

- **«Native host has exited» / компонент не найден:** убедитесь, что `native/AmneziaBrowserVpnHost` существует и исполняемый. Повторите `./install.sh`, затем перезапустите браузер.
- **Ошибка Go при сборке:** проверьте `go version` (нужна версия 1.25+) и интернет-соединение; затем повторите `bash ./native/build.sh`.
- **Порт 1080 занят:** закройте приложение, использующее `127.0.0.1:1080`, и подключитесь снова.
- **Сайт не открывается:** проверьте доступность сервера, `PrivateKey`/`PublicKey`, `Endpoint` и параметры обфускации. Журнал компонента находится в `~/.config/AmneziaBrowserVPN/proxy.log` (или `$XDG_CONFIG_HOME/AmneziaBrowserVPN/proxy.log`).
- **Расширение не может изменить прокси или WebRTC:** проверьте политики браузера и другие расширения, которые управляют теми же настройками.
- **Браузер не находит host в Snap/Flatpak:** проверьте документацию пакета и ограничения его sandbox. Установщик поддерживает стандартные пользовательские пути Native Messaging.
- **Браузер не находит host после перемещения проекта:** повторно запустите `./install.sh` из новой папки и перезапустите браузер.

### Ограничения и безопасность

- Это ранний прототип. SOCKS5-мост передаёт TCP CONNECT; UDP-приложения и QUIC не туннелируются. Настройка расширения блокирует WebRTC UDP без прокси, но другие типы UDP-трафика не поддерживаются.
- Успешный запуск означает, что локальный прокси слушает порт. Проверяйте соединение запросом из браузера и сравнением внешнего IP.
- `DNS` в конфиге должен содержать IP-адреса DNS-серверов.
- Анонимный SOCKS5 слушает только `127.0.0.1:1080`. Расширение настраивает прокси Chromium; системный прокси Linux и другие программы не перенаправляются. Локальная программа всё же может обратиться к порту, если знает о нём.
- Профили в `chrome.storage.local` и временный `active.conf` содержат приватный ключ в открытом виде для вашего пользователя Linux. Не публикуйте конфиги. Удаляйте папку данных после отключения, если больше не используете программу.
- Используйте профиль, которым вы вправе пользоваться, и проверьте подключение на своей системе до повседневного использования.

### Структура проекта

- `extension/` — Manifest V3, интерфейс, локальные профили и управление прокси Chromium.
- `native/main.go` — Native Messaging host, настройка AmneziaWG через Go-библиотеку и SOCKS5 TCP CONNECT-мост.
- `native/process_linux.go` — запуск и обнаружение процесса туннеля на Linux через `/proc`.
- `native/build.sh` — сборка исполняемого файла для архитектуры текущего Linux.
- `native/install.sh` — регистрация/удаление Native Messaging host для поддерживаемых браузеров текущего пользователя.
- `install.sh` — сборка, регистрация Native Messaging и открытие страницы расширений.
- `native/THIRD_PARTY.md` — сведения об основной внешней зависимости.

## English

### Features

- Import an AmneziaWG/WireGuard profile from a `.conf` file or pasted text.
- Store multiple profiles locally, select one, or delete it.
- Connect and disconnect from the extension popup.
- Route Chromium web traffic through a local SOCKS5 proxy backed by an AmneziaWG userspace tunnel.
- Leave Linux system routes and other applications unchanged.
- Disable WebRTC UDP while connected because it cannot use the SOCKS5 proxy.

### Requirements

- Linux and Go 1.25 or later.
- Chrome, Chrome for Testing, Chromium, Microsoft Edge, Brave, or Vivaldi.
- An AmneziaWG profile in WireGuard INI format (`[Interface]`, `[Peer]`).
- Internet access during the build so Go can download `github.com/amnezia-vpn/amneziawg-go/v3`.

The native host is built for the current Linux architecture and registered for the current user. Repeat installation from each account that needs to use the extension. The installer uses the standard user-level XDG config directories; sandboxed Snap or Flatpak browser packages may need additional host access configuration.

### Installation

1. Download this repository's ZIP and extract it to a permanent folder. Do not move or delete the folder after installation: the Native Messaging manifest stores the executable's absolute path.
2. Open a terminal and change to the extracted project directory. For example:

   ```sh
   cd ~/Downloads/AmneziaBrowserExtensionLinux
   ```

3. Run the installer:

   ```sh
   chmod +x ./install.sh
   ./install.sh
   ```

   The script builds `native/AmneziaBrowserVpnHost` for the current architecture, registers Native Messaging for Chrome, Chrome for Testing, Chromium, Edge, Brave, and Vivaldi in the user config directory (`$XDG_CONFIG_HOME` or `~/.config`), and opens the extensions page if it finds an installed browser. Administrator privileges are not required.

4. Open `chrome://extensions` in Chrome or Chromium, `edge://extensions` in Edge, `brave://extensions` in Brave, or `vivaldi://extensions` in Vivaldi.
5. Enable **Developer mode**, choose **Load unpacked**, and select the repository's `extension` folder.
6. Approve the extension permissions for proxy control, browser privacy settings, and Native Messaging.

If the browser was open during Native Messaging registration, restart it or reload the extension on the extensions page.

### First connection and usage

1. Click the **Amnezia Browser VPN** toolbar icon.
2. Under the config section, choose a `.conf` file or paste the profile text. Enter a name and click **Save config**.
3. Select the profile and click **Connect**.
4. Open a website in Chromium. AmneziaWG performs its handshake on the first network request; starting the local SOCKS proxy alone does not confirm that the VPN server is reachable.
5. Check the public IP in the browser before and after connecting. Other Linux applications should continue using the normal system connection.
6. Click **Disconnect VPN** to stop the tunnel and restore the previous browser proxy and WebRTC settings.

### Rebuild and update

After changing the code, rerun the installer to rebuild and register the native component:

```sh
./install.sh
```

Then reload the extension on the browser's extensions page. Profiles remain in local extension storage when the extension is reloaded. Removing the extension may delete them, so keep the original configuration files separately.

### Uninstall

1. If the VPN is connected, click **Disconnect VPN** in the extension.
2. Remove the extension from the browser's extensions page.
3. From the project root, remove the Native Messaging registration:

   ```sh
   bash ./native/install.sh --uninstall
   ```

4. After confirming that the tunnel is stopped, optionally delete `~/.config/AmneziaBrowserVPN` (or `$XDG_CONFIG_HOME/AmneziaBrowserVPN` if `XDG_CONFIG_HOME` is set). It contains the temporary config with the private key, PID file, and log.
5. Delete the project folder if you no longer need it.

### Troubleshooting

- **“Native host has exited” / host not found:** make sure `native/AmneziaBrowserVpnHost` exists and is executable. Rerun `bash ./native/install.sh`, then restart the browser.
- **Go build error:** check `go version` (1.25 or later is required) and internet access, then rerun `bash ./native/build.sh`.
- **Port 1080 is busy:** close the application using `127.0.0.1:1080` and retry.
- **A website does not load:** check server availability, `PrivateKey`/`PublicKey`, `Endpoint`, and obfuscation settings. The component log is at `~/.config/AmneziaBrowserVPN/proxy.log` (or `$XDG_CONFIG_HOME/AmneziaBrowserVPN/proxy.log`).
- **The extension cannot change proxy or WebRTC settings:** check browser policies and other extensions that may control the same settings.
- **The browser cannot find the host in Snap/Flatpak:** check the package documentation and sandbox restrictions. The installer targets standard user Native Messaging locations.
- **The browser cannot find the host after the project was moved:** rerun `./install.sh` from its new location and restart the browser.

### Limitations and security

- This is an early prototype. The SOCKS5 bridge carries TCP CONNECT only; UDP applications and QUIC are not tunneled. The extension blocks WebRTC UDP that cannot use the proxy, but other UDP traffic is unsupported.
- A successful start only confirms that the local proxy is listening. Verify connectivity with a browser request and a public-IP check.
- The config's `DNS` setting must contain DNS server IP addresses.
- The unauthenticated SOCKS5 proxy listens only on `127.0.0.1:1080`. The extension configures Chromium's proxy; it does not change Linux system proxy settings or redirect other applications. A local application can still connect to the port if it chooses.
- Profiles in `chrome.storage.local` and the temporary `active.conf` contain the private key in plaintext accessible to your Linux account. Do not publish your profiles. Remove the app data folder after disconnecting if you no longer use the application.
- Use a profile you are authorized to use, and confirm that the connection works on your Linux system before relying on it.

### Project layout

- `extension/` — Manifest V3 UI, local profile storage, and Chromium proxy control.
- `native/main.go` — Native Messaging host, AmneziaWG setup using the Go library, and SOCKS5 TCP CONNECT bridge.
- `native/process_linux.go` — launches and checks the tunnel process on Linux via `/proc`.
- `native/build.sh` — builds the executable for the current Linux architecture.
- `native/install.sh` — registers/unregisters the Native Messaging host for supported browsers for the current user.
- `install.sh` — builds and registers Native Messaging, then opens the extensions page.
- `native/THIRD_PARTY.md` — information about the main third-party dependency.

Chrome's documented Linux Native Messaging directories are `~/.config/google-chrome/NativeMessagingHosts`, `~/.config/google-chrome-for-testing/NativeMessagingHosts`, and `~/.config/chromium/NativeMessagingHosts`. See [Chrome for Developers: Native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging#native-messaging-host-location) and [Microsoft Edge: Native messaging](https://learn.microsoft.com/en-us/microsoft-edge/extensions/developer-guide/native-messaging) for browser-specific paths and manifest requirements.
