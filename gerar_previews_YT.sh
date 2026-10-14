#!/usr/bin/env bash
# ============================================================================
# gerar_previews.sh
#
# Baixa seções de vídeos de uma playlist do YouTube e gera um preview
# concatenado (com marca d'água), equivalente ao gerar_previews.ps1 do Windows.
#
# Uso:
#   ./gerar_previews.sh
#   ./gerar_previews.sh "https://www.youtube.com/playlist?list=XXXX"
#
# Requisitos:
#   yt-dlp, ffmpeg, ffprobe
# ============================================================================

set -euo pipefail

# ----------------------------------------------------------------------------
# CONFIGURAÇÃO
# ----------------------------------------------------------------------------

PLAYLIST_URL="${1:-https://www.youtube.com/playlist?list=PLGGCCGavSUJOSJxW_joMjs7kw0qX2QLI5}"

BASE_DIR="${HOME}/Casas3D"
ORIGEM="${BASE_DIR}/Originais"      # onde ficam os vídeos completos baixados
SEGMENTOS="${BASE_DIR}/Segmentos"   # onde ficam os trechos baixados
PREVIEWS="${BASE_DIR}/Previews"     # onde ficam os previews finais

FONT_FILE="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# Seções a baixar (em segundos), no formato do yt-dlp
SECOES=("0-5" "25-30" "55-60" "85-90")

# Duração de cada segmento no preview (em segundos)
CLIP_DURACAO=5

# Resolução de saída
LARGURA=1280
ALTURA=720
FPS=30

# ----------------------------------------------------------------------------
# VERIFICAÇÕES
# ----------------------------------------------------------------------------

for cmd in yt-dlp ffmpeg ffprobe; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "❌ Comando '$cmd' não encontrado. Instale antes de continuar."
        exit 1
    fi
done

if [[ ! -f "$FONT_FILE" ]]; then
    echo "⚠️  Fonte não encontrada: $FONT_FILE"
    echo "    Tentando localizar uma fonte alternativa..."
    FONT_FILE=$(fc-match -f '%{file}' sans 2>/dev/null || true)
    if [[ -z "$FONT_FILE" || ! -f "$FONT_FILE" ]]; then
        echo "❌ Nenhuma fonte disponível. Abortando."
        exit 1
    fi
    echo "    Usando: $FONT_FILE"
fi

mkdir -p "$ORIGEM" "$SEGMENTOS" "$PREVIEWS"

# ----------------------------------------------------------------------------
# 1. BAIXAR A PLAYLIST (apenas as seções desejadas)
# ----------------------------------------------------------------------------

echo ""
echo "============================================"
echo " 1. BAIXANDO SEÇÕES DA PLAYLIST"
echo "============================================"
echo ""

# Monta a string de seções para o yt-dlp
SECOES_STR=$(IFS=,; echo "${SECOES[*]}")

# --download-sections aceita múltiplas seções separadas por vírgula
# --force-keyframes-at-cuts garante cortes precisos (recodifica)
# -o organiza os arquivos dentro da pasta ORIGEM
yt-dlp \
    --download-sections "*${SECOES_STR}" \
    --force-keyframes-at-cuts \
    --merge-output-format mp4 \
    -f "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/b" \
    -o "${ORIGEM}/%(playlist_index)03d - %(title)s - sec %(section_number)s.%(ext)s" \
    --no-overwrites \
    --ignore-errors \
    --no-playlist-reverse \
    "$PLAYLIST_URL" || true

# ----------------------------------------------------------------------------
# 2. AGRUPAR SEGMENTOS POR VÍDEO
# ----------------------------------------------------------------------------

echo ""
echo "============================================"
echo " 2. AGRUPANDO SEGMENTOS POR VÍDEO"
echo "============================================"
echo ""

# Cada vídeo gera N arquivos: "001 - Título - sec 1.mp4", "001 - Título - sec 2.mp4", ...
# Vamos agrupar pelo prefixo "NNN - Título"

declare -A GRUPOS   # chave = prefixo, valor = lista de arquivos

shopt -s nullglob
for f in "${ORIGEM}"/*.mp4; do
    nome=$(basename "$f")
    # Extrai o prefixo antes do " - sec N"
    prefixo=$(echo "$nome" | sed -E 's/ - sec [0-9]+.*//')
    GRUPOS["$prefixo"]+="$f"$'\n'
