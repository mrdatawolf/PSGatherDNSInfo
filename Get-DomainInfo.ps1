<#
.SYNOPSIS
    Retrieves registrar, DNS, A record, MX, SPF, DKIM, and DMARC records for one or more domains.

.PARAMETER Domains
    A list of domain names to query.

.PARAMETER DomainListFile
    Optional path to a file containing domain names (one per line).

.PARAMETER ExportCsv
    Optional path to export results as CSV.

.PARAMETER VerboseOutput
    Enables verbose output for debugging.

.EXAMPLE
    .\Get-DomainInfo.ps1 -Domains "example.com" -ExportCsv "output.csv"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string[]]$Domains,

    [string]$DomainListFile,

    [string]$ExportCsv,

    [bool]$Fullpath,

    [switch]$VerboseOutput
)

if (-not $Domains) {
    $Domains = Read-Host "Please enter the domain name"
}

if ($VerboseOutput) {
    $VerbosePreference = "Continue"
}
function Initialize-Whois {
    $whoisCmd = "whois64.exe"
    $regPath = "HKCU:\Software\Sysinternals\Whois"
    # Accept Sysinternals EULA if not already set
     Write-Verbose "Testing for whois64..."
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
     Write-Verbose "Setting eula acceptance for whois64..."
    Set-ItemProperty -Path $regPath -Name "EulaAccepted" -Value 1
    if($FullPath) {
        # Always use full path if possible
        Write-Verbose "Getting whois path..."
        $whoisPath = Get-ChildItem -Path "$env:ProgramFiles\Sysinternals*" -Recurse -Filter whois64.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if ($whoisPath) {

        return $whoisPath
        }
    }
 

    return $whoisCmd
}

function Get-DomainRegistrar {
    param ([string]$Domain, [string]$WhoisCmd)
    try {
        $whoisOutput = & $WhoisCmd $Domain 2>&1 | Where-Object { $_ -notmatch "No such host is known" }
        $registrarLines = $whoisOutput | Select-String -Pattern "Registrar:|Sponsoring Registrar:|Registrar Name:"
        if ($registrarLines) {

            return ($registrarLines | Select-Object -Last 1).Line.Trim()
        } else {

            return "No Registrar info found or whois64.exe is not installed"
        }
    } catch {

        return "Registrar info not found or whois64.exe is not installed"
    }
}

function Get-DnsServers {
    param ([string]$Domain)
    try {
        $dnsRecords = Resolve-DnsName -Name $Domain -Type NS -ErrorAction Stop
        $dnsHosts = $dnsRecords | Where-Object { $_.Type -eq "NS" -and $_.NameHost } | Select-Object -ExpandProperty NameHost
        $baseDomains = @()
        foreach ($hoster in $dnsHosts) {
            $parts = $hoster -split '\.'
            if ($parts.Length -ge 2) {
                $baseDomain = ($parts[-2..-1] -join '.')
                $baseDomains += $baseDomain
            }
        }

        return ($baseDomains | Sort-Object -Unique)
    } catch {

        return "DNS server info not found"
    }
}

function Get-MxRecords {
    param ([string]$Domain)
    try {
        $mxRecords = Resolve-DnsName -Name $Domain -Type MX -ErrorAction Stop
        return ($mxRecords | Where-Object { $_.Type -eq "MX" } | Select-Object -ExpandProperty NameExchange)
    } catch {

        return "MX record info not found"
    }
}

function Get-ARecord {
    param ([string]$Domain)
    try {
        $aRecords = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop

        return ($aRecords | Where-Object { $_.Type -eq "A" } | Select-Object -ExpandProperty IPAddress)
    } catch {

        return "A record not found"
    }
}

function Get-SpfRecord {
    param ([string]$Domain)
    try {
        $txtRecords = Resolve-DnsName -Name $Domain -Type TXT -ErrorAction Stop
        $spf = $txtRecords | Where-Object { $_.Strings -match "^v=spf1" } | Select-Object -ExpandProperty Strings
        return ($spf -join ", ")
    } catch {

        return "SPF record not found"
    }
}

