# Velora: сборка через GitHub и подпись на Windows

Проект уже опубликован: [lirns200/velora-ios](https://github.com/lirns200/velora-ios).
Чтобы скачать сборку, переходи сразу к разделу 3. Разделы 1–2 нужны только для переноса проекта в другой репозиторий.

## 1. Создать репозиторий

Открой https://github.com/new и создай пустой репозиторий `velora-ios`. Публичность выбираешь сам. Не добавляй README/.gitignore при создании, если собираешься отправлять Git-командами ниже. Для приватных репозиториев доступность/лимиты macOS runner зависят от тарифа и настроек GitHub Actions.

Если получил `Velora-source.zip`, распакуй его в новую папку, например `C:\Projects\velora-ios`. Это архив **исходников**, не приложение для установки.

## 2. Загрузить исходники

В PowerShell из распакованной папки выполни, заменив `YOUR_LOGIN` на свой логин:

```powershell
cd C:\Projects\velora-ios
git init -b main
git add .
git commit -m "Add Velora iOS VPN client"
git remote add origin https://github.com/YOUR_LOGIN/velora-ios.git
git push -u origin main
```

Git может открыть вход в GitHub в браузере. Пароль GitHub в чат присылать не нужно. Если Git попросит имя/почту автора, настрой их для этого репозитория и повтори commit:

```powershell
git config user.name "Your Name"
git config user.email "YOUR_GITHUB_NOREPLY_EMAIL"
```

Альтернатива без команд: GitHub → **Add file → Upload files**. Загрузи **содержимое** распакованной папки, включая `.github/workflows/ios.yml`, в корень. Не загружай ZIP как единственный файл: GitHub не распакует его для сборки. В корне должны оказаться `project.yml`, `App`, `Tunnel`, `Packages`, `Shared`, `scripts`, `.github` и документация.

## 3. Получить IPA

Перейди **Actions → Build iOS IPA**. Push в `main`/`master` запускает сборку автоматически. Для повторного запуска нажми **Run workflow**.

Runner macOS скачивает зафиксированные исходники libXray, устанавливает нужный Go, компилирует библиотеки для iPhone и симулятора, генерирует Xcode-проект и собирает приложение. Первый запуск может занять десятки минут; последующие используют кэш библиотеки. Сертификаты Apple в workflow не передаются.

При зелёном результате открой запуск и скачай **Artifacts → Velora-unsigned-IPA**. В скачанном ZIP будут:

- `Velora-unsigned.ipa` — неподписанный пакет для устройства;
- `Velora-unsigned.ipa.sha256` — контрольная сумма;
- шаблоны entitlements приложения и расширения;
- эта инструкция и сведения о зависимостях.

Если сборка красная, скачай **Apple-build-logs** или открой упавший шаг. [Сборка 1.0.0 (2)](https://github.com/lirns200/velora-ios/actions/runs/33979661256) успешно проверена 5 сентября 2026 года; её [артефакт с IPA](https://github.com/lirns200/velora-ios/actions/runs/33979661256/artifacts/9973414620) доступен в течение срока хранения GitHub Actions.

## 4. Подписать на ПК

IPA содержит **два исполняемых компонента**:

| Компонент | Bundle ID по умолчанию |
|---|---|
| `Payload/Velora.app` | `app.velora.client` |
| `PlugIns/PacketTunnel.appex` внутри приложения | `app.velora.client.PacketTunnel` |

Подписывающая программа должна сохранить/подписать вложенное `.appex`. Основной app и extension подписываются одной Apple Team, каждый своим подходящим provisioning profile. Если меняешь bundle ID, меняй и ID расширения: он должен быть ровно `<APP_BUNDLE_ID>.PacketTunnel`.

У обоих компонентов должны присутствовать разрешённые профилями entitlements:

```xml
<key>com.apple.developer.networking.networkextension</key>
<array><string>packet-tunnel-provider</string></array>
<key>keychain-access-groups</key>
<array><string>YOUR_APP_IDENTIFIER_PREFIX.app.velora.client.shared</string></array>
```

`YOUR_APP_IDENTIFIER_PREFIX` — фактический App Identifier Prefix из provisioning profile, обычно Team ID. Указанная **одинаковая общая группа должна быть первой** в `keychain-access-groups` у приложения и расширения: код использует подписанную группу по умолчанию и не зашивает Team ID внутрь IPA. Профили обязаны разрешать эту группу. Не оставляй `$(AppIdentifierPrefix)` в финальных entitlements программы подписи.

Скрипты не обходят ограничения подписи iOS. Если программа может подписать обычное приложение, это ещё не подтверждает поддержку VPN-расширения. Бесплатный personal-team профиль обычно не даёт нужной Network Extension capability. Если нет подходящего профиля, работающая установка VPN остаётся заблокированной независимо от наличия IPA.

В случае ошибки Keychain `-34018` сначала проверь общую группу и подписи. Если приложение открывается, но VPN не создаётся, проверь `packet-tunnel-provider`, сохранность `.appex`, соответствие его ID и provisioning profiles.

## 5. Проверить на iPhone

1. Установи подписанный IPA способом, который поддерживает твоя программа. При необходимости включи Developer Mode/доверие для выбранного способа установки.
2. Открой Velora → **Добавить подключение**. Вставь свою VLESS-ссылку либо обычную HTTPS-подписку. Реальные ключи не добавляй в репозиторий.
3. Выбери сервер, нажми **Подключить**, разреши создание VPN-конфигурации iOS.
4. Проверь сайт/IP до и после подключения, работу DNS, IPv4/IPv6, Wi-Fi и мобильной сети, сон/пробуждение, отключение и повторное подключение.

Статус «Туннель включён» показывает состояние NetworkExtension, а не успешную проверку внешнего интернета. Неверный сервер/Reality-параметры могут дать поднятый туннель без доступа в сеть. Первая версия не обещает автоматическую смену сервера, kill switch после отключения, обход всех блокировок, полноту совместимости с Happ или готовность к App Store.

## Справочные документы

- Apple: https://developer.apple.com/documentation/networkextension/packet-tunnel-provider
- Apple: https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension
- GitHub: https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications
- Xray iOS TUN: https://github.com/XTLS/Xray-core/blob/5ca6f4b7d4dc/proxy/tun/README.md
