# ==========================================
# core.ps1 - Main Engine
# ==========================================
$botToken = $env:BOT_TOKEN
global:apiUrl = "https://api.telegram.org/bot$botToken"
$ownerId = $env:TELEGRAM_CHAT_ID # ID Mas Farid dari Secrets

Write-Host "[INFO] Core Engine Initialized."

# Global Function pengirim pesan agar bisa dipakai di semua modul
function global:Send-Msg {
    param([string]$chatId, [string]$text)
    $payload = @{ chat_id = $chatId; text = $text; parse_mode = "Markdown" }
    $json = $payload | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri "$apiUrl/sendMessage" -Method Post -ContentType "application/json" -Body $json | Out-Null
}

# Load Modul Eksternal (Dot-Sourcing)
. ./cmd_owner.ps1
. ./cmd_public.ps1

Write-Host "[INFO] Modules Loaded. Bot siap menerima perintah!"
$offset = 0

while ($true) {
    try {
        $updates = Invoke-RestMethod -Uri "$apiUrl/getUpdates?offset=$offset&timeout=30" -Method Get -ErrorAction Stop
        if ($updates.ok -and $updates.result.Count -gt 0) {
            foreach ($update in $updates.result) {
                $offset = $update.update_id + 1
                if ($update.message.text) {
                    $chatId = $update.message.chat.id
                    $text = $update.message.text
                    
                    $command = ($text -split ' ')[0].ToLower()
                    $args = ($text -split ' ', 2)[1]

                    # ROUTING LOGIC
                    if ($chatId -eq $ownerId) {
                        # Jika yang chat adalah Owner, cek apakah itu command owner dulu
                        $isOwnerCmd = Handle-OwnerCommands -command $command -args $args -chatId $chatId
                        # Jika bukan command owner, lempar ke command public
                        if (-not $isOwnerCmd) {
                            Handle-PublicCommands -command $command -args $args -chatId $chatId
                        }
                    } else {
                        # Jika yang chat adalah Pengguna Umum
                        Handle-PublicCommands -command $command -args $args -chatId $chatId
                    }
                }
            }
        }
    } catch {
        Start-Sleep -Seconds 5
    }
}
