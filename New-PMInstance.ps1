function New-PMInstance {

  [CmdletBinding(DefaultParametersetName = 'Help')]
  param(

    [Parameter( ParameterSetName = 'Help' )]
    [switch]$Help,

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
    [string]$Memory,

    [Parameter( Mandatory = $false )]
    [string]$Cpus,

    [Parameter( Mandatory = $false )]
    [string]$Network,
	
    [Parameter( Mandatory = $false )]
    [Alias('no-create')]
    [switch]$NoCreate,

    [Parameter( Mandatory = $false )]
    [Alias('skip-sh')]
    [switch]$SkipSh,

    [Parameter( Mandatory = $false )]
    [Alias('no-bash')]
    [switch]$NoBash,

    [Parameter( Mandatory = $false )]
    [switch]$Force
  )

  if ($PsCmdlet.ParameterSetName -eq "Help") {
    Write-Host;
    Write-Host "New-PMInstance name [-PipelineDir <string>] [-CloudInit <string>] [-Network <string>] [-Mem <string>] [-Cpus <number>]";
    Write-Host;
    Write-Host "  -PipelineDir <string>   Path to the directory to copy to the instance after finish to start.";
    Write-Host "                          Files with extension ""*.pipeline.sh"" are executed after finish copy.";
    Write-Host "  -CloudInit <string>     Path to a user-data cloud-init configuration.";
    Write-Host "  -Network <string>       Add a network interface to the instance, where <string> is in the ""key=value,key=value"" format, with the following.";
    Write-Host "                          name: the network to connect to (required). Use the ""multipass networks"" command for a list of possible values.";
    Write-Host "                          mode: auto|manual (default: auto).";
    Write-Host "                          mac: hardware address (default: random).";
    Write-Host "  -Memory <string>        Amount of memory to allocate. Positive integers, in bytes, or with K, M, G suffix.";
    Write-Host "  -Cpus <number>          Number of CPUs to allocate.";
    Write-Host "  -NoCreate               Optional: do not remove an create the virtual machine.";
    Write-Host "  -SkipSh                 Optional: do not run .sh scripts.";
    Write-Host "  -NoBash                 Optional: when the process finish, it stays in powershell instead of enter in the virtual machine command line.";
    Write-Host "  -Force                  Optional: replace all files from -PipelineDir in the remote even if they already exists and they are older.";
    Write-Host;
  }
  else {
    $stopwatch = [system.diagnostics.stopwatch]::StartNew();

    if ($NoCreate -eq $false) {
      # Check if the instance exists.
      $search = multipass info --all | Select-String -pattern "Name:\s+$Name" -CaseSensitive;
      if ($null -ne $search) {
        Write-Host "Deleting $Name";
        multipass delete $Name;
        multipass purge;
      }

      Write-Host "Launching $Name";
      $arguments = New-Object Collections.Generic.List[string];
      if ($CloudInit -ne "") {
        $arguments.Add("--cloud-init $CloudInit");
      }
      if ($Memory -ne "") {
        $arguments.Add("--mem $Memory");
      }
      if ($Cpus -ne "") {
        $arguments.Add("--cpus $Cpus");
      }
      if ($Network -ne "") {
        $arguments.Add("--network $Network");
      }
      Invoke-Expression "multipass launch --name $Name $arguments";
    }

    # Check that instance is ready (sometimes returns timeout).
    while (-not((multipass exec $Name -- hostname) -eq $Name)) {
      Write-Host "Waiting a while for multipass...";
      Start-Sleep -Seconds 15;
    }
    Write-Host "";

    if (-not ($PipelineDir -eq "")) {
      $scripts = New-Object Collections.Generic.List[string];
      $remoteFiles = New-Object Collections.Generic.List[PsObject];

      # Get existing files in VM.
      if ($NoCreate -eq $true -and $Force -eq $false) {
        Write-Host "Retrieving files in the virtual machine...";
        $remoteFiles = ((multipass exec CWA-LOCAL -- ls -laR --time-style='+%Y-%m-%d %H:%M:%S' pipeline) | Format-LsFiles);
        Write-Host "$($remoteFiles.Count) files found.";
      }

      # Copy files.
      Write-Host "Moving files to $Name";
      $dir = (Get-ItemProperty($PipelineDir));
      multipass exec $Name -- mkdir pipeline;
      foreach ($file in (Get-ChildItem($dir.FullName) -Recurse | Sort-Object FullName)) {
        $path = $file.FullName -replace [regex]::Escape("$($dir.FullName)"), "";
        $path = $path -replace [regex]::Escape("\"), "/";
      
        if ($file.PSIsContainer) {          
          $newFolder = $null;
          if ($NoCreate -eq $true) {
            $newFolder = $remoteFiles | Where-Object {$_.FileName -eq "pipeline/$path"};
          }
          if ($newFolder -eq $null) {
            Write-Host " - $path" -NoNewline;
            multipass exec $Name -- mkdir "pipeline/$path";
            Write-Host "";
          }
        }
        else {
          $newFile = $null;
          if ($NoCreate -eq $true) {
            $newFile = $remoteFiles | Where-Object {$_.FileName -eq "pipeline/$path" -and $_.Date -gt $file.LastWriteTime};
          }
          if ($newFile -eq $null) {
            Write-Host " - $path" -NoNewline;
            $isScript = ($file.Extension -eq '.sh');
            if ($isScript) {
              Write-Host " |" -NoNewline;
              Write-Host " Script " -ForegroundColor White -BackgroundColor DarkGreen -NoNewline;
              Write-Host "|" -NoNewline;
              Set-EOL unix -file "$($file.FullName)"
            }          
            multipass transfer "$($file.FullName)" "$($Name):pipeline/$path";
            if ($isScript) {
              multipass exec $Name -- chmod ug+x "pipeline/$path";
              $scripts.Add("pipeline/$path");
            }
            Write-Host "";
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

    if ($NoBash -eq $false) {
      multipass exec $Name -- /bin/bash;
    }
  }
}
Export-ModuleMember -Function New-PMInstance;