<#
.SYNOPSIS
    Convierte archivos de video y audio a diferentes formatos, utilizando aceleración por hardware si está disponible.
.DESCRIPTION
    Este script utiliza FFmpeg para convertir archivos multimedia. Puede funcionar de forma interactiva (mostrando un menú) o de forma no interactiva a través de parámetros.
    Detecta hardware NVIDIA (NVENC) para acelerar la codificación y decodificación de video, mejorando significativamente el rendimiento.
.PARAMETER Path
    La ruta completa al archivo de entrada que se desea convertir. Este parámetro es obligatorio.
.PARAMETER Type
    El formato de salida deseado. Valores permitidos: mp4, webm, mp3, wav. Si no se especifica, el script mostrará un menú interactivo para elegir el formato.
.PARAMETER Destination
    La ruta de destino. Puede ser una carpeta (donde se guardará el archivo con un nombre autogenerado) o una ruta de archivo completa. Si no se especifica, el archivo convertido se guardará en la misma carpeta que el original.
.EXAMPLE
    # Modo interactivo (mostrará un menú)
    .\Convert-Media.ps1 -Path "C:\Videos\mi_video.mkv"
.EXAMPLE
    # Modo no interactivo: convertir a MP4 con aceleración de hardware
    .\Convert-Media.ps1 -Path "C:\Peliculas\video con espacios.mkv" -Type mp4
.EXAMPLE
    # Convertir a MP3 y guardarlo en una carpeta específica
    .\Convert-Media.ps1 -Path "C:\Musica\entrevista.wav" -Type mp3 -Destination "C:\Audio Convertido\"
.EXAMPLE
    # Convertir a WebM y especificar el nombre y la ruta del archivo de salida
    .\Convert-Media.ps1 -Path "C:\Clips\gameplay.mp4" -Type webm -Destination "C:\Web\videos\gameplay_final.webm"
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param (
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Ruta al archivo de video o audio a convertir.")]
    [Alias("InputFile")]
    [string]$Path,

    [Parameter(Mandatory=$false, HelpMessage="Formato de salida deseado (mp4, webm, mp3, wav). Si no se especifica, se mostrará un menú interactivo.")]
    [ValidateSet("mp4", "webm", "mp3", "wav")]
    [string]$Type,

    [Parameter(Mandatory=$false, HelpMessage="Ruta de destino (carpeta o archivo). Si no se especifica, se guarda junto al original.")]
    [Alias("OutputFile")]
    [string]$Destination = ""
)

# --- 1. Validar la existencia del archivo de entrada ---
if (-not (Test-Path $Path -PathType Leaf)) {
    Write-Error "`n⚠️🚨🚧 El archivo de entrada no existe o no se puede acceder: '$Path'. `nPor favor, verifica la ruta y los permisos. 🚨🚧"
    exit 1
}

# Asumimos que ffmpeg y ffprobe están en el PATH
$ffmpegPath = "ffmpeg"
$ffprobePath = "ffprobe"

# --- 1.5. Detectar el códec del video de entrada ---
Write-Host "`n🕵️  Detectando códec del video de entrada..."
$inputVideoCodec = ""
try {
    # Obtener el nombre del códec del primer stream de video
    $inputVideoCodec = & $ffprobePath -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $Path
    if (-not [string]::IsNullOrWhiteSpace($inputVideoCodec)) {
        Write-Host "  - Códec de video detectado: '$inputVideoCodec'"
    } else {
        Write-Host "  - No se encontró un stream de video o no se pudo determinar el códec. Se procederá sin decodificación por hardware."
    }
} catch {
    Write-Warning "  - ⚠️ No se pudo ejecutar ffprobe para detectar el códec. Se continuará sin decodificación por hardware. Error: $($_.Exception.Message)"
}

# --- 2. Detección de Hardware y Codificadores/Decodificadores Disponibles ---
Write-Host "`n⏳ Realizando detección de hardware para FFmpeg..."

$hardwareAccelerators = @()
$encodersInfo = & $ffmpegPath -encoders 2>&1 | Out-String
$decodersInfo = & $ffmpegPath -decoders 2>&1 | Out-String

