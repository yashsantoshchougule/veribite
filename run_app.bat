@echo off
echo Starting VeriBite with 11-Key AI Pool (Gemini, Groq, OpenRouter)...
cd /d "%~dp0mobile_app"
flutter run --dart-define-from-file=.env.json

