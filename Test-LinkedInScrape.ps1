#╔════════════════════════════════════════════════════════════════════════════════╗
#║                                                                                ║
#║   Test-LinkedInScrape.ps1                                                      ║
#║                                                                                ║
#╟────────────────────────────────────────────────────────────────────────────────╢
#║   Guillaume Plante <codegp@icloud.com>                                         ║
#║   Code licensed under the GNU GPL v3.0. See the LICENSE file for details.      ║
#╚════════════════════════════════════════════════════════════════════════════════╝



[CmdletBinding(SupportsShouldProcess)]
param()


$UtilsPath = "$PSScriptRoot\Utils.ps1"
. "$UtilsPath"




function Register-HtmlAgilityPack {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $False)]
        [string]$Path
    )
    begin {
        if ([string]::IsNullOrEmpty($Path)) {
            $Path = "{0}\lib\{1}\HtmlAgilityPack.dll" -f "$PSScriptRoot", "$($PSVersionTable.PSEdition)"
        }
    }
    process {
        try {
            if (-not (Test-Path -Path "$Path" -PathType Leaf)) { throw "no such file `"$Path`"" }
            if (!("HtmlAgilityPack.HtmlDocument" -as [type])) {
                Write-Verbose "Registering HtmlAgilityPack... "
                add-type -Path "$Path"
            } else {
                Write-Verbose "HtmlAgilityPack already registered "
            }
        } catch {
            throw $_
        }
    }
}
function Save-CompanyProfileImages {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$HtmlFilePath,
        [Parameter(Mandatory = $False, HelpMessage = 'Recursive')]
        [int]$MaxImages = 150
    )

    try {
        if (!(Test-Path -Path "$HtmlFilePath" -PathType Leaf)) {
            Write-Error "Html File path `"$HtmlFilePath`"  doesn't exists"
            return
        }

        Add-Type -AssemblyName System.Web

        $Null = Register-HtmlAgilityPack

        $Ret = $False
        $HtmlContent = Get-Content -Path "$HtmlFilePath" -Raw


        [HtmlAgilityPack.HtmlDocument]$HtmlDoc = @{}
        $HtmlDoc.LoadHtml($HtmlContent)

        $HtmlNode = $HtmlDoc.DocumentNode
        [System.Collections.ArrayList]$List = [System.Collections.ArrayList]::new()
        $HashTable = @{}
        [int]$i = 1
        $Proceed = $True
        while ($Proceed) {
            $XNodeAddr = "/html/body/div[7]/div[3]/div/div[2]/div/div[2]/main/div[2]/div/div/div[2]/div[3]/div/div[1]/div[{0}]/div/div/div/div/div/div/div[1]/div[3]/div/div/button/div/div/img" -f $i
            if ($i -gt $MaxImages) {
                $Proceed = $False
            } else {
                $i++
            }

            try {
                $ResultNode = $HtmlNode.SelectNodes($XNodeAddr)
                if (!$ResultNode) {
                    continue;
                }
                [string]$u = $ResultNode.Attributes[1].Value
                ### IMPORTANT: Remove this from the image url so you can download it, else you get a unauthorized error!
                [string]$value = $u.Replace('&amp;', '&')
                [void]$List.Add($value)

            } catch {
                break;
            }

        }

        return $List

    } catch {
        Write-Verbose "$_"
        Write-Host "Error Occured. Probably Invalid Page Id" -f DarkRed
    }
    return $Null
}

function Show-MessageWithDelay {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = 'Message')]
        [string]$Message,
        [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'Delay')]
        [int]$Delay=10,
        [Parameter(Mandatory = $false)]
        [Alias('n')]
        [switch]$NoNewLine,
        [Parameter(Mandatory = $false)]
        [Alias('h')]
        [switch]$HideCountdown
  )
    [bool]$ShowCountdown = $True
    if ($PSBoundParameters.ContainsKey('HideCountdown') -Or ($PSBoundParameters.ContainsKey('h'))){
        $ShowCountdown = $False
    }else{
        $ShowCountdown = $True
    }

    [bool]$AppendLine = $True
    if ($PSBoundParameters.ContainsKey('NoNewLine') -Or ($PSBoundParameters.ContainsKey('n'))){
        $AppendLine = $False
    }else{
        $AppendLine = $True
    }

    Write-Host -n "$Message  " -f DarkCyan

    for ($i = $Delay; $i -gt 0; $i--) {
        if($ShowCountdown){
            Write-Host -n "$i " -f Blue
        }
        
        Start-Sleep -Seconds 1
    }
    if($AppendLine){Write-Host}

      
}

