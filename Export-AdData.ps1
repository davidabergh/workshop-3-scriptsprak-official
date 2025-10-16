# Read JSON
$data       = Get-Content -Path 'ad_export.json' -Raw -Encoding UTF8 | ConvertFrom-Json
$domain     = $data.domain
$exportDate = [datetime]$data.export_date

# Inactive > 30 days
$thirtyDaysAgo = (Get-Date).AddDays(-30)
$inactiveUsers =
    $data.users |
    Where-Object { $_.lastLogon -and ([datetime]$_.lastLogon) -lt $thirtyDaysAgo } |
    Select-Object samAccountName, displayName, lastLogon,
        @{ Name = 'DaysInactive'
           Expression = { (New-TimeSpan -Start ([datetime]$_.lastLogon) -End (Get-Date)).Days } }


# Counting inactive users, but also for transporting it into a csv file which users haven't logged in for 30 days
$inactiveUsers |
  Sort-Object DaysInactive -Descending |
  Select-Object `
    @{N='User';E={$_.samAccountName}},
    displayName,
    department,
    site,
    @{N='LastLogon';E={ ([datetime]$_.lastLogon).ToString('yyyy-MM-dd HH:mm') }},
    DaysInactive |
  Export-Csv 'inactive_users.csv' -NoTypeInformation -Encoding UTF8 -UseCulture

  # Calculating how many days old the users passwords are

$pwdAges =
  $data.users |
  Where-Object { $_.passwordLastSet } |
  Select-Object samAccountName, displayName, passwordNeverExpires,
    @{N='PasswordLastSet';E={ [datetime]$_.passwordLastSet }},
    @{N='PasswordAgeDays';E={ ((Get-Date) - [datetime]$_.passwordLastSet).Days }}

$pwdTable = ($pwdAges |
  Sort-Object PasswordAgeDays -Descending |
  Select-Object samAccountName, displayName,
                @{N='PasswordLastSet';E={ $_.PasswordLastSet.ToString('yyyy-MM-dd HH:mm') }},
                PasswordAgeDays, passwordNeverExpires |
  Format-Table -AutoSize | Out-String -Width 200)



$inactiveTable = ($inactiveUsers |
  Sort-Object DaysInactive -Descending |
  Select-Object samAccountName, displayName, lastLogon, DaysInactive |
  Format-Table -AutoSize | Out-String -Width 200)


$counts = @{}              # Department count
foreach ($u in $data.users) {
    $d = if ($u.department) { $u.department } else { '(saknas)' }
    if ($counts[$d]) { $counts[$d]++ } else { $counts[$d] = 1 }
}

# Show off more nicely
$deptSection = ($counts.GetEnumerator() |
  Sort-Object Value -Descending |
  ForEach-Object { "{0,-10} {1,5}" -f $_.Name, $_.Value }) -join "`n" #Numbers are for adjusting the rows


# Count for computers per site with group object 
$siteCounts =
  $data.computers |
  Group-Object site -NoElement |
  Sort-Object Count -Descending

$siteSection = ($siteCounts |
  ForEach-Object { "{0,-18} {1,5}" -f $_.Name, $_.Count }) -join "`n"

# Building the report after counts and loops have been established
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
-------------------------------

Datorer per site: 

$siteSection
--------------------------------

Lösenordsålder per användare:

$pwdTable
-----------------------------------------------------------------------------------------------
"@

# Write the file with encoding

Set-Content -Path 'ad_report.txt' -Value $report -Encoding UTF8

