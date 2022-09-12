function Start-PMInstance {

    [CmdletBinding(DefaultParametersetName = 'Help')]
    param(
  
      [Parameter( ParameterSetName = 'Help' )]
      [switch]$Help,
  
      [Parameter( Mandatory, 
        ParameterSetName = 'Name', 
        Position = 0 )]
      [Alias('n')]
      [string]$Name
      
    )
  
    if ($PsCmdlet.ParameterSetName -eq "Help") {
      Write-Host;
      Write-Host "Start-PMInstance name";
      Write-Host;
    }
    else {
        
      # Check if the instance exists.
      $search = multipass info --all | Select-String -pattern "Name:\s+$Name" -CaseSensitive;
      if ($null -eq $search) {
        Write-Error "Instance not found.";
      }
      else {
        $stopwatch = [system.diagnostics.stopwatch]::StartNew();

        Invoke-Expression "multipass start $Name";

        # Check that instance is ready (sometimes returns timeout).
        while (-not((multipass exec $Name -- hostname) -eq $Name)) {
          Write-Host "Waiting a while for multipass...";
          Start-Sleep -Seconds 15;
        }
        Write-Host "";

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
    }
  }
  Export-ModuleMember -Function Start-PMInstance;