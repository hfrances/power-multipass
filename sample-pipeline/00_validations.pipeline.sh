#/bin/sh

# Validations
while :
do
  echo 'Checking for dotnet...'
  dotnetRdo=$(dotnet --list-runtimes)
  dotnetErr=$?
  [[ $dotnetErr -eq 0 ]] && echo ' - OK'
  
  echo 'Checking for npm...'
  npmRdo=$(npm --version)
  npmErr=$?
  [[ $npmErr -eq 0 ]] && echo ' - OK'
  
  echo 'Checking for pwsh...'
  pwshRdo=$(pwsh --version)
  pwshErr=$?
  [[ $pwshErr -eq 0 ]] && echo " - OK"

  echo 'Checking for unzip...'
  unzip > /dev/null
  unzipErr=$?
  [[ $unzipErr -eq 0 ]] && echo " - OK"

  echo 'Checking for nginx...'
  nginxRdo=$(nginx -v)
  nginxErr=$?
  [[ $nginxErr -eq 0 ]] && echo " - OK"
  
  if [[ $dotnetErr -eq 0 && $npmErr -eq 0 && $pwshErr -eq 0 && $unzipErr -eq 0 && $nginxErr -eq 0 ]]; then
    break
  else
    read -t 60 -p 'Some errors where found. Continue? [y,N] ' droit
    if [[ $droit =~ ^[yY]$ ]]; then
      break
    fi
	echo ""
    echo ""
  fi
done

# Create repos folder.
[[ ! -d ~/repos ]] && mkdir ~/repos
echo ""
