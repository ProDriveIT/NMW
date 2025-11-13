 REM - Check paths and adjust Server name accordingly currently set to CAAZURAPP01
REM - Local Deploy to go to C:\CCHAPPS\LocalDeploy
REM - Ensure XML files changed in  \CENTRALCLIENT\RDS-CITRIX_ASSETS\CCHCENTRAL\
REM - Always use RUN AS ADMINISTRATOR to execute this



change user /install
regedit /s "\\CAAZURAPP01\CENTRALCLIENT\ADDINS\vconnect32.reg"
if Not Exist "%windir%\SysWOW64" goto CARRYON
regedit /s "\\CAAZURAPP01\CENTRALCLIENT\ADDINS\vconnect64.reg"

:CARRYON
c:\
cd\

mkdir "c:\programdata\CCHCENTRAL"
robocopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\CCHCENTRAL"  "c:\programdata\cchcentral" /E  /MIR /COPY:DAT /R:2 /W:2
icacls "c:\programdata\cchcentral" /grant users:(f) /inheritancelevel:e /t   

mkdir c:\CCHAPPS
copy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\CCH_CENTRAL_RDS_Roll_Out-Update_Script.bat" "c:\cchapps"  /y
mkdir c:\CCHAPPS\LocalDeploy
robocopy "\\CAAZURAPP01\Central" "C:\CCHAPPS\LocalDeploy" /E  /MIR /COPY:DAT /R:2 /W:2 /LOG:c:\CCHAPPS\robocopy-deployfolder-sync.txt
icacls "c:\CCHAPPS" /grant users:(f) /inheritancelevel:e /t   


regedit /s "\\CAAZURAPP01\CENTRALCLIENT\ADDINS\RDS-CITRIX_ASSETS\RegKey\RDScch.reg"

if Not Exist "%windir%\SysWOW64" goto FINISHOFF
%systemroot%\SysWOW64\regedt32.exe /s "\\CAAZURAPP01\CENTRALCLIENT\ADDINS\RDS-CITRIX_ASSETS\RegKey\RDScch.reg"

:FINISHOFF

 %systemroot%\SysWoW64\regsvr32.exe  /s  "c:\CCHAPPS\LocalDeploy\secman.dll" 

cd "%ALLUSERSPROFILE%\Microsoft\Windows\Start Menu\Programs\"
mkdir "CCH ProSystem"
cd "CCH ProSystem"
del "cch central.lnk"

Xcopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\icons\CCH Central.lnk" . /y
REM Xcopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\icons\CCH Review & Tag IXBRL.lnk" . /y
REM  Xcopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\icons\CCH Audit Automation.lnk" . /y

cd\
cd users 
cd public
cd desktop
del "cch central.lnk"
del "central.lnk"
Xcopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\icons\CCH Central.lnk" . /y
REm Xcopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\icons\CCH Review & Tag IXBRL.lnk" . /y
REM  Xcopy "\\CAAZURAPP01\CENTRALCLIENT\RDS-CITRIX_ASSETS\icons\CCH Audit Automation.lnk" . /y
 
change user /execute
PAUSE