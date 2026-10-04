#!/bin/bash

BASE="/media/alex/EE509C6A509C3B73/Casas3D"

ORIGINAIS="$BASE/Originais"
THUMBNAILS="$BASE/thumbnails"
HTML="$BASE/catalogo.html"

mkdir -p "$THUMBNAILS"

# ============================================================
# CONFIGURAÇÕES
# ============================================================

# Tempos padrão:
# 1min 5s  = 65 segundos
# 1min 15s = 75 segundos
# 1min 25s = 85 segundos
# 1min 35s = 95 segundos

TEMPOS_PADRAO=(45 55 65 75)

# ============================================================
# CONVERTER TEMPO PARA SEGUNDOS
# Aceita:
# 65
# 1:05
# 1m5s
# 1:05:00
# ============================================================

converter_tempo() {

    TEMPO="$1"

    # Apenas segundos
    if [[ "$TEMPO" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "$TEMPO"
        return
    fi

    # Formato 1:05 ou 01:05
    if [[ "$TEMPO" =~ ^([0-9]+):([0-9]{1,2})$ ]]; then

        MIN="${BASH_REMATCH[1]}"
        SEG="${BASH_REMATCH[2]}"

        echo $((MIN * 60 + SEG))
        return
    fi

    # Formato 1:05:00
    if [[ "$TEMPO" =~ ^([0-9]+):([0-9]{1,2}):([0-9]{1,2})$ ]]; then

        HORAS="${BASH_REMATCH[1]}"
        MIN="${BASH_REMATCH[2]}"
        SEG="${BASH_REMATCH[3]}"

        echo $((HORAS * 3600 + MIN * 60 + SEG))
        return
    fi

    # Formato 1m5s
    if [[ "$TEMPO" =~ ^([0-9]+)m([0-9]+)s$ ]]; then

        MIN="${BASH_REMATCH[1]}"
        SEG="${BASH_REMATCH[2]}"

        echo $((MIN * 60 + SEG))
        return
    fi

    return 1
}


# ============================================================
# FORMATAR SEGUNDOS PARA EXIBIÇÃO
# Exemplo:
# 65  -> 1min 5s
# 75  -> 1min 15s
# 125 -> 2min 5s
# ============================================================

formatar_tempo() {

    TOTAL="$1"

    MIN=$((TOTAL / 60))
    SEG=$((TOTAL % 60))

    if [ "$MIN" -eq 0 ]; then

        echo "${SEG}s"

    elif [ "$SEG" -eq 0 ]; then

        echo "${MIN}min"

    else

        echo "${MIN}min ${SEG}s"

    fi
}


# ============================================================
# VERIFICAR PASTA
# ============================================================

if [ ! -d "$ORIGINAIS" ]; then

    echo ""
    echo "ERRO: pasta de vídeos não encontrada:"
    echo "$ORIGINAIS"
    echo ""

    exit 1

fi


# ============================================================
# ENTRAR NA PASTA DOS VÍDEOS
# ============================================================

cd "$ORIGINAIS" || exit 1


# ============================================================
# CRIAR LISTA DOS VÍDEOS
# ============================================================

VIDEOS=()

for VIDEO in *.mp4 *.MP4 *.mov *.MOV *.mkv *.MKV *.avi *.AVI *.webm *.WEBM
do

    [ -f "$VIDEO" ] || continue

    VIDEOS+=("$VIDEO")

done


TOTAL_VIDEOS="${#VIDEOS[@]}"


if [ "$TOTAL_VIDEOS" -eq 0 ]; then

    echo ""
    echo "Nenhum vídeo encontrado."
    echo ""

    exit 1

fi


# ============================================================
# ESCOLHER MODO
# ============================================================

clear

echo ""
echo "=========================================="
echo "        CATÁLOGO DE CASAS 3D"
echo "=========================================="
echo ""

echo "Foram encontrados $TOTAL_VIDEOS vídeos."
echo ""

echo "Escolha como deseja definir os momentos:"
echo ""
echo "1. Usar tempos padrão"
echo "   1min 5s | 1min 15s | 1min 25s | 1min 35s"
echo ""
echo "2. Escolher manualmente os tempos de cada vídeo"
echo ""

while true
do

    read -rp "Escolha [1/2]: " MODO

    case "$MODO" in

        1)
            break
            ;;

        2)
            break
            ;;

        *)
            echo "Opção inválida. Digite 1 ou 2."
            ;;

    esac

