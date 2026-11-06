from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parent

folders = {
    'Thumbnails_sdesign': 'catalogo_Thumbnails_sdesign.pdf',
    'thumbnailsYT': 'catalogo_thumbnailsYT.pdf',
    'thumbnails_Plano_en_3D': 'catalogo_thumbnails_Plano_en_3D.pdf',
}

allowed_ext = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'}

for folder_name, pdf_name in folders.items():
    folder = root / folder_name
    pdf_path = root / pdf_name

    if not folder.exists():
        print(f'Pasta não encontrada: {folder}')
        continue

    images = []
    for file in sorted(folder.iterdir(), key=lambda item: item.name.lower()):
        if file.is_file() and file.suffix.lower() in allowed_ext:
            try:
                with Image.open(file) as img:
                    if img.mode not in ('RGB', 'L', 'RGBA', 'P'):
                        img = img.convert('RGB')
                    images.append(img.copy())
            except Exception as exc:
                print(f'Erro ao abrir {file.name}: {exc}')

    if not images:
        print(f'Nenhuma imagem encontrada em {folder_name}')
        continue

    try:
        first = images[0]
        first.save(pdf_path, save_all=True, append_images=images[1:])
        print(f'PDF gerado: {pdf_path} ({len(images)} imagens)')
    except Exception as exc:
        print(f'Erro ao gerar PDF para {folder_name}: {exc}')