# Definir una lista de verificaciones para hacer el código más mantenible y legible
$detectionChecks = @(
    [PSCustomObject]@{ Name = "nvenc";       Pattern = "h264_nvenc";        Message = "  - NVIDIA GPU detectada (NVENC).";            ForegroundColor = "Green"; SourceString = $encodersInfo },
    [PSCustomObject]@{ Name = "qsv";         Pattern = "h264_qsv|hevc_qsv"; Message = "  - Intel Quick Sync Video (QSV) detectado."; ForegroundColor = "Blue";  SourceString = $encodersInfo },
    [PSCustomObject]@{ Name = "amf";         Pattern = "h264_amf|hevc_amf"; Message = "  - AMD AMF detectado.";                     ForegroundColor = "Red";   SourceString = $encodersInfo },
    [PSCustomObject]@{ Name = "cuda_decode"; Pattern = "cuda|cuvid";        Message = "  - Soporte general CUDA/NVDEC detectado.";    ForegroundColor = "Green"; SourceString = $decodersInfo }
)

# Iterar sobre las verificaciones y ejecutar la lógica
foreach ($check in $detectionChecks) {
    if ($check.SourceString -match $check.Pattern) {
        Write-Host -BackgroundColor Black -ForegroundColor $check.ForegroundColor $check.Message
        $hardwareAccelerators += $check.Name
    }
}

# --- 3. Determinar el formato de salida (Interactivo o por Parámetro) ---
$outputType = ""
if ($PSBoundParameters.ContainsKey('Type')) {
    $outputType = $Type
    Write-Host "`n✅ Modo no interactivo. Formato de salida especificado: '$outputType'"
} else {
    Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "`n[ 🛸 ¿Qué tipo de salida deseas generar? 🛰 ]"
    Write-Host "`n"
    Write-Host -BackgroundColor Black -ForegroundColor Green "🚀 1.🎬 Video (MP4 - H.264) 📽"
    Write-Host -BackgroundColor Black -ForegroundColor Green "🚀 2.📺 Video (WebM - VP9) 📽"
    Write-Host -BackgroundColor Black -ForegroundColor Green "🚀 3.🎵🎧 Audio (MP3) 🎸"
    Write-Host -BackgroundColor Black -ForegroundColor Green "🚀 4.🎵🎧 Audio (WAV) 🎸"
    $menuChoice = Read-Host "`n`tIngresa el número de tu opción preferida [1-4]"
    switch ($menuChoice) {
        "1" { $outputType = "mp4" }
        "2" { $outputType = "webm" }
        "3" { $outputType = "mp3" }
        "4" { $outputType = "wav" }
        default {
            Write-Error "🚨🚧🛑 Opción no válida. 🚦 Por favor, selecciona un número entre 1 y 4 🚨🚧🛑"
            exit 1
        }
    }
}

$ffmpegDecoderParams = @() # Parámetros que van ANTES de -i (decodificadores)
$ffmpegEncoderParams = @() # Parámetros que van DESPUÉS de -i (codificadores, filtros, etc.)
$finalVideoCodec = ""
$finalAudioCodec = ""
$extension = ""
$isAudioOnly = $false

switch ($outputType) {
    "mp4" {
        $extension = "mp4"
        if ($hardwareAccelerators -contains "nvenc") {
            $cuvidDecoders = @{ "h264"="h264_cuvid"; "hevc"="hevc_cuvid"; "vp9"="vp9_cuvid"; "vp8"="vp8_cuvid"; "mpeg2video"="mpeg2_cuvid"; "mpeg4"="mpeg4_cuvid"; "vc1"="vc1_cuvid"; "av1"="av1_cuvid" }
            if ($cuvidDecoders.ContainsKey($inputVideoCodec)) {
                $decoder = $cuvidDecoders[$inputVideoCodec]
                Write-Host "  - ✅ Usando decodificador por hardware NVIDIA: '$decoder'"
                $ffmpegDecoderParams += @("-c:v", $decoder)
            } else {
                Write-Host "  - ℹ️ El códec de entrada '$inputVideoCodec' no tiene un decodificador CUVID soportado. Se usará decodificación por software."
            }

            $finalVideoCodec = "h264_nvenc"
            Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Se usará codificador por hardware H.264 con NVIDIA NVENC."

            # Preguntar por el preset de velocidad/calidad para NVENC
            Write-Host "`n`t⚡️ Se detectó NVIDIA NVENC. Elige un preajuste de codificación:"
            Write-Host "`t1. Mejor Calidad (más lento, preset p7)"
            Write-Host "`t2. Balanceado (predeterminado, preset p4)"
            Write-Host "`t3. Máxima Velocidad (calidad más baja, preset p1)"
            $presetChoice = Read-Host "`n`tIngresa tu opción [1-3, Enter para Balanceado]"

            $nvencPreset = "p4" # Predeterminado
            switch ($presetChoice) {
                "1" { $nvencPreset = "p7" }
                "2" { $nvencPreset = "p4" }
                "3" { $nvencPreset = "p1" }
                default { Write-Host "  - Opción no válida, se usará 'Balanceado'." }
            }
            $ffmpegEncoderParams += @("-preset", $nvencPreset)
            Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Usando preajuste NVENC: '$nvencPreset'."

        } else {
            $finalVideoCodec = "libx264"
            Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Se usará H.264 por software (libx264)."
        }
        $finalAudioCodec = "aac"
        Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Formato de salida seleccionado: Video MP4."
    }
    "webm" {
        $extension = "webm"
        $finalVideoCodec = "libvpx-vp9"
        $finalAudioCodec = "libopus"
        Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Formato de salida seleccionado: Video WebM (VP9)."
    }
    "mp3" {
        $extension = "mp3"
        $isAudioOnly = $true
        $finalAudioCodec = "libmp3lame"
        Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Formato de salida seleccionado: Audio MP3."
        $ffmpegEncoderParams += @("-vn")
    }
    "wav" {
        $extension = "wav"
        $isAudioOnly = $true
        $finalAudioCodec = "pcm_s16le"
        Write-Host -BackgroundColor Green -ForegroundColor DarkBlue "  - ✅ Formato de salida seleccionado: Audio WAV."
        $ffmpegEncoderParams += @("-vn")
    }
}

