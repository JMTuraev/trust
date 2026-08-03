@echo off
chcp 65001 >nul
cd /d D:\trust
echo ==== GIT PUSH v3.8.0 boshlandi... ====
(
  git add -A
  git commit -m "v3.8.0: audit + toifa/daromad tuzatishlari, yangi kirim paneli, limit 300"
  git push
  git tag v3.8.0
  git push origin v3.8.0
) > D:\trust\claude_push_result.txt 2>&1
type D:\trust\claude_push_result.txt
echo.
echo ==== TAYYOR — natija claude_push_result.txt da. Oynani yopsangiz boladi ====
pause
