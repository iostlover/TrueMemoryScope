@echo off
chcp 65001 >nul
title TrueMemoryScope - Real Memory Diagnostics
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0app.ps1"
