@echo off
title ASUS G53 (g53) - type "exit" to leave
rem Opens a terminal on the ASUS server over the home network. Uses the PC's SSH key, no password.
ssh -o UserKnownHostsFile=%~dp0g53_known_hosts root@192.168.0.50
if errorlevel 1 (
  echo.
  echo Could not connect. Is the ASUS on? Run %~dp0wake_asus.ps1 to wake it.
  pause
)
