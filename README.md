# ScreenCamRecorder — стартовий скелет

Це не готовий `.xcodeproj` (його не можна коректно згенерувати поза Xcode) —
це план + структура Swift-файлів, готова для імпорту в реальний проєкт.

## Як підключити

1. Відкрий Xcode → **File → New → Project → macOS → App**
   - Product Name: `ScreenCamRecorder`
   - Interface: **SwiftUI**
   - Language: **Swift**
2. Видали автозгенеровані `ContentView.swift` та стандартний `App.swift`.
3. Перетягни в проєкт (Finder → Xcode navigator) вміст папки `ScreenCamRecorder/`
   з цього архіву — збережи структуру папок `Recorder/` та `Models/`.
4. У Target → **Signing & Capabilities** додай:
   - **App Sandbox** (якщо плануєш App Store) → увімкни `Camera`
   - **Hardened Runtime** → увімкни `Camera` та `Screen Recording` entitlements
5. Заміни згенерований `Info.plist` на той, що в архіві (або перенеси ключі
   `NSCameraUsageDescription` / `NSMicrophoneUsageDescription`).
6. Мінімальний Deployment Target: **macOS 13.0** (через ScreenCaptureKit).

## Що вже є (каркас, з TODO)

- `App.swift`, `ContentView.swift` — робочий UI: кнопка старт/стоп, вибір камери,
  позиція/розмір/форма оверлею.
- `Models/RecordingSettings.swift` — модель налаштувань.
- `Recorder/ScreenRecorder.swift` — заглушка з TODO для `ScreenCaptureKit`.
- `Recorder/CameraRecorder.swift` — заглушка з TODO для `AVCaptureSession`.
- `Recorder/Compositor.swift` — заглушка з TODO для склеювання відео
  (`AVMutableComposition` + custom video compositor).

## Наступні кроки (з PLAN.md)

Дивись `PLAN.md` — там повний план по етапах з оцінкою часу.
Порядок реалізації TODO:
1. `ScreenRecorder` — захопити реальний потік з екрану
2. `CameraRecorder` — захопити реальний потік з камери
3. Синхронний старт обох (вже є в `ContentView.toggleRecording`)
4. `Compositor` — реальний export з накладеною камерою
