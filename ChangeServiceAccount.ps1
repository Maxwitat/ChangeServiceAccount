Function Get-RandomPassword
{
#define parameters
param([int]$PasswordLength = 10)

#ASCII Character set for Password
$CharacterSet = @{
Uppercase = (97..122) | Get-Random -Count 10 | % {[char]$_}
Lowercase = (65..90) | Get-Random -Count 10 | % {[char]$_}
Numeric = (48..57) | Get-Random -Count 10 | % {[char]$_}
SpecialChar = (33..47)+(58..64)+(91..96)+(123..126) | Get-Random -Count 10 | % {[char]$_}
}

#Frame Random Password from given character set
$StringSet = $CharacterSet.Uppercase + $CharacterSet.Lowercase + $CharacterSet.Numeric + $CharacterSet.SpecialChar

-join(Get-Random -Count $PasswordLength -InputObject $StringSet)
}


function Log([string]$InhaltLog) {

Write-Host "$(Get-Date -Format "dd.MM.yyyy HH:mm:ss,ff") $($InhaltLog)"
Add-Content -Path $logFile -Value "$(Get-Date -Format "dd.MM.yyyy HH:mm:ss,ff") $($InhaltLog)"

}

function Add-ServiceLogonRight([string] $Username) {
Log "Enable ServiceLogonRight for $Username"

$tmp = New-TemporaryFile
secedit /export /cfg "$tmp.inf" | Out-Null
(gc -Encoding ascii "$tmp.inf") -replace '^SeServiceLogonRight .+', "`$0,$Username" | sc -Encoding ascii "$tmp.inf"
secedit /import /cfg "$tmp.inf" /db "$tmp.sdb" | Out-Null
secedit /configure /db "$tmp.sdb" /cfg "$tmp.inf" | Out-Null
rm $tmp* -ea 0
}

#Call the function to generate random password of 8 character
$logFile = "$PSSCriptRoot\ModifyDutiServAccount_$(Get-Date -Format "yyyyMMddHHmmss").log"
#$RandomPwd = Get-RandomPassword -PasswordLength 14
$RandomPwd = "pOnz7$zed%Lkbv"
$AccountName = "MaxServ"   
$ServiceName = "MAXSERV" #REPLACE MAXSERV with your account

Log "Installation startet: Account MAXSERV will be added to local admin group"

Start-Process net -ArgumentList "user $AccountName $RandomPwd /add" -Wait
net user $AccountName $RandomPwd /add
$AdministratorGroupName = (gwmi win32_group -filter "LocalAccount = $True And SID = 'S-1-5-32-544'").Name

Start-Process net -ArgumentList "localgroup $AdministratorGroupName /add $AccountName " -Wait

Add-ServiceLogonRight($AccountName)
Set-LocalUser -Name $AccountName -PasswordNeverExpires 1

$Username="$env:COMPUTERNAME\$AccountName"

$ServiceObj = Get-WmiObject -Class Win32_Service -Filter "name='$serviceName'"
$stopServiceStatus = $serviceObj.StopService()

if ($stopServiceStatus.ReturnValue -eq "0") {
Log "The '$serviceName' service Stopped." -f Green
} elseif($stopServiceStatus.ReturnValue -eq "5"){
Log "The '$serviceName' service is already stopped. Error code: $($stopServiceStatus.ReturnValue)" -f Yellow
}
else {
Log "Failed to Stop the '$serviceName' service. Error code: $($stopServiceStatus.ReturnValue)" -f Red
}

Start-Sleep -Seconds 15

$changeLogonAccountStatus = $serviceObj.Change($null,$null,$null,
$null,$null,$null,
$username,$RandomPwd,$null,
$null,$null)

if ($changeLogonAccountStatus.ReturnValue -eq "0") {
Log "The logon account changed successfully for the '$serviceName' service." -f Green
}else {
Log "Failed to change the logon account for the '$serviceName' service. Error code: $($changeLogonAccountStatus.ReturnValue)" -f Red
}

$serviceObj.StartService()

$count = 0
while($count -le 10)
{
$status = (Get-Service).Status
if($status -eq "Running"){
Log "Successfully completed"
exit 0
}
else{
Log "Service $ServiceName not yet running - Sleeping 15 sec"
$count = $count + 1
Start-Sleep -Seconds 15
Start-Service $ServiceName
}
}

Log "Script failed"
exit 1