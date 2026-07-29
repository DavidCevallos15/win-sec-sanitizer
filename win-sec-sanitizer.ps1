# ==============================================================================
# Script Name: win-sec-sanitizer.ps1
# Description: Universal PowerShell Host Hygiene & DevSecOps Automated Cleanup Tool
#              with Detailed System Audit Report Generation (.txt + Console)
# License: MIT
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Directorio objetivo a higienizar. Por defecto detecta automaticamente el perfil del usuario actual.")]
    [string]$TargetDirectory = $env:USERPROFILE,

    [Parameter(Mandatory = $false, HelpMessage = "Indica si se exportara el informe a un archivo .txt")]
    [bool]$ExportReport = $true
)

$StartTime = Get-Date

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host " [+] WIN-SEC-SANITIZER - DevSecOps Host Hygiene & Storage Tool   " -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "[i] Directorio objetivo: $TargetDirectory`n" -ForegroundColor Gray

# Verificar si el directorio existe
if (-not (Test-Path -Path $TargetDirectory)) {
    Write-Host "[ERROR] El directorio '$TargetDirectory' no existe." -ForegroundColor Red
    exit 1
}

# Obtener Informacion del Sistema Operativo y Hardware
$OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
$ComputerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue

$HostnameStr = $env:COMPUTERNAME
$UsernameStr = $env:USERNAME
$OSNameStr = $OSInfo.Caption
$OSArchStr = $OSInfo.OSArchitecture
$OSVerStr = $OSInfo.Version
$TotalRamNum = [math]::Round($ComputerInfo.TotalPhysicalMemory / 1GB, 2)
$FreeRamNum = [math]::Round($OSInfo.FreePhysicalMemory / 1MB, 2)
$ExecTimeStr = $StartTime.ToString("yyyy-MM-dd HH:mm:ss")

$OrganizedDirectory = Join-Path -Path $TargetDirectory -ChildPath "Organizado"
$ReportDirectory = Join-Path -Path $OrganizedDirectory -ChildPath "Reportes"

# Estructuras de recopilacion de metricas
$DeletedFilesList = [System.Collections.Generic.List[string]]::new()
$TotalBytesFreed = 0

$SecurityAlertsList = [System.Collections.Generic.List[string]]::new()

$OrganizedDocsCount = 0
$OrganizedImgCount = 0
$OrganizedVidCount = 0

$DuplicatesFoundList = [System.Collections.Generic.List[string]]::new()
$DuplicateTotalBytes = 0

$AntivirusStatus = "No ejecutado"

# ==============================================================================
# 1. ELIMINAR ARCHIVOS BASURA Y TEMPORALES
# ==============================================================================
Write-Host "[+] Fase 1: Buscando y eliminando archivos basura..." -ForegroundColor Yellow

$JunkExtensions = @("*.tmp", "*.log", "*.bak", "*.old")
$JunkFiles = Get-ChildItem -Path $TargetDirectory -Recurse -Include $JunkExtensions -ErrorAction SilentlyContinue

foreach ($file in $JunkFiles) {
    try {
        $fileSize = $file.Length
        $filePath = $file.FullName
        Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
        $TotalBytesFreed += $fileSize
        $fileSizeKB = [math]::Round($fileSize / 1KB, 2)
        $DeletedFilesList.Add("$filePath ($fileSizeKB KB)")
        Write-Host "  [OK] Eliminado: $filePath" -ForegroundColor DarkGray
    }
    catch {
        Write-Host "  [!] No se pudo eliminar: $($file.FullName)" -ForegroundColor DarkYellow
    }
}
$TotalMBFreed = [math]::Round($TotalBytesFreed / 1MB, 2)
$deletedCount = $DeletedFilesList.Count
Write-Host "[OK] Fase 1 completada: $deletedCount archivos residuales eliminados ($TotalMBFreed MB liberados).`n" -ForegroundColor Green

# ==============================================================================
# 2. AUDITORIA DE SEGURIDAD (ARCHIVOS SOSPECHOSOS)
# ==============================================================================
Write-Host "[+] Fase 2: Auditando ejecutables y scripts en zonas de riesgo..." -ForegroundColor Yellow

