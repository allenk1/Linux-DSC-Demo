Clear-Host 
$Cred = Get-Credential -Username:”root” -Message:”Enter root user password for Linux Host(s).”
$Opt = New-CimSessionOption -UseSSL:$True -SkipCACheck:$True -SkipCNCheck:$True -SkipRevocationCheck:$True
$LinuxServer = New-CimSession -Credential:$Cred –ComputerName: linuxhost-01 -Port:5986 -Authentication:Basic -SessionOption:$Opt 
Configuration MyDSCDemo
{
   Import-DSCResource -Module nx
   
   Node "linuxhost-01"{  
   
        #Install Apache Service
        nxScript InstallApache {
            GetScript = @"
#!/bin/bash
systemctl status httpd.service
"@
            SetScript = @"
#!/bin/bash
yum install httpd -y
"@
            TestScript = @"
#!/bin/sh
ps auxw | grep httpd | grep -v grep > /dev/null
if [ $? != 0 ]
then
        exit 1
else
        exit 0
fi
"@
            
        }

        #Apache Service
        nxService ApacheService {
            Name = "httpd"
            Controller = "systemd"
            Enabled = $true
            State = "Running"
            DependsOn = '[nxScript]InstallApache'
        }
        
        #Demo Site Configuration
        nxFile ApacheConfig {
            DestinationPath = "/etc/httpd/conf.d/demosite.conf"
            Contents = @'
<VirtualHost *:80>
    ServerName www.demosite.com
    ServerAdmin webmaster@demotsite.com
    ErrorLog /var/log/httpd/demosite.err
    CustomLog /var/log/httpd/demosite.log combined
    DocumentRoot /var/www/demosite.com
    <Directory "/var/www/demosite.com">
        Order allow,deny
        Allow from all
    </Directory>
</VirtualHost>
'@
            DependsOn = '[nxService]ApacheService'
        }

        #Demo Site File Creation
        #Create directory
        nxFile DemositeRoot{
            DestinationPath = "/var/www/demosite.com/"
            Type = "Directory"
            Mode = '755'
        }

        #Create HTML File
        nxFile DemositeHTML{
            DestinationPath = "/var/www/demosite.com/index.html"
            Mode = '644'
            Contents = @'
<html>
    <head>
        <title>Welcome to demosite.com!</title>
    </head>
    <body>
        <h1>This is the DSC for Linux DemoSite!</h1>
    </body>
</html>
'@
            DependsOn = '[nxfile]DemositeRoot'
        }
        
        # Restart Apache
        nxScript RestartApache {
            GetScript = @"
#!/bin/bash
systemctl status httpd.service
"@
            SetScript = @"
#!/bin/bash
systemctl restart httpd.service
"@
            TestScript = @"
#!/bin/sh
ps auxw | grep httpd | grep -v grep > /dev/null
if [ $? != 0 ]
then
        exit 1
else
        exit 0
fi            
"@
            DependsOn = "[nxFile]DemositeHTML"
            
        }      
         

    }
}
MyDSCDemo -OutputPath:"C:\temp" 
Write-Host “Configuration Loaded” 
Start-DscConfiguration -CimSession:$LinuxServer -Path:”C:\temp” -Verbose –Wait