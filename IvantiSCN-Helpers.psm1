<##################################################################################
    Aim:        To generate a MAC address that has the following attributes: -
                * Unicast
                * LAA
    Notes:      See https://en.m.wikipedia.org/wiki/MAC_address for spec
##################################################################################>
function New-MACAddressField {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Delimeter = ':'
    )

    Begin {

    }

    Process {
        [byte]$mac = "0x{0:X}" -f $(Get-Random -Minimum 0 -Maximum 16)
        $mac = $mac -band 254 # Set to unicast MAC
        $mac = $mac -bor 2 # Set to LAA
        [string]$mac = ("{0:X}" -f $mac).PadLeft(2, "0")
        while ($mac.length -lt 12)  {
            $mac += "{0:X}" -f $(Get-Random -Minimum 0 -Maximum 16)
        }
        $ret = ($mac -split ('(..)') | Where { $_ }) -join $Delimeter
    }

    End {
        return $ret
    }
}

<###################################################################################################
    Aim:        To generate an epoch time that is somewhere between the given offset and base/now.
    Parameters: Offset = how far to go backwards or forwards
                Unit = which unit to use when generating the new epoch
                Base = if specified this will be taken as the starting point for th offset otherwise
                       Now is used.
                Format = as described here: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-6#notes
    Notes:      A negative offset will be in the past and a positive in the future
###################################################################################################>
function New-DateOffsetField {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$Offset,

        [Parameter(Mandatory=$true)]
        [ValidateSet('D', 'M')]
        [string]$Unit,

        [Parameter(Mandatory=$false)]
        $Base = -1,

        [Parameter(Mandatory=$false)]
        [string]$Format = '%s',

        [Parameter(Mandatory=$false)]
        [switch]$Exact
    )

    Begin {
        if ($Base -eq -1) {
            $now = Get-Date -UFormat %s
        } else {
            if ($Base -match "^\d+$") {
                $Base = [System.DateTimeOffset]::FromUnixTimeSeconds($Base).DateTime
            }
            $now = Get-Date $Base -UFormat '%s'
        }
    }

    Process {
        switch ($Unit) {
            'D' {
                $then = Get-Date ([System.DateTimeOffset]::FromUnixTimeSeconds($now).DateTime).AddDays($Offset) -UFormat '%s'
                break
            }
            'M' {
                $then = Get-Date ([System.DateTimeOffset]::FromUnixTimeSeconds($now).DateTime).AddMonths($Offset) -UFormat '%s'
                break
            }
        }
        if ($Exact.IsPresent) {
            $ret = $then
        } else {
            $ret = Get-Random -Minimum $(if ($Offset -lt 0) { $then } else { $now }) -Maximum $(if ($Offset -lt 0) { $now } else { $then })
        }
    }

    End {
        $ret = $(Get-Date ([System.DateTimeOffset]::FromUnixTimeSeconds($ret).DateTime) -UFormat $Format)
        return $ret
    }
}

<##################################################################################################################
    Aim:            To generate a new GUID in the format specified and convert to upper case if needed
    Parameters:     Format = the format to return the GUID in as per specification
                    Uppercase = if provided will convert the return to upper case
    Notes:          Formats are described here: https://docs.microsoft.com/en-us/dotnet/api/system.guid.tostring
##################################################################################################################>
function New-GuidField {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('N', 'D', 'B', 'P', 'X')]
        [string]$Format = 'D',

        [Parameter(Mandatory=$false)]
        [switch]$Uppercase
    )

    Begin {
    }

    Process {
        $ret = [Guid]::NewGuid().ToString($Format)
        if ($Uppercase) {
            $ret = $ret.ToUpper()
        }
    }

    End {
        return $ret
    }
}

<#######################################################################
    Aim:        To return a string formatted in the following way: -
                $Prefix$StringData$Suffix or $Prefix[$PadChar..n]$StringData$Suffix
