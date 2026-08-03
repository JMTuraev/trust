@echo off
chcp 65001 >nul
cd /d D:\trust
(
  echo === 1. Eski git qulflari tozalanmoqda ===
  del /f .git\index.lock
  del /f .git\index.lock.stale
  echo === 2. Noto'gri teg olib tashlanmoqda ===
  git tag -d v3.8.0
  git push origin :refs/tags/v3.8.0
  echo === 3. Commit ===
  git add -A
  git commit -m "v3.8.0: audit + toifa/daromad tuzatishlari, yangi kirim paneli, limit 300"
  echo === 4. Push ===
  git push
  echo === 5. Yangi teg ===
  git tag v3.8.0
  git push origin v3.8.0
  echo === 6. Holat ===
  git log --oneline -2
  git status -s
) > D:\trust\claude_fix_result.txt 2>&1
type D:\trust\claude_fix_result.txt
echo.
echo ==== TAYYOR — bu oynani yopishingiz mumkin ====
pause