done


# ============================================================
# LIMPAR THUMBNAILS ANTIGAS
# ============================================================

echo ""
echo "Limpando thumbnails antigas..."

rm -f "$THUMBNAILS"/*.jpg


# ============================================================
# CRIAR HTML INICIAL
# ============================================================

echo ""
echo "Criando catálogo HTML..."


cat > "$HTML" <<EOF
<!DOCTYPE html>
<html lang="pt">
<head>

<meta charset="UTF-8">

<meta name="viewport"
      content="width=device-width, initial-scale=1.0">

<title>Catálogo de Casas 3D</title>

<style>

* {
    box-sizing: border-box;
}

body {

    margin: 0;
    padding: 0;

    font-family:
        Arial,
        Helvetica,
        sans-serif;

    background: #f5f7fa;

    color: #1f2937;
}


/* =========================================================
   CABEÇALHO
========================================================= */

.header {

    background:
        linear-gradient(
            135deg,
            #172554,
            #2563eb
        );

    color: white;

    padding: 35px 18px;

    text-align: center;
}

.header h1 {

    margin: 0;

    font-size: 26px;

    line-height: 1.2;
}

.header p {

    margin: 10px 0 0;

    font-size: 14px;

    opacity: 0.9;
}


/* =========================================================
   CONTEÚDO
========================================================= */

.catalogo {

    width: 100%;

    max-width: 1400px;

    margin: auto;

    padding:
        18px
        12px
        40px;
}


/* =========================================================
   CARD DA CASA
========================================================= */

.casa {

    background: white;

    border-radius: 14px;

    margin-bottom: 20px;

    overflow: hidden;

    box-shadow:
        0 2px 8px rgba(0,0,0,0.06),
        0 8px 25px rgba(0,0,0,0.04);
}


/* =========================================================
   CABEÇALHO DA CASA
========================================================= */

.nome {

    padding:
        16px
        15px
        12px;

    font-size: 17px;

    font-weight: 700;

    line-height: 1.4;

    color: #172554;
}


/* Número da casa */

.numero {

    display: inline-flex;

    align-items: center;

    justify-content: center;

    min-width: 30px;

    height: 30px;

    margin-right: 8px;

    border-radius: 50%;

    background: #2563eb;

    color: white;

    font-size: 14px;

    font-weight: bold;
}


/* =========================================================
   THUMBNAILS
========================================================= */

.imagens {

    display: grid;

    grid-template-columns:
        repeat(2, 1fr);

    gap: 8px;

    padding:
        0
        10px
        12px;
}


.imagem {

    position: relative;

    overflow: hidden;

    border-radius: 9px;

    background: #e5e7eb;
}


.imagem img {

    display: block;

    width: 100%;

    aspect-ratio: 16 / 10;

    object-fit: cover;

    transition:
        transform 0.25s ease,
        opacity 0.25s ease;
}


.imagem:hover img {

    transform: scale(1.04);

    opacity: 0.92;
}


/* =========================================================
   TEMPO
========================================================= */

.tempo {

    position: absolute;

    bottom: 6px;

    left: 6px;

    background:
        rgba(0,0,0,0.72);

    color: white;

    padding:
        4px
        7px;

    border-radius: 5px;

    font-size: 11px;

    font-weight: 600;
}


/* =========================================================
   TABLET
========================================================= */

