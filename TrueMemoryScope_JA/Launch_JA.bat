@echo off
chcp 65001 >nul
title TrueMemoryScope - 真のメモリ診断ツール
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0app.ps1"
