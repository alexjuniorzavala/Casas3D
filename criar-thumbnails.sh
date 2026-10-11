#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$SCRIPT_DIR"

ORIGINAIS="$BASE/Originais"
THUMBNAILS="$BASE/thumbnails"

TEMPOS_PADRAO=(5 10 20 25 30 35 40 45 60 75 80 95 115 125 140 165 175 185 195 200 205 210 215 225 230 235 340)

mkdir -p "$THUMBNAILS"

if [ ! -d "$ORIGINAIS" ]; then
    echo ""
    echo "ERRO: pasta de vídeos não encontrada:"
    echo "$ORIGINAIS"
    echo ""
    exit 1
fi

cd "$ORIGINAIS" || exit 1

VIDEOS=()

for VIDEO in *.mp4 *.MP4 *.mov *.MOV *.mkv *.MKV *.avi *.AVI *.webm *.WEBM
 do
    [ -f "$VIDEO" ] || continue
    VIDEOS+=("$VIDEO")
done

if [ "${#VIDEOS[@]}" -eq 0 ]; then
    echo ""
    echo "Nenhum vídeo encontrado na pasta $ORIGINAIS"
    echo ""
    exit 1
fi

echo ""
echo "=========================================="
echo "      GERAR IMAGENS NÍTIDAS"
echo "=========================================="
echo ""

echo "Removendo imagens antigas..."
rm -f "$THUMBNAILS"/*.jpg

TOTAL_VIDEOS="${#VIDEOS[@]}"
NUMERO=0

for VIDEO in "${VIDEOS[@]}"
do
    NUMERO=$((NUMERO + 1))
    BASE_NOME="${VIDEO%.*}"

    echo ""
    echo "=========================================="
    echo "Vídeo $NUMERO de $TOTAL_VIDEOS"
    echo "=========================================="
    echo "$BASE_NOME"
    echo ""

    DURACAO=$(ffprobe \
        -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$VIDEO" 2>/dev/null)

    if [ -z "$DURACAO" ]; then
        echo "ERRO: não foi possível obter a duração de $VIDEO"
        continue
    fi

    for POS in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29
    do
        TEMPO="${TEMPOS_PADRAO[$POS]}"

        if awk "BEGIN {exit !($DURACAO < $TEMPO)}"; then
            TEMPO_REAL=$(awk "BEGIN {print $DURACAO * 0.90}")
        else
            TEMPO_REAL="$TEMPO"
        fi

        POSICAO=$((POS + 1))
        SAIDA="$THUMBNAILS/${BASE_NOME}_${POSICAO}.jpg"

        ffmpeg \
            -hide_banner \
            -loglevel error \
            -ss "$TEMPO_REAL" \
            -i "$VIDEO" \
            -map 0:v:0 \
            -an \
            -sn \
            -frames:v 1 \
            -q:v 1 \
            -y \
            "$SAIDA"

        if [ -s "$SAIDA" ]; then
            echo "✓ Imagem $POSICAO gerada: $SAIDA"
        else
            echo "✗ Falha ao gerar imagem $POSICAO para $VIDEO"
        fi
    done

done

echo ""
echo "Processo concluído. Imagens nítidas salvas em:"
echo "$THUMBNAILS"
echo ""
