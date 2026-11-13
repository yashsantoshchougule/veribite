Write-Host "Starting VeriBite with 11-Key AI Pool (Gemini, Groq, OpenRouter)..." -ForegroundColor Cyan
Set-Location "$PSScriptRoot/mobile_app"
flutter run --dart-define-from-file=.env.json

