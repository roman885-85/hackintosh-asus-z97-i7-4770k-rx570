# Hackintosh: ASUS Z97 · Core i7-4770K · Radeon RX 570 · OpenCore 1.0.8

🇺🇦 Українська · [🇬🇧 English](README.en.md)

Робоча папка **EFI** для OpenCore на настільному комп'ютері з процесором Haswell і відеокартою AMD Polaris.
Модель Mac — **MacPro7,1**, тому працюють і **macOS Sequoia 15**, і **macOS Tahoe 26**.

> [!IMPORTANT]
> Серійні номери в `EFI/OC/config.plist` замінено заглушками (`W00000000001`).
> Перед використанням згенеруйте власні — див. [Перед першим запуском](#перед-першим-запуском).

## Перевірено

| macOS | Збірка | Результат |
|---|---|---|
| Sequoia 15.8.1 | 24H32 | ✅ усе обладнання з таблиці нижче |
| Tahoe 26.7.1 | 25G241 | ✅ усе обладнання; вбудований звук — через VoodooHDA ([нижче](#macos-26-tahoe-що-змінилося)) |

## Обладнання

| Компонент | Модель | Стан |
|---|---|---|
| Плата | ASUS на чипсеті Intel Z97 (LGA1150, 9-та серія) | — |
| Процесор | Intel Core i7-4770K (Haswell, 4 ядра / 8 потоків) | ✅ XCPM, `plugin-type` через SSDT-PLUG |
| Пам'ять | 16 ГБ DDR3 | ✅ |
| Відеокарта | AMD Radeon RX 570, 4 ГБ (Polaris) | ✅ Metal, три монітори одночасно |
| Вбудована графіка | Intel HD 4600 | не використовується |
| NVMe | Patriot P300 256 ГБ (PCIe 3.0 x2) | ✅ NVMeFix, TRIM |
| SATA | Hitachi HTS545050A7E380 500 ГБ | ✅ |
| Мережа | Realtek RTL8111G, 1 Гбіт/с | ✅ RealtekRTL8111 3.0.0 (EEE вимкнено) |
| Звук на платі | Realtek ALC887 | ✅ macOS ≤ 15 — AppleALC, layout-id 52; macOS 26 — VoodooHDA |
| Звук HDMI/DP | RX 570 | ✅ |
| USB | Intel 9-series XHCI (8086:8CB1) + ASMedia ASM1042 | ✅ карта портів USBMap: 12 портів XHC + 2 ASMedia |
| Wi-Fi / Bluetooth | немає | — |
| Сон | не налаштовувався (`sleep 0`) | ⚠️ не перевірявся |

## Що всередині

- **OpenCore 1.0.8** (RELEASE, acidanthera), графічне меню OpenCanopy.
- **SMBIOS:** `MacPro7,1` — єдиний варіант для Haswell лише з дискретною відеокартою, який підтримує Tahoe.
- **SecureBootModel:** `Disabled`; оновлення через «Оновлення ПЗ» — `revpatch=sbvmm` у RestrictEvents.

| Kext | Версія | Навіщо |
|---|---|---|
| Lilu | 1.7.2 | основа для інших розширень |
| VirtualSMC + SMCProcessor + SMCSuperIO | 1.3.8 | емуляція SMC, датчики процесора й вентиляторів |
| WhateverGreen | 1.7.1 | виправлення для відеокарти |
| AppleALC | 1.9.8 | вбудований звук (лише до macOS 15, `MaxKernel 24.99.99`) |
| RestrictEvents | 1.1.6 | `revpatch=sbvmm,memtab,pci`: оновлення ОС, без попереджень MacPro7,1 про пам'ять і PCI |
| NVMeFix | 1.1.3 | керування живленням NVMe |
| RealtekRTL8111 | 3.0.0 | мережа; в `Info.plist` вимкнено `enableEEE` |
| USBMap | — | власна карта портів USB (ключі старого й нового формату) |

| ACPI | Навіщо |
|---|---|
| SSDT-EC | фіктивний вбудований контролер для macOS |
| SSDT-PLUG | `plugin-type` — керування живленням процесора (XCPM) |
| SSDT-SBUS | шина SMBus |
| SSDT-USBX | параметри живлення USB для нової моделі Mac |

Драйвери UEFI: `OpenRuntime`, `OpenCanopy`, `ResetNvramEntry`, `HfsPlus`.

Основні параметри: `DisableIoMapper`, `AppleXcpmCfgLock` (якщо CFG Lock у BIOS вимкнути не можна),
`csr-active-config` = `030A0000`, `boot-args` = `debug=0x100 keepsyms=1`.

## Перед першим запуском

1. **Серійні номери.** Завантажте [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS), згенеруйте набір для `MacPro7,1`
   і впишіть у `PlatformInfo → Generic`: `SystemSerialNumber`, `MLB`, `SystemUUID`.
   У `ROM` впишіть MAC-адресу мережевої карти (6 байтів, без двокрапок).
   Номер має бути **недійсним** на сайті Apple — інакше можливі проблеми з iCloud.
2. **BIOS** (загальні рекомендації для Haswell за посібником Dortania):
   - вимкнути: Fast Boot, Secure Boot (тип ОС — «Other OS»), CSM (якщо відеокарта має UEFI GOP), VT-d — за бажанням (у конфігурації вже є `DisableIoMapper`);
   - увімкнути: XHCI Hand-off, EHCI Hand-off, SATA — AHCI;
   - основний відеовихід — PCIe.
3. **Перевірка.** Спершу завантажтеся з флешки: скопіюйте `EFI` у корінь флешки FAT32 і виберіть її в меню завантаження плати (F8).
   Якщо все працює — скопіюйте `EFI` на розділ EFI системного диска.

## macOS 26 Tahoe: що змінилося

**1. Нові ключі в карті USB.** macOS 26 читає порти за ключами `usb-port-number` і `usb-port-type`
(замість `port` і `UsbConnector`). Зі старою картою контролери USB стартують без портів і вимикаються —
клавіатура й миша не працюють, а інсталятор з флешки падає з **«Still waiting for root device»**.
`USBMap.kext` у цьому репозиторії містить обидва набори ключів і працює і в Sequoia, і в Tahoe.

**2. Немає AppleHDA.** Apple прибрала драйвер вбудованого звуку, тому AppleALC у Tahoe нічого не дає
(він обмежений `MaxKernel 24.99.99`). Вбудований звук повертає **VoodooHDA 3.6.8** з папки `PostInstall`:

```bash
sudo cp -R PostInstall/VoodooHDA.kext /Library/Extensions/
sudo chown -R root:wheel /Library/Extensions/VoodooHDA.kext
sudo chmod -R 755 /Library/Extensions/VoodooHDA.kext
sudo kmutil load -p /Library/Extensions/VoodooHDA.kext
```

Далі «Параметри → Конфіденційність і безпека» → «Дозволити» і перезапуск. Звук USB-карт і HDMI при цьому лишається.

> [!WARNING]
> Не використовуйте збірку **VoodooHDA_BL 3.7.0-alpha** «для завантажувача»: вона несе всередині власну копію IOAudioFamily,
> системна після цього не вантажиться — і зникають звук USB-карт (AppleUSBAudio) та HDMI (AppleGFXHDA). Перевірено.

У `Info.plist` VoodooHDA змінено дві речі: `IONameMatch` = `HDEF` (так звуковий контролер називається на цій платі)
і прибрано окрему особу для HDMI-звуку AMD, щоб HDMI лишився за системним драйвером.

**3. Модель Mac.** Tahoe не підтримує `iMacPro1,1`; тут `MacPro7,1`.

## Встановлювальний пакет

`tools/macos-package/build.sh` збирає `dist/Z97-Haswell-Drivers-ДАТА.pkg`, який після чистого встановлення macOS:
- на macOS 26+ ставить VoodooHDA і викликає запит дозволу;
- ставить OpenCore на розділ EFI системного диска, **лише якщо його там немає**
  (такий самий — не чіпає; інший — не замінює, а кладе поруч у `EFI_from_pkg`).

Журнал: `/var/log/z97-drivers-install.log`. Дозвіл розширення і перезапуск пакет зробити не може — це завжди дія користувача.

## Відомі нюанси

- На цьому комп'ютері розділ EFI історично має тип «Microsoft Basic Data» — завантаженню це не заважає,
  але macOS підключає такий розділ сама. Тип можна змінити лише з Recovery або іншої системи.
- Обриви мережі й швидкість 10/100 Мбіт/с, з якими ми стикалися, спричинив **кабель**, а не драйвер.

## Історія змін

- **2026-10-12** — карта USB з ключами macOS 26; прибрано непотрібний XHCI-unsupported (контролер 8CB1 підтримується штатно);
  `layout-id` записано як дані; AppleALC обмежено macOS 15; VoodooHDA для Tahoe.
- **2026-10-11** — OpenCore 1.0.3 → 1.0.8, усі kext оновлено, `iMacPro1,1` → `MacPro7,1`;
  виправлено карту USB, яка не застосовувалася (зайвий `ExecutablePath` у безкодового kext); RealtekRTL8111 3.0.0.

## Подяки й ліцензії

- [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg), Lilu, WhateverGreen, AppleALC, VirtualSMC, NVMeFix, RestrictEvents — acidanthera, BSD-3-Clause.
- [RealtekRTL8111](https://github.com/Mieze/RTL8111_driver_for_OS_X) — Laura Müller.
- [VoodooHDA](https://github.com/CloverHackyColor/VoodooHDA) — CloverHackyColor, GPL-2.0 (змінено лише `Info.plist`).
- `HfsPlus.efi` і ресурси меню — [acidanthera/OcBinaryData](https://github.com/acidanthera/OcBinaryData).
- [Посібник Dortania](https://dortania.github.io/OpenCore-Install-Guide/).

Власні файли репозиторію (опис, сценарії, `config.plist`, `USBMap.kext`) — [MIT](LICENSE).
Користуєтеся на власний ризик; macOS дозволено встановлювати лише на обладнання Apple.
