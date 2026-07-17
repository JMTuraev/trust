@echo off
cd /d D:\trust
echo START > push_out.txt
git add -A >> push_out.txt 2>&1
git commit -m "diag: surface Anthropic error.message in [ai] log (400 invalid_request_error root cause) + home hub (bottom nav behind flag, smooth bezier sparkline, empty/skeleton states)" >> push_out.txt 2>&1
git push >> push_out.txt 2>&1
echo DONE >> push_out.txt
exit
