<#
    # CSV Format
    ------------

    ## Column Codes
    ---------------
    |repeat - when this pattern is used in a column heading the row is repeated the number of times specified, default = 1


    ## Field Codes
    --------------
    Date fields - if a date should be generated the field must contain the following pattern: |dt|format|unit|X|exact|link field
                    | = denotes a special field
                    dt = denotes a date time field
                    format = as per https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-6#notes
                    unit = the units to use (M = months, D = days)
                    X = offset to generate the date (negative for past)
                    exact = should not be random and should be exactly offset from the specified date (1|0)
                    link field = the field name to link to the value generated will be a random time between now and specified offset
    MAC fields - if a MAC address should be generated the field must contain the following pattern: |mac|delimeter
                    | = denotes a special field
                    mac = denotes a MAC field
                    delimeter = the delimter to use - if not provided a colon (:) will be used
    GUID fields - if a GUID is to be generated the field must contain the following pattern: |guid|case|format
                    | = denotes a special field
                    guid = denotes a GUID field
                    case = the case the GUID should be returned in - default is 'L' ('U', 'L')
                    format = the format of the GUID returned - default is 'D' ('N', 'D', 'B', 'P', 'X' - see https://docs.microsoft.com/en-us/dotnet/api/system.guid.tostring)
    Increment fields - if an incremental field is to be generated that increments in some way then the following pattern should be used: |inc|Type|Prefix|Suffix|Pad Character|Pad Length
                    | = denotes a special field
                    inc = denotes an incremental field
                    Type = Global, Field, Prefix, Suffix, PrefixSuffix - default is 'G' ('G', 'F', 'P', 'S', 'PS')
                            Global will use the same incremented number across all fields
                            Field will use the next number for that field only
                            Prefix will use the next number for that prefix only
                            Suffix will use the next number for that suffix only
                            PrefixSuffix will use the next number for that prefix/suffix combination only
                    Prefix = the prefix that should come before the incremental part
                    Suffix = the suffix that should come after the incremental part
                    Pad Character = the character to be used for left padding
                    Pad Length = the length of the entire incremental part
    Size fields - if a field needs to be generated that represents a size of a disk drive/RAM etc, the following pattern should be used: |size|lower|upper|units_from|units_to|power2|suffix
                    | = denotes a special field
                    size = denotes a size field
                    lower = the lower bound for which to generate a number
                    upper = the upper bound for which to generate a number - this is allowed to be a linked value just specify the field name that will act as the upper bound
                            - when using a linked field the unit from that field is ignored and is assumed to be the same as units_from.
                    units_from = the unit for the lower and upper bound, e.g. B, MB, GB
                    units_to = the unit for the output, e.g. B, MB, GB
                    power2 = whether the result should be a valid power2 for the result - Default is 1 (1|0)
                    suffix = whether to include the suffix in the output or not (1|0) - Default is 1 (1|0)
    IP field - use this to generate in IP in a given subnet.  No validation is done to check DHCP etc.  Use the following pattern: |ip|network_address|mask
                    | = denotes a special field
                    ip = denotes an IP field
                    network_address = provides the network address of the subnet in question
                    mask = can be CIDR (number of bits) or dotted decimal
    Lookup field - used to look up values from a CSV file.  The pattern should be: |lkp|path|field_format|key_field|key
                    | = denotes a special field
                    lkp = denotes a lookup field
                    path = full path to the CSV to lookup in
                    field_format = the fields to extract and the format they should take, e.g. "DOMAIN\%FirstName%.%LastName%"
                    key_field = lookup based on key_field (in lookup file) rather than selecting at random
                    key = the field which contains the matching value (this should not be a linked field, but can be a value or field name)
#>

#$script:increment = 1
#$script:persist = @{}

$script:incrementers = @{
    'g' = 1;
    'f' = @{};
    'p' = @{};
    's' = @{};
    'ps' = @{
        'delim' = '¬'
    }
}

<#########################################################################################################
    Aim:            To convert the given SCN item into an object
    Parameters:     InputObject = the item that needs to be converted
    Notes:          Properties should be kept in the order that they were received
                    It is assumed that SCN items starting with either '<' or '_' do not currently need
                    to be converted
#########################################################################################################>
function ConvertFrom-SCN {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$InputObject
    )

    Begin {
        $props = [ordered]@{}
    }

    Process {
        if (@('<', '_') -notcontains $InputObject[0]) {
            $obj = $InputObject.Split('=')
            if ($obj[0]) {
                $props[$($obj[0].Trim())] = $obj[1].Trim()
            }
        }
    }

    End {
        $ret = New-Object -Type PSCustomObject -Property $props
        return $ret
    }
}

