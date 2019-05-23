Param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [Parameter(Mandatory=$true)]
    [string]$Output
)

Import-Module .\IvantiSCN -Force


# Test if the input path exists
if (-not (Test-Path $Path -PathType Container)) {
    Throw("$Path does not exist")
}


# convert a directory of SCN files into CSV
$files = Get-ChildItem -File -Include "*.scn" -Path "$Path\*"
if (-not ($files -is [Array])) {
    $files = @($files)
}
$csv = @()
foreach ($f in $files) {
    Write-Progress -Activity "Parsing and converting contents of $Path" -Status "Processing $f `($($files.IndexOf($f) + 1)`/$($files.Count)`)" -PercentComplete ((($files.IndexOf($f) + 1) / $files.Count) * 100)
    $row = Import-SCN -Path $f.FullName
    ## check to see if we need to add any additional properties to each object ##
    if ($csv) {
        $propsCurrent = ($csv | Select -First 1 | Get-Member -MemberType NoteProperty).Name
        $propsNew = ($row | Get-Member -MemberType NoteProperty).Name
        $propsDiff = ((Compare-Object -ReferenceObject $propsCurrent -DifferenceObject $propsNew) | Where SideIndicator -eq '=>').InputObject
        ## we need to add some new properties - we'll default this to empty ##
        if ($propsDiff) {
            $props = [ordered]@{}
            foreach($p in $propsDiff) {
                $props[$p] = ''
            }
            foreach($c in $csv) {
                $c | Add-Member -NotePropertyMembers $props
            }
        }
    }
    $csv += $row
}
$csv | Export-Csv -Path $Output -NoTypeInformation