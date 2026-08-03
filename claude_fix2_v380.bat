@echo off
chcp 65001 >nul
cd /d D:\trust
(
  git add -A
  git commit -m "fix: CI analyze ogohlantirishlari (7 ta) - build gate yashil"
  git push
  git tag -f v3.8.0
  git push -f origin v3.8.0
  git log --oneline -2
) > D:\trust\claude_fix2_result.txt 2>&1
type D:\trust\claude_fix2_result.txt
echo.
echo ==== TAYYOR ====
pause