<###############################################################################################################
    Aim:            To convert the given object to the format required for a SCN file
    Parameters:     InputObject = Object as expected to be received after using Import-Csv or ConvertFrom-Csv
###############################################################################################################>
function ConvertTo-SCN {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [PSObject]$InputObject
    )

    Begin {
        $ret = @()
    }

    Process {
        $header = $InputObject | Get-Member -MemberType NoteProperty | Sort
        foreach ($col in $header) {
            if ($InputObject.$($col.Name)) {
                $ret += "$($col.Name) = $($InputObject.$($col.Name))"
            }
        }
    }

    End {
        return $ret
    }
}

<####################################################################################
    Aim:            To take the contents of a SCN file and convert it to an object
    Parameters:     Path = path to the SCN file to import
####################################################################################>
function Import-SCN {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    Begin {
    }

    Process {
        $content = Get-Content -Path $Path
        $ret = $content | ConvertFrom-SCN
    }

    End {
        return $ret
    }
}

<#########################################################################################################
    Aim:            To write the given object that is in SCN format to disk
    Parameters:     InputObject = can be passed on pipeline but is expected to the be the SCN object as
                                  generated by ConvertTo-SCN
                    Path = the path to write the SCN file
#########################################################################################################>
function Export-SCN {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [PSObject]$InputObject,

        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    Begin {
        if (-not (Test-Path (Split-Path $Path -Parent) -PathType Container)) {
            New-Item -ItemType Directory -Path (Split-Path $Path -Parent) | Out-Null
        }
    }

    Process {
        $InputObject | Out-File -FilePath $Path -Encoding UTF8
    }
}

<#############################################################################################################################
    Aim:            To initialise values that should be in special fields.
    Parameters:     InputObject = the object that needs to have values completed (expected to be prior to converting to SCN)
    Notes:          For the format of the field please see the comment at the top of the script