@media (min-width: 600px) {

    .header {

        padding:
            45px
            25px;
    }

    .header h1 {

        font-size: 32px;
    }

    .catalogo {

        padding:
            25px
            20px
            50px;
    }

    .casa {

        margin-bottom: 25px;
    }

    .nome {

        padding:
            18px
            20px
            14px;

        font-size: 19px;
    }

    .imagens {

        gap: 10px;

        padding:
            0
            15px
            15px;
    }
}


/* =========================================================
   DESKTOP
========================================================= */

@media (min-width: 900px) {

    .header {

        padding:
            55px
            30px;
    }

    .header h1 {

        font-size: 38px;
    }

    .header p {

        font-size: 16px;
    }

    .catalogo {

        padding:
            30px
            25px
            60px;
    }

    .casa {

        margin-bottom: 30px;

        border-radius: 16px;
    }

    .nome {

        padding:
            20px
            22px
            15px;

        font-size: 20px;
    }

    .imagens {

        grid-template-columns:
            repeat(4, 1fr);

        gap: 10px;

        padding:
            0
            18px
            18px;
    }

    .tempo {

        font-size: 12px;
    }
}


/* =========================================================
   TELAS GRANDES
========================================================= */

@media (min-width: 1300px) {

    .catalogo {

        padding-left: 35px;

        padding-right: 35px;
    }

    .imagens {

        gap: 12px;
    }
}

</style>

</head>


<body>


<header class="header">

    <h1>
        Catálogo de Casas 3D
    </h1>

    <p>
        Explore os projetos e visualize
        cada casa em diferentes momentos do vídeo.
    </p>

</header>


<main class="catalogo">

EOF


# ============================================================
# PROCESSAR CADA VÍDEO
# ============================================================

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


    # --------------------------------------------------------
    # OBTER DURAÇÃO
    # --------------------------------------------------------

    DURACAO=$(ffprobe \
        -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$VIDEO"
    )


    if [ -z "$DURACAO" ]; then

        echo "ERRO: não foi possível obter a duração."

        continue

    fi


    # --------------------------------------------------------
    # DEFINIR TEMPOS
    # --------------------------------------------------------

    if [ "$MODO" = "1" ]; then

        TEMPOS=(
            "${TEMPOS_PADRAO[0]}"
            "${TEMPOS_PADRAO[1]}"
            "${TEMPOS_PADRAO[2]}"
            "${TEMPOS_PADRAO[3]}"
        )

    else

        echo "Escolha os momentos das 4 imagens."
        echo ""
        echo "Pode escrever, por exemplo:"
        echo "65"
        echo "1:05"
        echo "1m5s"
        echo ""

        TEMPOS=()

        for POS in 0 1 2 3
        do

            PADRAO="${TEMPOS_PADRAO[$POS]}"

            PADRAO_FORMATADO=$(formatar_tempo "$PADRAO")


            while true
            do

                read -rp \
                    "Imagem $((POS + 1)) [$PADRAO_FORMATADO]: " \
                    ENTRADA


                # Se deixar vazio, usar padrão

                if [ -z "$ENTRADA" ]; then

                    VALOR="$PADRAO"

                    break

                fi


                VALOR=$(converter_tempo "$ENTRADA")


                if [ $? -eq 0 ]; then

                    break

                fi


                echo "Formato inválido. Tente 65, 1:05 ou 1m5s."

            done


            TEMPOS+=("$VALOR")

        done

    fi


    # --------------------------------------------------------
    # MOSTRAR TEMPOS ESCOLHIDOS
    # --------------------------------------------------------

    echo ""
    echo "Momentos selecionados:"

    for POS in 0 1 2 3
    do

        VALOR="${TEMPOS[$POS]}"

        echo "  Imagem $((POS + 1)): $(formatar_tempo "$VALOR")"

    done


    # --------------------------------------------------------
    # CRIAR THUMBNAILS
    # --------------------------------------------------------

    for POS in 0 1 2 3
    do

        TEMPO="${TEMPOS[$POS]}"

        TEMPO_FORMATADO=$(formatar_tempo "$TEMPO")


        # ----------------------------------------------------
        # Se o momento for maior que a duração,
        # utilizar 90% do vídeo
        # ----------------------------------------------------

        if awk "BEGIN {exit !($DURACAO < $TEMPO)}"
        then

            TEMPO_REAL=$(awk \
                "BEGIN {print $DURACAO * 0.90}")

        else

            TEMPO_REAL="$TEMPO"

        fi


        # Nome fixo baseado na posição.
        # Isso evita problemas caso o usuário escolha
        # tempos diferentes entre execuções.

        POSICAO=$((POS + 1))

        SAIDA="$THUMBNAILS/${BASE_NOME}_${POSICAO}.jpg"


        LOG_TEMP=$(mktemp)

        ffmpeg \
            -hide_banner \
            -loglevel error \
            -ss "$TEMPO_REAL" \
            -i "$VIDEO" \
            -map 0:v:0 \
            -an \
            -sn \
            -frames:v 1 \
            -q:v 2 \
            -vf "scale=500:-1:flags=lanczos" \
            -y \
            "$SAIDA" 2>"$LOG_TEMP"

        STATUS=$?

        if [ "$STATUS" -eq 0 ] && [ -s "$SAIDA" ]; then

            echo "  ✓ Imagem $POSICAO — $TEMPO_FORMATADO"

        else

            if [ -s "$LOG_TEMP" ]; then
                echo "  ⚠ Imagem $POSICAO — $TEMPO_FORMATADO (ffmpeg reportou aviso/erro)"
                cat "$LOG_TEMP"
            else
                echo "  ✗ Imagem $POSICAO — $TEMPO_FORMATADO"
            fi

        fi

        rm -f "$LOG_TEMP"

    done


    # ========================================================
    # ADICIONAR CASA AO HTML
    # ========================================================

    T1="${TEMPOS[0]}"
    T2="${TEMPOS[1]}"
    T3="${TEMPOS[2]}"
    T4="${TEMPOS[3]}"


    F1=$(formatar_tempo "$T1")
    F2=$(formatar_tempo "$T2")
    F3=$(formatar_tempo "$T3")
    F4=$(formatar_tempo "$T4")


    cat >> "$HTML" <<EOF

