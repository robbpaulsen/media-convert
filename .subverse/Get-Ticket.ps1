function Get-Ticket {
	<#
	.SYNOPSIS
		Usando el "Outfile" en `json` , configura el servicio que necesita
	.DESCRIPTION
        
	.OUTPUTS
    	PSCustomObject con propiedades: CPU, RAM, GPU y VRAM.
	.EXAMPLE
		PS> .\pull-urinfo.ps1 -Path 'Multimedia-File.flacc' -Output 'Multimedia-File-Output.json'
	.LINK
		https://github.com/robbpaulsen/media-convert
	.NOTES
    	Requiere FFmpeg y ffprobe en el PATH del sistema.
	.AUTHOR
		Robert Paulsen | License: MIT
	#>
}