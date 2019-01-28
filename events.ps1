
param (
    [string]$rubrik_host = $(Read-Host -Prompt 'Input your Rubrik IP or Hostname'),
    [string]$fetch_date = $(Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
)

$limit = 400

$before_date = [datetime]::parseexact($fetch_date, 'yyyy-MM-dd', $null).AddDays(1).ToString('yyyy-MM-dd')

# Check for / Install Rubrik Posh Mod
$RubrikModuleCheck = Get-Module -ListAvailable Rubrik
if ($RubrikModuleCheck -eq $null) {
    Install-Module -Name Rubrik -Scope CurrentUser -Confirm:$false
}
Import-Module Rubrik
$RubrikModuleCheck = Get-Module -ListAvailable Rubrik
if ($RubrikModuleCheck -eq $null) {
  write-host "Could not deploy Rubrik Powershell Module. Please see https://powershell-module-for-rubrik.readthedocs.io/en/latest/"
}

# Check for Credentials
$Credential = ''
$CredentialFile = "$($PSScriptRoot)\.$($rubrik_host).cred"
if (Test-Path $CredentialFile){
  write-host "Credentials found for $($rubrik_host)"
  $Credential = Import-CliXml -Path $CredentialFile
}
else {
  write-host "$($CredentialFile) not found"
  $Credential = Get-Credential -Message "Credentials not found for $($rubrik_host), please enter them now."
  $Credential | Export-CliXml -Path $CredentialFile
  exit
}

$conx = ''
try {
  $conx = (Connect-Rubrik -Server $rubrik_host -Credential $Credential)
}
catch {
  write-host "Could not log into $($rubrik_host)" 
  write-host "If bad credentials, remove $($CredentialFile) and rerun." 
}
Write-Host "Logged into $($rubrik_host)"

$event_uri = [uri]::EscapeUriString("event?limit=$($limit)&after_date=$($fetch_date)&before_date=$($before_date)")
$event_results = ((Invoke-RubrikRESTCALL -Method GET -Endpoint $event_uri -api 'internal'))
$event_all += $event_results.data
Write-Host -NoNewLine "Fetching events from $($fetch_date) to $($before_date)"
while ($event_results.hasMore){
    $event_uri = [uri]::EscapeUriString("event?limit=$($limit)&after_date=$($fetch_date)&before_date=$($before_date)&after_id=$($event_results.data[-1].id)")
    $event_results = (Invoke-RubrikRESTCALL -Method GET -Endpoint $event_uri -api 'internal' )
    $event_all += $event_results.data
    write-host -NoNewLine "."
  }
write-host " DONE"
foreach ($row in $event_all){
  $out = @()
  $out += ($row.eventStatus)
  $out += ($row.time)
  $out += ($row.eventType)
  $out += ($row.objectType)
  $out += ($row.objectName)
  $out += (($row.eventInfo|convertfrom-json).message)
  write-host ('"{0}"' -f ($out -join '","'))
}
write-host "Fetched $($event_all.length) events."
exit
