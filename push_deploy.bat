@echo off
cd /d D:\trust
echo START > push_out.txt
git add -A >> push_out.txt 2>&1
git commit -m "v2.2: STT 2-qatlam (Groq whisper-large-v3 + OpenAI gpt-4o-transcribe zaxira) — backend /api/stt/transcribe + Flutter ovoz yozish (record, mic ruxsatlar); docs" >> push_out.txt 2>&1
git push >> push_out.txt 2>&1
echo DONE >> push_out.txt
exit
