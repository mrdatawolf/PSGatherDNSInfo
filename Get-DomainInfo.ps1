
<#
.SYNOPSIS
    Retrieves registrar, DNS, A record, and MX records for one or more domains.

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

    [switch]$VerboseOutput
)

if ($VerboseOutput) {
    $VerbosePreference = "Continue"
}

function Ensure-WhoisInstalled {
    $whoisCmd = "whois64.exe"
    if (-not (Get-Command $whoisCmd -ErrorAction SilentlyContinue)) {
        Write-Warning "$whoisCmd not found. Please install it manually and ensure it's in your PATH."
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
            return "Registrar info not found"
        }
    } catch {
        return "Registrar info not found"
    }
}

function Get-DnsServers {
    param ([string]$Domain)
    try {
        $dnsRecords = Resolve-DnsName -Name $Domain -Type NS -ErrorAction Stop
        return ($dnsRecords | Where-Object { $_.Type -eq "NS" } | Select-Object -ExpandProperty NameHost)
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

# Load domains from file if specified
if ($DomainListFile) {
    $Domains = Get-Content $DomainListFile
}

# Ensure whois is available
$whoisCmd = Ensure-WhoisInstalled

$results = foreach ($domain in $Domains) {
    Write-Verbose "Processing $domain"
    $registrar = Get-DomainRegistrar -Domain $domain -WhoisCmd $whoisCmd
    $dnsServers = Get-DnsServers -Domain $domain
    $mxRecords = Get-MxRecords -Domain $domain
    $aRecords = Get-ARecord -Domain $domain

    $result = [PSCustomObject]@{
        Domain     = $domain
        Registrar  = $registrar
        DnsServers = ($dnsServers -join ", ")
        MxRecords  = ($mxRecords -join ", ")
        ARecord    = ($aRecords -join ", ")
    }

    # Output to console
    Write-Host "Domain:`t$($result.Domain)"
    Write-Host "Registrar:`t$($result.Registrar)"
    Write-Host ("DNS Servers:`t" + ($result.DnsServers -replace ',', "`n`t"))
    Write-Host ("MX Records:`t" + ($result.MxRecords -replace ',', "`n`t"))
    Write-Host ("A Record:`t" + ($result.ARecord -replace ',', "`n`t"))

    Write-Host ""

    $result
}

# Export to CSV if requested
if ($ExportCsv) {
    $results | Export-Csv -Path $ExportCsv -NoTypeInformation
    Write-Host "Results exported to $ExportCsv"
}
