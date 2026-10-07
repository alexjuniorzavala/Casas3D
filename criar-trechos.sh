#!/bin/bash

# ============================================================
# CONFIGURAÇÃO
# ============================================================

BASE="/media/alex/EE509C6A509C3B73/Casas3D"

ORIGEM="$BASE/Originais"
DESTINO="$BASE/Trechos"

FFMPEG="ffmpeg"
FFPROBE="ffprobe"


# ============================================================
# VERIFICAR FFMPEG
# ============================================================

if ! command -v "$FFMPEG" >/dev/null 2>&1; then

    echo "ERRO: ffmpeg não está instalado."

    echo ""
    echo "Instale com:"
    echo "sudo apt install ffmpeg"

    exit 1

fi


if ! command -v "$FFPROBE" >/dev/null 2>&1; then

    echo "ERRO: ffprobe não está instalado."

    exit 1

fi


# ============================================================
# VERIFICAR PASTAS
# ============================================================

if [ ! -d "$ORIGEM" ]; then

    echo "ERRO: pasta de origem não encontrada:"
    echo "$ORIGEM"

    exit 1

fi


mkdir -p "$DESTINO"


# ============================================================
# CRIAR LISTA DE VÍDEOS
# ============================================================

cd "$ORIGEM" || exit 1


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

    echo "Nenhum vídeo encontrado em:"
    echo "$ORIGEM"

    exit 1

fi


# ============================================================
# CONFIGURAÇÃO DOS TRECHOS
# ============================================================

CLIP_DURACAO=12

# Posições relativas:
#
# 5%  = início
# 25% = primeira parte
# 45% = centro
# 65% = segunda parte
# 85% = final

POSICOES=(0.05 0.25 0.45 0.65 0.85)


# ============================================================
# PROCESSAR VÍDEOS
# ============================================================

CONTADOR=0


for VIDEO in "${VIDEOS[@]}"
do

    CONTADOR=$((CONTADOR + 1))

    BASE_NOME="${VIDEO%.*}"


    echo ""
    echo "============================================"
    echo "[$CONTADOR/$TOTAL] $VIDEO"
    echo "============================================"


    # ========================================================
    # NOME DO ARQUIVO DE SAÍDA
    # ========================================================

    SAIDA="$DESTINO/${BASE_NOME}_trechos.mp4"


    # ========================================================
    # VERIFICAR SE JÁ EXISTE
    # ========================================================

    if [ -f "$SAIDA" ]; then

        echo "Trechos já existem. Ignorado."

        continue

    fi


    # ========================================================
    # DESCOBRIR DURAÇÃO
    # ========================================================

    DURACAO=$(
        ffprobe \
            -v error \
            -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 \
            "$VIDEO"
    )


    if [ -z "$DURACAO" ]; then

        echo "Não foi possível descobrir a duração."
        echo "Ignorado."

        continue

    fi


    # ========================================================
    # VÍDEOS MUITO CURTOS
    # ========================================================

    if awk "BEGIN {exit !($DURACAO < 6)}"
    then

        echo "Vídeo com menos de 6 segundos."
        echo "Ignorado."

        continue

    fi


    echo "Duração: ${DURACAO}s"


    # ========================================================
    # CALCULAR INÍCIO MÁXIMO
    # ========================================================

    MAX_INICIO=$(awk \
        -v d="$DURACAO" \
        -v c="$CLIP_DURACAO" \
        'BEGIN {
            resultado=d-c;
            if (resultado < 0)
                resultado=0;
            print resultado
        }'
    )


    # ========================================================
    # CONSTRUIR ARGUMENTOS
    # ========================================================

    ARGUMENTOS=()

    FILTROS=()


    # ========================================================
    # CRIAR OS 5 SEGMENTOS
    # ========================================================

    for I in 0 1 2 3 4
    do

        POSICAO="${POSICOES[$I]}"


        # ----------------------------------------------------
        # Calcular início
        # ----------------------------------------------------

        INICIO=$(awk \
            -v d="$DURACAO" \
            -v p="$POSICAO" \
            -v max="$MAX_INICIO" \
            'BEGIN {
                valor=d*p;

                if (valor > max)
                    valor=max;

                if (valor < 0)
                    valor=0;

                printf "%.3f", valor
            }'
        )


        echo "  Trecho $((I + 1)): ${INICIO}s → $((I + 1))"


        # ----------------------------------------------------
        # Adicionar entrada
        # ----------------------------------------------------

        ARGUMENTOS+=(
            "-ss"
            "$INICIO"

            "-t"
            "$CLIP_DURACAO"

            "-i"
            "$VIDEO"
        )


        # ----------------------------------------------------
        # Filtro do segmento
        # ----------------------------------------------------

        FILTROS+=(
            "[$I:v]"\
"scale=1280:720:force_original_aspect_ratio=decrease,"\
"pad=1280:720:(ow-iw)/2:(oh-ih)/2,"\
"setsar=1,"\
"fps=30,"\
"format=yuv420p"\
"[v$I]"
        )

    done


    # ========================================================
    # CONSTRUIR FILTRO FINAL
    # ========================================================

    FILTRO_FINAL=$(
        IFS=';'
        echo "${FILTROS[*]}"
    )


    FILTRO_FINAL+=";"


    FILTRO_FINAL+="[v0][v1][v2][v3][v4]concat=n=5:v=1:a=0,"


    # ========================================================
    # MARCA D'ÁGUA
    # ========================================================
    #
    # Usamos apenas caracteres simples:
    # Trechos
    #
    # Não usamos acentos para evitar problemas com fontes,
    # encoding ou caminhos no Linux.
    # ========================================================

    FILTRO_FINAL+="drawtext="
    FILTRO_FINAL+="text='Trechos':"
    FILTRO_FINAL+="fontcolor=white:"
    FILTRO_FINAL+="fontsize=42:"
    FILTRO_FINAL+="box=1:"
    FILTRO_FINAL+="boxcolor=black@0.6:"
    FILTRO_FINAL+="boxborderw=12:"
    FILTRO_FINAL+="x=30:"
    FILTRO_FINAL+="y=30"


    FILTRO_FINAL+="[v]"


    # ========================================================
    # FILTRO COMPLEXO
    # ========================================================

    ARGUMENTOS+=(
        "-filter_complex"
        "$FILTRO_FINAL"
    )


    # ========================================================
    # CONFIGURAÇÃO DA SAÍDA
    # ========================================================

    ARGUMENTOS+=(
        "-map"
        "[v]"

        "-an"

        "-c:v"
        "libx264"

        "-preset"
        "veryfast"

        "-crf"
        "27"

        "-movflags"
        "+faststart"

        "-y"

        "$SAIDA"
    )


    # ========================================================
    # EXECUTAR FFMPEG
    # ========================================================

    echo ""
    echo "Criando trechos..."


    ffmpeg \
        -hide_banner \
        "${ARGUMENTOS[@]}"


    # ========================================================
    # VERIFICAR RESULTADO
    # ========================================================

    if [ $? -eq 0 ]; then

        echo ""
        echo "✓ Trechos criados com sucesso:"
        echo "$SAIDA"

    else

        echo ""
        echo "✗ ERRO ao processar este vídeo."

        # Remover arquivo incompleto

        if [ -f "$SAIDA" ]; then

            rm -f "$SAIDA"

            echo "Arquivo incompleto removido."

        fi

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
echo "Vídeos encontrados: $TOTAL"
echo "Pasta de saída:"
echo "$DESTINO"
echo ""
