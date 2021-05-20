#!PS
#TIMEOUT=100000
$ErrorActionPreference = 'SilentlyContinue'
$endpointURL = '' # enter your endpoint URL here
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Content-Type", "application/json")
$hostname = $env:COMPUTERNAME #get computer name
$domain = $env:USERDOMAIN #get domain
$serial = (get-wmiobject -Class win32_bios).SerialNumber #get serial
$date=[Math]::Floor([decimal](Get-Date(Get-Date).ToUniversalTime()-uformat "%s"))*1000
$wmi_shadowcopyareas = get-ciminstance -classname win32_shadowstorage -property AllocatedSpace
$wmi_volumeinfo =  get-ciminstance -classname win32_volume | Where-Object {$_.caption -notlike "*Volume*" -and $_.DriveType -eq "3"}


# for each drive list shadow copy status, schedule, storage used
foreach ($wmi in $wmi_shadowcopyareas){
    foreach ($volume in $wmi_volumeinfo){
        $shadowcopies = (Get-CimInstance Win32_ShadowCopy | Where-Object {$_.VolumeName -eq $volume.deviceid} | Select-Object -ExpandProperty installdate)
        $mountpoint = ($volume.caption).split("\")[0]
        $lastcopyTimeDate = (get-date ($shadowcopies | Sort-Object | select-object -last 1))
        $epochDate = [Math]::Floor([decimal](Get-Date -date $lastcopytimedate -uformat "%s"))*1000
        $lastcopy = $epochDate
        $shadowcount = $shadowcopies.count
        if ($volume.deviceid -like ($wmi.volume).deviceID){
            $allocatedspace = ($wmi.allocatedspace)
            $enabled = $true
        }
        else{
            $allocatedspace = $null
            $enabled = $false
            
        }
        $sharecount = (Get-SmbShare | where {$_.Path -like "$mountpoint*" -and $_.description -ne "Default share"}).count
        $payload = @{
            serial = $serial;
            hostname = $hostname;
            domain = $domain;
            mountpoint = $mountpoint;
            allocatedSpace = $allocatedspace;
            enabled = $enabled;
            smbsharecount = $sharecount;
            shadowcopyCount = $shadowcount;
            lastShadowCopy = $lastcopy
            }
        $payloadconv = $payload | ConvertTo-Json -Depth 2 -compress
        $body = @"
        {
            "index":"dev-stateshadowcopies",
            "log":{
                "submit": $date,
                "source": "get-stateshadowcopies",
                "function": "get-stateshadowcopies",
                "message": "gather shadow copy information from $HOSTNAME",
                "severity": 100,
                "payload": $payloadconv
            }
        }
"@
        $response = Invoke-RestMethod $endpointURL -Method 'POST' -Headers $headers -Body $body
        
}
}


