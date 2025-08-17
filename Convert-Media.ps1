Clear-Host

function Convert-Media {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputFile,
        [Parameter(Mandatory=$false)]
        [string]$OutputFile = ""
    )

    # --- 1. Validar la existencia del archivo de entrada ---
    if (-not (Test-Path $InputFile -PathType Leaf)) {
        Write-Error "`n⚠️🚨🚧 El archivo de entrada no existe o no se puede acceder: '$InputFile'. `nPor favor, verifica la ruta y los permisos. 🚨🚧"
        exit 1
    }

    # Asumimos que ffmpeg está en el PATH
    $ffmpegPath = "ffmpeg"

    # --- 2. Detección de Hardware y Codificadores Disponibles ---
    Write-Host "`n⏳ Realizando detección de hardware para FFmpeg..."

    $hardwareAccelerators = @()
    $encodersInfo = & $ffmpegPath -encoders 2>&1 | Out-String
    $decodersInfo = & $ffmpegPath -decoders 2>&1 | Out-String

    # Definir una lista de verificaciones para hacer el código más mantenible y legible
    $detectionChecks = @(
        [PSCustomObject]@{
            Name            = "nvenc"
            Pattern         = "h264_nvenc"
            Message         = "  - NVIDIA GPU detectada (NVENC)."
            ForegroundColor = "Green"
            SourceString    = $encodersInfo
        },
        [PSCustomObject]@{
            Name            = "qsv"
            Pattern         = "h264_qsv|hevc_qsv"
            Message         = "  - Intel Quick Sync Video (QSV) detectado."
            ForegroundColor = "Blue"
            SourceString    = $encodersInfo
        },
        [PSCustomObject]@{
            Name            = "amf"
            Pattern         = "h264_amf|hevc_amf"
            Message         = "  - AMD AMF detectado."
            ForegroundColor = "Red"
            SourceString    = $encodersInfo
        },
        [PSCustomObject]@{
            Name            = "cuda_decode"
            Pattern         = "cuda|cuvid"
            Message         = "  - Soporte general CUDA/NVDEC detectado."
            ForegroundColor = "Green"
            SourceString    = $decodersInfo
        }
    )

    # Iterar sobre las verificaciones y ejecutar la lógica
    foreach ($check in $detectionChecks) {
        if ($check.SourceString -match $check.Pattern) {
            Write-Host -BackgroundColor Black -ForegroundColor $check.ForegroundColor $check.Message
            $hardwareAccelerators += $check.Name
        }
    }

    # --- 3. Preguntar al usuario por el formato de salida ---
    Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "[ 🛸 ¿Qué tipo de salida deseas generar? 🛰 ]"
    Write-Host "`n"
    Write-Host -BackgroundColor Black -ForegroundColor Green "🚀 1.📺🎬 Video (MP4 - H.264) 📽"
    Write-Host -BackgroundColor Black -ForegroundColor Green "🚀 2.📺🎥 Video (WebM - VP9) 📽"
    Write-Host -BackgroundColor Black -ForegroundColor Green "🚀 3.🎤🎵🎧 Audio (MP3) 🎸🎸"
    Write-Host -BackgroundColor Black -ForegroundColor Green "🚀 4.🎤🎵🎧 Audio (WAV) 🎸🎸"
    Write-Host "`n"
    $outputChoice = Read-Host "`n`tIngresa el número de tu opción preferida [1-4]"

    $ffmpegParams = @() # Array para almacenar los parámetros separados de FFmpeg
    $finalVideoCodec = ""
    $finalAudioCodec = ""
    $extension = ""
    $isAudioOnly = $false

    # Añadimos -hwaccel y -hwaccel_output_format si hay soporte CUDA/NVENC
    if ($hardwareAccelerators -contains "nvenc") {
        $ffmpegParams += @("-hwaccel", "cuda")
        $ffmpegParams += @("-hwaccel_output_format", "cuda")
    }

    switch ($outputChoice) {
        "1" { # Video (MP4 - H.264)
            $extension = "mp4"
            if ($hardwareAccelerators -contains "nvenc") {
                $finalVideoCodec = "h264_nvenc"
                Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Se usará H.264 con aceleración NVIDIA NVENC."
            } else {
                $finalVideoCodec = "libx264"
                Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Se usará H.264 por software (libx264)."
            }
            $finalAudioCodec = "aac" # Códec de audio común para MP4
            Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Formato de salida seleccionado: Video MP4."
        }
        "2" { # Video (WebM - VP9)
            $extension = "webm"
            # VP9 no suele tener aceleración de hardware tan extendida para codificación como H.264
            # Las GPU NVIDIA recientes SÍ soportan VP9 encoding (NVENC), pero libvpx-vp9 es más universal
            # Para simplificar por ahora, usaremos libvpx-vp9 (software) para WebM
            # Si en el futuro quieres añadir NVENC VP9, la flag es `-c:v vp9_nvenc`
            $finalVideoCodec = "libvpx-vp9"
            $finalAudioCodec = "libopus" # Códec de audio común para WebM
            Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Formato de salida seleccionado: Video WebM (VP9)."
        }
        "3" { # Audio (MP3)
            $extension = "mp3"
            $isAudioOnly = $true
            $finalAudioCodec = "libmp3lame" # Códec MP3
            Write-Host "  - ✅ Formato de salida seleccionado: Audio MP3."
            $ffmpegParams += @("-vn") # Deshabilitar video
        }
        "4" { # Audio (WAV)
            $extension = "wav"
            $isAudioOnly = $true
            $finalAudioCodec = "pcm_s16le" # Códec PCM para WAV (sin comprimir)
            Write-Host "  - ✅ Formato de salida seleccionado: Audio WAV."
            $ffmpegParams += @("-vn") # Deshabilitar video
        }
        default {
            Write-Error "🚨🚧🛑 Opción no válida. 🚦 Por favor, selecciona un número entre 1 y 4 🚨🚧🛑"
            exit 1
        }
    }

    # --- 4. Construir el comando FFmpeg ---

    # Archivo de entrada
    $ffmpegParams += @("-i", $InputFile)

    # Parámetros de video
    if (-not $isAudioOnly) {
        $ffmpegParams += @("-c:v", $finalVideoCodec)
        # Puedes añadir flags de calidad aquí si quieres, como -crf para libx264 o -preset para NVENC
        # Por ahora, los dejamos fuera para mantener la simplicidad, como pediste.
    }

    # Parámetros de audio
    if ($finalAudioCodec) { # Solo si se definió un códec de audio
        $ffmpegParams += @("-c:a", $finalAudioCodec)
        # También puedes añadir bitrate de audio si lo deseas, ej. -b:a 128k
    }

    # Definir el nombre del archivo de salida
    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
        $finalOutputFile = "$name`_converted.$extension"
        Write-Host "  - Nombre de archivo de salida automático: '$finalOutputFile'"
    } else {
        # Si el usuario especificó un nombre de archivo, asegúrate de que tenga la extensión correcta
        $specifiedExtension = [System.IO.Path]::GetExtension($OutputFile)
        if ([string]::IsNullOrEmpty($specifiedExtension) -or ($specifiedExtension -ne ".$extension")) {
            $finalOutputFile = "$OutputFile.$extension" # Añadir o corregir la extensión
            Write-Warning "  - 🚨🚧 La extensión del archivo de salida especificada no coincide con el  🚨🚧 `nformato elegido. Se usará: '$finalOutputFile'"
        } else {
            $finalOutputFile = $OutputFile
        }
        Write-Host "  - Usando nombre de archivo de salida especificado: '$finalOutputFile'"
    }

    # Añadir el archivo de salida
    $ffmpegParams += @($finalOutputFile)

    # --- 5. Ejecutar el Comando FFmpeg ---
    Write-Host "Iniciando conversión..."
    Write-Host "Comando FFmpeg a ejecutar: $ffmpegPath $($ffmpegParams -join ' ')"

    try {
        & $ffmpegPath $ffmpegParams
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 🚀¡Conversión completada exitosamente! Archivo: '$finalOutputFile'"
        } else {
            Write-Warning "⚠️🚨🚧🛑 FFmpeg finalizó con código de salida: $LASTEXITCODE. Puede haber habido errores. Revisa la salida de FFmpeg arriba."
        }
    } catch {
        Write-Error "⚠️🚨🚧🛑 Error al ejecutar FFmpeg: $($_.Exception.Message) 🚨🚧🛑"
    }
}
Convert-Media