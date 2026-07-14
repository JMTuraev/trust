@echo off
cd /d D:\trust\mobile
echo START > flutter_check_out.txt
call flutter pub get >> flutter_check_out.txt 2>&1
echo --- ANALYZE --- >> flutter_check_out.txt
call flutter analyze >> flutter_check_out.txt 2>&1
echo EXITCODE %ERRORLEVEL% >> flutter_check_out.txt
echo DONE >> flutter_check_out.txt
exit
