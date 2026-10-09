(function () {
  const TOTAL_IMAGENS = 30;
  const STYLE_ID = 'gallery-enhancer-styles';

  const state = {
    modal: null,
    urls: [],
    currentIndex: 0,
    baseName: '',
    card: null,
    orientation: 'landscape',
    hideTimer: null,
    touchStartX: 0,
    touchStartY: 0,
    isDragging: false
  };

  function ensureStyles() {
    if (document.getElementById(STYLE_ID)) {
      return;
    }

    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = `
      .gallery-enhancer-btn {
        grid-column: 1 / -1;
        margin-top: 6px;
        border: none;
        border-radius: 12px;
        background: linear-gradient(135deg, #2563eb, #7c3aed);
        color: white;
        padding: 12px 14px;
        font-size: 13px;
        font-weight: 800;
        cursor: pointer;
        box-shadow: 0 12px 25px rgba(79, 70, 229, 0.2);
      }

      .gallery-enhancer-modal {
        position: fixed;
        inset: 0;
        display: block;
        background: rgba(2, 6, 23, 0.88);
        padding: 0;
        margin: 0;
        opacity: 0;
        visibility: hidden;
        pointer-events: none;
        transition: opacity 0.2s ease, visibility 0.2s ease;
        z-index: 1000;
      }

      .gallery-enhancer-modal.visible {
        opacity: 1;
        visibility: visible;
        pointer-events: auto;
      }

      .gallery-enhancer-shell {
        position: relative;
        width: 100vw;
        height: 100vh;
        display: flex;
        align-items: center;
        justify-content: center;
        background: #020817;
        border-radius: 0;
        overflow: hidden;
        box-shadow: none;
        margin: 0;
      }

      .gallery-enhancer-shell.viewport-portrait {
        width: 100vw;
        height: 100vh;
      }

      .gallery-enhancer-stage {
        width: 100%;
        height: 100%;
        display: flex;
        align-items: center;
        justify-content: center;
        background: #020817;
        overflow: hidden;
        touch-action: pan-y;
      }

      .gallery-enhancer-image {
        display: block;
        width: 100%;
        height: 100%;
        object-fit: cover;
        background: #020817;
        transition: transform 0.35s ease;
        transform: rotate(0deg);
        margin: 0;
        padding: 0;
        border: none;
      }

      .gallery-enhancer-shell.is-landscape .gallery-enhancer-image {
        width: auto;
        height: auto;
        max-width: 100vw;
      }

      .gallery-enhancer-shell.is-portrait .gallery-enhancer-image {
        width: 100%;
        height: auto;
        max-height: 100vh;
      }

      .gallery-enhancer-arrow {
        position: absolute;
        top: 50%;
        width: 52px;
        height: 52px;
        border: none;
        border-radius: 50%;
        background: rgba(255, 255, 255, 0.15);
        color: white;
        font-size: 30px;
        line-height: 1;
        cursor: pointer;
        backdrop-filter: blur(6px);
        opacity: 0;
        pointer-events: auto;
        transition: opacity 0.2s ease, transform 0.2s ease;
        z-index: 2;
      }

      .gallery-enhancer-arrow.visible {
        opacity: 1;
      }

      .gallery-enhancer-arrow.prev {
        left: 18px;
      }

      .gallery-enhancer-arrow.next {
        right: 18px;
      }

      .gallery-enhancer-shell.viewport-portrait .gallery-enhancer-arrow {
        top: auto;
        bottom: 18px;
        transform: none;
      }

      .gallery-enhancer-shell.viewport-portrait .gallery-enhancer-arrow.prev {
        left: 24px;
      }

      .gallery-enhancer-shell.viewport-portrait .gallery-enhancer-arrow.next {
        right: 24px;
      }

      .gallery-enhancer-close {
        position: absolute;
        top: 14px;
        right: 14px;
        width: 42px;
        height: 42px;
        border: none;
        border-radius: 50%;
        background: rgba(15, 23, 42, 0.6);
        color: white;
        font-size: 28px;
        line-height: 1;
        cursor: pointer;
        z-index: 3;
      }

      .gallery-enhancer-rotate {
        position: absolute;
        top: 14px;
        left: 14px;
        z-index: 3;
        border: none;
        border-radius: 999px;
        background: rgba(255, 255, 255, 0.12);
        color: white;
        padding: 9px 14px;
        font-size: 12px;
        font-weight: 700;
        cursor: pointer;
      }

      .gallery-enhancer-count {
        position: absolute;
        bottom: 18px;
        right: 18px;
        z-index: 3;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 88px;
        padding: 8px 12px;
        border-radius: 999px;
        background: rgba(15, 23, 42, 0.7);
        color: white;
        font-size: 13px;
        font-weight: 700;
      }
    `;

    document.head.appendChild(style);
  }

  function getCasaTitle(card) {
    const nome = card && card.querySelector('.nome');
    if (!nome) {
      return 'Galeria da casa';
    }

    const text = nome.textContent.replace(/\s+/g, ' ').trim();
    return text || 'Galeria da casa';
  }

  function getStorageKey(baseName) {
    return 'gallery-orientation-' + (baseName || 'default');
  }

  function readOrientation(baseName) {
    try {
      const value = localStorage.getItem(getStorageKey(baseName));
      return value === 'portrait' ? 'portrait' : 'landscape';
    } catch (error) {
      return 'landscape';
    }
  }

  function saveOrientation(baseName, orientation) {
    try {
      localStorage.setItem(getStorageKey(baseName), orientation === 'portrait' ? 'portrait' : 'landscape');
    } catch (error) {
      // sem fallback necessário
    }
  }

  function getBaseNameFromSrc(src) {
    if (!src) {
      return '';
    }

    const cleanSrc = src.split('?')[0];
    const fileName = cleanSrc.split('/').pop();
    const withoutExtension = fileName.replace(/\.[^/.]+$/, '');

    if (!withoutExtension) {
      return '';
    }

    return withoutExtension.replace(/_\d+$/, '');
  }

  function getImageIndexFromSrc(src) {
    if (!src) {
      return 0;
    }

    const match = String(src).match(/_(\d+)(?:\.[a-zA-Z0-9]+)?$/);
    if (!match) {
      return 0;
    }

    return Math.max(0, Number(match[1]) - 1);
  }

  function buildGalleryUrls(baseName) {
    const urls = [];
    for (let index = 1; index <= TOTAL_IMAGENS; index += 1) {
      urls.push('thumbnails/' + baseName + '_' + index + '.jpg');
    }
    return urls;
  }

  function syncViewportMode() {
    if (!state.modal) {
      return;
    }

    const shell = state.modal.querySelector('.gallery-enhancer-shell');
    if (!shell) {
      return;
    }

    const isPortraitViewport = window.matchMedia('(orientation: portrait)').matches;
    shell.classList.toggle('viewport-portrait', isPortraitViewport);
    shell.classList.toggle('viewport-landscape', !isPortraitViewport);
  }

  function showArrows() {
    if (!state.modal) {
      return;
    }

    const arrows = state.modal.querySelectorAll('.gallery-enhancer-arrow');
    arrows.forEach(function (arrow) {
      arrow.classList.add('visible');
    });

    if (state.hideTimer) {
      clearTimeout(state.hideTimer);
    }

    state.hideTimer = setTimeout(function () {
      arrows.forEach(function (arrow) {
        arrow.classList.remove('visible');
      });
    }, 2200);
  }

  function applyOrientation() {
    if (!state.modal) {
      return;
    }

    const shell = state.modal.querySelector('.gallery-enhancer-shell');
    const rotateButton = state.modal.querySelector('.gallery-enhancer-rotate');

    if (!shell) {
      return;
    }

    const orientation = state.orientation || 'landscape';
    shell.classList.toggle('is-portrait', orientation === 'portrait');
    shell.classList.toggle('is-landscape', orientation === 'landscape');
    if (rotateButton) {
      rotateButton.textContent = orientation === 'landscape' ? 'Virar para vertical' : 'Virar para horizontal';
      rotateButton.setAttribute('aria-label', orientation === 'landscape' ? 'Virar para vertical' : 'Virar para horizontal');
    }

    syncViewportMode();
  }

  function renderSlide() {
    if (!state.modal) {
      return;
    }

    const image = state.modal.querySelector('.gallery-enhancer-image');
    const count = state.modal.querySelector('.gallery-enhancer-count');

    if (!image || state.urls.length === 0) {
      return;
    }

    state.currentIndex = Math.min(Math.max(state.currentIndex, 0), state.urls.length - 1);
    image.src = state.urls[state.currentIndex];
    image.alt = (state.card ? getCasaTitle(state.card) : 'Galeria da casa') + ' - imagem ' + (state.currentIndex + 1);
    count.textContent = (state.currentIndex + 1) + ' / ' + state.urls.length;
    applyOrientation();
  }

  function buildModal() {
    if (state.modal) {
      return state.modal;
    }

    const modal = document.createElement('div');
    modal.id = 'gallery-enhancer-modal';
    modal.className = 'gallery-enhancer-modal';
    modal.setAttribute('aria-hidden', 'true');

    modal.innerHTML = `
      <div class="gallery-enhancer-shell" role="dialog" aria-modal="true" aria-labelledby="gallery-enhancer-title">
        <button type="button" class="gallery-enhancer-rotate" aria-label="Virar imagem">Virar para vertical</button>
        <button type="button" class="gallery-enhancer-close" aria-label="Fechar galeria">×</button>
        <button type="button" class="gallery-enhancer-arrow prev" aria-label="Imagem anterior">‹</button>
        <div class="gallery-enhancer-stage">
          <img class="gallery-enhancer-image" alt="Imagem da casa" draggable="false" />
        </div>
        <button type="button" class="gallery-enhancer-arrow next" aria-label="Próxima imagem">›</button>
        <div class="gallery-enhancer-count">1 / 30</div>
      </div>
    `;

    const closeButton = modal.querySelector('.gallery-enhancer-close');
    const prevButton = modal.querySelector('.gallery-enhancer-arrow.prev');
    const nextButton = modal.querySelector('.gallery-enhancer-arrow.next');
    const rotateButton = modal.querySelector('.gallery-enhancer-rotate');
    const shell = modal.querySelector('.gallery-enhancer-shell');
    const stage = modal.querySelector('.gallery-enhancer-stage');

    rotateButton.addEventListener('click', function () {
      state.orientation = state.orientation === 'landscape' ? 'portrait' : 'landscape';
      if (state.baseName) {
        saveOrientation(state.baseName, state.orientation);
      }
      applyOrientation();
      showArrows();
    });

    closeButton.addEventListener('click', function () {
      modal.classList.remove('visible');
      modal.setAttribute('aria-hidden', 'true');
      document.body.style.overflow = '';
      if (state.hideTimer) {
        clearTimeout(state.hideTimer);
      }
    });

    function goPrev() {
      if (state.urls.length === 0) {
        return;
      }
      state.currentIndex = (state.currentIndex - 1 + state.urls.length) % state.urls.length;
      renderSlide();
      showArrows();
    }

    function goNext() {
      if (state.urls.length === 0) {
        return;
      }
      state.currentIndex = (state.currentIndex + 1) % state.urls.length;
      renderSlide();
      showArrows();
    }

    prevButton.addEventListener('click', goPrev);
    nextButton.addEventListener('click', goNext);

    stage.addEventListener('pointerdown', function (event) {
      state.touchStartX = event.clientX;
      state.touchStartY = event.clientY;
      state.isDragging = true;
      showArrows();
    }, { passive: true });

    stage.addEventListener('pointerup', function (event) {
      if (!state.isDragging) {
        return;
      }

      const deltaX = event.clientX - state.touchStartX;
      const deltaY = event.clientY - state.touchStartY;

      if (Math.abs(deltaX) > 60 && Math.abs(deltaX) > Math.abs(deltaY)) {
        if (deltaX < 0) {
          goNext();
        } else {
          goPrev();
        }
      }

      state.isDragging = false;
    }, { passive: true });

    shell.addEventListener('pointermove', function () {
      showArrows();
    });

    modal.addEventListener('click', function (event) {
      if (event.target === modal) {
        modal.classList.remove('visible');
        modal.setAttribute('aria-hidden', 'true');
        document.body.style.overflow = '';
      }
    });

    document.addEventListener('keydown', function (event) {
      if (!modal.classList.contains('visible')) {
        return;
      }

      if (event.key === 'Escape') {
        modal.classList.remove('visible');
        modal.setAttribute('aria-hidden', 'true');
        document.body.style.overflow = '';
      }

      if (event.key === 'ArrowLeft') {
        goPrev();
      }

      if (event.key === 'ArrowRight') {
        goNext();
      }
    });

    document.body.appendChild(modal);
    state.modal = modal;
    syncViewportMode();
    return modal;
  }

  function openGallery(card, startIndex) {
    const images = card ? card.querySelectorAll('.imagens img') : [];
    if (!images.length) {
      return;
    }

    const baseImage = images[0];
    const baseName = getBaseNameFromSrc(baseImage.getAttribute('src'));
    if (!baseName) {
      return;
    }

    state.card = card;
    state.baseName = baseName;
    state.urls = buildGalleryUrls(baseName);
    state.currentIndex = Number.isInteger(startIndex) ? startIndex : 0;
    state.orientation = 'landscape';

    const savedOrientation = readOrientation(baseName);
    if (savedOrientation === 'portrait') {
      state.orientation = 'portrait';
    }

    const modal = buildModal();
    modal.classList.add('visible');
    modal.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';
    applyOrientation();
    renderSlide();
    showArrows();
  }

  function enhanceCards() {
    document.querySelectorAll('.casa').forEach(function (card) {
      const imagens = card.querySelector('.imagens');
      if (!imagens) {
        return;
      }

      const button = imagens.querySelector('.gallery-enhancer-btn');
      if (!button) {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'gallery-enhancer-btn';
        btn.textContent = 'Ver mais';
        btn.addEventListener('click', function (event) {
          event.stopPropagation();
          openGallery(card, 0);
        });
        imagens.appendChild(btn);
      }

      const imageNodes = imagens.querySelectorAll('img');
      imageNodes.forEach(function (img) {
        img.style.cursor = 'pointer';
        img.addEventListener('click', function (event) {
          event.preventDefault();
          event.stopPropagation();
          openGallery(card, getImageIndexFromSrc(img.getAttribute('src')));
        });
      });
    });
  }

  function init() {
    ensureStyles();
    enhanceCards();
    window.addEventListener('orientationchange', function () {
      if (state.modal && state.modal.classList.contains('visible')) {
        syncViewportMode();
      }
    });
    window.addEventListener('resize', function () {
      if (state.modal && state.modal.classList.contains('visible')) {
        syncViewportMode();
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
