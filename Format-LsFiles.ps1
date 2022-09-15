function Format-LsFiles {

  [CmdletBinding(DefaultParameterSetName = 'Default')]
  param(
    
    [Parameter(
      ParameterSetName = 'Default',
      ValueFromPipeline, 
      ValueFromPipelineByPropertyName,
      Position=0 )]
    [string]$Value,
    
    [switch]$OutWindow
  )

  BEGIN {	
    $content = New-Object Collections.Generic.List[string];
  }

  PROCESS {
    $content.Add($Value);
  }

  END {
    $content.Add('');

    $files = New-Object Collections.Generic.List[PsObject];
    $folderPattern = '(?<folder>.+):\s+total\s(?<total>\d+)\s(?<items>(?:[\s\S]*))';

    $folderArray = ($content -join "`n") -split "`n`n";
    foreach ($folderPart in $folderArray) {
      $folderRegex = $folderPart | Select-String -pattern $folderPattern;
      
      if ($null -eq $folderRegex) {
        $parsedFiles = (Get-LsFiles -folder '' -content $folderPart);
        $files.AddRange([PSObject[]]$parsedFiles);
      }
      else {
        foreach ($folderMath in $folderRegex.Matches) {
          $folder = $folderMath.Groups['folder'].Value;
          $items = $folderMath.Groups['items'].Value;

          $parsedFiles = (Get-LsFiles -folder "$folder/" -content $items);
          $files.AddRange([PSObject[]]$parsedFiles);
        }
      }
    }
    return $files;
  }
}

function Get-LsFiles {
  [OutputType([PsObject[]])]
  param([Parameter(Position=0)][string]$folder, [Parameter(Position=1)][string]$content)

  # https://regex101.com/r/0YlNZz/3
  $linePattern = '(?ms)(?<type>[dpsl-])(?<permissions>[rwxt-]+)\.? +(?<hardLinks>\d)+ +(?<user>\w+) +(?<group>\w+) +(?<size>\d+) (?<lastWriteTime>[A-Z][a-z]{2} [ \d]\d +(?:\d{4}|\d{2}:\d{2})|[\d\-]+(?: \d{2}:\d{2}(?::\d{2})?)?) (?<filename>.+)';

  [Collections.Generic.List[PsObject]]$files = New-Object Collections.Generic.List[PsObject];
  $regex = ($content -split "`n") | Select-String -pattern $linePattern;
  foreach ($match in $regex.Matches) {
    $type = $match.Groups['type'].Value;
    $permissions = $match.Groups['permissions'].Value;
    $hardLinks = $match.Groups['hardLinks'].Value;
    $user = $match.Groups['user'].Value;
    $group = $match.Groups['group'].Value;
    $size = $match.Groups['size'].Value;
    $lastWriteTime = [DateTime](Format-LsDate $match.Groups['lastWriteTime'].Value);
    $filename = $match.Groups['filename'].Value;
    
    if ($filename -eq '.' -or $filename -eq '..') {
      # Do Nothing
    }
    else {
      $files.Add((New-Object PsObject -Property @{
        Type = $type
        Permissions = $permissions
        HardLinks = $hardLinks
        User = $user
        Group = $group
        Size = $size
        LastWriteTime = $lastWriteTime
        FileName = "$folder$filename"
      }));
    }
  }
  return $files;
}

function Format-LsDate {
  [OutputType([System.Nullable[DateTime]])]
  param([Parameter(Position=0)][string]$value)

  [System.Nullable[DateTime]]$result = $null;

  $notYearPattern="(?<date>[A-Z][a-z]{2} [ \d]\d) +(?<time>\d{2}:\d{2})";
  $regex = $value | Select-String -pattern $notYearPattern;
  if ($null -eq $regex) {
    $result = [DateTime]$value;
  }
  else {
    $match = $regex.Matches[0];
    $date = $match.Groups['date'].Value;
    $time = $match.Groups['time'].Value;
    $year = (get-date).Year;
    $result = [DateTime]("$date $year $time");
  }
  return $result;
}

Export-ModuleMember -Function Format-LsFiles;