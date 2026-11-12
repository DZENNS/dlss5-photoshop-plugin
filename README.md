# DLSS5 Native — Photoshop plugin for Mac

**Только macOS / Apple Silicon (ARM64). Плагин НЕ портирован на Windows. Windows-сборки нет. Intel Mac не поддерживается.**

**macOS / Apple Silicon ONLY. This plugin has NOT been ported to Windows. No Windows build is available. Intel Macs are unsupported.**

Нативный плагин для обработки фотографий в Adobe Photoshop: DLSS Neural Rendering через независимый MLX/Metal-перенос, сравнение до/после и Real-ESRGAN ×2. Это не официальный продукт NVIDIA или Adobe; результат не гарантированно идентичен NVIDIA runtime.

## Скачать и установить

- [Готовая сборка v0.9.4](https://github.com/DZENNS/dlss5-photoshop-plugin/releases/tag/v0.9.4)
- **[Подробная инструкция на русском: модель → плагин → Photoshop](docs/INSTALL_RU.md)**
- **[English installation and model setup](docs/INSTALL_EN.md)**
- [Сборка из исходников / Build from source](docs/BUILD.md)

В ZIP находится скомпилированный `.plugin`, Real-ESRGAN и команда настройки. **Весов NVIDIA внутри нет.** Для DLSS нужен собственный совместимый пакет HT `NR.dlss` / `NeuralRendering.dlssmodel`, содержащий `manifest.json` и `weights.safetensors`. Команда `Configure.command` добавит пакет в новую копию плагина и выполнит локальную ad-hoc подпись. DLL нельзя просто скопировать внутрь плагина: macOS её не исполняет.

No NVIDIA DLLs or extracted NVIDIA weights are distributed. Supply your own compatible HT model locally; see the guides. Adobe SDK headers are not included. The release is ad-hoc signed, not Developer ID signed or notarized.

## Возможности

- Запуск: **Filter → DLSS5 → DLSS5 Native**.
- По умолчанию DLSS выключен; Natural, Standard, Cinematic, Neutral.
- Сравнение до/после, перетаскиваемый разделитель, масштабирование и перемещение превью.
- Автоматическое или ручное превью, отмена обработки.
- Применение результата на новый слой.
- Пресеты. Между запусками отдельно сохраняется только «Автоматически».
- Рабочее разрешение: 320 / 384 / 512 / 640 / 768 / 960 / 1280 / 1920 px.
- Двойной клик по держателю ползунка возвращает параметр к исходному значению.
- Русский интерфейс при русском Photoshop, английский при любом другом языке.
- Real-ESRGAN ×2 увеличивает Image Size всего документа; нужен полноразмерный слой без выделения.

## Требования и ограничения

Apple Silicon, macOS 15.8+, Photoshop с поддержкой нативных ARM64 filter plugins, RGB 8 бит. Пользовательская проверка выполнялась в Photoshop Beta; совместимость со всеми версиями Photoshop не заявляется. Windows и Intel Mac не поддерживаются. Плагин работает только с изображениями.

DLSS обрабатывает изображение в выбранном рабочем разрешении; увеличение этого значения не равно апскейлу документа. Реальное увеличение размера — отдельный Real-ESRGAN ×2. Генеративная обработка может менять детали и внешность; проверяйте результат при 100%.

## Исходники и лицензии

`native/` — интерфейс AppKit, filter entry и создание слоя; `Sources/PhotoshopNative/` — Swift/Metal-мост; `Sources/ScreenCore/` — настройки; `Vendor/MLX-DLSS/` — используемый исходный перенос. [Уведомления](THIRD_PARTY_NOTICES.md).

Основной исходный код — MIT; MLX-DLSS — Apache 2.0; сторонние компоненты сохраняют свои лицензии. Лицензия репозитория **не распространяется на веса NVIDIA и Adobe SDK**. Не загружайте в issues пользовательские фотографии, SDK, DLL или модели NVIDIA.
