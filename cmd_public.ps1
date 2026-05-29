# ==========================================
# cmd_public.ps1 - Public Features Module (Revised & Stable)
# ==========================================

function Handle-PublicCommands {
    param([string]$command, [string]$args, [string]$chatId, $update)
    
    if ($command -eq "/start" -or $command -eq "/help") {
        $msg = "👋 **Halo! Saya Orbot Public Assistant.**`n`n"
        $msg += "📥 **/dl [link]** - Unduh media`n"
        $msg += "📸 **/ssweb [link]** - Screenshot web`n"
        $msg += "🎨 **/stiker** - Buat stiker`n"
        $msg += "✂️ **/rembg** - Hapus background`n"
        $msg += "📝 **/ocr** - Ekstrak teks`n"
        $msg += "🔳 **/qr [teks]** - Buat QR Code`n"
        $msg += "🔗 **/short [link]** - Singkat URL`n"
        $msg += "🤖 **/ringkas [teks]** - Rangkum via AI`n"
        $msg += "🗣️ **/tts [teks]** - Suara`n"
        $msg += "🌐 **/tr [bahasa] [teks]** - Terjemah`n"
        $msg += "🎭 **/meme** - Meme acak`n"
        $msg += "🌤️ **/cuaca [kota]** - Info cuaca`n"
        $msg += "🏓 **/ping** - Cek latensi`n"
        $msg += "📚 **/wiki [cari]** - Wiki`n"
        Send-Msg -chatId $chatId -text $msg
    }
    elseif ($command -eq "/ping") {
        Send-Msg -chatId $chatId -text "🏓 **PONG!** Orbot aktif."
    }
    elseif ($command -eq "/dl") {
        if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/dl [link]`"; return }
        Send-Msg -chatId $chatId -text "⏳ **Memproses...**"
        $tempId = Get-Random -Minimum 100000 -Maximum 999999
        $outputTemplate = "C:\Windows\Temp\dl_$tempId.%(ext)s"
        & yt-dlp --no-playlist -f "best[height<=720]" -o "$outputTemplate" "$args" 2>&1 | Out-Null
        $downloadedFile = Get-Item "C:\Windows\Temp\dl_$tempId.*" -ErrorAction SilentlyContinue
        if ($downloadedFile) {
            & curl.exe -s -X POST "$global:apiUrl/sendVideo" -F "chat_id=$chatId" -F "video=@$($downloadedFile.FullName)" | Out-Null
            Remove-Item $downloadedFile.FullName -Force
        }
    }
    elseif ($command -eq "/ssweb") {
        if (-not $args) { Send-Msg -chatId $chatId -text "⚠️ Format: `/ssweb [link]`"; return }
        $tempFile = "C:\Windows\Temp\ss.jpg"
        Invoke-WebRequest -Uri "https://image.thum.io/get/width/1080/crop/3000/noanimate/$args" -OutFile $tempFile
        & curl.exe -s -X POST "$global:apiUrl/sendDocument" -F "chat_id=$chatId" -F "document=@$tempFile" | Out-Null
        Remove-Item $tempFile -Force
    }
    elseif ($command -eq "/stiker") {
        if ($update.message.reply_to_message.photo) {
            $f = (Invoke-RestMethod -Uri "$global:apiUrl/getFile?file_id=$($update.message.reply_to_message.photo[-1].file_id)").result.file_path
            Invoke-WebRequest -Uri "https://api.telegram.org/file/bot$($env:BOT_TOKEN)/$f" -OutFile "C:\Windows\Temp\in.jpg"
            & magick.exe convert "C:\Windows\Temp\in.jpg" -resize 512x512 "C:\Windows\Temp\out.webp"
            & curl.exe -s -X POST "$global:apiUrl/sendSticker" -F "chat_id=$chatId" -F "sticker=@C:\Windows\Temp\out.webp" | Out-Null
        }
    }
    elseif ($command -eq "/rembg") {
        if ($update.message.reply_to_message.photo) {
            $f = (Invoke-RestMethod -Uri "$global:apiUrl/getFile?file_id=$($update.message.reply_to_message.photo[-1].file_id)").result.file_path
            Invoke-WebRequest -Uri "https://api.telegram.org/file/bot$($env:BOT_TOKEN)/$f" -OutFile "C:\Windows\Temp\in.jpg"
            & curl.exe -s -X POST "https://api.remove.bg/v1.0/removebg" -H "X-Api-Key: $($env:REMOVEBG_KEY)" -F "image_file=@C:\Windows\Temp\in.jpg" -o "C:\Windows\Temp\out.png"
            & curl.exe -s -X POST "$global:apiUrl/sendDocument" -F "chat_id=$chatId" -F "document=@C:\Windows\Temp\out.png" | Out-Null
        }
    }
    elseif ($command -eq "/ocr") {
        $f = (Invoke-RestMethod -Uri "$global:apiUrl/getFile?file_id=$($update.message.reply_to_message.photo[-1].file_id)").result.file_path
        Invoke-WebRequest -Uri "https://api.telegram.org/file/bot$($env:BOT_TOKEN)/$f" -OutFile "C:\Windows\Temp\ocr.jpg"
        $ocr = & curl.exe -s -X POST "https://api.ocr.space/parse/image" -H "apikey: helloworld" -F "file=@C:\Windows\Temp\ocr.jpg" | ConvertFrom-Json
        Send-Msg -chatId $chatId -text "📝 **Teks:** $($ocr.ParsedResults[0].ParsedText)"
    }
    elseif ($command -eq "/qr") {
        & curl.exe -s -X POST "$global:apiUrl/sendPhoto" -F "chat_id=$chatId" -F "photo=https://api.qrserver.com/v1/create-qr-code/?size=500x500&data=$args" | Out-Null
    }
    elseif ($command -eq "/short") {
        $url = Invoke-RestMethod -Uri "https://is.gd/create.php?format=simple&url=$args"
        Send-Msg -chatId $chatId -text "🔗 $url"
    }
    elseif ($command -eq "/ringkas") {
        $body = @{ model = "llama3-70b-8192"; messages = @( @{ role = "user"; content = $args } ) } | ConvertTo-Json
        $res = Invoke-RestMethod -Uri "https://api.groq.com/openai/v1/chat/completions" -Method Post -Headers @{ "Authorization" = "Bearer $($env:GROQ_KEY)" } -ContentType "application/json" -Body $body
        Send-Msg -chatId $chatId -text "📑 $($res.choices[0].message.content)"
    }
    elseif ($command -eq "/tts") {
        Invoke-WebRequest -Uri "https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=id&q=$([uri]::EscapeDataString($args))" -OutFile "C:\Windows\Temp\tts.mp3"
        & curl.exe -s -X POST "$global:apiUrl/sendVoice" -F "chat_id=$chatId" -F "voice=@C:\Windows\Temp\tts.mp3" | Out-Null
    }
    elseif ($command -eq "/tr") {
        $p = $args -split ' ', 2
        $res = Invoke-RestMethod -Uri "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$($p[0])&dt=t&q=$([uri]::EscapeDataString($p[1]))"
        Send-Msg -chatId $chatId -text "🌐 $($res[0][0][0])"
    }
    elseif ($command -eq "/cuaca") {
        $w = Invoke-RestMethod -Uri "https://wttr.in/$args?format=3"
        Send-Msg -chatId $chatId -text "🌤️ $w"
    }
    elseif ($command -eq "/wiki") {
        $w = Invoke-RestMethod -Uri "https://id.wikipedia.org/api/rest_v1/page/summary/$([uri]::EscapeDataString($args))"
        Send-Msg -chatId $chatId -text "📚 **$($w.title)**`n$($w.extract)"
    }
    elseif ($command -eq "/meme") {
        $m = Invoke-RestMethod -Uri "https://meme-api.com/gimme"
        & curl.exe -s -X POST "$global:apiUrl/sendPhoto" -F "chat_id=$chatId" -F "photo=$($m.url)" | Out-Null
    }
}
