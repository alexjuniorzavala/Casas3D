#!/bin/bash
# Uso: ./acelerar_dividir_mp4.sh <video.mkv> <velocidade> [segmento]
set -e

if [ $# -lt 2 ]; then
    echo "Uso: $0 <video.mkv> <velocidade> [segmento]"
    echo "Exemplo: $0 filme.mkv 2.5 6"
    exit 1
fi

INPUT="$1"; VELOCIDADE="$2"; SEGMENTO="${3:-6}"
[ ! -f "$INPUT" ] && { echo "Erro: '$INPUT' não encontrado."; exit 1; }

BASENAME=$(basename "$INPUT" .mkv)
OUTDIR="$(dirname "$INPUT")/${BASENAME}_acelerado_mp4"
mkdir -p "$OUTDIR"

# ---- Detecta se há áudio ----
TEM_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=index \
    -of csv=p=0 "$INPUT" | head -n1)

echo "=========================================="
echo "Input:      $INPUT"
echo "Velocidade: ${VELOCIDADE}x"
echo "Segmento:   ${SEGMENTO}s"
echo "Áudio:      ${TEM_AUDIO:+sim}${TEM_AUDIO:-NÃO (apenas vídeo)}"
echo "Saída:      $OUTDIR"
echo "=========================================="

TEMP="${OUTDIR}/_temp.mp4"

# ---- Monta filtro e mapa conforme existência de áudio ----
if [ -n "$TEM_AUDIO" ]; then
    FILTRO="[0:v]setpts=PTS/${VELOCIDADE}[v];[0:a]atempo=${VELOCIDADE}[a]"
    MAPAS=(-map "[v]" -map "[a]")
    AUDIO_OPTS=(-c:a aac -b:a 192k -ac 2)
else
    FILTRO="[0:v]setpts=PTS/${VELOCIDADE}[v]"
    MAPAS=(-map "[v]")
    AUDIO_OPTS=(-an)
fi

echo "[1/2] Acelerando ${VELOCIDADE}x e convertendo para MP4..."
ffmpeg -y -i "$INPUT" \
    -filter_complex "$FILTRO" \
    "${MAPAS[@]}" \
    -c:v libx264 -preset medium -crf 20 \
    -pix_fmt yuv420p \
    -force_key_frames "expr:gte(t,n_forced*${SEGMENTO})" \
    "${AUDIO_OPTS[@]}" \
    -movflags +faststart \
    "$TEMP"

echo "[2/2] Dividindo em ${SEGMENTO}s..."
ffmpeg -y -i "$TEMP" \
    -c:v libx264 -preset medium -crf 20 \
    "${AUDIO_OPTS[@]}" \
    -force_key_frames "expr:gte(t,n_forced*${SEGMENTO})" \
    -f segment \
    -segment_time "$SEGMENTO" \
    -reset_timestamps 1 \
    -segment_format mp4 \
    "${OUTDIR}/${BASENAME}_parte_%03d.mp4"

rm -f "$TEMP"

echo "Concluído! Saída: $OUTDIR"
ls -lh "$OUTDIR"