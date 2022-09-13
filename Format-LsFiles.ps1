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

    # https://regex101.com/r/0YlNZz/1
    $linePattern = '(?ms)(?<type>[d-])(?<permissions>[rwx-]+)\s(?<number>\d)\s(?<user>\w+)\s+(?<group>\w+)\s+(?<size>\d+)\s(?<date>([\d\-]+(?:\s[\d\:]+)?))\s(?<filename>.+)';
    $folderPattern = '(?<folder>.+):\s+total\s(?<total>\d+)\s(?<items>(?:[\s\S]*))';

    $folderArray = ($content -join "`n") -split "`n`n";
    foreach ($folderPart in $folderArray) {
      $folderRegex = $folderPart | Select-String -pattern $folderPattern;

      foreach ($folderMath in $folderRegex.Matches) {
        $folder = $folderMath.Groups['folder'].Value;
        $items = $folderMath.Groups['items'].Value;

        $regex = ($items -split "`n") | Select-String -pattern $linePattern;
        foreach ($match in $regex.Matches) {
          $type = $match.Groups['type'].Value;
          $date = [DateTime]$match.Groups['date'].Value;
          $filename = $match.Groups['filename'].Value;
          
          if ($filename -eq '.' -or $filename -eq '..') {
            # Do Nothing
          }
          else {
            $files.Add((New-Object PsObject -Property @{
              Type = $type
              Date = $date
              FileName = "$folder/$filename"
            }));
          }
        }
      }
    }
    return $files;
  }
}