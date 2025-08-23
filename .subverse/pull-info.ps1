param (
    [Parameter(Mandatory=$true, HelpMessage="Ruta completa al archivo de video de entrada.")]
    [string]$InputFilePath,
    [Parameter(Mandatory=$false, HelpMessage="Ruta completa para el archivo de salida JSON. Si no se especifica, se genera junto al archivo de entrada.")]
    [string]$OutputPath
)

function Get-HardwareInfo {
	<#
	.SYNOPSIS
		Obtiene información detallada del hardware (CPU, RAM, GPU) del sistema usando CIM.
	.DESCRIPTION
    	Este script de PowerShell analiza un archivo de video y el hardware del sistema.
    	El objetivo es generar un archivo JSON con todos los metadatos necesarios
    	para que un módulo posterior pueda construir comandos de FFmpeg optimizados.
	.OUTPUTS
    	PSCustomObject con propiedades: CPU, RAM, GPU y VRAM.
	.EXAMPLE
		PS> .\Pull-Info.ps1 -InputFilePath 'C:\ruta\a\tu\video.mp4' -OutputPath 'C:\ruta\a\tu\salida.json'
	.LINK
		https://github.com/robbpaulsen/media-convert
	.NOTES
    	Requiere FFmpeg y ffprobe en el PATH del sistema.
	.AUTHOR
		Robert Paulsen | License: MIT
	#>
	Write-Host "Analizando el hardware del sistema..." -ForegroundColor Green
    
    # 1. Obtener información de la CPU
    try {
        $cpuInfo = Get-CimInstance -ClassName Win32_Processor
        $cpu = [PSCustomObject]@{
            Name              = $cpuInfo.Name
            Manufacturer      = $cpuInfo.Manufacturer
            NumberOfCores     = $cpuInfo.NumberOfCores
            NumberOfThreads   = $cpuInfo.NumberOfLogicalProcessors
        }
    } catch {
        Write-Host "Error al obtener la información de la CPU. Detalle: $_" -ForegroundColor Red
        $cpu = "Desconocido"
    }

    # 2. Obtener información de la RAM
    try {
        $ramInfo = Get-CimInstance -ClassName Win32_PhysicalMemory
        $ramCapacity = [math]::Round(($ramInfo | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)
        $ramSpeed = ($ramInfo | Select-Object -First 1).Speed
        $ram = [PSCustomObject]@{
            TotalCapacityGB = $ramCapacity
            SpeedMHz        = $ramSpeed
        }
    } catch {
        Write-Host "Error al obtener la información de la RAM. Detalle: $_" -ForegroundColor Red
        $ram = "Desconocido"
    }

    # 3. Obtener información de la GPU
    try {
        $gpuInfo = Get-CimInstance -ClassName Win32_VideoController
        $gpuName = $gpuInfo.Name
        # Convertir VRAM de bytes a GB
        $vramGB = [math]::Round($gpuInfo.AdapterRAM / 1GB, 2)
        
        $gpu = [PSCustomObject]@{
            Name    = $gpuName
            VRAM_GB = $vramGB
        }
    } catch {
        Write-Host "Error al obtener la información de la GPU. Detalle: $_" -ForegroundColor Red
        $gpu = "Desconocido"
    }

    # Crear y devolver un objeto principal con toda la info.
    $hardwareInfo = [PSCustomObject]@{
        CPU = $cpu
        RAM = $ram
        GPU = $gpu
    }

    Write-Host "Análisis de hardware completado." -ForegroundColor Green
    return $hardwareInfo
}

function Get-MediaInfo {
    <#
    .SYNOPSIS
        Analiza un archivo de video usando ffprobe y devuelve sus metadatos.
    .DESCRIPTION
        Ejecuta ffprobe en modo silencioso y formatea la salida como JSON.
        Esto es mucho más eficiente que usar ffmpeg para el análisis.
    .PARAMETER InputFile
        La ruta al archivo multimedia a analizar.
    .OUTPUTS
        PSCustomObject con metadatos del archivo.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$InputFile
    )

    Write-Host "Analizando el archivo de entrada: '$InputFile'..." -ForegroundColor Green
    
    # Verificar si ffprobe está disponible
    if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
        Write-Host "Error: 'ffprobe' no se encontró. Asegúrate de que FFmpeg esté instalado y en el PATH." -ForegroundColor Red
        return $null
    }

    # Verificar si el archivo existe
    if (-not (Test-Path $InputFile)) {
        Write-Host "Error: El archivo no existe en la ruta especificada." -ForegroundColor Red
        return $null
    }
    
    try {
        # Comando para ffprobe
        $ffprobeArgs = @(
            '-v', 'quiet',
            '-print_format', 'json',
            '-show_format',
            '-show_streams',
            $InputFile
        )

        # Ejecutar ffprobe y capturar la salida JSON
        $ffprobeOutput = & ffprobe @ffprobeArgs | Out-String | ConvertFrom-Json

        # Reestructurar la salida para que sea más fácil de usar
        $mediaInfo = [PSCustomObject]@{
            FileName = $ffprobeOutput.format.filename
            DurationSeconds = [math]::Round([double]$ffprobeOutput.format.duration, 2)
            SizeMB = [math]::Round([double]$ffprobeOutput.format.size / 1MB, 2)
            Streams = $ffprobeOutput.streams
        }
    } catch {
        Write-Host "Error al analizar el archivo con ffprobe. Detalle: $_" -ForegroundColor Red
        return $null
    }

    Write-Host "Análisis de archivo completado." -ForegroundColor Green
    return $mediaInfo
}

# --- Lógica principal del script ---

# 1. Obtener la información del hardware
$hardwareData = Get-HardwareInfo

# 2. Obtener la información del archivo
$mediaData = Get-MediaInfo -InputFile $InputFilePath

# 3. Combinar ambos objetos en una sola estructura
if ($hardwareData -and $mediaData) {
    Write-Host "Combinando información y generando archivo de salida..." -ForegroundColor Green
    
    $combinedData = [PSCustomObject]@{
        HardwareInfo = $hardwareData
        MediaInfo = $mediaData
        GenerationDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        SourceFile = $InputFilePath
    }

    # Determinar la ruta de salida
    if (-not [string]::IsNullOrEmpty($OutputPath)) {
        $finalOutputPath = $OutputPath
    } else {
        $outputFileName = [System.IO.Path]::GetFileNameWithoutExtension($InputFilePath) + "_metadata.json"
        $finalOutputPath = Join-Path -Path (Split-Path $InputFilePath) -ChildPath $outputFileName
    }

    # Convertir el objeto a JSON y guardarlo en el archivo
    $combinedData | ConvertTo-Json -Depth 5 | Set-Content -Path $finalOutputPath

    Write-Host ""
    Write-Host "¡Operación completada con éxito!" -ForegroundColor Cyan
    Write-Host "El archivo de metadatos se ha guardado en: $finalOutputPath" -ForegroundColor Yellow
} else {
    Write-Host "No se pudo completar el proceso debido a errores anteriores." -ForegroundColor Red
}