function Get-DkimInfo {
    param ([string]$Domain)
    try {
        $selectors = @("default", "selector1", "selector2")
        $dkimRecords = @()
        foreach ($selector in $selectors) {
            $dkimDomain = "$selector._domainkey.$Domain"
            try {
                $txt = Resolve-DnsName -Name $dkimDomain -Type TXT -ErrorAction Stop
                $dkim = $txt | Where-Object { $_.Strings -match "v=DKIM1" } | Select-Object -ExpandProperty Strings
                if ($dkim) {
                    $dkimRecords += "${selector}: $($dkim -join '')"
                }
            } catch {
                $dkimRecords += "${selector}: DKIM record not found"
            }
        }

        return ($dkimRecords -join "`n")
    } catch {

        return "DKIM info not found"
    }
}

function Get-DmarcInfo {
    param ([string]$Domain)
    try {
        $dmarcDomain = "_dmarc.$Domain"
        $txt = Resolve-DnsName -Name $dmarcDomain -Type TXT -ErrorAction Stop
        $dmarc = $txt | Where-Object { $_.Strings -match "^v=DMARC1" } | Select-Object -ExpandProperty Strings

        return ($dmarc -join ", ")
    } catch {

        return "DMARC info not found"
    }
}

# Load domains from file if specified
 Write-Verbose "Loading domains..."
if ($DomainListFile) {
    $Domains = Get-Content $DomainListFile
}

# Ensure whois is available
 Write-Verbose "Initializing Whois..."
$whoisCmd = Initialize-Whois

$results = foreach ($domain in $Domains) {
    Write-Host "This process could take 45 seconds before returning the data..."
    Write-Verbose "Processing $domain"
    Write-Verbose "Getting Registrar data..."
    $registrar = Get-DomainRegistrar -Domain $domain -WhoisCmd $whoisCmd
    Write-Verbose "Getting Getting DNS Server data..."
    $dnsServers = Get-DnsServers -Domain $domain
    Write-Verbose "Getting MxRecord data..."
    $mxRecords = Get-MxRecords -Domain $domain
    Write-Verbose "Getting A record data..."
    $aRecords = Get-ARecord -Domain $domain
    Write-Verbose "Getting SPF record data..."
    $spfRecord = Get-SpfRecord -Domain $domain
    Write-Verbose "Getting DKIM record data..."
    $dkimInfo = Get-DkimInfo -Domain $domain
    Write-Verbose "Getting Dmarc record data..."
    $dmarcInfo = Get-DmarcInfo -Domain $domain

    $result = [PSCustomObject]@{
        Domain     = $domain
        Registrar  = $registrar
        DnsServers = ($dnsServers -join ", ")
        MxRecords  = ($mxRecords -join ", ")
        ARecord    = ($aRecords -join ", ")
        SPF        = $spfRecord
        DKIM       = $dkimInfo
        DMARC      = $dmarcInfo
    }

    Write-Host "Domain:`t$($result.Domain)"
    Write-Host "Registrar:`t$($result.Registrar)"
    Write-Host ("DNS Servers:`t" + ($result.DnsServers -replace ',', "`n`t"))
    Write-Host ("MX Records:`t" + ($result.MxRecords -replace ',', "`n`t"))
    Write-Host ("A Record:`t" + ($result.ARecord -replace ',', "`n`t"))
    Write-Host "SPF:`t$($result.SPF)"
    Write-Host "DKIM:`t$($result.DKIM)"
    Write-Host "DMARC:`t$($result.DMARC)"
    Write-Host ""
    Pause
    
    $result
}

# Export to CSV if requested
if ($ExportCsv) {
    $results | Export-Csv -Path $ExportCsv -NoTypeInformation
    Write-Host "Results exported to $ExportCsv"
}
