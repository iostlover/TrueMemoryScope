@echo off
chcp 65001 >nul
title TrueMemoryScope - English Version
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0TrueMemoryScope_EN\app.ps1"