function Save-BrowseLinkedInPage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$HtmlFilePath,        
        [Parameter(Mandatory = $False, Position = 0)]
        [string]$CompanyName = "machitech-automation-inc-",
        [Parameter(Mandatory = $false, Position = 1, HelpMessage = 'MaxBytes')]
        [int]$MaxBytes=[int]::MaxValue
    )
    try {
        Write-Host -n "Detecting Selenium Module..." -f Blue
        $IsSeleniumPresent = (Get-Command 'Start-SeFirefox' -ErrorAction Ignore) -ne $Null
        if(!$IsSeleniumPresent){
            throw "You need the selenium module! `"Install-Module Selenium`""
        }else{
            Write-Host "Ok!" -f DarkGreen
        }
        [bool]$RetVal = $True
        $DoConvertBytes =  (Get-Command 'Convert-Bytes' -ErrorAction Ignore) -ne $Null
        $MaxBytesLimitStr = if($DoConvertBytes){ $MaxBytes | Convert-Bytes }else{ "$MaxBytes bytes" }
        Write-Host "Web page data stream limited to $MaxBytesLimitStr" -f Red
        [string]$LogFilePath = Join-Path "$PSScriptRoot" "SaveBrowseLinkedInPage.log"
        [string]$datestr = ((Get-Date).GetDateTimeFormats()[19]) -as [string]
        [string]$logstr = "test started on $datestr"
        [string]$sep = [string]::new('=',$logstr.Length)
        Add-Content -Path "$LogFilePath" -Value "`n`n$sep" -Force
        Add-Content -Path "$LogFilePath" -Value "$sep" -Force
        Add-Content -Path "$LogFilePath" -Value "$logstr" -Force
        Add-Content -Path "$LogFilePath" -Value "$sep`n" -Force

        #########################################################################################
        #
        # Comment out the following lines if not using Get-AppCredentials
        #
        #########################################################################################
        $CredsCmd = Get-Command 'Get-AppCredentials' -ErrorAction Ignore
        if (!$CredsCmd) { throw "no Get-AppCredentials command (core mod)" }
        Write-Host "Get-AppCredentials for LinkedInWebPage..." -f Blue
        $Credz = Get-AppCredentials -Id "LinkedInWebPage"
        if (!$Credz) { throw "no LinkedInWebPage credentials registered, use Register-LinkedInCreds " }
        $LinkedInUsername = $Credz.UserName
        $LinkedInPassword = $Credz.GetNetworkCredential().Password
        #########################################################################################
        #########################################################################################
        ##$LinkedInUsername = 'RogerRabbit'      <--- enter your username here
        ##$LinkedInPassword = 'WolfKGaryMyDaddy' <--- enter your password here
        #########################################################################################
        #########################################################################################

        $XPathUsername = '/html/body/div/main/div[3]/div[1]/form/div[1]/input'

        $XPathPassword = '/html/body/div/main/div[3]/div[1]/form/div[2]/input'

        $XPathLoginButton = '/html/body/div/main/div[3]/div[1]/form/div[4]/button'

        # Start a Firefox browser and go to the LinkedIn page
        $Url = "https://www.linkedin.com/company/{0}/posts/?feedView=all" -f $CompanyName
        $IsFirefoxInstalled = Test-FirefoxInstalled
        $IsMsEdgeInstalled = Test-MsEdgeInstalled
        $IsChromeInstalled = Test-ChromeInstalled

        if($IsFirefoxInstalled){
            $Driver = Start-SeFirefox -StartURL "$Url" 
        }elseif($IsChromeInstalled){
            $Driver = Start-SeChrome -StartURL "$Url" 
        }elseif($IsMsEdgeInstalled){
            $Driver = Start-SeEdge -StartURL "$Url" 
        }else{
            throw "no supported browser detected!"
        }
        
        Show-MessageWithDelay "Opening $Url..." -Delay 5
        Write-Host -n "Get Username Input Element..." -f Blue
        $UsernameElement = Find-SeElement -Driver $Driver -Wait -Timeout 10 -XPath $XPathUsername
        if (!$UsernameElement) { throw "cannot find login input" }
        Write-Host "Ok!" -f DarkGreen
        Write-Host -n "Get Password Input Element..." -f Blue
        $PasswordElement = Find-SeElement -Driver $Driver -Wait -Timeout 10 -XPath $XPathPassword
        if (!$PasswordElement) { throw "cannot find password input" }
        Write-Host "Ok!" -f DarkGreen
        Write-Host -n "Get Login Button Element..." -f Blue
        $LoginButtonElem = Find-SeElement -Driver $Driver -Wait -Timeout 10 -XPath $XPathLoginButton
        if (!$LoginButtonElem) { throw "cannot find login btn" }
        Write-Host "Ok!" -f DarkGreen

        Write-Host "Inputting Username..." -f Blue

        Send-SeKeys -Element $UsernameElement -Keys "$LinkedInUsername"
        #Start-Sleep 3

        Write-Host "Inputting Password..." -f Blue
        Send-SeKeys -Element $PasswordElement -Keys "$LinkedInPassword"
        #Start-Sleep 2

        Write-Host "Login In...." -f Blue
        Invoke-SeClick -Element $LoginButtonElem

        Show-MessageWithDelay "Page Loading..." -Delay 5

        [int]$TotalSize = 0
        [int]$NumReloads = 0
        [int]$MaxReloads = 20
        [int]$ZeroSizeCount = 0
        [bool]$NomoreData = $false

        # Scroll loop: simulate user scrolling down multiple times
        while( ($NomoreData -eq $False) -And ($NumReloads -lt $MaxReloads) -And ($TotalSize -lt $MaxBytes)){
            $Driver.ExecuteScript("window.scrollTo(0, document.body.scrollHeight);")
            $NumReloads++
            Show-MessageWithDelay "[$NumReloads / $MaxReloads] Auto Scroll User feed..." -Delay 2 -n -h
            $HtmlBuffer = $Driver.PageSource
            $DownloadedSize = $HtmlBuffer.Length - $TotalSize
            
            $TotalSize += $DownloadedSize
            if($DownloadedSize -eq 0){
                Write-Host "no data streamed ($ZeroSizeCount)" -f DarkRed
                if($ZeroSizeCount -ge 3){
                    $NomoreData = $True
                    Write-Host "NO MORE DATA" -f DarkRed
                }else{
                    $ZeroSizeCount++    
                }
            }else{
                $TotalSizeStr = if($DoConvertBytes){ $TotalSize | Convert-Bytes }else{ "$TotalSize bytes" }
                $DownloadedSizeStr = if($DoConvertBytes){ $DownloadedSize | Convert-Bytes }else{ "$DownloadedSize bytes" }
                Write-Host "streamed $DownloadedSizeStr. Total so far $TotalSizeStr" -f DarkGreen
            }

        }

        # Once done, extract full HTML
        $Html = $Driver.PageSource

        $TotalSize = $Html.Length
        $TotalSizeStr = if($DoConvertBytes){ $TotalSize | Convert-Bytes }else{ "$TotalSize bytes" }
        Write-Host "Downloaded page source, total $TotalSizeStr" -f DarkCyan
        Add-Content -Path "$LogFilePath" -Value "Downloaded page source, total $TotalSizeStr"
        
        # Save to file or parse it directly
        
        
        Set-Content -Path "$HtmlFilePath" -Value "$Html" -Force -ErrorAction Stop
        Start-Sleep 2
        if (!(Test-Path -Path "$HtmlFilePath" -PathType Leaf)) {
            throw "Saving Error Html File path `"$HtmlFilePath`"  doesn't exists"
        }

        Write-Host "Closing Webpage...." -f DarkCyan
        $Driver.Close()
        $Driver.Dispose()
        
    } catch {
        if($Driver){
          $Driver.Close()
          $Driver.Dispose()    
        }
        
        Add-Content -Path "$LogFilePath" -Value "$_"
        $logs = Get-Content -Path "$LogFilePath" -Raw
        $RetVal = $False
        throw " $logs"
    }
    return $RetVal

}

function Save-LinkedInImage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Url,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath
    )
    try {

        $FilePath = $Url.Replace('https://media.licdn.com', '')

        if (!(Test-Path -Path "$DestinationPath" -PathType Container)) {
            Write-Error "Download path `"$DestinationPath`"  doesn't exists. Create it before."
            return
        }
            
        
        if (!$FilePath.StartsWith('/dms')) {
            Write-Error "bad url `"$Url`" $FilePath"
        }
        $DoConvertBytes =  (Get-Command 'Convert-Bytes' -ErrorAction Ignore) -ne $Null

        [int]$RetSize = 0
        [int]$TotalSize = 0

        
        $OutFilePath = Join-Path "$DestinationPath" "$(Get-Random).jfif"
        $LogFilePath = $OutFilePath + ".log"
        
        New-Item -Path "$LogFilePath" -ItemType File -Value  "downloading file to `"$OutFilePath`"" -Force | Out-Null
        $RelLogPath = Resolve-Path -Path $LogFilePath -Relative
        $RelImgPath = $RelLogPath.TrimEnd('.log')
        $Headers = @{
            "authority" = "media.licdn.com"
            "method" = "GET"
            "path" = "$FilePath"
            "scheme" = "https"
            "accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
            "accept-encoding" = "gzip, deflate, br, zstd"
            "accept-language" = "en-US,en;q=0.7"
            "cache-control" = "no-cache"
            "pragma" = "no-cache"
            "priority" = "u=0, i"
            "referer" = "https://www.linkedin.com/"
            "sec-ch-ua" = "`"Brave`";v=`"135`", `"Not-A.Brand`";v=`"8`", `"Chromium`";v=`"135`""
            "sec-ch-ua-mobile" = "?0"
            "sec-ch-ua-platform" = "`"Windows`""
            "sec-fetch-dest" = "document"
            "sec-fetch-mode" = "navigate"
            "sec-fetch-site" = "cross-site"
            "sec-fetch-user" = "?1"
            "sec-gpc" = "1"
            "upgrade-insecure-requests" = "1"
        }
        

        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0.0.0 Safari/537.36"
        Write-Host " [i] downloading file to `"$RelImgPath`"" -f DarkCyan
        try{
           Invoke-WebRequest -UseBasicParsing -Uri "$Url" -WebSession $session -Headers $Headers -OutFile "$OutFilePath" -ErrorAction Stop -Verbose *> "$LogFilePath"
           $RetSize = (Get-Item "$OutFilePath").Length
           $RetSizeStr = if($DoConvertBytes){ $RetSize | Convert-Bytes }else{ "$RetSize bytes" }
           Write-Host " [i] transfered $RetSizeStr" -f DarkGreen
           Remove-Item -Path "$LogFilePath" -Recurse -Force | Out-Null
        }catch{
            $RetSize = 0
            Add-Content -Path "$LogFilePath" -Value "$_"
            $logs = Get-Content -Path "$LogFilePath" -Raw
            throw " $logs"
        }
        
        return $RetSize
        

    } catch {
        Write-Error "$_"
    }

}



function Start-LinkedInScrapeTest {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, Position = 0, HelpMessage = 'MaxBytes')]
        [int]$MaxBytes=[int]::MaxValue        
    )
    try {
        $DoConvertBytes =  (Get-Command 'Convert-Bytes' -ErrorAction Ignore) -ne $Null

        Write-Host -n "`nDetecting Selenium Module..." -f Blue
        $IsSeleniumLoaded = (Get-Module -Name Selenium -ErrorAction Ignore) -ne $Null
        if(!$IsSeleniumLoaded){
            $IsSeleniumLoaded = (Import-Module -Name Selenium -Force -PassThru) -ne $Null
        }else{
            Write-Host "Ok!" -f DarkGreen
        }
        Write-Host -n "Detecting Selenium Commands..." -f Blue
        $IsSeleniumPresent = $IsSeleniumLoaded -And ((Get-Command 'Start-SeFirefox' -ErrorAction Ignore) -ne $Null)
        if(!$IsSeleniumPresent){
            throw "You need the selenium module! `"Install-Module Selenium`""
        }else{
            Write-Host "Ok!" -f DarkGreen
        }

        try{
            Write-Host -n "Register HtmlAgilityPack Libraries..." -f DarkCyan
            Register-HtmlAgilityPack
            Write-Host "Ok!" -f DarkGreen
        }catch{
            throw "Error registering HtmlAgilityPack!"
        }

        try{
            $OutFilePath = New-TemporaryFile | Select -ExpandProperty Fullname
 
            $MaxBytesLimitStr = if($DoConvertBytes){ $MaxBytes | Convert-Bytes }else{ "$MaxBytes bytes" }
            
            Write-Host "`nSave page source for parsing to `"$OutFilePath`"" -f DarkCyan
            Write-Host "Web page data stream limited to $MaxBytesLimitStr" -f DarkCyan
            # TEST ONLY:  Limit Downloaded Page to 2MB
            #$Ret = Save-BrowseLinkedInPage -HtmlFilePath "$OutFilePath" -MaxBytes 2Mb 
            $Ret = Save-BrowseLinkedInPage -HtmlFilePath "$OutFilePath" -MaxBytes $MaxBytes
            if ((!$Ret) -Or !(Test-Path -Path "$OutFilePath" -PathType Leaf)) {
                throw "Saving Error Html File path `"$OutFilePath`"  doesn't exists"
            }else{
                Write-Host "Saved to $OutFilePath" -f DarkGreen
            }
        }catch{
            throw "Error Save page source for parsing: $_"
            
        }
        try{
            Write-Host -n "`nParse web page source $OutFilePath for image links..." -f DarkCyan
            $ParsedImageLinks = Save-CompanyProfileImages -HtmlFilePath "$OutFilePath"
            $ParsedLinksCount = $ParsedImageLinks.Count
            Write-Host "Ok! Found $ParsedLinksCount image!" -f DarkGreen
        }catch{
            throw "Error when parsing page: $_"
        }
        
        
        $OutFileDir = Join-Path "$PWD" "downloaded_images"
        Remove-Item -Path "$OutFileDir" -Recurse -Force -ErrorAction Ignore | Out-Null
        New-Item -Path "$OutFileDir" -ItemType Directory -Force -ErrorAction Stop | Out-Null

        $GitIgnore = Join-Path "$PWD" ".gitignore"
        if(!(Select-String -Path "$GitIgnore" -Pattern "downloaded_images")) {
            Add-Content -Path "$GitIgnore" -Value "downloaded_images" -Force
            Write-Host "Updating .gitignore"
        }
        
        [int]$linkcount=1
        [int]$imgcount=0
        foreach ($img in $ParsedImageLinks) {
            $log = "`nProcessing Image Link {0}/{1}..." -f $linkcount, $ParsedLinksCount
            Write-Host "$log" -f DarkYellow
            $RetSize = Save-LinkedInImage -Url "$img" -DestinationPath "$OutFileDir"
            if($RetSize -eq 0){
                Write-Host " [!] download failed!" -f DarkRed
            }else{
                $imgcount++
                $TotalSize += $RetSize
                Write-Host " [i] downloaded image no $imgcount" -f DarkGreen
            }
            $linkcount++
        }
        $TotalSizeStr = if($DoConvertBytes){ $TotalSize | Convert-Bytes }else{ "$TotalSize bytes" }
        Write-Host "Script Complete! downloaded a total of $imgcount images, totalling $TotalSizeStr" -f DarkGreen

        $ExplorerExe = (Get-Command 'explorer.exe').Source
        & "$ExplorerExe" "$OutFileDir"


    } catch {
        Write-Error "$_"
    }

}

