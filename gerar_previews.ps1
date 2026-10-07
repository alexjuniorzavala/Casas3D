#!/bin/bash

# ============================================================
# CASAS3D — CRIAR TRECHOS RÁPIDOS
# ============================================================

BASE="/media/alex/EE509C6A509C3B73/Casas3D"

ORIGEM="$BASE/Originais"
DESTINO="$BASE/Trechos"

mkdir -p "$DESTINO"

# ============================================================
# CONFIGURAÇÕES
# ============================================================

CLIP=12

# 5 posições do vídeo
POSICOES=(0.05 0.25 0.45 0.65 0.85)

# Resolução para pré-visualização
LARGURA=854
ALTURA=480


# ============================================================
# VERIFICAR FFMPEG
# ============================================================

if ! command -v ffmpeg >/dev/null 2>&1; then

    echo "FFmpeg não está instalado."

    echo ""
    echo "Instale com:"
    echo "sudo apt install ffmpeg"

    exit 1
fi


if ! command -v ffprobe >/dev/null 2>&1; then

    echo "FFprobe não está instalado."

    exit 1
fi


# ============================================================
# ENTRAR NA PASTA
# ============================================================

cd "$ORIGEM" || exit 1


# ============================================================
# DETECTAR VÍDEOS
# ============================================================

VIDEOS=()

for VIDEO in \
    *.mp4 *.MP4 \
    *.mov *.MOV \
    *.mkv *.MKV \
    *.avi *.AVI \
    *.webm *.WEBM
do

    [ -f "$VIDEO" ] || continue

    VIDEOS+=("$VIDEO")

done


