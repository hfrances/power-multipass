#/bin/sh

# Create repos folder.
[[ ! -d ~/repos ]] && mkdir ~/repos
cd ~/repos

# Clone repository
git clone https://github.com/examples-hfrances/hello-react.git

# Install packages
npm install --prefix hello-react
# Build project
npm run build --prefix hello-react

# Create site folder
sudo mkdir --parents /var/www/html/hello-react
# Copy build to site folder
sudo cp -R ./hello-react/build/* /var/www/html/hello-react/

# Create site
sudo bash -c 'cat > /etc/nginx/conf.d/hello-react.conf' << EOF
server {
    listen        80;
    server_name hello-react.example.com;
    
	root /var/www/html/hello-react;
    index index.html index.htm index.nginx-debian.html;

    #auth_basic "Administrator Login";
    #auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        #try_files \$uri \$uri/ =404;
        try_files \$uri /index.html;
    }
}
EOF

# Add DNS to localhost.
sudo bash -c 'cat >> /etc/hosts' << EOF

# Auto-generated by pipelines.
127.0.1.1 hello-react.example.com
EOF

# Start service
sudo service nginx restart

# Get active processes
ps -ef | grep nginx

# Wait some seconds
sleep 2
# Check that service is working
pwsh -command "echo ((Invoke-WebRequest 'http://hello-react.example.com' -Method Get -DisableKeepAlive) | select-string -pattern '<title>([\w\s]+)<\/title>' -AllMatches).Matches.Groups[1].Value"

