REM ==============================================================================
REM Script Name: Remove crowdstrike
REM ==============================================================================
REM
REM Description:
REM   Removes CrowdStrike products from the system using WMIC.
REM
REM Metadata:
REM   - NinjaOne Script ID: 83
REM   - Language: batchfile
REM   - OS Type: Windows
REM   - Architecture: 64
REM   - Created By: Roland Penner
REM   - Created On: 2025-04-17
REM   - Last Updated By: Roland Penner
REM   - Last Updated: 2025-04-17 14:08:06
REM   - Active: True
REM ==============================================================================
wmic product where name="CrowdStrike Device Control" call uninstall /nointeractive
wmic product where name="CrowdStrike Firmware Analysis" call uninstall /nointeractive
wmic product where name="CrowdStrike Sensor Platform" call uninstall /nointeractive
