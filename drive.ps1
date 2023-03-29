
<#
Supports logging
Checks drive for free space
Lets user specify drive
Supports both windows and linux
#>
#TODO
# try sending noti to email instead of log file
# adjust parameter to a dynamic variable instead of hard 20%


# user has to provide drive
param (
    [Parameter(Mandatory = $true)]
    [string] 
    $Drive
)


# log directory - where are we writing to?
if ($PSVersionTable.Platform -eq 'Unix') {
    $logPath = '/tmp'
} else {
    $logPath = 'C:\Logs'
}

$logFile = "$logPath\driveCheck.log" #logfile

# verify if log directy exists / otherwise create on device

try {
    if (-not (Test-Path -Path $logPath  -ErrorAction Stop)) {
        #output dir not found. Create dir
        New-Item -ItemType Directory -Path $logPath -ErrorAction Stop | Out-Null #bypass spitting to console
        New-Item -ItemType File -Path $logFile -ErrorAction Stop | Out-Null
    } 
} catch {
    throw
}

Add-Content -Path $logFile -Value "[INFO] Running $PSCommandPath" #location
# verify that PoshGram is installed

if (-not (Get-Module -Name PoshGram -ListAvailable)) {
    Add-Content -Path $logFile -Value "[ERROR] PoshGram is not installed."
    throw
} else {
    Add-Content -Path $logFile -Value "[INFO] PoshGram is installed."
}

# get hard drive info

try {
    if ($PSVersionTable.Platform -eq 'Unix') {
        # used
        # free
        $volume = Get-PSDrive -Name $Drive -ErrorAction Stop
        #verify if volume exists
        if($volume) {
            $total = $volume.Used + $volume.Free
            $percentFree = [int](($volume.Free / $total) * 100)
            Add-Content -Path $logFile -Value "[INFO] Percent Free: $percentFree%"
        } else {
            Add-Content -Path $logFile -Value "[ERROR] $Drive not found."
            throw
        }
    } else { #windows
        $volume = Get-Volume -ErrorAction Stop | Where-Object {$_.DriveLetter -eq $Drive} #check if driveletter equals drive specified 
        if($volume) {
            $total = $volume.Size
            $percentFree = [int](($volume.SizeRemaining / $total) * 100)
            Add-Content -Path $logFile -Value "[INFO] Percent Free: $percentFree%"
        } else {
            Add-Content -Path $logFile -Value "[ERROR] $Drive not found."
            throw
        }
    }
}
catch {
    
    Add-Content -Path $logFile -Value "[ERROR] Unable to retrieve volume information."
    Add-Content -Path $logFile -Value $_ #error msg
    throw
    
}

# send telegram message is drive is low
# less than 20%
if ($percentFree -le 20) {
    try {
        Import-Module -Name PoshGram -ErrorAction Stop
        Add-Content -Path $logFile -Value "[INFO] Imported PoshGram Successfully"
    }
    catch {
        Add-Content -Path $logFile -Value "[ERROR] PoshGram could not be implemented"
        Add-Content -Path $logFile -Value $_ #error msg
        
    }
    Add-Content -Path $logFile -Value "[INFO] Sending Telegram Notification"
    # $botToken = '604891196:AAGngAfLUjjblCo9HcrQbSwEvHXHQ4sWNxo'
    # $chat = '-355448593'
    #Send-TelegramTextMessage -BotToken $botToken -ChatID $chat -Message "Your drive is low"
    #splat
    $sendTelegramTextMessageSplat = @{
        Message = "[LOW SPACE] Drive at $percentFree%."
        ChatID = '-355448593'
        BotToken = '604891196:AAGngAfLUjjblCo9HcrQbSwEvHXHQ4sWNxo'
        ErrorAction = 'Stop'
    }
    try {
        Send-TelegramTextMessage @sendTelegramTextMessageSplat
        Add-Content -Path $logFile -Value "[INFO] Message sent successfully"
        
    }
    catch {
        Add-Content -Path $logFile -Value "[ERROR] Error encountered sending message: "
        Add-Content -Path $logFile -Value $_
        throw
        }
}
