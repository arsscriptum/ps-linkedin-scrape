
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

function Register-LinkedInCreds { 
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, HelpMessage = "Gui")]
        [switch]$Gui
    )

    Write-Host "`n==============================="
    Write-Host "   ENTER LINKEDIN CREDENTIALS"
    Write-Host "===============================`n"

    if ($Gui) {
        Add-Type -AssemblyName System.Windows.Forms

        $form = New-Object System.Windows.Forms.Form
        $form.Text = "LinkedIn Credentials"
        $form.Size = New-Object System.Drawing.Size (310, 250)
        $form.StartPosition = "CenterScreen"

        $usernameLabel = New-Object System.Windows.Forms.Label
        $usernameLabel.Text = "Username:"
        $usernameLabel.Location = New-Object System.Drawing.Point (10, 20)
        $usernameLabel.Size = New-Object System.Drawing.Size (280, 20)
        $form.Controls.Add($usernameLabel)

        $usernameBox = New-Object System.Windows.Forms.TextBox
        $usernameBox.Location = New-Object System.Drawing.Point (10, 40)
        $usernameBox.Size = New-Object System.Drawing.Size (260, 20)
        $form.Controls.Add($usernameBox)

        $passwordLabel = New-Object System.Windows.Forms.Label
        $passwordLabel.Text = "Password:"
        $passwordLabel.Location = New-Object System.Drawing.Point (10, 70)
        $passwordLabel.Size = New-Object System.Drawing.Size (280, 20)
        $form.Controls.Add($passwordLabel)

        $passwordBox = New-Object System.Windows.Forms.TextBox
        $passwordBox.Location = New-Object System.Drawing.Point (10, 90)
        $passwordBox.Size = New-Object System.Drawing.Size (230, 20)
        $passwordBox.UseSystemPasswordChar = $true
        $form.Controls.Add($passwordBox)

        $togglePasswordButton = New-Object System.Windows.Forms.Button
        $togglePasswordButton.Text = "🔍"
        $togglePasswordButton.Width = 30
        $togglePasswordButton.Height = 20
        $togglePasswordButton.Location = New-Object System.Drawing.Point (245, 90)
        $togglePasswordButton.Add_Click({
            $passwordBox.UseSystemPasswordChar = -not $passwordBox.UseSystemPasswordChar
            $confirmBox.Enabled = $passwordBox.UseSystemPasswordChar
            $confirmBox.Text = ""
        })
        $form.Controls.Add($togglePasswordButton)

        $confirmLabel = New-Object System.Windows.Forms.Label
        $confirmLabel.Text = "Confirm Password:"
        $confirmLabel.Location = New-Object System.Drawing.Point (10, 120)
        $confirmLabel.Size = New-Object System.Drawing.Size (280, 20)
        $form.Controls.Add($confirmLabel)

        $confirmBox = New-Object System.Windows.Forms.TextBox
        $confirmBox.Location = New-Object System.Drawing.Point (10, 140)
        $confirmBox.Size = New-Object System.Drawing.Size (260, 20)
        $confirmBox.UseSystemPasswordChar = $true
        $form.Controls.Add($confirmBox)

        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "OK"
        $okButton.Location = New-Object System.Drawing.Point (100, 170)

        $PlaceHolderUser = "{0}** linkedin username" -f "$ENV:USERNAME" 
        $usernameBox.Text = $PlaceHolderUser

        $okButton.Add_Click({
            [bool]$DoPasswordCheck = $True
            if (-not $usernameBox.Text -or -not $passwordBox.Text) {
                [System.Windows.Forms.MessageBox]::Show("Username or Password cannot be empty.", "Error", 'OK', 'Error')
            }
            if(!$passwordBox.UseSystemPasswordChar){
                $DoPasswordCheck = $False
            }
            if($DoPasswordCheck){
                if ($passwordBox.Text -ne $confirmBox.Text) {
                    [System.Windows.Forms.MessageBox]::Show("Passwords do not match.", "Error", 'OK', 'Error')
                } else {
                    $form.Tag = $true
                    $form.Close()
                }
            } else {
                $form.Tag = $true
                $form.Close()
            }
        })
        $form.Controls.Add($okButton)

        $form.ShowDialog() | Out-Null

        if (-not $form.Tag) {
            Write-Error "User cancelled or error occurred."
            return
        }

        $UsernameInputted = $usernameBox.Text
        $PasswordInputted = $passwordBox.Text
    }
    else {
        $UsernameInputted = Read-Host "Enter your LinkedIn username"
        $pass1 = Read-Host "Enter password" -AsSecureString
        $pass2 = Read-Host "Confirm password" -AsSecureString

        if (([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass1))) -ne
            ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass2)))) {
            Write-Error "Passwords do not match."
            return
        }

        $PasswordInputted = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass1))
    }

    $Success = Register-AppCredentials -Id "LinkedInWebPage" -Username $UsernameInputted -Password $PasswordInputted
    #### FOR TESTING!
    #### SET THIS TO TRU TO VIEW THE REGISTERED CREDENTIALS IN CLEAR IN THE CONSOLE FOR TESTING!
    $TestOutput = $True
    if($TestOutput){
      $lu = "u={0}" -f "$((Get-AppCredentials -Id "LinkedInWebPage").GetNetworkCredential().Username)"
      $lp = "p={0}" -f "$((Get-AppCredentials -Id "LinkedInWebPage").GetNetworkCredential().Password)"
      Write-Host -n "$lu " -f DarkCyan
      Write-Host -n "$lp" -f Magenta
      Start-Sleep 3
      Clear-Host
    }
}



function Resolve-AnyPath {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, HelpMessage = 'Path')]
        [string]$Path,
        [Parameter(Mandatory = $False, HelpMessage = 'Recursive')]
        [switch]$CreateIfMissing
    )

    process {
        try {
            [string]$ReturnValue = ''
            [System.Management.Automation.PathInfo]$FullDestinationPathInfo = Resolve-Path -Path "$Path" -ErrorAction Stop
            $ReturnValue = $FullDestinationPathInfo.Path
        } catch {
            [System.Management.Automation.ErrorCategoryInfo]$CatInfo = $_.CategoryInfo
            if ($CatInfo.Category -eq 'ObjectNotFound') {
                $MissingPath = $CatInfo.TargetName
                [string]$ReturnValue = $MissingPath
                if ($CreateIfMissing) {
                    $null = New-Item -ItemType Directory -Path $MissingPath -Force -ErrorAction Ignore
                }
            }
        }
        return $MissingPath
    }
}


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
        $RegKeyRoot = "HKCU:\Software\arsscriptum\ps-linkedin-scrape\{0}" -f $Id
        $RegKeyRootCreds = "{0}\credentials" -f $RegKeyRoot

        [securestring]$SecPassword = ConvertTo-SecureString $Password -AsPlainText -Force
        [pscredential]$Credentials = New-Object System.Management.Automation.PSCredential ($Username, $SecPassword)
    
        $Username = $Credentials.UserName
        $EncodedPassword = ConvertFrom-SecureString $Credentials.Password

        $epoch = [int][double]::Parse((Get-Date -UFormat %s))
        New-ItemProperty -Path $RegKeyRoot -Name "$Id" -Value $epoch -PropertyType "DWORD"  -Force -ErrorAction Stop | Out-null
        New-ItemProperty -Path $RegKeyRootCreds -Name "username" -Value $Username -PropertyType "String" -Force -ErrorAction Stop | Out-null
        New-ItemProperty -Path $RegKeyRootCreds -Name "password" -Value $EncodedPassword -PropertyType "String"  -Force -ErrorAction Stop | Out-null

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