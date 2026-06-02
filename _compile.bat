@echo off
cd /d "D:\openclaw\projects\儿童智能体\pet-habit"
call "D:\software\Maven\apache-maven-3.6.3-bin\apache-maven-3.6.3\bin\mvn.cmd" compile -q > _mvn_output.txt 2>&1
echo %ERRORLEVEL% > _mvn_exit.txt
