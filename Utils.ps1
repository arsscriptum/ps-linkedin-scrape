
#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   Utils.ps1                                                                    ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝



[CmdletBinding(SupportsShouldProcess)]
param()



function Test-IsSoftwareInstalled {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )    
    process{
     $ItemPropertyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\{0}' -f $Name
     $Prop = Get-ItemProperty -Path $ItemPropertyPath -ErrorAction Ignore
     if(!$Prop){ return $False }
     [string]$AppPath = $Prop.'(default)'
     if(!$AppPath) { return $False }
     $IsInstalled = (Test-Path -Path "$AppPath" -PathType Leaf) -eq $True
     $IsInstalled
    }
}


function Test-BraveInstalled {
    return ("brave.exe" | Test-IsSoftwareInstalled )
}


function Test-MsEdgeInstalled {
    return ("msedge.exe" | Test-IsSoftwareInstalled )
}



function Test-ChromeInstalled {
    return ("chrome.exe" | Test-IsSoftwareInstalled )
}


function Test-FirefoxInstalled {
    return ("firefox.exe" | Test-IsSoftwareInstalled )
}


function Register-AppCredentials {
[CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Password
    )
    try {    
        $RegKeyRoot = "HKCU:\Software\arsscriptum\ps-linkedin-scrape\{0}\credentials" -f $Id

        [securestring]$SecPassword = ConvertTo-SecureString $Password -AsPlainText -Force
        [pscredential]$Credentials = New-Object System.Management.Automation.PSCredential ($Username, $SecPassword)
    
        $Username = $Credentials.UserName
        $EncodedPassword = ConvertFrom-SecureString $Credentials.Password

        $epoch = [int][double]::Parse((Get-Date -UFormat %s))
        New-RegistryValue -Path $RegKeyRoot -Name "$Id" -Type "DWORD" -Value $epoch | Out-null
        New-ItemProperty -Path $RegKeyRoot -Name "username" -Value $Username -PropertyType "String" -Force -ErrorAction Stop | Out-null
        New-ItemProperty -Path $RegKeyRoot -Name "password" -Value $EncodedPassword -PropertyType "String"  -Force -ErrorAction Stop | Out-null

        return ($r1 -and $r2)
    } catch {
        Write-Error "$_"
    }
}

function Get-AppCredentials {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [string]$Id
    )
    try {
        $RegKeyRoot = "HKCU:\Software\arsscriptum\ps-linkedin-scrape\{0}\credentials" -f $Id

        if (-not (Test-Path $RegKeyRoot)) { return $Null }
        $ItemProperty = Get-ItemProperty -Path $RegKeyRoot -ErrorAction Ignore
        if(!$ItemProperty){ return $Null }
        $Username = ($ItemProperty | Select-Object -ExpandProperty "username")
        $Passwd = ($ItemProperty | Select-Object -ExpandProperty "password")
        try {
            $Password = ConvertTo-SecureString $Passwd -ErrorAction Stop
        } catch {
            Write-Warning "The Decryption Failed! The Secure Key is linked to the user account and the Computer name, if either changed, it broke the encrypted values"
            throw ($_)
        }
        $Credentials = New-Object System.Management.Automation.PSCredential $Username, $Password

        return $Credentials
    } catch {
        Write-Error "$_"
    }
}