@echo off
cd /d D:\trust
echo START > push_out.txt
git add -A >> push_out.txt 2>&1
git commit -m "v3.3 production hardening: 4-menu E2E audit fixes (partners ledger/links, expenses brand colors + manual folder edit, circles join-by-code + security, profile) + subscription read-only enforcement (7d trial, \$9/mo, 402 SUB_EXPIRED + banners) + chat UI hidden (kChatEnabled) + migrations 011/012 + team reports & e2e scripts" >> push_out.txt 2>&1
git push >> push_out.txt 2>&1
echo DONE >> push_out.txt
exit
