# ==========================================
# cmd_public.ps1 - Public Features Module
# ==========================================

function Handle-PublicCommands {
    param([string]$command, [string]$args, [string]$chatId, $update)
    
    switch ($command) {
        "/start", "/help" {
            $msg = "👋 **Halo! Saya Orbot Public Assistant.**`nBot utilitas otomatis yang berjalan di server Azure 10Gbps.`n`n"
            $msg += "📚 **PERINTAH TERSEDIA:**`n"
            $msg += "📥 **/dl [link]** - Unduh media (Max 50MB)`n"
            $msg += "📸 **/ssweb [link]** - Screenshot web`n"
            $msg += "🎨 **/stiker** - Buat stiker (Reply gambar)`n"
            $msg += "✂️ **/rembg** - Hapus background (Reply gambar)`n"
            $msg += "📝 **/ocr** - Ekstrak teks gambar (Reply gambar)`n"
            $msg += "🔳 **/qr [teks]** - Buat QR Code`n"
            $msg += "🔗 **/short [link]** - Singkat URL panjang`n"
            $msg += "🤖 **/ringkas [teks]** - Rangkum via AI`n"
            $msg += "🗣️ **/tts [teks]** - Ubah teks jadi suara`n"
            $msg += "🌐 **/tr [bahasa] [teks]** - Terjemahan instan`n"
            $msg += "🎭 **/meme** - Asupan meme acak`n"
            $msg += "🌤️ **/cuaca [kota]** - Info cuaca terkini`n"
            $msg += "🏓 **/ping** - Cek latensi server`n"
            $msg += "📚 **/wiki [cari]** - Ringkasan Wikipedia`n`n"
            $msg += "💡 _Anda juga dapat mengobrol langsung dengan saya tanpa garis miring!_"
            Send-Msg -chatId $chatId -text $msg
        }
        
        "/ping" {
            Send-Msg -chatId $chatId -text "🏓 **PONG!** Orbot Engine merespons."
        }

        "/dl" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/dl [link]`"; return }
            Send-Msg -chatId $chatId -text "⏳ **Memproses unduhan...**"

            $tempId = Get-Random -Minimum 100000 -Maximum 999999
            $outputTemplate = "C:\Windows\Temp\dl_$tempId.%(ext)s"

            try {
                & yt-dlp --no-playlist -f "best[height<=720]" -o "$outputTemplate" "$args" 2>&1 | Out-Null
                $downloadedFile = Get-Item "C:\Windows\Temp\dl_$tempId.*" -ErrorAction SilentlyContinue

                if (-not $downloadedFile) { Send-Msg -chatId $chatId -text "❌ **Gagal mengambil media.**"; return }

                if (($downloadedFile.Length / 1MB) -gt 49.5) {
                    Remove-Item $downloadedFile.FullName -Force -ErrorAction SilentlyContinue
                    Send-Msg -chatId $chatId -text "⚠️ **DOWNLOAD FAILED, FILE TOO LARGE (50MB+)**"
                    return
                }

                $filePath = $downloadedFile.FullName
                & curl.exe -s -X POST "$global:apiUrl/sendVideo" -F "chat_id=$chatId" -F "video=@$filePath" -F "supports_streaming=true" | Out-Null
                Remove-Item $filePath -Force -ErrorAction SilentlyContinue
            } catch {
                Send-Msg -chatId $chatId -text "❌ **Terjadi kesalahan sistem unduhan.**"
            }
        }

        "/ssweb" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/ssweb [link]`"; return }
            Send-Msg -chatId $chatId -text "📸 **Mesin sedang merender website, mohon tunggu...**"
            $targetUrl = $args
            if (-not $targetUrl.StartsWith("http")) { $targetUrl = "http://$targetUrl" }
            $tempId = Get-Random -Minimum 10000 -Maximum 99999
            $tempFile = "C:\Windows\Temp\ss_$tempId.jpg"
            try {
                $ssUrl = "https://image.thum.io/get/width/1080/crop/3000/noanimate/$targetUrl"
                Invoke-WebRequest -Uri $ssUrl -OutFile $tempFile -TimeoutSec 30 -ErrorAction Stop
                if (Test-Path $tempFile) {
                    & curl.exe -s -X POST "$global:apiUrl/sendDocument" -F "chat_id=$chatId" -F "document=@$tempFile" -F "caption=📸 **Target:** $targetUrl" | Out-Null
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                } else { Send-Msg -chatId $chatId -text "❌ **Gagal menghasilkan gambar dari tautan tersebut.**" }
            } catch {
                Send-Msg -chatId $chatId -text "❌ **Situs tidak dapat diakses atau diblokir oleh mesin perender.**"
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
            }
        }

        "/stiker" {
            if (-not $update.message.reply_to_message -or -not $update.message.reply_to_message.photo) {
                Send-Msg -chatId $chatId -text "⚠️ **Gunakan dengan cara me-reply gambar (dikirim sebagai Photo).**"
                return
            }
            Send-Msg -chatId $chatId -text "🎨 **Sedang mengonversi gambar menjadi stiker...**"
            $tempInput = "C:\Windows\Temp\in_stk_$chatId.jpg"
            $tempOutput = "C:\Windows\Temp\out_stk_$chatId.webp"
            try {
                $fileId = $update.message.reply_to_message.photo[-1].file_id
                $fileInfo = Invoke-RestMethod -Uri "$global:apiUrl/getFile?file_id=$fileId" -ErrorAction Stop
                Invoke-WebRequest -Uri "https://api.telegram.org/file/bot$($env:BOT_TOKEN)/$($fileInfo.result.file_path)" -OutFile $tempInput -ErrorAction Stop
                & magick.exe convert "$tempInput" -resize 512x512 "$tempOutput" 2>&1 | Out-Null
                if (Test-Path $tempOutput) {
                    & curl.exe -s -X POST "$global:apiUrl/sendSticker" -F "chat_id=$chatId" -F "sticker=@$tempOutput" | Out-Null
                    Remove-Item $tempInput, $tempOutput -Force -ErrorAction SilentlyContinue
                } else { Send-Msg -chatId $chatId -text "❌ **Gagal mengonversi gambar.**" }
            } catch {
                Send-Msg -chatId $chatId -text "❌ **Terjadi kesalahan internal saat memproses stiker.**"
            }
        }

        "/rembg" {
            if (-not $update.message.reply_to_message -or -not $update.message.reply_to_message.photo) {
                Send-Msg -chatId $chatId -text "⚠️ **Gunakan dengan cara me-reply gambar (dikirim sebagai Photo).**"
                return
            }
            $removeBgKey = $env:REMOVEBG_KEY
            if (-not $removeBgKey) { Send-Msg -chatId $chatId -text "❌ **Sistem gagal: API Key Remove.bg belum dikonfigurasi.**"; return }
            Send-Msg -chatId $chatId -text "✂️ **Mesin sedang memotong latar belakang gambar...**"
            $tempInput = "C:\Windows\Temp\rbg_in_$chatId.jpg"
            $tempOutput = "C:\Windows\Temp\rbg_out_$chatId.png"
            try {
                $fileId = $update.message.reply_to_message.photo[-1].file_id
                $filePath = (Invoke-RestMethod -Uri "$global:apiUrl/getFile?file_id=$fileId").result.file_path
                Invoke-WebRequest -Uri "https://api.telegram.org/file/bot$($env:BOT_TOKEN)/$filePath" -OutFile $tempInput
                & curl.exe -s -X POST "https://api.remove.bg/v1.0/removebg" -H "X-Api-Key: $removeBgKey" -F "image_file=@$tempInput" -F "size=auto" -o "$tempOutput"
                if (Test-Path $tempOutput) {
                    & curl.exe -s -X POST "$global:apiUrl/sendDocument" -F "chat_id=$chatId" -F "document=@$tempOutput" -F "caption=✂️ **Background berhasil dihapus.**" | Out-Null
                } else { Send-Msg -chatId $chatId -text "❌ **Gagal memproses gambar.**" }
                Remove-Item $tempInput, $tempOutput -Force -ErrorAction SilentlyContinue
            } catch { Send-Msg -chatId $chatId -text "❌ **Terjadi kesalahan jaringan.**" }
        }

        "/ocr" {
            if (-not $update.message.reply_to_message -or -not $update.message.reply_to_message.photo) {
                Send-Msg -chatId $chatId -text "⚠️ **Gunakan dengan cara me-reply gambar (dikirim sebagai Photo).**"
                return
            }
            Send-Msg -chatId $chatId -text "📝 **Menganalisis dan mengekstrak teks...**"
            $tempInput = "C:\Windows\Temp\ocr_in_$chatId.jpg"
            try {
                $fileId = $update.message.reply_to_message.photo[-1].file_id
                $filePath = (Invoke-RestMethod -Uri "$global:apiUrl/getFile?file_id=$fileId").result.file_path
                Invoke-WebRequest -Uri "https://api.telegram.org/file/bot$($env:BOT_TOKEN)/$filePath" -OutFile $tempInput
                $ocrResponse = & curl.exe -s -X POST "https://api.ocr.space/parse/image" -H "apikey: helloworld" -F "file=@$tempInput" -F "language=eng" -F "isOverlayRequired=false" | ConvertFrom-Json
                $parsedText = $ocrResponse.ParsedResults[0].ParsedText
                if ([string]::IsNullOrWhiteSpace($parsedText)) { Send-Msg -chatId $chatId -text "❌ **Tidak ada teks terbaca.**" }
                else { Send-Msg -chatId $chatId -text "📝 **Hasil Ekstraksi:**`n`n```text`n$parsedText`n```" }
                Remove-Item $tempInput -Force -ErrorAction SilentlyContinue
            } catch { Send-Msg -chatId $chatId -text "❌ **Terjadi kesalahan pindaian.**" }
        }

        "/qr" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/qr [teks/link]`"; return }
            $query = [uri]::EscapeDataString($args)
            $qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=500x500&data=$query"
            & curl.exe -s -X POST "$global:apiUrl/sendPhoto" -F "chat_id=$chatId" -F "photo=$qrUrl" -F "caption=🔳 QR Code berhasil dibuat." | Out-Null
        }

        "/short" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/short [link]`"; return }
            try {
                $query = [uri]::EscapeDataString($args)
                $shortLink = Invoke-RestMethod -Uri "https://is.gd/create.php?format=simple&url=$query" -ErrorAction Stop
                Send-Msg -chatId $chatId -text "🔗 **Link Singkat:** $shortLink"
            } catch { Send-Msg -chatId $chatId -text "❌ Gagal memendekkan tautan." }
        }

        "/ringkas" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/ringkas [teks]`"; return }
            Send-Msg -chatId $chatId -text "🤖 **Groq AI sedang merangkum teks...**"
            $systemPrompt = "Kamu adalah AI asisten perangkum. Tugasmu adalah merangkum teks yang diberikan pengguna menjadi poin utama (bullet points) yang padat dan jelas. Jangan bertele-tele."
            $body = @{ model = "llama3-70b-8192"; messages = @( @{ role = "system"; content = $systemPrompt }, @{ role = "user"; content = $args } ); max_tokens = 500; temperature = 0.5 } | ConvertTo-Json -Depth 10
            try {
                $response = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers @{ "Authorization" = "Bearer $($env:GROQ_KEY)" } -ContentType "application/json" -Body $body
                Send-Msg -chatId $chatId -text "📑 **Intisari Teks:**`n`n$($response.choices[0].message.content)"
            } catch { Send-Msg -chatId $chatId -text "❌ **Sistem Groq sedang sibuk.**" }
        }

        "/tts" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/tts [teks]`"; return }
            Send-Msg -chatId $chatId -text "🗣️ **Merekam suara...**"
            $tempAudio = "C:\Windows\Temp\tts_$chatId.mp3"
            $safeText = if ($args.Length -gt 200) { $args.Substring(0, 200) } else { $args }
            $encodedText = [uri]::EscapeDataString($safeText)
            try {
                $ttsUrl = "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=id&q=$encodedText"
                Invoke-WebRequest -Uri $ttsUrl -OutFile $tempAudio -ErrorAction Stop
                if (Test-Path $tempAudio) {
                    & curl.exe -s -X POST "$global:apiUrl/sendVoice" -F "chat_id=$chatId" -F "voice=@$tempAudio" | Out-Null
                    Remove-Item $tempAudio -Force -ErrorAction SilentlyContinue
                } else { Send-Msg -chatId $chatId -text "❌ **Gagal menghasilkan file suara.**" }
            } catch { Send-Msg -chatId $chatId -text "❌ **Terjadi kesalahan sintesis suara.**" }
        }

        "/tr" {
            $parts = $args -split ' ', 2
            if ($parts.Count -lt 2) { Send-Msg -chatId $chatId -text "⚠️ Format: `/tr [kode_bahasa] [teks]`"; return }
            $targetLang = $parts[0]
            $textToTranslate = [uri]::EscapeDataString($parts[1])
            Send-Msg -chatId $chatId -text "🌐 **Menerjemahkan teks...**"
            try {
                $translateUrl = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$targetLang&dt=t&q=$textToTranslate"
                $response = Invoke-RestMethod -Uri $translateUrl -ErrorAction Stop
                $translatedText = ""
                foreach ($sentence in $response[0]) { $translatedText += $sentence[0] }
                Send-Msg -chatId $chatId -text "🇺🇳 **Hasil ($targetLang):**`n`n```text`n$translatedText`n```"
            } catch { Send-Msg -chatId $chatId -text "❌ **Gagal menerjemahkan.**" }
        }

        "/cuaca" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/cuaca [kota]`"; return }
            try {
                $query = [uri]::EscapeDataString($args)
                $weather = Invoke-RestMethod -Uri "https://wttr.in/${query}?format=j1" -ErrorAction Stop
                $current = $weather.current_condition[0]
                $msg = "🌤️ **Cuaca di $args:**`nSuhu: $($current.temp_C)°C`nKondisi: $($current.weatherDesc[0].value)`nKelembapan: $($current.humidity)%"
                Send-Msg -chatId $chatId -text $msg
            } catch { Send-Msg -chatId $chatId -text "❌ Kota tidak ditemukan." }
        }

        "/wiki" {
            if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/wiki [pencarian]`"; return }
            try {
                $query = [uri]::EscapeDataString($args)
                $wiki = Invoke-RestMethod -Uri "https://id.wikipedia.org/api/rest_v1/page/summary/$query" -ErrorAction Stop
                Send-Msg -chatId $chatId -text "📚 **$($wiki.title)**`n`n$($wiki.extract)"
            } catch { Send-Msg -chatId $chatId -text "❌ Halaman tidak ditemukan." }
        }

        "/meme" {
            try {
                $meme = Invoke-RestMethod -Uri "https://meme-api.com/gimme" -ErrorAction Stop
                & curl.exe -s -X POST "$global:apiUrl/sendPhoto" -F "chat_id=$chatId" -F "photo=$($meme.url)" -F "caption=🎭 $($meme.title)" | Out-Null
            } catch { Send-Msg -chatId $chatId -text "❌ Gagal mengambil meme." }
        }
    }
}
