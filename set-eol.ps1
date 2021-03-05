# Change the line endings of a text file to: Windows (CR/LF), MacOS/Unix (LF) or Classic Mac (CR)
# https://ss64.com/ps/syntax-set-eol.html
# 
# Requires PowerShell 3.0 or greater:
#Requires –Version 3

# Syntax
#     ./set-eol.ps1 -lineEnding {mac|unix|dos} -file FullFilename

#     mac, unix or dos  : The file endings desired.
#     FullFilename      : The full pathname of the file to be modified.

#     example:
#     ./set-eol dos "c:\demo\data.txt"

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True,Position=1)]
    [ValidateSet("mac","unix","dos")] 
    [string]$lineEnding,
  [Parameter(Mandatory=$True)]
    [string]$file
)

# Convert the friendly name into a PowerShell EOL character
Switch ($lineEnding) {
  "mac"  { $eol="`r" }
  "unix" { $eol="`n" }
  "dos"  { $eol="`r`n" }
} 

# Replace CR+LF with LF
$text = [IO.File]::ReadAllText($file) -replace "`r`n", "`n"
[IO.File]::WriteAllText($file, $text)

# Replace CR with LF
$text = [IO.File]::ReadAllText($file) -replace "`r", "`n"
[IO.File]::WriteAllText($file, $text)

# At this point all line-endings should be LF.

# Replace LF with intended EOL char
if ($eol -ne "`n") {
  $text = [IO.File]::ReadAllText($file) -replace "`n", $eol
  [IO.File]::WriteAllText($file, $text)
}
