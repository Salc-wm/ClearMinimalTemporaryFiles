@echo off
:: user's temp
del /q /s /f "%temp%\*" 2>nul
for /d %%x in ("%temp%\*") do rd /s /q "%%x" 2>nul

:: system temp
del /q /s /f "C:\Windows\Temp\*" 2>nul
for /d %%x in ("C:\Windows\Temp\*") do rd /s /q "%%x" 2>nul
