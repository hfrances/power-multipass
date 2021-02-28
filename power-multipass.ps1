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
	[string]$pipelineDir,
	
	[Parameter( Mandatory=$false )]
	[Alias('cloud-init')]
	[string]$cloudInit,
	
	[Parameter( Mandatory=$false,
                HelpMessage="Write to error log file or not." )]
	[Alias('skip-sh')]
	[switch]$skip_sh,
	
	[Parameter( Mandatory=$false,
                HelpMessage="Write to error log file or not." )]
	[Alias('no-create', 'skip-creation')]
	[switch]$skip_creation
)

$stopwatch = [system.diagnostics.stopwatch]::StartNew();

if ($skip_creation -eq $false) {
	echo "Deleting $Name";
	multipass delete $Name;
	multipass purge;

	echo "Launching $Name";
	if ($cloudInit -eq "") {
		multipass launch -n $Name;
	}
	else {
		multipass launch -n $Name --cloud-init $cloudInit;
	}
}

# Check that instance is ready (sometimes returns timeout).
while (-not((multipass exec $Name -- hostname) -eq $Name)) {
	echo "Waiting a while for multipass...";
	Start-Sleep -Seconds 15;
}
echo "";

if (-not ($pipelineDir -eq "")) {
	echo "Moving files to $Name";
	$dir = (Get-ItemProperty($pipelineDir));
	$scripts = New-Object Collections.Generic.List[string];

	multipass exec $Name -- mkdir pipeline;
	foreach($file in (Get-ChildItem($dir.FullName) -Recurse | sort FullName)) {
		$path = $file.FullName -replace [regex]::Escape("$($dir.FullName)\"), "";
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
			}
			Write-Host "";
			
			multipass transfer $($file.FullName) "$($Name):pipeline/$path";
			if ($isScript) {
				multipass exec $Name -- chmod ug+x "pipeline/$path";
				$scripts.Add("pipeline/$path");
			}
		}
	}
	echo "";

	if ($skip_sh -eq $false) {
		foreach ($script in $scripts) {
			echo "Running script '$script' ...";
			multipass exec $Name -- $script;
			echo "";
		}
	}
}

echo "Updating host file...";
./update-hosts $Name;
echo "";

echo "Machine info:";
multipass info $Name;
echo "";

$stopwatch.Stop();
echo "Done.";
echo "Elapsed time: $($stopwatch.Elapsed)";
echo "";

multipass exec $Name -- /bin/bash;
