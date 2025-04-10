
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
    [CmdletBinding()]
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
