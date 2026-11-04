
#!/bin/bash

# ==========================================
# CONFIGURAÇÕES
# ==========================================

BASE="/mnt/06A83994A839836B/Alex/Projetos/HTML/Casas3D"

PLAYLIST_URL="https://www.youtube.com/playlist?list=PLE6tt5HXJv4efcyPErOoy7TaZOwfy97LK"

DESTINO="$BASE/Trechos/Playlist"

mkdir -p "$DESTINO"

# Verificar dependências
for CMD in yt-dlp ffmpeg; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
        echo "ERRO: $CMD não está instalado."
        exit 1
    fi
done

# ==========================================
# INTERVALOS DOS TRECHOS
# ==========================================

NOMES=(
    "trecho1"
    "trecho2"
    "trecho3"
    "trecho4"
    "trecho5"
)

INICIOS=(
    "00:00:10"
    "00:00:50"
    "00:01:20"
    "00:02:00"
    "00:03:40"
)

FINS=(
    "00:00:15"
    "00:00:55"
    "00:01:30"
    "00:02:10"
    "00:03:40"
)

# ==========================================
# OBTER LISTA DE VÍDEOS
# ==========================================

TEMP_LISTA=$(mktemp)
trap 'rm -f "$TEMP_LISTA"' EXIT

# Embaralhar a ordem dos vídeos
TEMP_ALEATORIA=$(mktemp)
shuf "$TEMP_LISTA" > "$TEMP_ALEATORIA"

# Substituir a lista original pela aleatória
mv "$TEMP_ALEATORIA" "$TEMP_LISTA"

echo "A consultar playlist..."

if ! yt-dlp --flat-playlist \
    --print "%(playlist_index)03d|%(id)s|%(title)s" \
    "$PLAYLIST_URL" > "$TEMP_LISTA"; then
    echo "Não foi possível consultar a playlist."
    exit 1
fi

TOTAL=$(wc -l < "$TEMP_LISTA")

if [ "$TOTAL" -eq 0 ]; then
    echo "A playlist não contém vídeos disponíveis."
    exit 1
fi

echo ""
echo "Total de vídeos encontrados: $TOTAL"
echo "Destino: $DESTINO"
echo ""

# ==========================================
# PROCESSAR CADA VÍDEO
# ==========================================

SUCESSOS=0
ERROS=0

while IFS='|' read -r NUMERO VIDEO_ID TITULO; do

    [ -n "$VIDEO_ID" ] || continue

    PASTA="$DESTINO/Casa_$NUMERO"

    mkdir -p "$PASTA"

    URL="https://www.youtube.com/watch?v=$VIDEO_ID"

    echo ""
    echo "=========================================="
    echo "CASA $NUMERO: $TITULO"
    echo "=========================================="

    # Extrair os cinco trechos individualmente
    for i in 0 1 2 3 4; do

        NOME="${NOMES[$i]}"
        INICIO="${INICIOS[$i]}"
        FIM="${FINS[$i]}"

        ARQUIVO="$PASTA/$NOME.mp4"

        echo ""
        echo "[$NOME] $INICIO até $FIM"

        # Não repetir trechos já existentes
        if [ -f "$ARQUIVO" ]; then
            echo "Já existe. Ignorado."
            continue
        fi

        yt-dlp \
            --no-warnings \
            --download-sections "*${INICIO}-${FIM}" \
            --playlist-items 5-5 \
            -f "bv*[height<=360]+ba/b[height<=360]" \
            --merge-output-format mp4 \
            --remux-video mp4 \
            -o "$PASTA/$NOME.%(ext)s" \
            "$URL"

        if [ -f "$ARQUIVO" ]; then
            echo "Trecho criado com sucesso."
            ((SUCESSOS++))
        else
            echo "ERRO ao extrair $NOME."
            ((ERROS++))
        fi

    done

done < "$TEMP_LISTA"

# ==========================================
# RESUMO
# ==========================================

echo ""
echo "=========================================="
echo "PROCESSAMENTO CONCLUÍDO"
echo "=========================================="
echo "Vídeos na playlist: $TOTAL"
echo "Trechos criados: $SUCESSOS"
echo "Erros: $ERROS"
echo ""
echo "Local dos ficheiros:"
echo "$DESTINO"
