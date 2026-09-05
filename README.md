# Velora VPN · iOS

Нативный VPN-клиент на SwiftUI с VLESS/Reality и HTTPS-подписками. Разработка с Windows, сборка iOS через GitHub Actions на macOS, неподписанный IPA для подписи на ПК.

**Статус:** исходники и workflow подготовлены. Локально проверены упаковщик IPA и структура исходников. Сборка Xcode и подключение на iPhone ещё не проверены: GitHub-репозиторий, подписывающий профиль и тестовый сервер не предоставлены. Готового скомпилированного IPA в исходниках нет.

## Что реализовано

- SwiftUI-интерфейс: подключение, серверы, импорт, подписки, настройки.
- VLESS TCP/Reality, TCP/TLS, WebSocket/TLS, gRPC/TLS.
- Импорт VLESS-ссылок и обычных HTTPS-подписок, в том числе base64/base64url.
- Обновление подписки с сохранением старых серверов при ошибке загрузки/разбора.
- Shared Keychain для профилей и ссылок; без аналитики, рекламы и автоматического чтения буфера.
- Packet Tunnel Extension с настоящим Xray TUN inbound для IPv4/IPv6 и DNS.
- CI: Swift-тесты, компиляция симулятора и устройства, упаковка `.app` и `.appex` в неподписанный `.ipa`.

Это клиент: серверы не входят в приложение. Зашифрованные `happ://crypto`, VMess, Shadowsocks, XHTTP, нестандартное VLESS encryption и неподдерживаемые параметры первой версии отклоняются. Поддержка всех форматов Happ не заявляется.

## Сборка с Windows

Полная пошаговая инструкция: **[docs/WINDOWS-RU.md](docs/WINDOWS-RU.md)**.

1. Создай пустой репозиторий GitHub.
2. Загрузи исходники с папкой `.github` в корень репозитория.
3. Открой **Actions → Build iOS IPA → Run workflow** (или дождись сборки после push).
4. После успешной сборки скачай артефакт **Velora-unsigned-IPA**.
5. Распакуй ZIP и подпиши `Velora-unsigned.ipa` своей программой на ПК, включая `PacketTunnel.appex`.

**Подпись должна разрешать Network Extension и общую Keychain-группу у обоих targets.** Обычный sideload-профиль без нужных entitlements не обеспечит работающий VPN. Подробнее — в инструкции. В GitHub не нужны Apple-сертификаты или секреты для неподписанной сборки.

## Локальная разработка на Mac

```sh
swift test --package-path Packages/VPNCore
python3 scripts/build_native.py --checkout-only
# Установи Go версии, указанной в Vendor/libxray-source/go.mod
python3 scripts/build_native.py
python3 scripts/collect_licenses.py
brew install xcodegen
xcodegen generate
open Velora.xcodeproj
```

Для подписанной локальной сборки выбери Apple Team и уникальный `APP_BUNDLE_ID` для обоих targets. Убедись, что provisioning profiles разрешают первую общую группу Keychain и Network Extension. Неподписанный GitHub workflow этого не делает.

## Проверки

```sh
python -m unittest discover -s scripts/tests -v
swift test --package-path Packages/VPNCore
```

Python-тесты выполняются на Windows. Swift-тесты пакета требуют macOS (CryptoKit), Xcode — macOS. Статическая проверка Swift-синтаксиса не заменяет компиляцию. Реальный VPN требует физического iPhone и рабочего сервера; симулятор проверяет компиляцию интерфейса/расширения, а не сетевое подключение.

Точный журнал выполненных и невыполненных проверок: [docs/VALIDATION.md](docs/VALIDATION.md).

## Структура

| Путь | Назначение |
|---|---|
| `App/` | SwiftUI, подписки, VPN manager |
| `Tunnel/` | NEPacketTunnelProvider и libXray bridge |
| `Shared/` | Доступ к Keychain |
| `Packages/VPNCore/` | Парсер, модели, Xray config и тесты |
| `scripts/native-lock.json` | Зафиксированная ревизия libXray / API |
| `project.yml` | XcodeGen, bundle IDs, targets, зависимости |
| `.github/workflows/ios.yml` | Облачная сборка IPA |

Зависимости: [libXray](https://github.com/XTLS/libXray), [Xray-core](https://github.com/XTLS/Xray-core), [XcodeGen](https://github.com/yonaskolb/XcodeGen). Лицензии: [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
