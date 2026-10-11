@echo off
chcp 65001 >nul
title TrueMemoryScope - 日本語版
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0TrueMemoryScope_JA\app.ps1"
