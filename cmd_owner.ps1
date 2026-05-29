# ==========================================
# cmd_owner.ps1 - Admin & Maintenance Module
# ==========================================

function Handle-OwnerCommands {
    param([string]$command, [string]$args, [string]$chatId)
    $handled = $true
    
    if ($command -eq "/status") {
        $cpu = (Get-WmiObject win32_processor | Measure-Object -Property LoadPercentage -Average).Average
        $ram = Get-WmiObject Win32_OperatingSystem
        $freeRam = [math]::Round($ram.FreePhysicalMemory / 1024, 2)
        $totalRam = [math]::Round($ram.TotalVisibleMemorySize / 1024, 2)
        Send-Msg -chatId $chatId -text "📊 **SYSTEM STATUS**`n⚙️ CPU: $cpu%`n💾 RAM Free: $freeRam MB"
    }
    elseif ($command -eq "/ip") {
        $tsIP = $env:TAILSCALE_IP
        $pubIP = (Invoke-RestMethod -Uri "https://api.ipify.org")
        Send-Msg -chatId $chatId -text "🌐 **NETWORK**`nTS IP: $tsIP`nPub IP: $pubIP"
    }
    elseif ($command -eq "/ps") {
        $output = Invoke-Expression $args | Out-String
        Send-Msg -chatId $chatId -text "💻 **Output:**`n$output"
    }
    elseif ($command -eq "/cmd") {
        $output = cmd.exe /c $args | Out-String
        Send-Msg -chatId $chatId -text "🖥️ **Output:**`n$output"
    }
    elseif ($command -eq "/fetch") {
        & curl.exe -s -X POST "$global:apiUrl/sendDocument" -F "chat_id=$chatId" -F "document=@$args" | Out-Null
    }
    elseif ($command -eq "/kill") {
        Send-Msg -chatId $chatId -text "💀 **Shutting down...**"
        Stop-Process -Id $PID -Force
    }
    else {
        $handled = $false
    }
    
    return $handled
}