#############################################################################################################################>
function Initialize-SCNFields {
    [CmdletBinding()]
    Param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [PSObject]$InputObject
    )

    Begin {
    }

    Process {
        $incWasGlobal = $false
        $ret = $InputObject.PsObject.Copy()
        $retAct = @()
        ## we only need to work on columns that aren't special ##
        $header = $InputObject | Get-Member -MemberType NoteProperty | Where Name -notlike "|*"
        ## remove the special members from the return object ##
        $headerSpecial = ($InputObject | Get-Member -MemberType NoteProperty | Where Name -like "|*").Name
        foreach($h in $headerSpecial) {
            $ret.PSObject.Properties.Remove($h)
        }
        $rowRepeat = if ('|repeat' -in $headerSpecial) { $InputObject.'|repeat' } else { 1 }
        if (-not $rowRepeat) {
            $rowRepeat = 1
        }

        for($r=0; $r -lt $rowRepeat; $r++) {
            foreach($fld in $header) {
                if ($InputObject.($fld.Name)[0] -eq '|') {
                    $fDetails = $InputObject.($fld.Name).Split('|', [System.StringSplitOptions]::RemoveEmptyEntries)
                    switch ($fDetails[0]) {
                        'dt' {
                            ## work out which fields need to be complete prior to this one ##
                            $tDeps = @()
                            $tFldName = $fld.Name
                            $tFld = $InputObject.($tFldName)
                            while ($tFld -ne $fDetails) {
                                $tBase = if ($fDetails.Count -gt 5) { $fDetails[5] } else { -1 }
                                $tDeps += $tFldName
                                if ($tBase -ne -1) {
                                    $tFldName = $tBase
                                    $fDetails = $InputObject.($tFldName).Split('|', [System.StringSplitOptions]::RemoveEmptyEntries)
                                    $tFld = $InputObject.($tFldName)
                                } else {
                                    break
                                }
                            }
                            ## reverse the array and go and fill them out ##
                            [Array]::Reverse($tDeps)
                            foreach($fld in $tDeps) {
                                $fDetails = $InputObject.($fld).Split('|', [System.StringSplitOptions]::RemoveEmptyEntries)
                                [bool]$tExact = if ($fDetails.Count -gt 4) { $fDetails[4] } else { 0 }
                                $tBase = if ($fDetails.Count -gt 5) { $ret.($fDetails[5]) } else { -1 }
                                $ret.($fld) = New-DateOffsetField -Format $fDetails[1] -Unit $fDetails[2] -Offset $fDetails[3] -Base $tBase -Exact:$tExact
                            }
                            break
                        }
                        'mac' {
                            $delim = if ($fDetails.Count -eq 2) { $fDetails[1] } else { ':' }
                            $ret.($fld.Name) = New-MACAddressField -Delimeter $delim
                            break
                        }
                        'guid' {
                            $toFormat = 'D'
                            $toUpper = $false
                            if ($fDetails.Count -gt 1) {
                                $toUpper = if ($fDetails[1].toLower() -eq 'u') { $true } else { $false }
                                if ($fDetails.Count -eq 3) {
                                    $toFormat = $fDetails[2]
                                }
                            }
                            $ret.($fld.Name) = New-GuidField -Format $toFormat -Uppercase:$toUpper
                            break
                        }
                        'inc' {
                            [string]$tPrefix = if ($fDetails.Count -gt 2) { $fDetails[2] } else { '' }
                            [string]$tSuffix = if ($fDetails.Count -gt 3) { $fDetails[3] } else { '' }
                            $tPadChar = if ($fDetails.Count -gt 4) { $fDetails[4] } else { '' }
                            $tPadLength = if ($fDetails.Count -gt 5) { $fDetails[5] } else { 0 }

                            $incGlobal = $true
                            if ($fDetails.Count -gt 1) {
                                $incGlobal = if ($fDetails[1].toLower() -eq 'g') { $true } else { $false }
                            }
                            ## determine the current value of the increment field ##
                            if (-not $incGlobal) {
                                switch($fDetails[1].toLower()) {
                                    'f' {
                                        if (-not $script:incrementers.f.ContainsKey($fld.Name)) {
                                            $inc = $script:incrementers.f.($fld.Name) = 1
                                        } else {
                                            $inc = $script:incrementers.f.($fld.Name)
                                        }
                                        break
                                    }
                                    'p' {
                                        if (-not $tPrefix) {
                                            throw('Cannot use a prefix increment as no prefix has been specified')
                                        }
                                        if (-not $script:incrementers.p.ContainsKey($tPrefix)) {
                                            $inc = $script:incrementers.p.($tPrefix) = 1
                                        } else {
                                            $inc = $script:incrementers.p.($tPrefix)
                                        }
                                        break
                                    }
                                    's' {
                                        if (-not $tSuffix) {
                                            throw('Cannot use a suffix increment as no suffix has been specified')
                                        }
                                        if (-not $script:incrementers.s.ContainsKey($tSuffix)) {
                                            $inc = $script:incrementers.s.($tSuffix) = 1
                                        } else {
                                            $inc = $script:incrementers.s.($tSuffix)
                                        }
                                        break
                                    }
                                    'ps' {
                                        if (-not $tPrefix -or -not $tSuffix) {
                                            throw('Cannot use a prefix/suffix increment as either a prefix or suffix has not been specified')
                                        }
                                        if (-not $script:incrementers.ps.ContainsKey("$tPrefix$($script:incrementers.ps.delim)$tSuffix")) {
                                            $inc = $script:incrementers.ps.("$tPrefix$($script:incrementers.ps.delim)$tSuffix") = 1
                                        } else {
                                            $inc = $script:incrementers.ps.("$tPrefix$($script:incrementers.ps.delim)$tSuffix")
                                        }
                                        break
                                    }
                                }
                            } else {
                                $inc = $script:incrementers.g
                                $incWasGlobal = $true
                            }
                            $ret.($fld.Name) = New-StringField -StringData $inc -Prefix $tPrefix -Suffix $tSuffix -PadChar $tPadChar -PadLength $tPadLength
                            ## increment the correct counter ##
                            if (-not $incGlobal) {
                                switch($fDetails[1].toLower()) {
                                    'f' {
                                        $script:incrementers.f.($fld.Name)++
                                        break
                                    }
                                    'p' {
                                        $script:incrementers.p.($tPrefix)++
                                        break
                                    }
                                    's' {
                                        $script:incrementers.s.($tSuffix)++
                                        break
                                    }
                                    'ps' {
                                        $script:incrementers.ps.("$tPrefix$($script:incrementers.ps.delim)$tSuffix")++
                                        break
                                    }
                                }
                            }
                            break
                        }
                        'size' {
                            ## work out which fields need to be complete prior to this one ##
                            $tIsNumeric = '^\d+$'
                            $tDeps = @($fld.Name)
                            $tUpper = $fDetails[2]
                            while ($tUpper -and $tUpper -notmatch $tIsNumeric) {
                                $fDetails = $InputObject.($tUpper).Split('|', [System.StringSplitOptions]::RemoveEmptyEntries)
                                if ($fDetails -eq $InputObject.($tUpper)) {
                                    break
                                }
                                $tDeps += $tUpper
                                $tUpper = $fDetails[2]
                            }
                            ## reverse the array and go and fill them out ##
                            [Array]::Reverse($tDeps)
                            foreach($fld in $tDeps) {
                                $fDetails = $InputObject.($fld).Split('|', [System.StringSplitOptions]::RemoveEmptyEntries)
                                $tLower = $fDetails[1]
                                $tUpper = if ($fDetails[2] -match $tIsNumeric) { $fDetails[2] } else { $ret.($fDetails[2]) }
                                $tUpper = $tUpper.Split(' ')[0]
                                $tUnitsFrom = if ($fDetails.Count -gt 3) { $fDetails[3] } else { 'MB' }
                                $tUnitsTo = if ($fDetails.Count -gt 4) { $fDetails[4] } else { 'MB' }
                                [bool]$tPower2 = if ($fDetails.Count -gt 5) { [int]$fDetails[5] } else { $true }
                                [bool]$tSuffix = if ($fDetails.Count -gt 6) { [int]$fDetails[6] } else { $true }
                                $ret.($fld) = New-SizeField -Lower $tLower -Upper $tUpper -UnitsFrom $tUnitsFrom -UnitsTo $tUnitsTo -Power2:$tPower2 -Suffix:$tSuffix
                            }
                            break
                        }
                        'ip' {
                            $tIp = $fDetails[1]
                            $tMask = $fDetails[2]
                            $ret.($fld.Name) = New-IPField -Address $tIp -Mask $tMask
                            break
                        }
                        'lkp' {
                            $tPath = [System.Environment]::ExpandEnvironmentVariables($fDetails[1])
                            $tFormat = $fDetails[2]
                            $tKeyField = if ($fDetails.Count -gt 3) { $fDetails[3] } else { $false }
                            $tKeyValue = if ($fDetails.Count -gt 4) { $fDetails[4] } else { $false }
                            ## get the fields we need to look for ##
                            $tPattern = "(%.+?%)"
                            $tFormatFields = [System.Text.RegularExpressions.Regex]::Matches($tFormat, $tPattern)
                            ## get the lookup file into memory ##
                            $csv = Import-Csv -Path $tPath
                            ## check the format fields exist ##
                            $tCsvFields = ($csv | Get-Member -MemberType NoteProperty).Name
                            foreach($ff in $tFormatFields) {
                                if ($ff.ToString().Replace('%', '') -notin $tCsvFields) {
                                    throw("Invalid field specified in format field - $ff")
                                }
                            }
                            ## pick an entry from the lookup file ##
                            if (-not $tKeyField) {
                                $tRow = Get-Random -Minimum 0 -Maximum ($csv.Count - 1)
                            } else {
                                if ($tKeyField -notin $tCsvFields) {
                                    throw("Invalid key field specified - $tKeyField")
                                }
                                if (-not $tKeyValue) {
                                    throw("No value for the key field specified")
                                }
                                if ($tKeyValue -in ($header).Name) { # key value is a field name
                                    $tKeyValue = $ret."$tKeyValue"
                                }
                                $tRow = $csv.IndexOf($($csv | Where $tKeyField -eq $tKeyValue))
                                if ($tRow -eq -1) {
                                    throw("No corresponding row found in the lookup file")
                                }
                            }
                            ## build the result ##
                            $tValue = $tFormat
                            foreach($ff in $tFormatFields) {
                                $tValue = $tValue.Replace($ff, $csv[$tRow].$($ff.ToString().Replace('%', '')))
                            }
                            $ret.($fld.Name) = $tValue
                        }
                    }
                }
            }
            if ($incWasGlobal) {
                $script:incrementers.g++
            }
            $retAct += $ret.PsObject.Copy()
        }
    }

    End {
        return $retAct
    }
}

Export-ModuleMember -Function *-SCN*