$ScriptExtensions = @("*.exe", "*.bat", "*.cmd", "*.ps1", "*.vbs")
$SuspiciousFiles = Get-ChildItem -Path $TargetDirectory -Recurse -Include $ScriptExtensions -ErrorAction SilentlyContinue

foreach ($file in $SuspiciousFiles) {
    $filePath = $file.FullName
    if ($filePath -like "*Downloads*" -or $filePath -like "*Temp*") {
        $fileExt = $file.Extension
        $SecurityAlertsList.Add("$filePath (Extension: $fileExt)")
        Write-Host "  [ALERTA DE SEGURIDAD] Revisar ejecutable en zona de riesgo: $filePath" -ForegroundColor Red
    }
}
if ($SecurityAlertsList.Count -eq 0) {
    Write-Host "  [OK] No se detectaron ejecutables sospechosos en areas de riesgo." -ForegroundColor DarkGray
}
$alertCount = $SecurityAlertsList.Count
Write-Host "[OK] Fase 2 completada: $alertCount alertas de seguridad registradas.`n" -ForegroundColor Green

# ==============================================================================
# 3. CREAR ESTRUCTURA ORGANIZADA DE DIRECTORIOS
# ==============================================================================
Write-Host "[+] Fase 3: Creando estructura jerarquica de carpetas..." -ForegroundColor Yellow

$SubFolders = @(
    (Join-Path -Path $OrganizedDirectory -ChildPath "Documentos"),
    (Join-Path -Path $OrganizedDirectory -ChildPath "Imagenes"),
    (Join-Path -Path $OrganizedDirectory -ChildPath "Videos"),
    (Join-Path -Path $OrganizedDirectory -ChildPath "Otros"),
    $ReportDirectory
)

foreach ($folder in $SubFolders) {
    if (-not (Test-Path -Path $folder)) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        Write-Host "  [+] Carpeta creada: $folder" -ForegroundColor DarkGray
    }
}
Write-Host "[OK] Fase 3 completada: Estructura de directorios lista.`n" -ForegroundColor Green

# ==============================================================================
# 4. ORGANIZAR ARCHIVOS SEGUN EXTENSION
# ==============================================================================
Write-Host "[+] Fase 4: Clasificando y organizando archivos sueltos..." -ForegroundColor Yellow

$FileCategoryMap = @{
    "Documentos" = @("*.pdf", "*.docx", "*.doc", "*.txt", "*.xlsx", "*.pptx")
    "Imagenes"   = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.svg", "*.webp")
    "Videos"     = @("*.mp4", "*.mkv", "*.avi", "*.mov")
}

foreach ($category in $FileCategoryMap.Keys) {
    $targetCategoryPath = Join-Path -Path $OrganizedDirectory -ChildPath $category
    foreach ($extension in $FileCategoryMap[$category]) {
        $filesToMove = Get-ChildItem -Path "$TargetDirectory\$extension" -ErrorAction SilentlyContinue
        foreach ($file in $filesToMove) {
            try {
                $fileName = $file.Name
                Move-Item -Path $file.FullName -Destination $targetCategoryPath -Force -ErrorAction SilentlyContinue
                if ($category -eq "Documentos") { $OrganizedDocsCount++ }
                elseif ($category -eq "Imagenes") { $OrganizedImgCount++ }
                elseif ($category -eq "Videos") { $OrganizedVidCount++ }
                Write-Host "  [->] Movido a ${category}: $fileName" -ForegroundColor DarkGray
            }
            catch {
                Write-Host "  [!] Error al mover: $($file.Name)" -ForegroundColor DarkYellow
            }
        }
    }
}
Write-Host "[OK] Fase 4 completada: Clasificacion finalizada.`n" -ForegroundColor Green

# ==============================================================================
# 5. DETECTAR ARCHIVOS DUPLICADOS POR TAMAÑO
# ==============================================================================
Write-Host "[+] Fase 5: Escaneando archivos duplicados por tamaño..." -ForegroundColor Yellow

$DuplicateGroups = Get-ChildItem -Path $TargetDirectory -Recurse -File -ErrorAction SilentlyContinue |
    Group-Object -Property Length |
    Where-Object { $_.Count -gt 1 }

