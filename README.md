# PSGatherDNSInfo
get the info we need to properly work on DNS issues

### If the script needs to install whois it will exit. Just run it again.
 
## Note right click and save as for the following links.
[Download exe](https://github.com/mrdatawolf/PSGatherDNSInfo/releases/download/v1.0.0/Get-DomainInfo.exe) 

[Download ps1](https://raw.githubusercontent.com/mrdatawolf/PSGatherDNSInfo/refs/heads/main/Get-DomainInfo.ps1)

# If it is failing strangely you can try running...
## first:
winget remove --id Microsoft.Sysinternals.Whois

## second:
### If it closes right away or you see a ExecutionPolicy error

    Win10 Pro

    Set-ExecutionPolicy Unrestricted

    Win11 Pro

    Set-ExecutionPolicy -Scope CurrentUser Unrestricted

