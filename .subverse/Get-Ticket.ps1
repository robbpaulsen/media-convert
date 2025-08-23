<#
.SYNOPSIS
    Usando el archivo de metadatos JSON, este script presenta al usuario
    un menú de operaciones de medios para generar un "ticket" de procesamiento.
.DESCRIPTION
    Este script es la segunda etapa del flujo de trabajo. Carga el archivo JSON
    creado por Pull-Info.ps1, y pregunta al usuario qué acción realizar sobre
    el archivo multimedia original.
.PARAMETER InputJsonPath
    Ruta al archivo JSON de metadatos generado en la Etapa 1.
.OUTPUTS
    Un objeto PowerShell (ticket) que describe la tarea a realizar.
.EXAMPLE
    PS> .\Get-Ticket.ps1 -InputJsonPath 'C:\ruta\a\tu\video_metadata.json'
.LINK
    https://github.com/robbpaulsen/media-convert
.NOTES
    Requiere FFmpeg y ffprobe en el PATH del sistema.
.AUTHOR
    Robert Paulsen | License: MIT
#>

param (
    [Parameter(Mandatory=$true, HelpMessage="Ruta al archivo JSON de metadatos.")]
    [string]$InputJsonPath
)

# --- Validación de entrada ---
if (-not (Test-Path $InputJsonPath)) {
    Write-Host "Error: El archivo JSON especificado no existe en la ruta: $InputJsonPath" -ForegroundColor Red
    return # Termina el script si el archivo no existe.
}

# --- Cargar y mostrar información del ticket ---
try {
    $metadata = Get-Content $InputJsonPath | ConvertFrom-Json
    Write-Host "Ticket de procesamiento para:" -ForegroundColor Cyan
    Write-Host "Archivo: $($metadata.SourceFile)"
    Write-Host "Fecha de análisis: $($metadata.GenerationDate)"
    Write-Host "---"
} catch {
    Write-Host "Error al leer o procesar el archivo JSON. Verifica que el formato sea correcto." -ForegroundColor Red
    Write-Host "Detalle del error: $_" -ForegroundColor Red
    return
}


# --- Menú de Interacción con el Usuario ---
Write-Host "Por favor, elige la operación que deseas realizar:" -ForegroundColor Green
Write-Host "1. Convertir formato (ej. MP4 a MKV, JPG a PNG)"
Write-Host "2. Limpieza de Audio (ej. Reducir ruido, Normalizar volumen)"
Write-Host "3. Upscaling (Aumentar resolución de video o imagen)"
Write-Host "4. Generar Thumbnails (crear vistas previas de un video)"
Write-Host "Q. Salir"
Write-Host ""

# --- Bucle para obtener una opción válida ---
$validChoice = $false
while (-not $validChoice) {
    $choice = Read-Host "Introduce el número de tu elección y presiona Enter"

    switch ($choice) {
        "1" {
            Write-Host "Has elegido: 1. Convertir formato" -ForegroundColor Yellow
            # Aquí irá la lógica para la conversión
            $validChoice = $true
        }
        "2" {
            Write-Host "Has elegido: 2. Limpieza de Audio" -ForegroundColor Yellow
            # Aquí irá la lógica para la limpieza de audio
            $validChoice = $true
        }
        "3" {
            Write-Host "Has elegido: 3. Upscaling" -ForegroundColor Yellow
            # Aquí irá la lógica para el upscaling
            $validChoice = $true
        }
        "4" {
            Write-Host "Has elegido: 4. Generar Thumbnails" -ForegroundColor Yellow
            # Aquí irá la lógica para generar thumbnails
            $validChoice = $true
        }
        "Q" {
            Write-Host "Saliendo del script." -ForegroundColor Magenta
            return # Sale del script
        }
        default {
            Write-Host "Opción no válida. Por favor, introduce un número del 1 al 4, o Q para salir." -ForegroundColor Red
        }
    }
}

# En futuras versiones, aquí se creará y devolverá el "ticket" con la tarea seleccionada.
Write-Host "--- Fin de la Etapa 2 (interacción) ---" -ForegroundColor Cyan