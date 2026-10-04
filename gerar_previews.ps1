```powershell
$Origem = "C:\Casas3D\Originais"
$Destino = "C:\Casas3D\Previews"

$FFmpeg = "C:\ffmpeg\bin\ffmpeg.exe"
$FFprobe = "C:\ffmpeg\bin\ffprobe.exe"

# Criar pasta de previews se não existir
New-Item -ItemType Directory -Force -Path $Destino | Out-Null

$Videos = Get-ChildItem $Origem -File |
    Where-Object {
        $_.Extension -match '\.(mp4|mov|mkv|avi|webm)$'
    }

$total = $Videos.Count
$contador = 0

foreach ($Video in $Videos) {

    $contador++

    $Saida = Join-Path $Destino "$($Video.BaseName)_preview.mp4"

    Write-Host ""
    Write-Host "[$contador/$total] $($Video.Name)" -ForegroundColor Cyan

    # ============================================================
    # VERIFICAR SE O PREVIEW JÁ EXISTE
    # ============================================================

    if (Test-Path $Saida) {

        Write-Host "Preview já existe. Ignorado." -ForegroundColor DarkYellow

        continue
    }

    # ============================================================
    # DESCOBRIR DURAÇÃO DO VÍDEO
    # ============================================================

    $DuracaoTexto = & $FFprobe `
        -v error `
        -show_entries format=duration `
        -of default=noprint_wrappers=1:nokey=1 `
        $Video.FullName

    if (-not $DuracaoTexto) {

        Write-Host "Não foi possível descobrir a duração. Ignorado." -ForegroundColor Red

        continue
    }

    $Duracao = [double]::Parse(
        $DuracaoTexto,
        [Globalization.CultureInfo]::InvariantCulture
    )

    # ============================================================
    # VÍDEOS MUITO CURTOS
    # ============================================================

    if ($Duracao -lt 6) {

        Write-Host "Vídeo com menos de 6 segundos. Ignorado." -ForegroundColor Red

        continue
    }

    # ============================================================
    # CONFIGURAÇÃO DO PREVIEW
    # ============================================================

    $ClipDuracao = 12

    # Posições relativas dentro do vídeo
    #
    # 5%   -> início
    # 25%  -> primeira parte
    # 45%  -> centro
    # 65%  -> segunda parte
    # 85%  -> final
    #
    # Resultado:
    # 5 segmentos x 6 segundos = aproximadamente 30 segundos

    $Posicoes = @(0.05, 0.25, 0.45, 0.65, 0.85)

    $MaxInicio = $Duracao - $ClipDuracao

    $Argumentos = [System.Collections.Generic.List[string]]::new()

    $Filtros = [System.Collections.Generic.List[string]]::new()

    # ============================================================
    # CRIAR OS 5 SEGMENTOS
    # ============================================================

    for ($i = 0; $i -lt 5; $i++) {

        $Inicio = [math]::Min(
            $Duracao * $Posicoes[$i],
            $MaxInicio
        )

        $Inicio = [math]::Max(0, $Inicio)

        $InicioTexto = $Inicio.ToString(
            "0.###",
            [Globalization.CultureInfo]::InvariantCulture
        )

        $Argumentos.Add("-ss")
        $Argumentos.Add($InicioTexto)

        $Argumentos.Add("-t")
        $Argumentos.Add("$ClipDuracao")

        $Argumentos.Add("-i")
        $Argumentos.Add($Video.FullName)

        # Normalizar cada segmento
        $Filtros.Add(
            "[$i`:v]" +
            "scale=1280:720:force_original_aspect_ratio=decrease," +
            "pad=1280:720:(ow-iw)/2:(oh-ih)/2," +
            "setsar=1," +
            "fps=30," +
            "format=yuv420p" +
            "[v$i]"
        )
    }

    # ============================================================
    # JUNTAR OS SEGMENTOS
    # ============================================================

    $FiltroFinal = (
        ($Filtros -join ";") +
        ";" +
        "[v0][v1][v2][v3][v4]" +
        "concat=n=5:v=1:a=0," +

        # ========================================================
        # MARCA DE ÁGUA
        # ========================================================

        "drawtext=" +
        "fontfile='C\:/Windows/Fonts/arial.ttf':" +
        "text='Pre-visualição':" +
        "fontcolor=white:" +
        "fontsize=42:" +
        "box=1:" +
        "boxcolor=black@0.6:" +
        "boxborderw=12:" +
        "x=30:" +
        "y=30" +

        "[v]"
    )

    $Argumentos.Add("-filter_complex")
    $Argumentos.Add($FiltroFinal)

    # ============================================================
    # CONFIGURAÇÃO DA SAÍDA
    # ============================================================

    $Argumentos.Add("-map")
    $Argumentos.Add("[v]")

    $Argumentos.Add("-an")

    $Argumentos.Add("-c:v")
    $Argumentos.Add("libx264")

    $Argumentos.Add("-preset")
    $Argumentos.Add("veryfast")

    $Argumentos.Add("-crf")
    $Argumentos.Add("27")

    $Argumentos.Add("-movflags")
    $Argumentos.Add("+faststart")

    $Argumentos.Add("-y")

    $Argumentos.Add($Saida)

    # ============================================================
    # EXECUTAR FFMPEG
    # ============================================================

    & $FFmpeg @Argumentos

    if ($LASTEXITCODE -eq 0) {

        Write-Host "Preview criado com sucesso." -ForegroundColor Green

    }
    else {

        Write-Host "ERRO ao processar este vídeo." -ForegroundColor Red

        # Remover arquivo incompleto, caso tenha sido criado
        if (Test-Path $Saida) {
            Remove-Item $Saida -Force
        }
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "PROCESSAMENTO CONCLUÍDO" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
```