# --- 4. Construir el comando FFmpeg ---

$ffmpegParams = $ffmpegDecoderParams
$ffmpegParams += @("-i", $Path)
$ffmpegParams += $ffmpegEncoderParams

if (-not $isAudioOnly) {
    $ffmpegParams += @("-c:v", $finalVideoCodec)
}
if ($finalAudioCodec) {
    $ffmpegParams += @("-c:a", $finalAudioCodec)
}

# Definir el nombre del archivo de salida de forma robusta
$finalOutputFile = ""
if ([string]::IsNullOrWhiteSpace($Destination)) {
    # Caso 1: No se especificó destino. Guardar junto al archivo original.
    $inputDirectory = [System.IO.Path]::GetDirectoryName($Path)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $finalOutputFile = [System.IO.Path]::Combine($inputDirectory, "$name`_converted.$extension")
    Write-Host "  - No se especificó destino. Archivo de salida autogenerado: '$finalOutputFile'"
} elseif (Test-Path $Destination -PathType Container) {
    # Caso 2: El destino es una carpeta existente.
    $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $finalOutputFile = [System.IO.Path]::Combine($Destination, "$name`_converted.$extension")
    Write-Host "  - Destino es una carpeta. Archivo de salida autogenerado: '$finalOutputFile'"
} else {
    # Caso 3: El destino es una ruta de archivo completa.
    $finalOutputFile = $Destination
    $specifiedExtension = [System.IO.Path]::GetExtension($finalOutputFile)
    if ($specifiedExtension -ne ".$extension") {
        $finalOutputFile = [System.IO.Path]::ChangeExtension($finalOutputFile, $extension)
        Write-Warning "  - La extensión del destino no coincide con el tipo '$Type'. Se ha corregido a: '$finalOutputFile'"
    }
    Write-Host "  - Usando ruta de destino especificada: '$finalOutputFile'"
}

$ffmpegParams += @($finalOutputFile)
$fullCommand = @($ffmpegPath) + $ffmpegParams

# --- 5. Ejecutar el Comando FFmpeg ---
Write-Host "`nIniciando conversión..."
Write-Host "Comando FFmpeg a ejecutar: $($fullCommand -join ' ')"

if ($PSCmdlet.ShouldProcess($Path, "Convertir a formato '$extension' en '$finalOutputFile'")) {
    try {
        & $ffmpegPath $ffmpegParams
        if ($LASTEXITCODE -eq 0) {
            Write-Host -BackgroundColor Green -ForegroundColor Black "✅ 🚀¡Conversión completada exitosamente! Archivo: '$finalOutputFile'"
        } else {
            Write-Warning "⚠️🚨🚧🛑 FFmpeg finalizó con código de salida: $LASTEXITCODE. Puede haber habido errores. Revisa la salida de FFmpeg arriba."
        }
    } catch {
        Write-Error "⚠️🚨🚧🛑 Error al ejecutar FFmpeg: $($_.Exception.Message) 🚨🚧🛑"
    }
}
