# ==========================================
# core.ps1 - Public Bot Engine
# ==========================================

# 1. Menarik Environment Variables dari YAML
$botToken = $env:BOT_TOKEN
$groqKey = $env:GROQ_KEY
$apiUrl = "https://api.telegram.org/bot$botToken"

Write-Host "[INFO] Core Engine Initialized. Menyambungkan ke Telegram..."

# 2. Fungsi Dasar Pengirim Pesan
function Send-Msg {
    param([string]$chatId, [string]$text)
    $payload = @{
        chat_id = $chatId
        text = $text
        parse_mode = "Markdown"
    }
    $jsonPayload = $payload | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri "$apiUrl/sendMessage" -Method Post -ContentType "application/json" -Body $jsonPayload | Out-Null
}

# 3. Main Polling Loop (Long Polling)
$offset = 0
Write-Host "[INFO] Bot siap menerima perintah!"

while ($true) {
    try {
        $updates = Invoke-RestMethod -Uri "$apiUrl/getUpdates?offset=$offset&timeout=30" -Method Get -ErrorAction Stop
        
        if ($updates.ok -and $updates.result.Count -gt 0) {
            foreach ($update in $updates.result) {
                $offset = $update.update_id + 1
                
                # Memastikan pesan adalah teks
                if ($update.message.text) {
                    $chatId = $update.message.chat.id
                    $text = $update.message.text
                    
                    # Memecah command dan argumen (contoh: "/dl https://..." -> Command: "/dl", Args: "https://...")
                    $command = ($text -split ' ')[0].ToLower()
                    $args = ($text -split ' ', 2)[1]

                    # 4. Routing Menu Publik
                    switch ($command) {
                        "/ping" {
                            Send-Msg -chatId $chatId -text "🏓 **PONG!** Azure Public Server merespons dengan baik."
                        }
                        "/dl" {
                            if (-not $args) {
                                Send-Msg -chatId $chatId -text "⚠️ Format salah. Gunakan: `/dl [link]`"
                            } else {
                                Send-Msg -chatId $chatId -text "Memproses unduhan media... (Logika yt-dlp segera ditambahkan)"
                            }
                        }
                        "/wiki" {
                            Send-Msg -chatId $chatId -text "Mencari artikel di Wikipedia... (Logika segera ditambahkan)"
                        }
                        # ... (12 menu lainnya akan kita suntikkan di sini) ...
                        
                        default {
                            # Abaikan perintah yang tidak dikenali agar bot tidak spam
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "[ERROR] Koneksi terputus atau timeout: $_"
        Start-Sleep -Seconds 5
    }
}
