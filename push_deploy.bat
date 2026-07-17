@echo off
cd /d D:\trust
echo START > push_out.txt
git add -A >> push_out.txt 2>&1
git commit -m "v3.4 Trust AI: interactive AI chat (Claude Opus 4.8 + Groq fallback, blocks JSON, aggregate context + partner pseudonymization, 40/day-400/mo limits, ai_usage audit, Play-required flagging) + AI tab replaces Circles (kCirclesEnabled=false, code kept) + text-only: STT/audio/mic permission fully removed + privacy policy 3rd-party AI disclosure + migration 013" >> push_out.txt 2>&1
git push >> push_out.txt 2>&1
echo DONE >> push_out.txt
exit
