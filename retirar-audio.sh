#!/bin/bash

PASTA="/media/alex/EE509C6A509C3B73/Casas3D/Originais"
SAIDA="/media/alex/EE509C6A509C3B73/Casas3D/SemAudio"

mkdir -p "$SAIDA"

cd "$PASTA" || exit 1

for VIDEO in *.mp4 *.MP4 *.mov *.MOV *.mkv *.MKV
do
    [ -f "$VIDEO" ] || continue

    NOME="${VIDEO%.*}"

    echo "Processando: $VIDEO"

    ffmpeg \
        -hide_banner \
        -loglevel error \
        -i "$VIDEO" \
        -map 0:v:0 \
        -c:v copy \
        -an \
        "$SAIDA/${NOME}.mp4"

    if [ $? -eq 0 ]; then
        echo "✓ Concluído"
    else
        echo "✗ Erro"
    fi

    echo ""
done

echo "Concluído."