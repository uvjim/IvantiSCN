# IvantiSCN
## Purpose
This PowerShell module and wrapper scripts was originally intended to convert a CSV file into a SCN file that can be imported by Ivanti Endpoint Manager.  It has somewhat grown since then to provide the following functionality: -

* Convert from CSV to SCN
* Convert from SCN to PowerShell object (and subsequently to CSV if required)
* Produce demo/dummy data that can be used in an Ivanti Endpoint Manager system

## Producing Demo Data
When looking to produce demo data it is important that it is both relevant and believable; sticking with the same static data over time does not bode well for good demonstrations or for showing off functionality very well.

With that in mind a template CSV file can be built which allows dynamic creation of this data.  The rules of the CSV file format are described below.  An example "template" can be found in this repository.

### CSV Format
In order to identify a dynamic/special field the `pipe (|)` character is used.  This character is also used as a delimter in that field.

#### Column Codes
In order to control what happens to a row a "Column Code" is used.  This code is ignored in the output and is only used for affecting the behaviour of processing a row.

##### Available Patterns
* `repeat` - when this pattern is used in the row is repeated the number of times specified, default = 1

#### Field Codes
Field codes are used to define what a fiedl should be populated with.  If the field does not start with the delimeter then it is assumed to be a literal value.

##### Available Patterns
* Date fields - if a date should be generated the field must contain the following pattern:  

  ###### `|dt|format|unit|X|exact|link field`  

  `dt` = denotes a date time field  
  `format` = as per https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-date?view=powershell-6#notes  
  `unit` = the units to use (M = months, D = days)  
  `X` = offset to generate the date (negative for past)  
  `exact` = should not be random and should be exactly offset from the specified date (1|0)  
  `link field` = the field name to link to the value generated will be a random time between now and specified offset
                
* MAC fields - if a MAC address should be generated the field must contain the following pattern:  

  ###### `|mac|delimeter`  

  `mac` = denotes a MAC field  
  `delimeter` = the delimter to use - if not provided a colon (:) will be used
                
* GUID fields - if a GUID is to be generated the field must contain the following pattern:  

  ###### `|guid|case|format`  

  `guid` = denotes a GUID field  
  `case` = the case the GUID should be returned in - default is 'L' ('U', 'L')  
  `format` = the format of the GUID returned - default is 'D' ('N', 'D', 'B', 'P', 'X' - see https://docs.microsoft.com/en-us/dotnet/api/system.guid.tostring)
                
* Increment fields - if an incremental field is to be generated that increments in some way then the following pattern should be used:  

  ###### `|inc|Type|Prefix|Suffix|Pad Character|Pad Length`  

  `inc` = denotes an incremental field  
  `Type` = Global, Field, Prefix, Suffix, PrefixSuffix - default is 'G' ('G', 'F', 'P', 'S', 'PS')  
  --> `Global` will use the same incremented number across all fields  
  --> `Field` will use the next number for that field only  
  --> `Prefix` will use the next number for that prefix only  
  --> `Suffix` will use the next number for that suffix only  
  --> `PrefixSuffix` will use the next number for that prefix/suffix combination only  
  `Prefix` = the prefix that should come before the incremental part  
  `Suffix` = the suffix that should come after the incremental part  
  `Pad Character` = the character to be used for left padding  
  `Pad Length` = the length of the entire incremental part  
                
* Size fields - if a field needs to be generated that represents a size of a disk drive/RAM etc, the following pattern should be used:  

  ###### `|size|lower|upper|units_from|units_to|power2|suffix`
                
  `size` = denotes a size field  
  `lower` = the lower bound for which to generate a number  
  `upper` = the upper bound for which to generate a number - this is allowed to be a linked value just specify the field name that will act as the upper bound  
  --> when using a linked field the unit from that field is ignored and is assumed to be the same as units_from.  
  `units_from` = the unit for the lower and upper bound, e.g. B, MB, GB  
  `units_to` = the unit for the output, e.g. B, MB, GB  
  `power2` = whether the result should be a valid power2 for the result - Default is 1 (1|0)  
  `suffix` = whether to include the suffix in the output or not (1|0) - Default is 1 (1|0)
                
* IP field - use this to generate in IP in a given subnet.  No validation is done to check DHCP etc.  Use the following pattern:  

  ###### `|ip|network_address|mask`
                
  `ip` = denotes an IP field  
  `network_address` = provides the network address of the subnet in question  
  `mask` = can be CIDR (number of bits) or dotted decimal
                
* Lookup field - used to look up values from a CSV file.  The pattern should be:  

  ###### `|lkp|Type|path|field_format|key_field|key`
  
  `lkp` = denotes a lookup field  
  `Type` = Global, Field  
  --> `Global` will use the same looked up row values across all lookup fields for that row  
  --> `Field` will use a potentially different row of values to that of any other lookup field  
  `path` = full path to the CSV to lookup in  
  `field_format` = the fields to extract and the format they should take, e.g. "DOMAIN\%FirstName%.%LastName%"  
  `key_field` = lookup based on key_field (in lookup file) rather than selecting at random  
  `key` = the field which contains the matching value (this should not be a linked field, but can be a value or field name)  

* Copy field - used to make the field have the same value as the specified field.  **_N.B. Copy fields are calculated after all other field interpolation is complete._**  

  ###### `|cp|Field`  
  
  `cp` = denotes a copy field
  `Field` = the heading of the field to copy
