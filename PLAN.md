# ScreenCamRecorder — план мінімального SwiftUI-додатку

## Мета MVP
Записати екран, одночасно писати з камери, зберегти готове відео з накладеною камерою (кружечок у кутку).

---

## 1. Технологічний стек
- **SwiftUI** — інтерфейс (кнопка старт/стоп, вибір камери, позиція оверлею)
- **ScreenCaptureKit** — запис екрану (macOS 12.3+, краще 13+)
- **AVFoundation** — запис з камери
- **AVFoundation / AVMutableComposition** або **Core Image + AVAssetWriter** — композитинг (накладання камери на екран)

## 2. Структура проєкту
```
ScreenCamRecorder/
├── App.swift                 // точка входу
├── ContentView.swift         // UI: старт/стоп, налаштування
├── Recorder/
│   ├── ScreenRecorder.swift  // обгортка над ScreenCaptureKit
│   ├── CameraRecorder.swift  // обгортка над AVCaptureSession
│   └── Compositor.swift      // склеювання відео
├── Models/
│   └── RecordingSettings.swift // позиція/розмір камери, форма
└── Info.plist                // дозволи (Camera, Screen Recording)
```

## 3. Етапи розробки

**Етап 1 — Дозволи та каркас (0.5 дня)**
- Додати `NSCameraUsageDescription` в Info.plist
- Запит дозволу на Screen Recording (System Settings, через API)
- Порожній SwiftUI-екран з кнопкою Start/Stop

**Етап 2 — Запис екрану (1 день)**
- `SCStream` з `ScreenCaptureKit`
- Вибір дисплея/вікна
- Запис у `.mov` через `AVAssetWriter`

**Етап 3 — Запис камери (0.5-1 день)**
- `AVCaptureSession` + `AVCaptureDeviceInput` (вибір камери зі списку)
- Паралельний запис у окремий `.mov`

**Етап 4 — Синхронний старт (0.5 дня)**
- Запуск обох записів одночасно (спільний `CMClock` для синхронізації)
- Важливо: обидва потоки мають писати з одним таймстемпом, інакше буде розсинхрон

**Етап 5 — Композитинг (найважчий, 1-2 дні)**

Два підходи:
- **Простий (post-processing):** записати 2 файли окремо → після зупинки склеїти через `AVMutableComposition` + `AVMutableVideoComposition` (шар камери зверху, кругла маска через `CALayer`/`CIFilter`)
- **Live (складніше):** обробляти кадри в реальному часі через `AVCaptureVideoDataOutput` + Core Image, писати вже готовий композитний кадр в `AVAssetWriter` — так робить Screen Studio, але це більше роботи

Для MVP обраний **post-processing підхід** — простіше і надійніше.

**Етап 6 — UI-налаштування (0.5 дня)**
- Позиція камери (drag або preset: кути)
- Розмір бульбашки (slider)
- Форма (круг/прямокутник) через `CALayer.mask`

**Етап 7 — Експорт (0.5 дня)**
- Зберегти фінальний `.mov` через `AVAssetExportSession`
- Кнопка "Show in Finder"

## 4. Орієнтовний час

| Етап | Час |
|---|---|
| Дозволи + UI каркас | 0.5 дня |
| Запис екрану | 1 день |
| Запис камери | 0.5-1 день |
| Синхронізація | 0.5 дня |
| Композитинг (пост-обробка) | 1-2 дні |
| UI налаштувань | 0.5 дня |
| Експорт | 0.5 дня |
| **Разом** | **~5-6 днів** для розробника з базовим досвідом Swift/AVFoundation |

## 5. Ризики
- **ScreenCaptureKit permissions** — треба explicit System Settings toggle, не можна просто попросити в коді
- **Синхронізація аудіо/відео** з двох джерел — найчастіше джерело багів
- **Apple Silicon vs Intel** — продуктивність кодування різниться, тестуй на реальному залізі
