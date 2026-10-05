#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$SCRIPT_DIR"

ORIGINAIS="$BASE/Originais"
THUMBNAILS="$BASE/thumbnails"
HTML="$BASE/index.html"
CATALOGO_HTML="$BASE/catalogo.html"

normalizar_nome_casa() {

    local nome="$1"

    nome="${nome%.*}"
    nome="${nome//_/ }"

    while [[ "$nome" == *"  "* ]]; do
        nome="${nome//  / }"
    done

    nome="${nome//\(480P\)/}"
    nome="${nome//\(720P_HD\)/}"
    nome="${nome//\(720P_60FPS\)/}"
    nome="${nome//\(720P\)/}"
    nome="${nome//\(480P_HD\)/}"
    nome="${nome//\(360P\)/}"
    nome="${nome//\(1080P\)/}"
    nome="${nome//\(480P_HD\)/}"
    nome="${nome//  / }"

    nome="${nome#${nome%%[![:space:]]*}}"
    nome="${nome%${nome##*[![:space:]]}}"

    echo "$nome"
}

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

/* =========================================================
   CONTROLE DE SELEÇÃO E WHATSAPP
========================================================= */

.casa-topo {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    flex-wrap: wrap;
    padding: 0 15px 12px;
}

.selecao {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    min-height: 40px;
    border-radius: 999px;
    background: #e0edff;
    color: #102a63;
    border: 1px solid #bfd5ff;
    padding: 8px 12px;
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
    user-select: none;
}

.selecao input {
    margin: 0 8px 0 0;
    accent-color: #2563eb;
    transform: scale(1.15);
}

.toggle-geral {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 12px;
    flex-wrap: wrap;
    margin: 0 0 18px;
}

.checkbox-btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 8px;
    padding: 10px 14px;
    border-radius: 999px;
    border: 1px solid #cbd5e1;
    background: white;
    color: #0f172a;
    font-size: 13px;
    font-weight: 700;
    cursor: pointer;
    box-shadow: 0 4px 10px rgba(15, 23, 42, 0.06);
}

.checkbox-btn input {
    accent-color: #2563eb;
    width: 16px;
    height: 16px;
}

.barra-whatsapp {
    position: sticky;
    bottom: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    width: min(1200px, calc(100% - 24px));
    margin: 0 auto 18px;
    padding: 12px 14px;
    background: rgba(17, 24, 39, 0.96);
    color: white;
    border-radius: 16px;
    box-shadow: 0 10px 30px rgba(15, 23, 42, 0.25);
    z-index: 30;
}

.barra-whatsapp strong {
    font-size: 14px;
    line-height: 1.2;
}

#enviarWhatsApp {
    background: linear-gradient(135deg, #22c55e, #16a34a);
    color: white;
    border: none;
    border-radius: 12px;
    padding: 12px 16px;
    font-size: 14px;
    font-weight: 700;
    cursor: pointer;
    min-width: 180px;
}

#enviarWhatsApp:disabled {
    opacity: 0.6;
    cursor: default;
}