done
shopt -u nullglob

if [[ ${#GRUPOS[@]} -eq 0 ]]; then
    echo "⚠️  Nenhum arquivo encontrado em $ORIGEM"
    exit 0
fi

# ----------------------------------------------------------------------------
# 3. GERAR PREVIEWS (concat + escala + marca d'água)
# ----------------------------------------------------------------------------

echo ""
echo "============================================"
echo " 3. GERANDO PREVIEWS"
echo "============================================"
echo ""

total=${#GRUPOS[@]}
contador=0

for prefixo in "${!GRUPOS[@]}"; do
    contador=$((contador + 1))

    # Nome amigável para o arquivo final
    nome_limpo=$(echo "$prefixo" | sed -E 's/[\/\\:*?"<>|]/_/g')
    saida="${PREVIEWS}/${nome_limpo}_preview.mp4"

    echo ""
    echo "[$contador/$total] $prefixo"
    echo "--------------------------------------------"

    if [[ -f "$saida" ]]; then
        echo "✅ Preview já existe. Ignorado."
        continue
    fi

    # Pega os arquivos do grupo, ordenados pelo número da seção
    mapfile -t arquivos < <(echo "${GRUPOS[$prefixo]}" | grep -v '^$' | sort -t' ' -k3 -V)

    num_segs=${#arquivos[@]}
    if [[ $num_segs -eq 0 ]]; then
        echo "⚠️  Nenhum segmento para este vídeo. Ignorado."
        continue
    fi

    echo "   Segmentos: $num_segs"

    # ------------------------------------------------------------------
    # Monta os argumentos do ffmpeg
    # ------------------------------------------------------------------

    args=()

    for arq in "${arquivos[@]}"; do
        args+=("-i" "$arq")
    done

    # ------------------------------------------------------------------
    # Constrói o filter_complex
    # ------------------------------------------------------------------

    filtros=()

    for ((i = 0; i < num_segs; i++)); do
        filtros+=(
            "[$i:v]"\
"scale=${LARGURA}:${ALTURA}:force_original_aspect_ratio=decrease,"\
"pad=${LARGURA}:${ALTURA}:(ow-iw)/2:(oh-ih)/2,"\
"setsar=1,"\
"fps=${FPS},"\
"format=yuv420p"\
"[v$i]"
        )
    done

    # Concatena todos os segmentos
    concat_inputs=""
    for ((i = 0; i < num_segs; i++)); do
        concat_inputs+="[v$i]"
    done

    # Escapa o caminho da fonte para o drawtext (dois-pontos precisa de escape)
    font_escaped=$(echo "$FONT_FILE" | sed 's/:/\\:/g')

    filtro_final=$(
        IFS=';'
        echo "${filtros[*]}"
    )
    filtro_final+=";${concat_inputs}concat=n=${num_segs}:v=1:a=0"
    filtro_final+=",drawtext="
    filtro_final+="fontfile='${font_escaped}':"
    filtro_final+="text='Pre-visualizacao':"
    filtro_final+="fontcolor=white:"
    filtro_final+="fontsize=42:"
    filtro_final+="box=1:"
    filtro_final+="boxcolor=black@0.6:"
    filtro_final+="boxborderw=12:"
    filtro_final+="x=30:"
    filtro_final+="y=30"
    filtro_final+="[v]"

    # ------------------------------------------------------------------
    # Executa ffmpeg
    # ------------------------------------------------------------------

    if ffmpeg -hide_banner -loglevel warning \
        "${args[@]}" \
        -filter_complex "$filtro_final" \
        -map "[v]" \
        -an \
        -c:v libx264 \
        -preset veryfast \
        -crf 27 \
        -movflags +faststart \
        -y \
        "$saida"; then
        echo "✅ Preview criado: $saida"
    else
        echo "❌ ERRO ao processar este vídeo."
        rm -f "$saida"
    fi
done

# ----------------------------------------------------------------------------
# FIM
# ----------------------------------------------------------------------------

echo ""
echo "============================================"
echo " PROCESSAMENTO CONCLUÍDO"
echo "============================================"
echo ""
echo "Originais (seções):  $ORIGEM"
echo "Previews finais:     $PREVIEWS"
echo ""