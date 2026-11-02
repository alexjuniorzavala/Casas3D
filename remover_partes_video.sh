#!/usr/bin/env bash
set -euo pipefail

# Remove partes de um vídeo mantendo o resto do material.
# Exemplo:
#   ./remover_partes_video.sh "Videos/arquivo.mp4"
#   ./remover_partes_video.sh "Videos/arquivo.mp4" "saida.mp4" "baixa"
#
# Intervalos removidos por defeito:
#   0s-7s
#   15s-20s
#   31s-40s
#   1:38s-1:51s
#   7:55s-9:99s (até ao fim)
#
# Qualidade opcional:
#   normal  -> CRF 23
#   baixa   -> CRF 28 + escala 1280x720 (ou proporcional)
#   media   -> CRF 25 + escala 1280x720 (ou proporcional)

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERRO: ffmpeg não está instalado."
  echo "Instale com: sudo apt install ffmpeg"
  exit 1
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 3 ]; then
  echo "Uso: $0 <video_entrada> [video_saida] [normal|media|baixa]"
  echo "Exemplo: $0 \"Videos/ab28954d3bcad5d2_Small House Design8x10 Meters 80sqm 2 bedroom(1080P_HD).mp4\""
  exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.*}_sem_partes.mp4}"
QUALITY="${3:-normal}"

if [ ! -f "$INPUT" ]; then
  echo "ERRO: ficheiro não encontrado: $INPUT"
  exit 1
fi

case "$QUALITY" in
  normal)
    CRF=23
    SCALE_FILTER=""
    ;;
  media)
    CRF=25
    SCALE_FILTER="scale=1280:-2,"
    ;;
  baixa)
    CRF=28
    SCALE_FILTER="scale=1280:-2,"
    ;;
  *)
    echo "ERRO: qualidade inválida: $QUALITY"
    echo "Valores válidos: normal | media | baixa"
    exit 1
    ;;
esac

# Intervalos a remover.
# A expressão usa filtros booleanos em segundos.
# O último intervalo é removido até ao fim, usando um valor muito alto.
RANGE_EXPR="between(t,0,7)+between(t,15,20)+between(t,31,40)+between(t,98,111)+between(t,475,1000000)"
SELECT_FILTER="select='not(${RANGE_EXPR})',setpts=N/FRAME_RATE/TB"
ASELECT_FILTER="aselect='not(${RANGE_EXPR})',asetpts=N/SR/TB"

# Se o filtro de escala foi definido, coloca-o depois do select.
if [ -n "$SCALE_FILTER" ]; then
  SELECT_FILTER="select='not(${RANGE_EXPR})',setpts=N/FRAME_RATE/TB,${SCALE_FILTER%,}"
fi

DIR="$(dirname "$OUTPUT")"
mkdir -p "$DIR"

ffmpeg -y \
  -i "$INPUT" \
  -vf "$SELECT_FILTER" \
  -af "$ASELECT_FILTER" \
  -c:v libx264 \
  -preset medium \
  -crf "$CRF" \
  -pix_fmt yuv420p \
  -c:a aac \
  -movflags +faststart \
  "$OUTPUT"

echo ""
echo "Vídeo processado: $OUTPUT"
echo "Qualidade: $QUALITY (CRF=$CRF)"
echo "Intervalos removidos: 0-7, 15-20, 31-40, 98-111, 475-fim"
