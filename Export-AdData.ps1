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

$inactiveTable = ($inactiveUsers |
  Format-Table samAccountName, displayName, lastLogon, DaysInactive -AutoSize |
  Out-String -Width 200)


$counts = @{}              # Department count
foreach ($u in $data.users) {
    $d = if ($u.department) { $u.department } else { '(saknas)' }
    if ($counts[$d]) { $counts[$d]++ } else { $counts[$d] = 1 }
}

# Show off more nicely
$deptSection = ($counts.GetEnumerator() |
  Sort-Object Value -Descending |
  ForEach-Object { "{0,-10} {1,5}" -f $_.Name, $_.Value }) -join "`n" #Numbers are for adjusting the rows

# Building the report after counts and loops has been established
$report = @"
ACTIVE DIRECTORY AUDIT
======================
Exportdatum: $($exportDate.ToString('yyyy-MM-dd HH:mm'))

-----------------------------------------------------------------------


Inaktiva användare (>30 dagar): $($inactiveUsers.Count)

$inactiveTable
-----------------------------------------------------------------------

Användare per avdelning: 

$deptSection
"@

# Write the file with encoding

Set-Content -Path 'ad_report.txt' -Value $report -Encoding UTF8

