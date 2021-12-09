function Update-Hosts {

  [CmdletBinding(DefaultParameterSetName = 'HostsPipeline')]
  param(
    [Parameter( Mandatory,
      ParameterSetName='HostsPipeline',
      Position=0 )]
    [string]$IPAddress,
    
    [Parameter(
      ParameterSetName='HostsPipeline',
      Position=1 )]
    [string[]]$IPFilter='127.0.1.1',
    
    [Parameter(
      ParameterSetName = 'HostsPipeline',
      ValueFromPipeline, 
      ValueFromPipelineByPropertyName,
      Position=2 )]
    [string]$HostContent,
    
    [switch]$NoSave,
    
    [switch]$OutWindow
  )

  BEGIN {	
    $content = New-Object Collections.Generic.List[string];
  }

  PROCESS {
    $content.Add($HostContent);
  }

  END {
    $hostLinePattern = '(?m)^\s*(?<Address>[0-9.:]+)\s+(?<Hosts>[\w\t .-]+)';
    $hostNamePattern = '(?<Host>\b[\w\t.-]+)';
    
    $hosts = New-Object Collections.Generic.Dictionary'[string,string]';

    if ($IsWindows) {
      $hostFile = "$env:SystemRoot\System32\Drivers\etc\hosts";
    }
    elseif ($IsLinux) {
      $hostFile = "/etc/hosts";
    }
    else {
      # Not implemented.
    }

    # --- Get valid hosts. ---
    #Write-Host "Remote addresses:";
    $regex = $content | select-string -pattern $hostLinePattern;
    foreach ($match in $regex.Matches) {
      $address = $match.Groups['Address'].Value;
      $hostNames = $match.Groups['Hosts'].Value;
      
      if ($IPFilter -contains $address) {
        $hostRegex = $hostNames | select-string -pattern $hostNamePattern -allmatches;
        
        foreach ($hostMatch in $hostRegex.Matches) {
          $hostName = $hostMatch.Value;
          $hosts[$hostMatch.Value] = $address;
        }
      }
    }
    foreach ($hostName in $hosts.Keys) {
      $address = $hosts[$hostName];
      #Write-Host "$hostName $address";
    }
    #Write-Host "";

    # --- Apply in local hosts ---
    Write-Host "Local addresses:"
    $lines = New-Object Collections.Generic.List[string];
    $includedHosts = New-Object Collections.Generic.List[string];
    $lastFoundIndex = -1;
    foreach ($line in Get-Content $hostFile) {
      $skipLine = $false;
      $newLine = "";
      $regex = $line | select-string -pattern $hostLinePattern;
      
      if ($regex.Matches.Success) {
        $match = $regex.Matches[0];
        $address = $match.Groups['Address'].Value;
        $hostNames = $match.Groups['Hosts'].Value;
        $hostRegex = $hostNames | select-string -pattern $hostNamePattern -allmatches;
        $matchCount = $hostRegex.Matches.Length;
        
        foreach ($hostMatch in $hostRegex.Matches) {
          $hostName = $hostMatch.Value;
                
          # Buscar el $hostName en el diccionario. Tener en cuenta que puede cambiar mayusculas-minúsculas.
          $foundHost = $hosts.Keys | Where-Object { ($_ -eq $hostName) };
          if (-not ($null -eq $foundHost)) {
            $lastFoundIndex = $lines.Count - 1;
            
            Write-Host "$hostName $address " -NoNewline;
            Write-Host "|" -NoNewline;
            if ($address -eq $IPAddress) {
              Write-Host " unmodified " -ForegroundColor Black -BackgroundColor White -NoNewline;
            }
            else {
              Write-Host " updated " -ForegroundColor White -BackgroundColor DarkYellow -NoNewline;
              
              # Crear nueva línea abajo con $IPAddress y $hostName.
              if ($newLine -eq "") {
                $newLine = $IPAddress;
              }
              $newLine = "$newLine $hostName";
              # Modificar la línea actual, quitando el $hostName.
              $line = $line -replace "(?<=\s|^)($([regex]::Escape($hostName)))(?=\s|$)", "";
              # Si la línea se queda sin $hostNames, no se insertará.
              $matchCount--;
            }
            Write-Host "|" -NoNewline;
            
            # Marcar el host como añadido.
            $includedHosts.Add($foundHost);
              
            Write-Host "";
          }
        }
        # No insertar la linea si se queda sin $hostsNames.
        if ($matchCount -eq 0) {
          $skipLine = $true;
        }
      }
      # Insertar las líneas (si tienen valor).
      if ($skipLine -eq $false) { 
        $lines.Add($line);
      }
      if (-not ($newLine -eq "")) { 
        $lastFoundIndex +=1; # La línea donde se añadieron los hostNames.
        $lines.Add($newLine);
      }
    }
    # Añadir al final del fichero aquellos elementos en $hosts que no estén en $includedHosts.
    foreach ($hostName in $hosts.Keys | Where-Object { (-not ($includedHosts -contains $_)) }) {
      Write-Host "$hostName " -NoNewline;
      Write-Host "|" -NoNewline;
      Write-Host " added " -ForegroundColor White -BackgroundColor DarkYellow -NoNewline;
      Write-Host "|" -NoNewline;
      
      if ($lastFoundIndex -eq -1) {
        $lines.Add("$IPAddress $hostName");
        $lastFoundIndex = $lines.Count - 1;
      }
      else {
        $lines[$lastFoundIndex] = "$($lines[$lastFoundIndex]) $hostName";
      }
      Write-Host "";
    }
    if ($OutWindow -eq $true) {
      Write-Host "";
      $lines;
    }
    if ($NoSave -eq $false) {
      Copy-Item $hostFile -Destination "$hostFile.bak"
      $lines | Out-File $hostFile;
      Write-Host "Hosts file modified. Previous file moved to hosts.bak"
    }
  }
}