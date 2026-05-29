# ==========================================
# cmd_owner.ps1 - Admin & Maintenance Module
# ==========================================

function Handle-OwnerCommands {
    param([string]$command, [string]$args, [string]$chatId)
    
    $handled = $true
    
    switch ($command) {
        "/status" {
            $cpu = (Get-WmiObject win32_processor | Measure-Object -Property LoadPercentage -Average).Average
            $ram = Get-WmiObject Win32_OperatingSystem
            $freeRam = [math]::Round($ram.FreePhysicalMemory / 1024, 2)
            $totalRam = [math]::Round($ram.TotalVisibleMemorySize / 1024, 2)
            
            $msg = "📊 **[PUBLIC BOT] SYSTEM STATUS**`n"
            $msg += "⚙️ CPU Usage: $cpu%`n"
            $msg += "💾 RAM Free: $freeRam MB / $totalRam MB`n"
            Send-Msg -chatId $chatId -text $msg
        }
        "/ip" {
            $tsIP = $env:TAILSCALE_IP
            $pubIP = (Invoke-RestMethod -Uri "https://api.ipify.org")
            
            $msg = "🌐 **[PUBLIC BOT] NETWORK INFO**`n"
            $msg += "Tailscale IP: `$ $tsIP`n"
            $msg += "Public IP: `$ $pubIP`n"
            Send-Msg -chatId $chatId -text $msg
        }
        "/ps" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Masukkan command PowerShell."; return $handled }
            try {
                $output = Invoke-Expression $args | Out-String
                if ([string]::IsNullOrWhiteSpace($output)) { $output = "Command dieksekusi tanpa output." }
                Send-Msg -chatId $chatId -text "💻 **PS Output:**`n```text`n$output`n```"
            } catch {
                Send-Msg -chatId $chatId -text "❌ **Error:**`n```text`n$_`n```"
            }
        }
        "/cmd" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Masukkan command CMD."; return $handled }
            $output = cmd.exe /c $args | Out-String
            Send-Msg -chatId $chatId -text "🖥️ **CMD Output:**`n```text`n$output`n```"
        }
        "/kill" {
            Send-Msg -chatId $chatId -text "💀 **TERMINATING PUBLIC BOT ENGINE...**"
            Stop-Process -Id $PID -Force
        }
        default {
            # Jika command tidak ada di daftar owner, kembalikan ke public (misal Owner mau pakai /dl)
            $handled = $false 
        }
    }
    
    return $handled
}
