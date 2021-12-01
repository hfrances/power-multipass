function New-PMInstance {

  [CmdletBinding(DefaultParameterSetName = 'Name')]
  param(
    [Parameter( Mandatory, 
      ParameterSetName = 'Name', 
      Position = 0 )]
    [Alias('n')]
    [string]$Name,
	
    [Parameter( Mandatory = $false,
      ParameterSetName = 'Name',
      Position = 1 )]
    [Alias('pipeline-dir')]
    [string]$PipelineDir,
	
    [Parameter( Mandatory = $false )]
    [Alias('cloud-init')]
    [string]$CloudInit,
	
    [Parameter( Mandatory = $false )]
    [Alias('skip-sh')]
    [switch]$SkipSh,
	
    [Parameter( Mandatory = $false )]
    [Alias('no-create')]
    [switch]$NoCreate
  )

  $stopwatch = [system.diagnostics.stopwatch]::StartNew();

  if ($NoCreate -eq $false) {
    Write-Host "Deleting $Name";
    multipass delete $Name;
    multipass purge;

    Write-Host "Launching $Name";
    if ($CloudInit -eq "") {
      multipass launch -n $Name;
    }
    else {
      multipass launch -n $Name --cloud-init $CloudInit;
    }
  }

  # Check that instance is ready (sometimes returns timeout).
  while (-not((multipass exec $Name -- hostname) -eq $Name)) {
    Write-Host "Waiting a while for multipass...";
    Start-Sleep -Seconds 15;
  }
  Write-Host "";

  if (-not ($PipelineDir -eq "")) {
    Write-Host "Moving files to $Name";
    $dir = (Get-ItemProperty($PipelineDir));
    $scripts = New-Object Collections.Generic.List[string];

    multipass exec $Name -- mkdir pipeline;
    foreach ($file in (Get-ChildItem($dir.FullName) -Recurse | Sort-Object FullName)) {
      $path = $file.FullName -replace [regex]::Escape("$($dir.FullName)"), "";
      $path = $path -replace [regex]::Escape("\"), "/";
		
      Write-Host " - $path" -NoNewline;
      if ($file.PSIsContainer) {
        Write-Host "";
			
        multipass exec $Name -- mkdir pipeline/$path;
      }
      else {
        $isScript = ($file.Extension -eq '.sh');
        if ($isScript) {
          Write-Host " " -NoNewline;
          Write-Host " Script " -ForegroundColor White -BackgroundColor DarkGreen -NoNewline;
          Set-EOL unix -file "$($file.FullName)"
        }
        Write-Host "";
			
        multipass transfer "$($file.FullName)" "$($Name):pipeline/$path";
        if ($isScript) {
          multipass exec $Name -- chmod ug+x "pipeline/$path";
          $scripts.Add("pipeline/$path");
        }
      }
    }
    Write-Host "";

    if ($SkipSh -eq $false) {
      foreach ($script in $scripts) {
        Write-Host "Running script '$script' ...";
        multipass exec $Name -- "$script";
        Write-Host "";
      }
    }
  }

  # --- Get machine IP and update in hosts file ---
  Write-Host "Machine address:";
  $regex = multipass info $Name | select-string -pattern '(?<Property>\b[\w .-]+):\s+(?<Value>.+)';
  $ipv4match = $regex.Matches | Where-Object { ($_.Groups['Property'].Value -eq 'IPv4') };
  $ipv4 = $ipv4match.Groups['Value'].Value;
  Write-Host $ipv4;

  Write-Host "Updating host file...";
  # Connect to VM and take /etc/hosts file content.
  (multipass exec $Name -- cat /etc/hosts) | Update-Hosts -IPAddress $ipv4 -IPFilter '127.0.1.1';
  Write-Host "";

  # --- Print machine info ---
  Write-Host "Machine info:";
  multipass info $Name;
  Write-Host "";

  $stopwatch.Stop();
  Write-Host "Done.";
  Write-Host "Elapsed time: $($stopwatch.Elapsed)";
  Write-Host "";

  multipass exec $Name -- /bin/bash;
}
Export-ModuleMember -Function New-PMInstance;