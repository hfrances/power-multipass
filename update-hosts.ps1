param($p1, $p2)

$hostFile = 'C:\Windows\System32\drivers\etc\hosts';
$hostLinePattern = '(?m)^\s*(?<Address>[0-9.:]+)\s+(?<Hosts>[\w\t .-]+)';
$hostNamePattern = '(?<Host>\b[\w\t.-]+)';

# --- Get machine IP ---
echo "Machine address:";
$regex = multipass info $p1 | select-string -pattern '(?<Property>\b[\w .-]+):\s+(?<Value>.+)';
$ipv4match = $regex.Matches | Where-Object { ($_.Groups['Property'].Value -eq 'IPv4') };
$ipv4 = $ipv4match.Groups['Value'].Value;
echo $ipv4;
echo "";

# --- Get remote hosts ---
echo "Remote addresses:";
$hosts = New-Object Collections.Generic.Dictionary'[string,string]'
$content = (multipass exec $p1 -- cat /etc/hosts);
$regex = $content | select-string -pattern $hostLinePattern;

foreach ($match in $regex.Matches) {
	$address = $match.Groups['Address'].Value;
	$hostNames = $match.Groups['Hosts'].Value;
	
	if ($address -eq '127.0.1.1') {
		$hostRegex = $hostNames | select-string -pattern $hostNamePattern -allmatches;
		
		foreach ($hostMatch in $hostRegex.Matches) {
			$hostName = $hostMatch.Value;
			$hosts[$hostMatch.Value] = $address;
		}
	}
}

foreach ($hostName in $hosts.Keys) {
	$address = $hosts[$hostName];
	echo "$hostName $address";
}
echo "";

# --- Apply in local hosts ---
echo "Local addresses:"
$lines = New-Object Collections.Generic.List[string];
$includedHosts = New-Object Collections.Generic.List[string];
$lastFoundIndex = -1;
$index = 0;
foreach ($line in Get-Content $hostFile) {
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
						
			# Buscar el $hostName en el diccionario. Tener en cuenta que puede camibiar mayusculas-minúsculas.
			$foundHost = $hosts.Keys | Where-Object { ($_ -eq $hostName) };
			if (-not ($foundHost -eq $null)) {
				Write-Host "$hostName $address " -NoNewline;
				Write-Host " updated " -ForegroundColor White -BackgroundColor DarkYellow -NoNewline;
				$lastFoundIndex = $lines.Count - 1;
				
				# Crear nueva línea abajo con $ipv4 y $hostName.
				if ($newLine -eq "") {
					$newLine = $ipv4;
				}
				$newLine = "$newLine $hostName";
				# Marcar el host como añadido.
				$includedHosts.Add($foundHost);
				# Modificar la línea actual, quitando el $hostName.
				$scapedHostName = [regex]::Escape($hostName);
				$line = $line -replace "(?<=\s|^)($([regex]::Escape($hostName)))(?=\s|$)", "";
				# Si la línea se queda sin $hostNames, no se insertará.
				$matchCount--;
				
				Write-Host "";
			}
		}
		# No insertar la linea si se queda sin $hostsNames.
		if ($matchCount -eq 0) {
			$line = "";
		}
	}
	# Insertar las líneas (si tienen valor).
	if (-not ($line -eq "")) { 
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
	Write-Host " added " -ForegroundColor White -BackgroundColor DarkYellow -NoNewline;
	
	if ($lastFoundIndex -eq -1) {
		$lines.Add("$ipv4 $hostName");
		$lastFoundIndex = $lines.Count - 1;
	}
	else {
		$lines[$lastFoundIndex] = "$($lines[$lastFoundIndex]) $hostName";
	}
	Write-Host "";
}
if ($p2 -eq 'Write-Host') {
	Write-Host "";
	$lines;
}
else {
	Copy-Item $hostFile -Destination "$hostFile.bak"
	$lines | Out-File $hostFile;
	echo "Hosts file modified. Previous file moved to hosts.bak"
}
echo "";