foreach ($group in $DuplicateGroups) {
    $groupSize = $group.Name
    $groupCount = $group.Count
    $DuplicateTotalBytes += ($groupSize * ($groupCount - 1))
    $sizeKB = [math]::Round($groupSize / 1KB, 2)
    $DuplicateEntry = "Tamaño: $sizeKB KB (Archivos: $groupCount)"
    foreach ($item in $group.Group) {
        $DuplicateEntry += "`n      - $($item.FullName)"
    }
    $DuplicatesFoundList.Add($DuplicateEntry)
    Write-Host "  [i] Posibles duplicados ($sizeKB KB):" -ForegroundColor Cyan
    foreach ($item in $group.Group) {
        Write-Host "      - $($item.FullName)" -ForegroundColor DarkGray
    }
}
if ($DuplicatesFoundList.Count -eq 0) {
    Write-Host "  [OK] No se encontraron archivos duplicados por tamaño." -ForegroundColor DarkGray
}
$DuplicateMBWasted = [math]::Round($DuplicateTotalBytes / 1MB, 2)
$duplicateGroupCount = $DuplicatesFoundList.Count
Write-Host "[OK] Fase 5 completada: $duplicateGroupCount grupos de duplicados ($DuplicateMBWasted MB redundantes).`n" -ForegroundColor Green

# ==============================================================================
# 6. ESCANEO ANTIMALWARE CON WINDOWS DEFENDER
# ==============================================================================
Write-Host "[+] Fase 6: Iniciando escaneo antimalware con Windows Defender..." -ForegroundColor Yellow

try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        Write-Host "  [i] Permisos de Administrador confirmados. Iniciando FullScan..." -ForegroundColor Cyan
        Start-MpScan -ScanType FullScan
        $AntivirusStatus = "FullScan de Windows Defender ejecutado correctamente"
        Write-Host "[OK] Escaneo de Windows Defender iniciado correctamente." -ForegroundColor Green
    }
    else {
        $AntivirusStatus = "Omitido (Se requieren permisos de Administrador)"
        Write-Host "  [AVISO] Para ejecutar Start-MpScan se requieren permisos de Administrador." -ForegroundColor Red
    }
}
catch {
    $AntivirusStatus = "Error de ejecucion: $_"
    Write-Host "  [!] No se pudo iniciar Windows Defender: $_" -ForegroundColor Red
}

$EndTime = Get-Date
$Duration = $EndTime - $StartTime
$DurationFormatted = "{0:D2}m:{1:D2}s" -f $Duration.Minutes, $Duration.Seconds

# ==============================================================================
# 7. GENERACIÓN DEL INFORME DETALLADO (CONSOLA + ARCHIVO .TXT)
# ==============================================================================

$ReportFileName = "sec-sanitizer-report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$ReportFilePath = Join-Path -Path $ReportDirectory -ChildPath $ReportFileName

$ReportLines = [System.Collections.Generic.List[string]]::new()

$ReportLines.Add("================================================================================")
$ReportLines.Add("            WIN-SEC-SANITIZER - INFORME DETALLADO DE HIGIENIZACION")
$ReportLines.Add("================================================================================")
$ReportLines.Add("")
$ReportLines.Add("1. INFORMACION GENERAL DEL SISTEMA Y EJECUCION")
$ReportLines.Add("--------------------------------------------------------------------------------")
$ReportLines.Add("Fecha y Hora de Inicio: $ExecTimeStr")
$ReportLines.Add("Tiempo de Procesamiento: $DurationFormatted")
$ReportLines.Add("Nombre de la Computadora: $HostnameStr")
$ReportLines.Add("Usuario Activo:         $UsernameStr")
$ReportLines.Add("Sistema Operativo:     $OSNameStr ($OSArchStr)")
$ReportLines.Add("Version del SO:         $OSVerStr")
$ReportLines.Add("Memoria RAM Total:      $TotalRamNum GB")
$ReportLines.Add("Memoria RAM Libre:      $FreeRamNum GB")
$ReportLines.Add("Directorio Escaneado:   $TargetDirectory")
$ReportLines.Add("")
$ReportLines.Add("2. RESUMEN DE METRICAS Y OPTIMIZACION")
$ReportLines.Add("--------------------------------------------------------------------------------")
$ReportLines.Add("Archivos Basura Eliminados:     $deletedCount")
$ReportLines.Add("Espacio Recuperado en Disco:    $TotalMBFreed MB")
$ReportLines.Add("Alertas de Seguridad:          $alertCount")
$ReportLines.Add("Archivos Organizados (Docs):   $OrganizedDocsCount")
$ReportLines.Add("Archivos Organizados (Fotos):  $OrganizedImgCount")
$ReportLines.Add("Archivos Organizados (Videos): $OrganizedVidCount")
$ReportLines.Add("Grupos Duplicados Hallados:    $duplicateGroupCount")
$ReportLines.Add("Espacio Redundante Estimado:   $DuplicateMBWasted MB")
$ReportLines.Add("Estado de Antivirus (Defender): $AntivirusStatus")
$ReportLines.Add("")
$ReportLines.Add("3. DETALLE DE ARCHIVOS ELIMINADOS (LIMPIEZA DE RESIDUOS)")
$ReportLines.Add("--------------------------------------------------------------------------------")

