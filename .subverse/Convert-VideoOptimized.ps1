function Convert-VideoOptimized {
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputFile,
        [Parameter(Mandatory=$false)]
        [string]$OutputFile = ""
    )

    # --- 1. Validar la existencia del archivo de entrada ---
    # Esta es una validación crítica que debe permanecer para un mensaje claro si el archivo no existe.
    if (-not (Test-Path $InputFile -PathType Leaf)) {
        Write-Error "El archivo de entrada no existe o no se puede acceder: '$InputFile'. Por favor, verifica la ruta y los permisos."
        exit 1
    }

    # Asumimos que ffmpeg está en el PATH, por lo que no necesitamos buscar su ruta explícitamente.
    # PowerShell lo encontrará automáticamente al ejecutar '& ffmpeg'.
    $ffmpegPath = "ffmpeg"

    # --- 2. Detección de Hardware y Codificadores Disponibles ---
    Write-Host "Realizando detección de hardware para FFmpeg..."

    $hardwareAccelerators = @()
    # Redirigir la salida de error a la salida estándar para capturar toda la información
    $encodersInfo = & $ffmpegPath -encoders 2>&1 | Out-String
    $decodersInfo = & $ffmpegPath -decoders 2>&1 | Out-String

    # Detectar NVIDIA NVENC
    # Mantengo esta verificación, pero la simplifico y elimino la dependencia de nvidia-smi.exe
    # Solo confiaremos en lo que FFmpeg nos reporta de sus codificadores.
    if ($encodersInfo -match "h264_nvenc") {
        Write-Host "  - NVIDIA GPU detectada (NVENC)."
        $hardwareAccelerators += "nvenc"
    }

    # Las detecciones de QSV y AMF se mantienen solo para informar, no para la selección automática
    if ($encodersInfo -match "h264_qsv" -or $encodersInfo -match "hevc_qsv") {
        Write-Host "  - Intel Quick Sync Video (QSV) detectado."
        $hardwareAccelerators += "qsv"
    }
    if ($encodersInfo -match "h264_amf" -or $encodersInfo -match "hevc_amf") {
        Write-Host "  - AMD AMF detectado."
        $hardwareAccelerators += "amf"
    }

    # Detección de soporte CUDA/NVDEC para decodificación
    if ($decodersInfo -match "cuda" -or $decodersInfo -match "cuvid") {
        Write-Host "  - Soporte general CUDA/NVDEC detectado."
        $hardwareAccelerators += "cuda_decode"
    }

    # --- 3. Determinar los Parámetros de Codificación (simplificado al máximo) ---
    $ffmpegParams = @()
    $finalVideoCodec = "libx264" # Por defecto, software

    if ($hardwareAccelerators -contains "nvenc") {
        $finalVideoCodec = "h264_nvenc"
        # Añadimos -hwaccel y -hwaccel_output_format como elementos separados al array
        $ffmpegParams += @("-hwaccel", "cuda")
        $ffmpegParams += @("-hwaccel_output_format", "cuda")
        Write-Host "  - Seleccionando codificación por hardware (NVIDIA NVENC)."
    } else {
        Write-Host "  - No se detectó hardware de codificación dedicado (NVENC). Usando codificación por software (libx264)."
    }

    # --- Construir el resto del comando FFmpeg ---
    # **IMPORTANTE:** Pasamos las rutas sin comillas adicionales. PowerShell las manejará si hay espacios.
    $ffmpegParams += @("-i", $InputFile) # Archivo de entrada

    $ffmpegParams += @("-c:v", $finalVideoCodec) # Códec de video

    # Definir el nombre del archivo de salida
    if ([string]::IsNullOrWhiteSpace($OutputFile)) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($InputFile)
        $extension = "mov" # Tu extensión preferida
        if ($finalVideoCodec -eq "libx264") {
            $extension = "mp4" # Común para software
        }
        $finalOutputFile = "$name`_converted.$extension"
        Write-Host "  - Nombre de archivo de salida automático: '$finalOutputFile'"
    } else {
        $finalOutputFile = $OutputFile
        Write-Host "  - Usando nombre de archivo de salida especificado: '$finalOutputFile'"
    }

    # **IMPORTANTE:** Pasamos la ruta de salida sin comillas adicionales.
    $ffmpegParams += @($finalOutputFile)

    # --- 4. Ejecutar el Comando FFmpeg ---
    Write-Host "Iniciando conversión..."
    Write-Host "Comando FFmpeg a ejecutar: $ffmpegPath $($ffmpegParams -join ' ')"

    try {
        # Ejecutar FFmpeg
        & $ffmpegPath $ffmpegParams
        if ($LASTEXITCODE -eq 0) {
            Write-Host "¡Conversión completada exitosamente! Archivo: '$finalOutputFile'"
        } else {
            Write-Warning "FFmpeg finalizó con código de salida: $LASTEXITCODE. Puede haber habido errores. Revisa la salida de FFmpeg arriba."
        }
    } catch {
        Write-Error "Error al ejecutar FFmpeg: $($_.Exception.Message)"
    }
}

Convert-VideoOptimized