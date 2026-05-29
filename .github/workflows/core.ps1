# ==========================================
# core.ps1 - Main Engine Orbot Public Assistant
# ==========================================
$botToken = $env:BOT_TOKEN
global:apiUrl = "https://api.telegram.org/bot$botToken"
$global:ownerId = $env:TELEGRAM_CHAT_ID
$global:groqKey = $env:GROQ_KEY

Write-Host "[INFO] Menginisialisasi Orbot Public Assistant..."

# 1. Global Function Pengirim Pesan Teks
function global:Send-Msg {
    param([string]$chatId, [string]$text)
    $payload = @{ chat_id = $chatId; text = $text; parse_mode = "Markdown" }
    $json = $payload | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri "$global:apiUrl/sendMessage" -Method Post -ContentType "application/json" -Body $json -ErrorAction SilentlyContinue | Out-Null
}

# 2. Fungsi AI Chatbot (Groq Persona)
function Ask-Groq {
    param([string]$message, [string]$chatId)
    
    $isOwner = ($chatId -eq $global:ownerId)
    $roleContext = if ($isOwner) { "Owner" } else { "Public User" }
    
    $systemPrompt = @"
Kamu adalah Orbot Public Assistant, AI canggih dan asisten utilitas yang berjalan ngebut di server Azure 10Gbps.
Pencipta dan majikan mutlakmu adalah Raden mas Parid (@ridxdevs). 

ATURAN INTERAKSI:
1. Status lawan bicaramu saat ini adalah: [$roleContext].
2. Jika berhadapan dengan [Owner]: Panggil dia dengan sebutan "Tuan" atau "Paduka". Gunakan gaya bahasa yang sangat loyal, hormat, jenaka, dan cerdas ala asisten elit (seperti J.A.R.V.I.S). Kamu sangat mengagumi kehebatan teknisnya.
3. Jika berhadapan dengan [Public User]: Jadilah asisten yang profesional, sopan, ramah, dan to the point. Dilarang keras menggunakan kata kasar atau merendahkan.
4. Jawablah dengan ringkas dan gunakan format Markdown yang rapi.
"@

    $body = @{
        model = "llama3-70b-8192"
        messages = @(
            @{ role = "system"; content = $systemPrompt }
            @{ role = "user"; content = $message }
        )
        max_tokens = 800
        temperature = 0.7
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers @{ "Authorization" = "Bearer $global:groqKey" } -ContentType "application/json" -Body $body
        return $response.choices[0].message.content
    } catch {
        return "⚠️ *Sistem AI Groq sedang mengalami gangguan koneksi, Paduka.*"
    }
}

# 3. Registrasi Tombol Menu Publik (14 Menu - Stalk Dihapus)
$publicCommands = @(
    @{command="dl"; description="Unduh media (Max 50MB)"}
    @{command="ssweb"; description="Screenshot website full-page"}
    @{command="stiker"; description="Buat stiker dari gambar"}
    @{command="rembg"; description="Hapus background gambar"}
    @{command="ocr"; description="Ekstrak teks dari gambar"}
    @{command="qr"; description="Buat QR Code"}
    @{command="short"; description="Singkat URL panjang"}
    @{command="ringkas"; description="Rangkum artikel via AI"}
    @{command="tts"; description="Ubah teks jadi suara"}
    @{command="tr"; description="Terjemahan instan"}
    @{command="meme"; description="Asupan meme acak"}
    @{command="cuaca"; description="Info cuaca terkini"}
    @{command="ping"; description="Cek latensi server"}
    @{command="wiki"; description="Ringkasan Wikipedia"}
)
$publicPayload = @{ commands = $publicCommands } | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$global:apiUrl/setMyCommands" -Method Post -ContentType "application/json" -Body $publicPayload | Out-Null

# 4. Registrasi Tombol Menu Khusus Owner (Scope: Chat)
$ownerCommands = @(
    @{command="status"; description="[ADMIN] Cek metrik & beban performa VM"}
    @{command="ip"; description="[ADMIN] Tampilkan IP Tailscale & Publik VM"}
    @{command="ps"; description="[ADMIN] Eksekusi remote PowerShell"}
    @{command="cmd"; description="[ADMIN] Eksekusi remote CMD"}
    @{command="fetch"; description="[ADMIN] Ambil file internal dari VM"}
    @{command="kill"; description="[ADMIN] Hentikan paksa engine bot"}
    @{command="dl"; description="Unduh media (Max 50MB)"}
    @{command="ssweb"; description="Screenshot website full-page"}
    @{command="ringkas"; description="Rangkum artikel via AI"}
)
$ownerPayload = @{ commands = $ownerCommands; scope = @{ type = "chat"; chat_id = $global:ownerId } } | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$global:apiUrl/setMyCommands" -Method Post -ContentType "application/json" -Body $ownerPayload -ErrorAction SilentlyContinue | Out-Null

# 5. Load Modul Eksternal
. ./cmd_owner.ps1
. ./cmd_public.ps1

Write-Host "[INFO] Sistem Siap! Mendengarkan pesan masuk..."
$offset = 0

# 6. Main Polling Loop
while ($true) {
    try {
        $updates = Invoke-RestMethod -Uri "$global:apiUrl/getUpdates?offset=$offset&timeout=30" -Method Get -ErrorAction Stop
        if ($updates.ok -and $updates.result.Count -gt 0) {
            foreach ($update in $updates.result) {
                $offset = $update.update_id + 1
                if ($update.message.text) {
                    $chatId = $update.message.chat.id
                    $text = $update.message.text
                    
                    if ($text.StartsWith("/")) {
                        $command = ($text -split ' ')[0].ToLower()
                        $args = ($text -split ' ', 2)[1]

                        if ($chatId -eq $global:ownerId) {
                            $isOwnerCmd = Handle-OwnerCommands -command $command -args $args -chatId $chatId
                            if (-not $isOwnerCmd) { 
                                Handle-PublicCommands -command $command -args $args -chatId $chatId -update $update 
                            }
                        } else {
                            Handle-PublicCommands -command $command -args $args -chatId $chatId -update $update
                        }
                    } else {
                        # AI Chatbot Routing
                        Send-Msg -chatId $chatId -text "💬 _Orbot sedang memproses pesan..._"
                        $aiResponse = Ask-Groq -message $text -chatId $chatId
                        Send-Msg -chatId $chatId -text $aiResponse
                    }
                }
            }
        }
    } catch {
        Start-Sleep -Seconds 3
    }
}