.pricing-floating-btn {
    position: fixed;
    right: 18px;
    bottom: 110px;
    z-index: 40;
    background: linear-gradient(135deg, #7c3aed, #2563eb);
    color: white;
    border: none;
    border-radius: 999px;
    padding: 14px 18px;
    box-shadow: 0 15px 35px rgba(79, 70, 229, 0.35);
    font-size: 14px;
    font-weight: 800;
    cursor: pointer;
    animation: pulse 1.8s ease-in-out infinite;
}

@keyframes pulse {
    0%, 100% {
        transform: scale(1);
        box-shadow: 0 15px 35px rgba(79, 70, 229, 0.35);
    }
    50% {
        transform: scale(1.05);
        box-shadow: 0 18px 38px rgba(37, 99, 235, 0.5);
    }
}

.pricing-modal {
    position: fixed;
    inset: 0;
    background: rgba(15, 23, 42, 0.62);
    display: grid;
    place-items: center;
    z-index: 50;
    opacity: 0;
    pointer-events: none;
    transition: opacity 0.2s ease;
}

.pricing-modal.visible {
    opacity: 1;
    pointer-events: auto;
}

.pricing-panel {
    position: relative;
    width: min(980px, calc(100% - 24px));
    max-height: 85vh;
    overflow-y: auto;
    background: linear-gradient(180deg, #f8fafc 0%, #eef2ff 100%);
    border-radius: 22px;
    padding: 28px 20px 16px;
    box-shadow: 0 25px 60px rgba(15, 23, 42, 0.28);
}

.pricing-header {
    text-align: center;
    margin-bottom: 18px;
}

.pricing-header h3 {
    margin: 0 0 8px;
    font-size: 28px;
    color: #0f172a;
}

.pricing-header p {
    margin: 0;
    color: #475569;
    font-size: 14px;
}

.pricing-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
    gap: 16px;
}

.pricing-card {
    background: white;
    border: 1px solid #dfe7f5;
    border-radius: 18px;
    padding: 20px 16px;
    box-shadow: 0 12px 22px rgba(15, 23, 42, 0.04);
    display: flex;
    flex-direction: column;
    gap: 12px;
}

.pricing-card.popular {
    background: linear-gradient(180deg, #eef2ff, #ffffff);
    border: 2px solid #8b5cf6;
    transform: translateY(-4px);
}

.pricing-label {
    display: inline-block;
    align-self: flex-start;
    background: #dbeafe;
    color: #1d4ed8;
    border-radius: 999px;
    padding: 6px 10px;
    font-size: 11px;
    font-weight: 800;
    letter-spacing: 0.08em;
    text-transform: uppercase;
}

.pricing-card.popular .pricing-label {
    background: #ede9fe;
    color: #6d28d9;
}

.pricing-card h4 {
    margin: 0;
    font-size: 20px;
    color: #0f172a;
}

.pricing-card .preco {
    font-size: 30px;
    font-weight: 900;
    color: #111827;
}

.pricing-card .preco small {
    font-size: 14px;
    font-weight: 700;
    color: #475569;
}

.pricing-card ul {
    list-style: none;
    padding: 0;
    margin: 0;
    display: grid;
    gap: 8px;
    color: #334155;
    font-size: 13px;
    line-height: 1.5;
}

.pricing-card li::before {
    content: "✓";
    color: #16a34a;
    font-weight: 800;
    margin-right: 8px;
}

.pricing-card .badge {
    display: inline-flex;
    align-self: flex-start;
    background: #fef3c7;
    color: #92400e;
    border-radius: 999px;
    padding: 6px 10px;
    font-size: 11px;
    font-weight: 800;
}

.pricing-close {
    position: absolute;
    top: 12px;
    right: 12px;
    width: 36px;
    height: 36px;
    border: none;
    border-radius: 50%;
    background: #e2e8f0;
    color: #0f172a;
    font-size: 24px;
    cursor: pointer;
}

@media (max-width: 600px) {
    .casa-topo {
        padding: 0 10px 10px;
    }

    .toggle-geral {
        justify-content: center;
    }

    .barra-whatsapp {
        flex-direction: column;
        align-items: stretch;
        text-align: center;
    }

    #enviarWhatsApp {
        width: 100%;
    }

    .pricing-floating-btn {
        right: 14px;
        bottom: 100px;
        padding: 12px 16px;
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


    NOME_EXIBICAO=$(normalizar_nome_casa "$BASE_NOME")

    cat >> "$HTML" <<EOF

<article class="casa">

    <div class="nome">

        <span class="numero">
            $NUMERO
        </span>

        $NOME_EXIBICAO

    </div>

    <div class="casa-topo">

        <label class="selecao">
            <input
                type="checkbox"
                class="casa-checkbox"
                value="$NUMERO"
                data-nome="$NOME_EXIBICAO"
            >
            <span>Selecionar</span>
        </label>

    </div>


    <div class="imagens">


        <div class="imagem">

            <img
                src="thumbnails/${BASE_NOME}_1.jpg"
                alt="${NOME_EXIBICAO} - $F1"
                loading="lazy"
            >

            <div class="tempo">
                $F1
            </div>

        </div>


        <div class="imagem">

            <img
                src="thumbnails/${BASE_NOME}_2.jpg"
                alt="${NOME_EXIBICAO} - $F2"
                loading="lazy"
            >

            <div class="tempo">
                $F2
            </div>

        </div>


        <div class="imagem">

            <img
                src="thumbnails/${BASE_NOME}_3.jpg"
                alt="${NOME_EXIBICAO} - $F3"
                loading="lazy"
            >

            <div class="tempo">
                $F3
            </div>

        </div>


        <div class="imagem">

            <img
                src="thumbnails/${BASE_NOME}_4.jpg"
                alt="${NOME_EXIBICAO} - $F4"
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

<div class="toggle-geral">

    <label class="checkbox-btn">
        <input type="checkbox" id="selecionarTodos">
        <span>Selecionar todos</span>
    </label>

    <label class="checkbox-btn">
        <input type="checkbox" id="desmarcarTodos">
        <span>Desmarcar todos</span>
    </label>

</div>

<div class="barra-whatsapp">

    <div>
        <strong id="contador">
            0 casas selecionadas
        </strong>
    </div>

    <button id="enviarWhatsApp" type="button">
        Enviar pelo WhatsApp
    </button>

</div>

<button class="pricing-floating-btn" id="pricingToggle" type="button" aria-expanded="false">
    💰 Pacotes
</button>

<div class="pricing-modal" id="pricingModal" aria-hidden="true">
    <div class="pricing-panel" role="dialog" aria-modal="true" aria-labelledby="pricingTitle">
        <button class="pricing-close" id="pricingClose" type="button" aria-label="Fechar pacotes">×</button>

        <div class="pricing-header">
            <h3 id="pricingTitle">Planos de acesso</h3>
            <p>Escolha o pacote ideal para explorar os modelos.</p>
        </div>

        <div class="pricing-grid">

            <article class="pricing-card">
                <span class="pricing-label">Escolha</span>
                <h4>Pacote ESCOLHA</h4>
                <div class="preco">500 <small>MT</small></div>
                <ul>
                    <li>3 modelos</li>
                    <li>Vídeos 3D</li>
                    <li>Plantas com dimensões</li>
                    <li>Visualização exterior e interior</li>
                </ul>
            </article>

            <article class="pricing-card popular">
                <span class="pricing-label">Mais popular</span>
                <h4>Pacote EXPLORE</h4>
                <div class="preco">1.000 <small>MT</small></div>
                <div class="badge">⭐ MAIS POPULAR</div>
                <ul>
                    <li>10 modelos</li>
                    <li>Vídeos 3D completos</li>
                    <li>Plantas com dimensões</li>
                    <li>Mais estilos para comparar</li>
                </ul>
            </article>

            <article class="pricing-card">
                <span class="pricing-label">Compare</span>
                <h4>Pacote COMPARE</h4>
                <div class="preco">1.700 <small>MT</small></div>
                <ul>
                    <li>20 modelos</li>
                    <li>Vídeos 3D</li>
                    <li>Grande variedade de estilos</li>
                    <li>Ideal para comparar opções</li>
                </ul>
            </article>

            <article class="pricing-card">
                <span class="pricing-label">Completo</span>
                <h4>Catálogo completo</h4>
                <div class="preco">3.000 <small>MT</small></div>
                <div class="badge">💰 MELHOR CUSTO</div>
                <ul>
                    <li>+50 modelos</li>
                    <li>Vídeos 3D</li>
                    <li>Plantas com dimensões</li>
                    <li>Exploração ampla antes de escolher</li>
                </ul>
            </article>

        </div>
    </div>
</div>

<script>
    const numeroWhatsApp = "258842922516";
    const checkboxes = document.querySelectorAll(".casa-checkbox");
    const contador = document.getElementById("contador");
    const botao = document.getElementById("enviarWhatsApp");
    const selecionarTodos = document.getElementById("selecionarTodos");
    const desmarcarTodos = document.getElementById("desmarcarTodos");
    const pricingToggle = document.getElementById("pricingToggle");
    const pricingModal = document.getElementById("pricingModal");
    const pricingClose = document.getElementById("pricingClose");

    function atualizarContador() {
        const selecionadas = document.querySelectorAll(".casa-checkbox:checked");
        const quantidade = selecionadas.length;

        contador.textContent =
            quantidade === 1
                ? "1 casa selecionada"
                : quantidade + " casas selecionadas";

        botao.disabled = quantidade === 0;

        if (checkboxes.length > 0) {
            selecionarTodos.checked = quantidade === checkboxes.length;
            desmarcarTodos.checked = quantidade === 0;
        }
    }

    function abrirPricing() {
        pricingModal.classList.add("visible");
        pricingModal.setAttribute("aria-hidden", "false");
        pricingToggle.setAttribute("aria-expanded", "true");
    }

    function fecharPricing() {
        pricingModal.classList.remove("visible");
        pricingModal.setAttribute("aria-hidden", "true");
        pricingToggle.setAttribute("aria-expanded", "false");
    }

    checkboxes.forEach(function (checkbox) {
        checkbox.addEventListener("change", atualizarContador);
    });

    selecionarTodos.addEventListener("change", function () {
        if (this.checked) {
            checkboxes.forEach(function (checkbox) {
                checkbox.checked = true;
            });
        }
        atualizarContador();
    });

    desmarcarTodos.addEventListener("change", function () {
        if (this.checked) {
            checkboxes.forEach(function (checkbox) {
                checkbox.checked = false;
            });
        }
        atualizarContador();
    });

    botao.addEventListener("click", function () {
        const selecionadas = document.querySelectorAll(".casa-checkbox:checked");

        if (selecionadas.length === 0) {
            alert("Selecione pelo menos uma casa.");
            return;
        }

        let mensagem = "Olá! Tenho interesse nas seguintes casas:\n\n";

        selecionadas.forEach(function (checkbox) {
            mensagem += checkbox.value + ". " + checkbox.dataset.nome + "\n";
        });

        mensagem += "\nGostaria de receber mais informações sobre estas casas.";

        const link =
            "https://wa.me/" +
            numeroWhatsApp +
            "?text=" +
            encodeURIComponent(mensagem);

        window.location.href = link;
    });

    pricingToggle.addEventListener("click", function () {
        if (pricingModal.classList.contains("visible")) {
            fecharPricing();
            return;
        }

        abrirPricing();
    });

    pricingClose.addEventListener("click", fecharPricing);

    pricingModal.addEventListener("click", function (event) {
        if (event.target === pricingModal) {
            fecharPricing();
        }
    });

    document.addEventListener("keydown", function (event) {
        if (event.key === "Escape" && pricingModal.classList.contains("visible")) {
            fecharPricing();
        }
    });

    atualizarContador();
</script>

</body>

</html>

EOF

cp "$HTML" "$CATALOGO_HTML"

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
echo "HTML duplicado:"
echo "$CATALOGO_HTML"
echo ""
echo "Thumbnails:"
echo "$THUMBNAILS"
echo ""

