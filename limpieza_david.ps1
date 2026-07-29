# ===============================
# CONFIGURACIÓN
# ===============================
$basePath = "C:\Users\David"
$organizadoPath = "$basePath\Organizado"

Write-Host "==== INICIANDO LIMPIEZA SEGURA ====" -ForegroundColor Green

# ===============================
# 1. ELIMINAR ARCHIVOS BASURA
# ===============================
Write-Host "`nBuscando archivos basura..." -ForegroundColor Yellow

$basura = Get-ChildItem -Path $basePath -Recurse -Include *.tmp, *.log, *.bak, *.old -ErrorAction SilentlyContinue

foreach ($file in $basura) {
    try {
        Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "Eliminado: $($file.FullName)"
    }
    catch {
        Write-Host "No se pudo eliminar: $($file.FullName)"
    }
}

# ===============================
# 2. ARCHIVOS SOSPECHOSOS
# ===============================
Write-Host "`nBuscando archivos potencialmente peligrosos..." -ForegroundColor Yellow

$sospechosos = Get-ChildItem -Path $basePath -Recurse -Include *.exe, *.bat, *.cmd, *.ps1 -ErrorAction SilentlyContinue

foreach ($file in $sospechosos) {
    if ($file.FullName -like "*Downloads*" -or $file.FullName -like "*Temp*") {
        Write-Host "⚠️ Revisar: $($file.FullName)" -ForegroundColor Red
    }
}

# ✅ IMPORTANTE: aquí faltaba la llave en tu versión, ahora está correcta

# ===============================
# 3. CREAR CARPETAS
# ===============================
Write-Host "`nCreando estructura organizada..." -ForegroundColor Yellow

$folders = @(
    "$organizadoPath\Documentos",
    "$organizadoPath\Imagenes",
    "$organizadoPath\Videos",
    "$organizadoPath\Otros"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
}

# ===============================
# 4. ORGANIZAR ARCHIVOS
# ===============================
Write-Host "`nOrganizando archivos..." -ForegroundColor Yellow

Move-Item "$basePath\*.pdf" "$organizadoPath\Documentos" -Force -ErrorAction SilentlyContinue
Move-Item "$basePath\*.docx" "$organizadoPath\Documentos" -Force -ErrorAction SilentlyContinue
Move-Item "$basePath\*.txt" "$organizadoPath\Documentos" -Force -ErrorAction SilentlyContinue

Move-Item "$basePath\*.jpg" "$organizadoPath\Imagenes" -Force -ErrorAction SilentlyContinue
Move-Item "$basePath\*.png" "$organizadoPath\Imagenes" -Force -ErrorAction SilentlyContinue

Move-Item "$basePath\*.mp4" "$organizadoPath\Videos" -Force -ErrorAction SilentlyContinue

# ===============================
# 5. DETECTAR DUPLICADOS
# ===============================
Write-Host "`nBuscando archivos duplicados..." -ForegroundColor Yellow

$duplicates = Get-ChildItem $basePath -Recurse -ErrorAction SilentlyContinue |
Group-Object Length |
Where-Object { $_.Count -gt 1 }

foreach ($group in $duplicates) {
    Write-Host "`nPosibles duplicados (tamaño: $($group.Name)):" -ForegroundColor Cyan
    foreach ($f in $group.Group) {
        Write-Host $f.FullName
    }
}

# ===============================
# 6. ESCANEO DE VIRUS
# ===============================
Write-Host "`nEjecutando análisis completo con Windows Defender..." -ForegroundColor Yellow

Start-MpScan -ScanType FullScan

# ===============================
# FINAL
# ===============================
Write-Host "`n==== LIMPIEZA COMPLETADA ====" -ForegroundColor Green