TOTAL=${#VIDEOS[@]}


if [ "$TOTAL" -eq 0 ]; then

    echo "Nenhum vídeo encontrado."

    exit 1

fi


# ============================================================
# VERIFICAR SE HÁ INTEL QSV
# ============================================================

if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "h264_qsv"; then

    ENCODER="h264_qsv"

    echo ""
    echo "Intel Quick Sync detectado."
    echo "Usando aceleração de hardware."

else

    ENCODER="libx264"

    echo ""
    echo "Intel Quick Sync não disponível."
    echo "Usando libx264 ultrafast."

fi


echo ""
echo "============================================"
echo "CASAS3D — CRIAR TRECHOS"
echo "============================================"
echo ""
echo "Vídeos encontrados: $TOTAL"
echo "Resolução: ${LARGURA}x${ALTURA}"
echo "Duração de cada trecho: ${CLIP}s"
echo "Encoder: $ENCODER"
echo ""


# ============================================================
# PROCESSAR
# ============================================================

CONTADOR=0


for VIDEO in "${VIDEOS[@]}"
do

    CONTADOR=$((CONTADOR + 1))

    BASE_NOME="${VIDEO%.*}"

    SAIDA="$DESTINO/${BASE_NOME}_trechos.mp4"


    echo ""
    echo "[$CONTADOR/$TOTAL]"
    echo "$VIDEO"


    # ========================================================
    # SE JÁ EXISTE
    # ========================================================

    if [ -f "$SAIDA" ]; then

        echo "→ Já existe. Ignorado."

        continue

    fi


    # ========================================================
    # DURAÇÃO
    # ========================================================

    DURACAO=$(ffprobe \
        -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$VIDEO"
    )


    if [ -z "$DURACAO" ]; then

        echo "→ Não foi possível obter duração."

        continue

    fi


    # ========================================================
    # MÁXIMO PARA INÍCIO DOS CLIPES
    # ========================================================

    MAX=$(awk \
        -v d="$DURACAO" \
        -v c="$CLIP" \
        'BEGIN {
            x=d-c;
            if (x<0) x=0;
            print x
        }'
    )


    # ========================================================
    # CALCULAR OS 5 INÍCIOS
    # ========================================================

    TEMPOS=()


    for POS in "${POSICOES[@]}"
    do

        T=$(awk \
            -v d="$DURACAO" \
            -v p="$POS" \
            -v max="$MAX" \
            'BEGIN {
                x=d*p;

                if (x>max)
                    x=max;

                if (x<0)
                    x=0;

                printf "%.2f",x
            }'
        )

        TEMPOS+=("$T")

    done


    echo "→ Duração: ${DURACAO}s"
    echo "→ Cortes: ${TEMPOS[*]}"


    # ========================================================
    # ARGUMENTOS
    # ========================================================

    ARGS=()


    # --------------------------------------------------------
    # 5 entradas
    #
    # -ss ANTES de -i = seeking rápido
    # --------------------------------------------------------

    for T in "${TEMPOS[@]}"
    do

        ARGS+=(
            "-ss" "$T"
            "-t" "$CLIP"
            "-i" "$VIDEO"
        )

    done


    # ========================================================
    # FILTROS
    # ========================================================

    FILTERS=()


    for I in 0 1 2 3 4
    do

        FILTERS+=(
            "[$I:v]"\
"scale=${LARGURA}:${ALTURA}:force_original_aspect_ratio=decrease,"\
"pad=${LARGURA}:${ALTURA}:(ow-iw)/2:(oh-ih)/2,"\
"fps=24,"\
"format=yuv420p"\
"[v$I]"
        )

    done


    # ========================================================
    # CONCATENAR
    # ========================================================

    FILTER_COMPLEX=""

    for I in 0 1 2 3 4
    do

        if [ "$I" -gt 0 ]; then
            FILTER_COMPLEX+=";"
        fi

        FILTER_COMPLEX+="${FILTERS[$I]}"

    done


    FILTER_COMPLEX+=";"

    FILTER_COMPLEX+="[v0][v1][v2][v3][v4]"
    FILTER_COMPLEX+="concat=n=5:v=1:a=0"


    # ========================================================
    # MARCA D'ÁGUA
    # ========================================================

    FILTER_COMPLEX+=",drawtext="
    FILTER_COMPLEX+="text='Trechos':"
    FILTER_COMPLEX+="fontcolor=white:"
    FILTER_COMPLEX+="fontsize=36:"
    FILTER_COMPLEX+="box=1:"
    FILTER_COMPLEX+="boxcolor=black@0.6:"
    FILTER_COMPLEX+="boxborderw=8:"
    FILTER_COMPLEX+="x=20:"
    FILTER_COMPLEX+="y=20"


    # ========================================================
    # FILTRO FINAL
    # ========================================================

    FILTER_COMPLEX+="[v]"


    ARGS+=(
        "-filter_complex"
        "$FILTER_COMPLEX"

        "-map"
        "[v]"

        "-an"
    )


    # ========================================================
    # ENCODER
    # ========================================================

    if [ "$ENCODER" = "h264_qsv" ]; then

        # Intel Quick Sync

        ARGS+=(
            "-c:v"
            "h264_qsv"

            "-global_quality"
            "28"

            "-look_ahead"
            "0"

            "-preset"
            "veryfast"
        )

    else

        # CPU
        #
        # ultrafast = muito mais rápido
        # que veryfast
        #
        # CRF 30 = preview, não vídeo final

        ARGS+=(
            "-c:v"
            "libx264"

            "-preset"
            "ultrafast"

            "-crf"
            "30"

            "-threads"
            "0"
        )

    fi


    # ========================================================
    # MP4
    # ========================================================

    ARGS+=(
        "-movflags"
        "+faststart"

        "-y"

        "$SAIDA"
    )


    # ========================================================
    # EXECUTAR
    # ========================================================

    INICIO=$(date +%s)


    ffmpeg \
        -hide_banner \
        -loglevel warning \
        "${ARGS[@]}"


    RESULTADO=$?


    FIM=$(date +%s)

    TEMPO_EXECUCAO=$((FIM - INICIO))


    # ========================================================
    # RESULTADO
    # ========================================================

    if [ "$RESULTADO" -eq 0 ]; then

        echo ""
        echo "✓ Concluído em ${TEMPO_EXECUCAO}s"
        echo "$SAIDA"

    else

        echo ""
        echo "✗ ERRO"

        rm -f "$SAIDA"

    fi

done


# ============================================================
# FINAL
# ============================================================

echo ""
echo "============================================"
echo "PROCESSAMENTO CONCLUÍDO"
echo "============================================"
echo ""
echo "Total: $TOTAL"
echo "Saída:"
echo "$DESTINO"
echo ""