if ($DeletedFilesList.Count -gt 0) {
    foreach ($item in $DeletedFilesList) {
        $ReportLines.Add("- $item")
    }
} else {
    $ReportLines.Add("No se encontraron archivos residuo (.tmp, .log, .bak, .old).")
}

$ReportLines.Add("")
$ReportLines.Add("4. AUDITORIA DE SEGURIDAD (EJECUTABLES EN CARPETAS DE RIESGO)")
$ReportLines.Add("--------------------------------------------------------------------------------")

if ($SecurityAlertsList.Count -gt 0) {
    foreach ($alert in $SecurityAlertsList) {
        $ReportLines.Add("[RIESGO] $alert")
    }
} else {
    $ReportLines.Add("No se detectaron archivos ejecutables (.exe, .bat, .ps1) en Downloads o Temp.")
}

$ReportLines.Add("")
$ReportLines.Add("5. DETALLE DE ARCHIVOS DUPLICADOS ENCONTRADOS")
$ReportLines.Add("--------------------------------------------------------------------------------")

if ($DuplicatesFoundList.Count -gt 0) {
    foreach ($dup in $DuplicatesFoundList) {
        $ReportLines.Add($dup)
        $ReportLines.Add("")
    }
} else {
    $ReportLines.Add("No se encontraron archivos duplicados.")
}

$ReportLines.Add("")
$ReportLines.Add("================================================================================")
$ReportLines.Add("                        FIN DEL INFORME AUDITABLE")
$ReportLines.Add("================================================================================")

# Exportar archivo de informe .txt
if ($ExportReport) {
    try {
        [System.IO.File]::WriteAllLines($ReportFilePath, $ReportLines, [System.Text.Encoding]::UTF8)
        Write-Host "`n[INFORME PERSISTENTE GENERADO]" -ForegroundColor Cyan
        Write-Host "  Ruta del reporte: $ReportFilePath" -ForegroundColor Green
    }
    catch {
        Write-Host "`n[!] No se pudo guardar el archivo de informe: $_" -ForegroundColor Red
    }
}

Write-Host "`n==================================================================" -ForegroundColor Green
Write-Host " RESUMEN EJECUTIVO DE HIGIENIZACION (TIEMPO: $DurationFormatted) " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host " Equipo / Usuario:    $HostnameStr \ $UsernameStr" -ForegroundColor White
Write-Host " Espacio Liberado:    $TotalMBFreed MB ($deletedCount archivos)" -ForegroundColor White
Write-Host " Alertas Seguridad:   $alertCount ejecutables en Downloads/Temp" -ForegroundColor White
Write-Host " Archivos Ordenados:  $OrganizedDocsCount Docs, $OrganizedImgCount Fotos, $OrganizedVidCount Videos" -ForegroundColor White
Write-Host " Redundancia:         $DuplicateMBWasted MB en $duplicateGroupCount grupos duplicados" -ForegroundColor White
Write-Host " Antivirus (Defender): $AntivirusStatus" -ForegroundColor White
Write-Host "==================================================================`n" -ForegroundColor Green
