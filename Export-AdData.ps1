# Read JSON
$data       = Get-Content -Path 'ad_export.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$domain     = $data.domain
$exportDate = [datetime]$data.export_date

# Inactive > 30 dagar
$thirtyDaysAgo = (Get-Date).AddDays(-30)
$inactiveUsers =
    $data.users |
    Where-Object { $_.lastLogon -and ([datetime]$_.lastLogon) -lt $thirtyDaysAgo } |
    Select-Object samAccountName, displayName, lastLogon,
        @{ Name = 'DaysInactive'
           Expression = { (New-TimeSpan -Start ([datetime]$_.lastLogon) -End (Get-Date)).Days } }

# Building the report after inactive users has been established
$report = @"
ACTIVE DIRECTORY AUDIT
======================
Exportdatum: $($exportDate.ToString('yyyy-MM-dd HH:mm'))
--------------------------------------------------------

Inaktiva användare (>30 dagar): $($inactiveUsers.Count)

$($inactiveUsers | Format-Table samAccountName, displayName, lastLogon, DaysInactive -AutoSize | Out-String)
"@

# Write the file with encoding
Set-Content -Path 'ad_report.txt' -Value $report -Encoding UTF8

