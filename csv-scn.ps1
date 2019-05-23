Param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory=$false)]
    [string]$FileNameField
)

Import-Module .\IvantiSCN -Force

# Test if the input file exists
if (-not (Test-Path $Path)) {
    Throw("$Path does not exist")
}

# convert CSV file into SCN files
$csv = Import-CSV -Path $Path
if (-not ($csv -is [Array])) {
    $csv = @($csv)
}
$i = 1
foreach ($line in $csv) {
    Write-Progress -Activity "Parsing and exporting $Path" -Status "Processing row $($csv.IndexOf($line) + 1) of $($csv.Count)" -PercentComplete ((($csv.IndexOf($line) + 1) / $csv.Count) * 100)
    $scn = $line | Initialize-SCNFields
    foreach($s in $scn) {
        $fName = if (-not $FileNameField) { $i } else { $s.$FileNameField }
        $s = $s | ConvertTo-SCN
        Export-SCN -InputObject $s -Path "$OutputDirectory\$fName.scn"
        $i++
    }
}