<article class="casa">

    <div class="nome">

        <span class="numero">
            $NUMERO
        </span>

        $BASE_NOME

    </div>


    <div class="imagens">


        <div class="imagem">

            <img
                src="thumbnails/${BASE_NOME}_1.jpg"
                alt="${BASE_NOME} - $F1"
                loading="lazy"
            >

            <div class="tempo">
                $F1
            </div>

        </div>


        <div class="imagem">

            <img
                src="thumbnails/${BASE_NOME}_2.jpg"
                alt="${BASE_NOME} - $F2"
                loading="lazy"
            >

            <div class="tempo">
                $F2
            </div>

        </div>


        <div class="imagem">

            <img
                src="thumbnails/${BASE_NOME}_3.jpg"
                alt="${BASE_NOME} - $F3"
                loading="lazy"
            >

            <div class="tempo">
                $F3
            </div>

        </div>


        <div class="imagem">

            <img
                src="thumbnails/${BASE_NOME}_4.jpg"
                alt="${BASE_NOME} - $F4"
                loading="lazy"
            >

            <div class="tempo">
                $F4
            </div>

        </div>


    </div>

</article>

EOF

done


# ============================================================
# FINALIZAR HTML
# ============================================================

cat >> "$HTML" <<EOF

</main>

</body>

</html>

EOF


# ============================================================
# FINAL
# ============================================================

echo ""
echo "=========================================="
echo "CATÁLOGO CONCLUÍDO"
echo "=========================================="
echo ""
echo "Vídeos processados: $NUMERO"
echo ""
echo "HTML:"
echo "$HTML"
echo ""
echo "Thumbnails:"
echo "$THUMBNAILS"
echo ""