#######################################################################>
function New-StringField {
    [CmdletBinding(DefaultParametersetName='None')]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$StringData,

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [string]$Prefix = '',

        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [string]$Suffix = '',

        [Parameter(Mandatory=$true, ParameterSetName='ApplyPad')]
        [AllowEmptyString()]
        [string]$PadChar,

        [Parameter(Mandatory=$true, ParameterSetName='ApplyPad')]
        [byte]$PadLength
    )

    Begin {
    }

    Process {
        $ret = ($Prefix + $(if ($PSCmdlet.ParameterSetName -eq 'ApplyPad' -and $PadChar -ne [string]::Empty) { $StringData.PadLeft($PadLength, $PadChar) } else { $StringData }) + $Suffix).Trim()
    }

    End {
        return $ret
    }
}

<#

#>
function New-SizeField {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [int]$Lower,

        [Parameter(Mandatory=$true)]
        [int]$Upper,

        [Parameter(Mandatory=$false)]
        [string]$UnitsFrom = 'MB',

        [Parameter(Mandatory=$false)]
        [string]$UnitsTo = 'MB',

        [Parameter(Mandatory=$false)]
        [switch]$Power2,

        [Parameter(Mandatory=$false)]
        [switch]$Suffix
    )

    Begin {
        $ret = $null
    }

    Process {
        $ret = Get-Random -Minimum $Lower -Maximum $Upper
        if ($Power2) {
            if (($ret -band ($ret - 1)) -ne 0) {
                $ret = [Convert]::ToString($ret, 2)
                $ret = '1'.PadRight($ret.length, '0')
                $ret = [Convert]::ToInt32($ret, 2)
            }
        }
        if ($UnitsTo -eq 'B') {
            $UnitsTo = ''
        }
        if ($UnitsFrom -eq 'B') {
            $UnitsFrom = ''
        }
        $ret = $("$ret$UnitsFrom"/"1$UnitsTo")

        if ($Suffix) {
            [string]$ret += " $UnitsTo"
        }
    }

    End {
        return $ret
    }
}

<#

#>
function New-IPField {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Address,

        [Parameter(Mandatory=$true)]
        [string]$Mask
    )

    Begin {
        $ret = $null
        $mBits = ''
        $cidr = 0
        $binAddress = ''
    }

    Process {
        ## get the binary version of the IP address ##
        foreach($octet in $Address.Split('.')) {
            $binAddress += $([Convert]::toString($octet, 2).PadLeft(8, '0'))
        }

        ## calculate the mask bits ##
        if ($Mask.Contains('.')) {
            foreach($octet in $Mask.Split('.')) {
                $mBits += $([Convert]::toString($octet, 2).PadLeft(8, '0'))
            }
            $cidr = $mBits.indexOf('0')
        } else {
            $cidr = $Mask
        }

        ## calculate the first and last addresses ##
        $firstIP = "$($binAddress -replace ".{$(32 - $cidr)}$", ''.PadLeft(32 - $cidr - 1, '0'))1"
        $lastIP = "$($binAddress -replace ".{$(32 - $cidr)}$", ''.PadLeft(32 - $cidr - 1, '1'))0"

        ## get all the possible addresses in the range ##
        $firstIP64 = ([Convert]::ToInt64($firstIP, 2))
        $lastIP64 = ([Convert]::ToInt64($lastIP, 2))
        $ipAddresses = @()
        for($ip=$firstIP64; $ip -le $lastIP64; $ip++) {
            $i=0
            $dottedDecimal = ''
            $binIP = ([Convert]::ToString($ip, 2)).PadLeft(32, '0')
            do {
                $dottedDecimal += '.' + [string]$([Convert]::toInt32($binIP.Substring($i, 8), 2))
                $i+=8
            } while ($i -le 24)
            $ipAddresses += $dottedDecimal.Substring(1)
        }
        $ret = $ipAddresses[(Get-Random -Minimum 0 -Maximum ($ipAddresses.Count - 1))]
    }

    End {
        return $ret
    }
}