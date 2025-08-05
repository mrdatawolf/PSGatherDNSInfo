# PSGatherDNSInfo
get the info we need to properly work on DNS issues

### If the script needs to install whois it should exit. Just run it again.

### Also if it just sits there for more then a minute press 'y' and enter.  You might not have accepted the winget license before.

### Winget install is just being weird on the exe.  you should do "winget install --id Microsoft.Sysinternals.Whois
" it it talks about failing to install.

## Note right click and save as for the following links.
[Download exe](https://github.com/mrdatawolf/PSGatherDNSInfo/releases/download/v1.1.3/Get-DomainInfo.exe) 

[Download ps1](https://raw.githubusercontent.com/mrdatawolf/PSGatherDNSInfo/refs/heads/main/Get-DomainInfo.ps1)

# If it is failing strangely you can try running...
## first:
winget remove --id Microsoft.Sysinternals.Whois

### it is possible the best fix will be to also just manually install whois:
winget install --id Microsoft.Sysinternals.Whois

## second:
### If it closes right away or you see a ExecutionPolicy error

    Win10 Pro

    Set-ExecutionPolicy Unrestricted

    Win11 Pro

    Set-ExecutionPolicy -Scope CurrentUser Unrestricted

