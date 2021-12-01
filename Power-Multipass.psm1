[CmdletBinding(DefaultParameterSetName = 'Name')]
param(
	[Parameter( Mandatory, 
				ParameterSetName='Name', 
				Position=0 )]
	[Alias('n')]
	[string]$Name,
	
	[Parameter( Mandatory=$false,
				ParameterSetName='Name',
				Position=1 )]
	[Alias('pipeline-dir')]
	[string]$PipelineDir,
	
	[Parameter( Mandatory=$false )]
	[Alias('cloud-init')]
	[string]$CloudInit,
	
	[Parameter( Mandatory=$false )]
	[Alias('skip-sh')]
	[switch]$SkipSh,
	
	[Parameter( Mandatory=$false )]
	[Alias('no-create')]
	[switch]$NoCreate
)

$stopwatch = [system.diagnostics.stopwatch]::StartNew();

if ($NoCreate -eq $false) {
	echo "Deleting $Name";
	multipass delete $Name;
	multipass purge;

	echo "Launching $Name";
	if ($CloudInit -eq "") {
		multipass launch -n $Name;
	}
	else {
		multipass launch -n $Name --cloud-init $CloudInit;
	}
}

# Check that instance is ready (sometimes returns timeout).
while (-not((multipass exec $Name -- hostname) -eq $Name)) {
	echo "Waiting a while for multipass...";
	Start-Sleep -Seconds 15;
}
echo "";

if (-not ($PipelineDir -eq "")) {
	echo "Moving files to $Name";
	$dir = (Get-ItemProperty($PipelineDir));
	$scripts = New-Object Collections.Generic.List[string];

	multipass exec $Name -- mkdir pipeline;
	foreach($file in (Get-ChildItem($dir.FullName) -Recurse | sort FullName)) {
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
				./set-eol unix -file "$($file.FullName)"
			}
			Write-Host "";
			
			multipass transfer "$($file.FullName)" "$($Name):pipeline/$path";
			if ($isScript) {
				multipass exec $Name -- chmod ug+x "pipeline/$path";
				$scripts.Add("pipeline/$path");
			}
		}
	}
	echo "";

	if ($SkipSh -eq $false) {
		foreach ($script in $scripts) {
			echo "Running script '$script' ...";
			multipass exec $Name -- "$script";
			echo "";
		}
	}
}

# --- Get machine IP and update in hosts file ---
echo "Machine address:";
$regex = multipass info $Name | select-string -pattern '(?<Property>\b[\w .-]+):\s+(?<Value>.+)';
$ipv4match = $regex.Matches | Where-Object { ($_.Groups['Property'].Value -eq 'IPv4') };
$ipv4 = $ipv4match.Groups['Value'].Value;
echo $ipv4;

echo "Updating host file...";
# Connect to VM and take /etc/hosts file content.
(multipass exec $Name -- cat /etc/hosts) | ./update-hosts -IPAddress $ipv4 -IPFilter '127.0.1.1';
echo "";

# --- Print machine info ---
echo "Machine info:";
multipass info $Name;
echo "";

$stopwatch.Stop();
echo "Done.";
echo "Elapsed time: $($stopwatch.Elapsed)";
echo "";

multipass exec $Name -- /bin/bash;
