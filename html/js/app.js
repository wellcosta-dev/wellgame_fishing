const gotfish = document.getElementById('gotfish');
const tensionHud = document.getElementById('tension-hud');
const spindleHud = document.getElementById('spindle-hud');
const chargeHud = document.getElementById('charge-hud');
const tensionFill = document.getElementById('tension-fill');
const tengrad = document.getElementById('tengrad');
const chargeFill = document.getElementById('charge-fill');
const orsol = document.getElementById('orsol');
const orso2 = document.getElementById('orso2');
const orso3 = document.getElementById('orso3');
const orso4 = document.getElementById('orso4');
const lineInt = document.getElementById('line-int');
const lineDec = document.getElementById('line-dec');
const gears = document.querySelectorAll('#gears span');
const win = document.getElementById('win');
const sell = document.getElementById('sell');
const sellGame = document.getElementById('sell-game');
const sellGameFill = document.getElementById('sell-game-fill');
const sellGameCursor = document.getElementById('sell-game-cursor');
const floatDepth = document.getElementById('float-depth');
const floatImg = document.getElementById('float-img');
const floatDepthLabel = document.getElementById('float-depth-label');
const tournament = document.getElementById('tournament');
const tournamentList = document.getElementById('tournament-list');
const tournamentEmpty = document.getElementById('tournament-empty');
const tournamentLive = document.getElementById('tournament-live');
const tournamentLiveList = document.getElementById('tournament-live-list');
const tournamentWin = document.getElementById('tournament-win');
const npcTagsContainer = document.getElementById('npc-tags');
const npcTagEls = new Map();

let gotFishTimer = null;
let spindleRot = 0;
let sellGameMin = 0;
let sellGameMax = 0;
let tournamentTimer = null;

function resName() {
  return typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'wellgame_fishing';
}

function post(name, data) {
  return fetch('https://' + resName() + '/' + name, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  });
}

function formatMoney(n) {
  n = Math.floor(Number(n) || 0);
  const neg = n < 0;
  const s = String(Math.abs(n));
  const parts = [];
  for (let i = s.length; i > 0; i -= 3) {
    parts.unshift(s.slice(Math.max(0, i - 3), i));
  }
  return (neg ? '-' : '') + parts.join(' ');
}

const soundPool = {};
const loopPool = {};
let sharedAudioCtx = null;

function getAudioCtx() {
  if (!sharedAudioCtx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    sharedAudioCtx = new AC();
  }
  return sharedAudioCtx;
}

function playSound(file, volume) {
  try {
    const key = String(file || '');
    if (!key) return;
    if (!soundPool[key]) {
      const a = new Audio('nui://' + resName() + '/sounds/' + key);
      a.preload = 'auto';
      soundPool[key] = a;
    }
    const a = soundPool[key];
    a.pause();
    a.currentTime = 0;
    a.playbackRate = 1;
    a.volume = Math.max(0, Math.min(1, Number(volume) || 0.5));
    a.play().catch(() => {});
  } catch (_) {}
}

/**
 * Continuous reel/spindle loop.
 * Web Audio GainNode (smooth volume) — never playbackRate (CEF warbles MP3).
 * Pause when silent so loops don't keep decoding under mute spam.
 */
function setLoopSound(id, file, volume) {
  try {
    const key = String(id || '');
    if (!key) return;
    const vol = Math.max(0, Math.min(1, Number(volume) || 0));
    const ctx = getAudioCtx();

    if (!loopPool[key]) {
      const a = new Audio('nui://' + resName() + '/sounds/' + (file || 'reel.mp3'));
      a.preload = 'auto';
      a.loop = true;
      a.volume = 1; // gain node owns loudness
      a.playbackRate = 1;
      const entry = { a, gain: null, lastVol: -1 };
      if (ctx) {
        try {
          const src = ctx.createMediaElementSource(a);
          const gain = ctx.createGain();
          gain.gain.value = 0;
          src.connect(gain);
          gain.connect(ctx.destination);
          entry.gain = gain;
        } catch (_) {
          a.volume = 0;
        }
      } else {
        a.volume = 0;
      }
      loopPool[key] = entry;
    }

    const L = loopPool[key];
    L.a.playbackRate = 1;

    if (L.gain && ctx) {
      if (ctx.state === 'suspended') ctx.resume().catch(() => {});
      const g = L.gain.gain;
      try {
        g.cancelScheduledValues(ctx.currentTime);
        g.setTargetAtTime(vol, ctx.currentTime, 0.04);
      } catch (_) {
        g.value = vol;
      }
    } else {
      L.a.volume = vol;
    }

    if (vol > 0.001) {
      if (L.a.paused) L.a.play().catch(() => {});
    } else if (!L.a.paused) {
      L.a.pause();
    }
    L.lastVol = vol;
  } catch (_) {}
}

// Fekete orsótest + damil-színű, feltekert-mennyiség-arányos vastagságú gyűrű
const orsolCtx = orsol.getContext('2d');
const ORSOL_R = 56;
const ORSOL_MIN_THICK = 10;
const ORSOL_MAX_THICK = 40;
let lastOrsolColor = [173, 176, 151];

function drawOrsol(lineLength, rgb) {
  if (Array.isArray(rgb) && rgb.length >= 3) lastOrsolColor = rgb;
  const [r, g, b] = lastOrsolColor;
  const len = Math.max(0, Math.min(100, Number(lineLength) || 0));
  const wound = 1 - (len / 100) * 0.72; // 1 = tele orsó, kevesebb = jobban le van tekerve
  const thickness = ORSOL_MIN_THICK + (ORSOL_MAX_THICK - ORSOL_MIN_THICK) * wound;

  orsolCtx.clearRect(0, 0, 128, 128);
  orsolCtx.fillStyle = '#0a0a0a';
  orsolCtx.beginPath();
  orsolCtx.arc(64, 64, ORSOL_R, 0, Math.PI * 2);
  orsolCtx.fill();

  orsolCtx.strokeStyle = `rgb(${r},${g},${b})`;
  orsolCtx.lineWidth = thickness;
  orsolCtx.beginPath();
  orsolCtx.arc(64, 64, ORSOL_R - thickness / 2, 0, Math.PI * 2);
  orsolCtx.stroke();
}

function setGears(gear) {
  gear = Math.max(1, Math.min(5, Number(gear) || 1));
  gears.forEach((el) => {
    const g = Number(el.getAttribute('data-g'));
    el.classList.toggle('active', g === gear);
  });
}

function setLineLength(len) {
  len = Math.max(0, Number(len) || 0);
  const whole = Math.floor(len);
  const frac = Math.floor((len % 1) * 10);
  lineInt.textContent = String(whole);
  lineDec.textContent = '.' + frac + ' m';
}

function setTension(t) {
  // v4: fill width = clamp(tension, 0, 1); gradient spans FULL track, clipped by fill
  t = Number(t) || 0;
  const p = Math.max(0, Math.min(1, t));
  const pct = p * 100;
  const track = tensionFill && tensionFill.parentElement;
  const trackW = track ? track.clientWidth : 700;
  tensionFill.style.backgroundSize = trackW + 'px 100%';
  tensionFill.style.width = pct + '%';
  if (t > 0.6) {
    tengrad.classList.remove('hidden');
    tengrad.classList.add('visible');
    const a = Math.min(1, (t - 0.6) / 0.4);
    tengrad.style.opacity = String(a);
    tengrad.style.right = (100 - pct - 2) + '%';
  } else {
    tengrad.classList.remove('visible');
    tengrad.style.opacity = '0';
  }
}

function setFloatDepth(depth, floatingValue, underwater) {
  if (!floatDepth) return;
  depth = Math.max(2.5, Math.min(6.5, Number(depth) || 2.5));
  floatingValue = Math.max(0, Math.min(1, Number(floatingValue) || 0));
  underwater = Math.max(0, Math.min(1, Number(underwater) || 0));
  const topPct = 18 + (1 - floatingValue) * 28 + underwater * 22;
  floatImg.style.top = topPct + '%';
  floatDepthLabel.textContent = depth.toFixed(1) + ' m';
}

// v4-parity: 'catching' holds the banner indefinitely, 'catched' holds it 5s more,
// anything else fades it out — matches sourceC.lua's gotFishNoti/preRenderPlayerGui.
let gotFishState = false; // false | true (catching) | <ms remaining> (catched hold)
let gotFishA = 0;
let gotFishLast = 0;

function setGotFish(state) {
  if (state === 'catching') {
    if (!gotFishState) playSound('gotfish.mp3', 0.65);
    gotFishState = true;
  } else if (state === 'catched') {
    gotFishState = 5000;
  } else {
    gotFishState = false;
  }
  if (!gotFishTimer) {
    gotfish.classList.remove('hidden');
    gotFishLast = performance.now();
    gotFishTimer = requestAnimationFrame(gotFishTick);
  }
}

function gotFishTick(now) {
  const delta = now - gotFishLast;
  gotFishLast = now;
  if (gotFishState) {
    gotFishA = Math.min(1, gotFishA + (3 * delta) / 600);
    if (typeof gotFishState === 'number') {
      gotFishState -= delta;
      if (gotFishState <= 0) gotFishState = false;
    }
  } else {
    gotFishA = Math.max(0, gotFishA - (3 * delta) / 5000);
  }
  const scale = gotFishA;
  const scale2 = scale * scale;
  const alpha = Math.min(1, gotFishA * 5);
  gotfish.style.setProperty('--gf-scale', String(scale));
  gotfish.style.setProperty('--gf-scale2', String(scale2));
  gotfish.style.setProperty('--gf-alpha', String(alpha));
  if (gotFishA > 0 || gotFishState) {
    gotFishTimer = requestAnimationFrame(gotFishTick);
  } else {
    gotfish.classList.add('hidden');
    gotFishTimer = null;
  }
}

function setSpindleVisible(show) {
  if (show) {
    spindleHud.classList.remove('hidden');
  } else {
    spindleHud.classList.add('hidden');
    tensionHud.classList.add('hidden');
    chargeHud.classList.add('hidden');
    if (floatDepth) floatDepth.classList.add('hidden');
  }
}

function setTensionVisible(show) {
  if (show) tensionHud.classList.remove('hidden');
  else {
    tensionHud.classList.add('hidden');
    tengrad.classList.remove('visible');
    tengrad.style.opacity = '0';
  }
}

function formatTimeMs(ms) {
  ms = Math.max(0, Number(ms) || 0);
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const rem = s % 60;
  return m > 0 ? m + ':' + String(rem).padStart(2, '0') : rem + 's';
}

function updateTournamentBoardData(rows) {
  if (!tournamentList) return;
  tournamentList.innerHTML = '';
  const list = Array.isArray(rows) ? rows : [];
  if (list.length === 0) {
    tournamentEmpty.classList.remove('hidden');
  } else {
    tournamentEmpty.classList.add('hidden');
    list.forEach((r, i) => {
      const li = document.createElement('li');
      const fish = r.fish ? '<span class="tournament-fish">' + r.fish + '</span>' : '';
      li.innerHTML =
        '<span class="tournament-rank">' + (i + 1) + '</span>' +
        '<span class="tournament-name">' + (r.name || '?') + fish + '</span>' +
        '<span class="tournament-weight">' + (Number(r.weight) || 0).toFixed(1) + ' kg</span>';
      tournamentList.appendChild(li);
    });
  }
}

function showTournamentBoard() {
  if (!tournament) return;
  if (tournamentTimer) clearTimeout(tournamentTimer);
  tournament.classList.remove('hidden');
  tournamentTimer = setTimeout(() => tournament.classList.add('hidden'), 12000);
}

function renderTournamentLive(data) {
  if (!tournamentLive) return;
  if (!data || !data.rows || data.rows.length === 0) {
    tournamentLive.classList.add('hidden');
    return;
  }
  const vw = window.innerWidth || 1;
  const vh = window.innerHeight || 1;
  tournamentLive.classList.remove('hidden');
  tournamentLive.style.opacity = String(Math.max(0, Math.min(1, Number(data.alpha) || 1)));
  // GetScreenCoordFromWorldCoord → 0..1, pixelre skálázva (mint wellgame-nametag)
  tournamentLive.style.transform =
    'translate3d(' + (Number(data.x) || 0) * vw + 'px, ' + (Number(data.y) || 0) * vh + 'px, 0) translate(-50%, -100%)';
  tournamentLiveList.innerHTML = '';
  data.rows.forEach((r) => {
    const li = document.createElement('li');
    li.innerHTML =
      '<span class="tlive-rank">' + r.rank + '.</span>' +
      '<span class="tlive-name">' + (r.name || '?') + '</span>' +
      '<span class="tlive-weight">' + (Number(r.weight) || 0).toFixed(1) + ' kg</span>';
    tournamentLiveList.appendChild(li);
  });
}

function showTournamentWin(d) {
  if (!tournamentWin) return;
  document.getElementById('tournament-win-name').textContent = d.name || '?';
  document.getElementById('tournament-win-stats').textContent =
    (Number(d.weight) || 0).toFixed(1) + ' kg · ' + (d.fish || '?');
  tournamentWin.classList.remove('hidden');
  playSound('gotfishdrum.mp3', 0.55);
  playSound('legendary.wav', 0.6);
  setTimeout(() => tournamentWin.classList.add('hidden'), 7000);
}

window.addEventListener('message', (e) => {
  const msg = e.data || {};
  if (msg.action === 'showHud') {
    setSpindleVisible(true);
    if (msg.data && msg.data.lineColor) drawOrsol(0, msg.data.lineColor);
  } else if (msg.action === 'hideHud') {
    setSpindleVisible(false);
    setGotFish(false);
  } else if (msg.action === 'updateHud') {
    const d = msg.data || {};
    const m = d.mode || 'idle';
    // Tension only when line is in the water / fighting — not idle/aim/getout
    const tensionModes = { throw: 1, waiting: 1, catching: 1, catched: 1 };
    setTensionVisible(!!tensionModes[m]);
    setTension(d.tension || 0);
    setGears(d.gear || 1);
    setLineLength(d.lineLength != null ? d.lineLength : d.line || 0);

    if (d.spindleRot != null) {
      spindleRot = d.spindleRot;
    }
    const rot = `rotate(${(-(d.lineLength || 0) / 1.15) * 360}deg)`;
    const rot2 = `rotate(${-spindleRot * 360}deg)`;
    orso2.style.transform = rot;
    orso3.style.transform = rot2;
    orso4.style.transform = rot2;

    drawOrsol(d.lineLength, d.lineColor);

    if (d.charging) {
      chargeHud.classList.remove('hidden');
      chargeFill.style.width = Math.min(100, (d.charge || 0) * 100) + '%';
    } else {
      chargeHud.classList.add('hidden');
    }

    const inWater = d.mode === 'waiting' || d.mode === 'catching' || d.mode === 'catched' || d.mode === 'throw' || d.mode === 'fighting';
    if (floatDepth) {
      if (inWater) {
        floatDepth.classList.remove('hidden');
        setFloatDepth(d.floatDepth, d.floatingValue, d.lineUnderwater);
      } else {
        floatDepth.classList.add('hidden');
      }
    }
  } else if (msg.action === 'gotFish') {
    setGotFish(msg.state);
  } else if (msg.action === 'catchWin') {
    const d = msg.data || {};
    win.classList.remove('hidden');
    const cls = document.getElementById('win-class');
    cls.textContent = (d.class || 'Common').toUpperCase();
    cls.className = 'win-class';
    const c = (d.class || '').toLowerCase();
    if (c === 'rare') cls.classList.add('is-rare');
    if (c === 'epic') cls.classList.add('is-epic');
    if (c === 'legendary') cls.classList.add('is-legendary');
    const glowColors = { common: '#06b6d4', rare: '#f3d65a', epic: '#e74c3c', legendary: '#a855f7' };
    win.style.setProperty('--win-glow-color', glowColors[c] || glowColors.common);
    document.getElementById('win-name').textContent = d.name || 'Hal';
    document.getElementById('win-stats').textContent =
      (d.weight || '?') + ' kg · ' + (d.length || '?') + ' cm';
    const meta = document.getElementById('win-meta');
    if (meta) {
      const parts = [];
      if (d.rod) parts.push(d.rod);
      if (d.timeMs != null) parts.push(formatTimeMs(d.timeMs));
      meta.textContent = parts.join(' · ');
    }
    setTimeout(() => win.classList.add('hidden'), 4500);
    playSound('gotfishdrum.mp3', 0.45);
  } else if (msg.action === 'openSellConfirm') {
    const d = msg.data || {};
    document.getElementById('sell-name').textContent = d.name || 'Hal';
    document.getElementById('sell-length').textContent =
      'Hossz: ' + (d.length || '?') + ' cm';
    document.getElementById('sell-range').innerHTML =
      'Eladási ár: <span class="hi">' + formatMoney(d.minPrice) + ' – ' + formatMoney(d.maxPrice) + ' $</span>';
    sell.classList.remove('hidden');
    sellGame.classList.add('hidden');
    sellGame.classList.remove('visible');
    sellGame.style.opacity = '0';
  } else if (msg.action === 'startSellGame') {
    const d = msg.data || {};
    sell.classList.add('hidden');
    sellGameMin = d.minPrice || 0;
    sellGameMax = d.maxPrice || 0;
    document.getElementById('sell-game-left').textContent = formatMoney(sellGameMin) + ' $';
    document.getElementById('sell-game-right').textContent = formatMoney(sellGameMin) + ' $';
    document.getElementById('sell-game-mid').textContent = formatMoney(sellGameMax) + ' $';
    sellGameFill.style.width = '0%';
    sellGameCursor.style.left = '0%';
    sellGameCursor.textContent = formatMoney(sellGameMin) + ' $';
    sellGameCursor.style.color = '#3cb882';
    sellGame.classList.remove('hidden');
    sellGame.classList.add('visible');
    sellGame.style.opacity = '0';
  } else if (msg.action === 'updateSellGame') {
    const d = msg.data || {};
    const prog = Math.max(0, Math.min(1, Number(d.progress) || 0));
    const quality = Math.max(0, Math.min(1, Number(d.quality) || 0));
    const alpha = d.alpha != null ? Math.max(0, Math.min(1, Number(d.alpha))) : 1;
    const minP = d.minPrice != null ? d.minPrice : sellGameMin;
    const maxP = d.maxPrice != null ? d.maxPrice : sellGameMax;
    const price = Math.floor(minP + (maxP - minP) * quality);
    const pct = prog * 100;
    sellGameFill.style.width = pct + '%';
    // Pontosan a sáv végén — ne legyen 6%/94% clamp (az elején „lemaradt” a címke)
    sellGameCursor.style.left = pct + '%';
    sellGameCursor.textContent = formatMoney(price) + ' $';
    sellGameCursor.style.color = '#3cb882';
    sellGame.style.opacity = String(alpha);
  } else if (msg.action === 'closeSell') {
    sell.classList.add('hidden');
    sellGame.classList.add('hidden');
    sellGame.classList.remove('visible');
    sellGame.style.opacity = '0';
  } else if (msg.action === 'playSound') {
    playSound(msg.file, msg.volume);
  } else if (msg.action === 'loopSound') {
    setLoopSound(msg.id, msg.file, msg.volume);
  } else if (msg.action === 'openShop') {
    openShopUi(msg.data || {});
  } else if (msg.action === 'closeShop') {
    if (fishShop) {
      fishShop.classList.add('hidden');
      fishShop.setAttribute('aria-hidden', 'true');
    }
  } else if (msg.action === 'shopCash') {
    setShopCash(msg.cash);
    if (typeof renderShopDetail === 'function') renderShopDetail();
  } else if (msg.action === 'openFishLog') {
    openFishLogUi(msg);
  } else if (msg.action === 'closeFishLog') {
    if (fishLog) {
      fishLog.classList.add('hidden');
      fishLog.setAttribute('aria-hidden', 'true');
    }
  } else if (msg.action === 'tournamentBoard') {
    updateTournamentBoardData(msg.data || []);
  } else if (msg.action === 'tournamentBoardShow') {
    showTournamentBoard();
  } else if (msg.action === 'updateTournamentLive') {
    renderTournamentLive(msg.data);
  } else if (msg.action === 'tournamentWin') {
    showTournamentWin(msg.data || {});
  } else if (msg.action === 'updateNpcTags') {
    renderNpcTags(msg.tags || []);
  }
});

function renderNpcTags(tags) {
  const seen = new Set();
  const vw = window.innerWidth || 1;
  const vh = window.innerHeight || 1;
  for (const t of tags) {
    seen.add(t.id);
    let el = npcTagEls.get(t.id);
    if (!el) {
      el = document.createElement('div');
      el.className = 'npc-tag';
      el.innerHTML =
        '<div class="npc-tag-name"></div>' +
        '<div class="npc-tag-role"></div>';
      npcTagsContainer.appendChild(el);
      npcTagEls.set(t.id, el);
    }
    const nameEl = el.querySelector('.npc-tag-name');
    const roleEl = el.querySelector('.npc-tag-role');
    const name = t.name || '';
    const role = t.role || 'Hal felvásárló';
    if (nameEl && nameEl.textContent !== name) nameEl.textContent = name;
    if (roleEl && roleEl.textContent !== role) roleEl.textContent = role;
    const scale = Number(t.scale) || 0.5;
    el.style.fontSize = 28 * scale + 'px';
    el.style.opacity = String(Number(t.alpha) || 1);
    // GetScreenCoordFromWorldCoord → 0..1 (wellgame-nametag ugyanígy skáláz)
    el.style.transform =
      'translate3d(' + (Number(t.x) || 0) * vw + 'px, ' + (Number(t.y) || 0) * vh + 'px, 0) translate(-50%, -100%)';
  }
  for (const [id, el] of npcTagEls) {
    if (!seen.has(id)) {
      el.remove();
      npcTagEls.delete(id);
    }
  }
}

document.getElementById('sell-btn').addEventListener('click', () => post('sellStartGame', {}));
document.getElementById('sell-close').addEventListener('click', () => post('sellCancel', {}));
const tournamentClose = document.getElementById('tournament-close');
if (tournamentClose) {
  tournamentClose.addEventListener('click', () => {
    if (tournamentTimer) clearTimeout(tournamentTimer);
    tournament.classList.add('hidden');
  });
}

/* ===== Horgászbolt ===== */
const fishShop = document.getElementById('fish-shop');
const fishShopGrid = document.getElementById('fish-shop-grid');
const fishShopCats = document.getElementById('fish-shop-cats');
const fishShopDetail = document.getElementById('fish-shop-detail');
const fishShopCash = document.getElementById('fish-shop-cash');
let shopItems = [];
let shopCategories = [];
let shopCategory = 'all';
let shopSelected = null;
let shopCash = 0;

function invImage(file) {
  return 'nui://qb-inventory/html/images/' + (file || 'placeholder.png');
}

function formatShopMoney(n) {
  return formatMoney(n) + ' $';
}

function setShopCash(n) {
  shopCash = Math.max(0, Math.floor(Number(n) || 0));
  if (fishShopCash) fishShopCash.textContent = formatShopMoney(shopCash);
}

function closeShopUi() {
  if (!fishShop) return;
  fishShop.classList.add('hidden');
  fishShop.setAttribute('aria-hidden', 'true');
  shopSelected = null;
  post('shopClose', {});
}

function renderShopCats() {
  if (!fishShopCats) return;
  fishShopCats.innerHTML = '';
  shopCategories.forEach((c) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'fish-shop-cat' + (c.id === shopCategory ? ' is-active' : '');
    btn.textContent = c.label || c.id;
    btn.addEventListener('click', () => {
      shopCategory = c.id;
      renderShopCats();
      renderShopGrid();
    });
    fishShopCats.appendChild(btn);
  });
}

function filteredShopItems() {
  if (shopCategory === 'all') return shopItems;
  return shopItems.filter((it) => it.category === shopCategory);
}

function renderShopGrid() {
  if (!fishShopGrid) return;
  fishShopGrid.innerHTML = '';
  const list = filteredShopItems();
  list.forEach((it) => {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'fish-shop-card' + (shopSelected && shopSelected.item === it.item ? ' is-selected' : '');
    const imgWrap = document.createElement('div');
    imgWrap.className = 'fish-shop-card-img';
    const img = document.createElement('img');
    img.alt = it.label || '';
    img.src = invImage(it.image);
    img.onerror = () => {
      img.onerror = null;
      img.src = invImage('placeholder.png');
    };
    imgWrap.appendChild(img);
    const meta = document.createElement('div');
    meta.className = 'fish-shop-card-meta';
    meta.innerHTML =
      '<div class="fish-shop-card-name"></div><div class="fish-shop-card-price"></div>';
    meta.querySelector('.fish-shop-card-name').textContent = it.label || it.item;
    meta.querySelector('.fish-shop-card-price').textContent = formatShopMoney(it.price);
    card.appendChild(imgWrap);
    card.appendChild(meta);
    card.addEventListener('click', () => {
      shopSelected = it;
      renderShopGrid();
      renderShopDetail();
    });
    fishShopGrid.appendChild(card);
  });
}

function renderShopDetail() {
  if (!fishShopDetail) return;
  if (!shopSelected) {
    fishShopDetail.innerHTML = '<div class="fish-shop-detail-empty">Válassz egy terméket</div>';
    return;
  }
  const it = shopSelected;
  const catLabel = (shopCategories.find((c) => c.id === it.category) || {}).label || it.category || '';
  const canBuy = shopCash >= (it.price || 0);
  fishShopDetail.innerHTML = '';
  const imgBox = document.createElement('div');
  imgBox.className = 'fish-shop-detail-img';
  const img = document.createElement('img');
  img.alt = it.label || '';
  img.src = invImage(it.image);
  img.onerror = () => {
    img.onerror = null;
    img.src = invImage('placeholder.png');
  };
  imgBox.appendChild(img);
  const cat = document.createElement('div');
  cat.className = 'fish-shop-detail-cat';
  cat.textContent = catLabel;
  const name = document.createElement('div');
  name.className = 'fish-shop-detail-name';
  name.textContent = it.label || it.item;
  const desc = document.createElement('p');
  desc.className = 'fish-shop-detail-desc';
  desc.textContent = it.desc || '';
  const price = document.createElement('div');
  price.className = 'fish-shop-detail-price';
  price.textContent = formatShopMoney(it.price);
  const buy = document.createElement('button');
  buy.type = 'button';
  buy.className = 'fish-shop-buy';
  buy.textContent = canBuy ? 'Megvásárlás' : 'Nincs elég készpénz';
  buy.disabled = !canBuy;
  buy.addEventListener('click', () => {
    if (!shopSelected) return;
    post('shopBuy', { item: shopSelected.item });
  });
  fishShopDetail.appendChild(imgBox);
  fishShopDetail.appendChild(cat);
  fishShopDetail.appendChild(name);
  fishShopDetail.appendChild(desc);
  fishShopDetail.appendChild(price);
  fishShopDetail.appendChild(buy);
}

function openShopUi(data) {
  if (!fishShop) return;
  const d = data || {};
  shopItems = Array.isArray(d.items) ? d.items : [];
  shopCategories = Array.isArray(d.categories) && d.categories.length
    ? d.categories
    : [{ id: 'all', label: 'Összes' }];
  shopCategory = 'all';
  shopSelected = shopItems[0] || null;
  setShopCash(d.cash);
  const title = document.getElementById('fish-shop-title');
  if (title && d.title) title.textContent = d.title;
  renderShopCats();
  renderShopGrid();
  renderShopDetail();
  fishShop.classList.remove('hidden');
  fishShop.setAttribute('aria-hidden', 'false');
}

document.querySelectorAll('[data-shop-close]').forEach((el) => {
  el.addEventListener('click', () => closeShopUi());
});

/* ===== Horgásznapló ===== */
const fishLog = document.getElementById('fishlog');
const fishLogGrid = document.getElementById('fishlog-grid');
const fishLogTagline = document.getElementById('fishlog-tagline');
const fishLogLevel = document.getElementById('fishlog-level');
const fishLogProgressFill = document.getElementById('fishlog-progress-fill');
const fishLogProgressText = document.getElementById('fishlog-progress-text');

const CLASS_RANK = { Legendary: 0, Epic: 1, Rare: 2, Common: 3 };

function closeFishLogUi() {
  if (!fishLog) return;
  fishLog.classList.add('hidden');
  fishLog.setAttribute('aria-hidden', 'true');
  post('closeFishLog', {});
}

function openFishLogUi(msg) {
  if (!fishLog || !fishLogGrid) return;
  const species = Array.isArray(msg.species) ? msg.species : [];
  const caught = Array.isArray(msg.caught) ? msg.caught : [];
  const level = Number(msg.level) || 1;
  const maxLevel = Number(msg.maxLevel) || 30;
  const perLevel = Number(msg.catchesPerLevel) || 15;

  const caughtByKey = {};
  let totalCatches = 0;
  caught.forEach((row) => {
    caughtByKey[row.fish_key] = row;
    totalCatches += Number(row.count) || 0;
  });

  fishLogLevel.textContent = String(level);
  const discoveredCount = Object.keys(caughtByKey).length;
  fishLogTagline.textContent = `${discoveredCount} / ${species.length} faj felfedezve`;

  if (level >= maxLevel) {
    fishLogProgressFill.style.width = '100%';
    fishLogProgressText.textContent = 'Elérted a max szintet';
  } else {
    const into = totalCatches % perLevel;
    fishLogProgressFill.style.width = `${Math.round((into / perLevel) * 100)}%`;
    fishLogProgressText.textContent = `${into} / ${perLevel} a következő szintig`;
  }

  const sorted = species.slice().sort((a, b) => {
    const aCaught = !!caughtByKey[a.key];
    const bCaught = !!caughtByKey[b.key];
    if (aCaught !== bCaught) return aCaught ? -1 : 1;
    const rankDiff = (CLASS_RANK[a.class] ?? 9) - (CLASS_RANK[b.class] ?? 9);
    if (rankDiff !== 0) return rankDiff;
    return String(a.name).localeCompare(String(b.name));
  });

  fishLogGrid.innerHTML = '';
  sorted.forEach((sp) => {
    const row = caughtByKey[sp.key];
    const card = document.createElement('div');
    card.className = 'fishlog-card' + (row ? ' is-caught' : ' is-undiscovered');

    const top = document.createElement('div');
    top.className = 'fishlog-card-top';
    const name = document.createElement('span');
    name.className = 'fishlog-card-name';
    name.textContent = row ? sp.name : '???';
    const cls = document.createElement('span');
    cls.className = 'fishlog-card-class class-' + String(sp.class || 'common').toLowerCase();
    cls.textContent = sp.class || 'Common';
    top.appendChild(name);
    top.appendChild(cls);
    card.appendChild(top);

    const stats = document.createElement('div');
    stats.className = 'fishlog-card-stats';
    if (row) {
      const parts = [`Fogások: <b>${row.count}</b>`];
      if (!sp.nonAlive) {
        parts.push(`Legjobb: <b>${Number(row.best_weight).toFixed(1)} kg</b> / <b>${row.best_length} cm</b>`);
      }
      stats.innerHTML = parts.join('<br>');
    } else {
      stats.textContent = 'Még nem fogtad ki';
    }
    card.appendChild(stats);

    fishLogGrid.appendChild(card);
  });

  fishLog.classList.remove('hidden');
  fishLog.setAttribute('aria-hidden', 'false');
}

document.querySelectorAll('[data-fishlog-close]').forEach((el) => {
  el.addEventListener('click', () => closeFishLogUi());
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    if (fishShop && !fishShop.classList.contains('hidden')) {
      closeShopUi();
      return;
    }
    if (fishLog && !fishLog.classList.contains('hidden')) {
      closeFishLogUi();
      return;
    }
    if (tournament && !tournament.classList.contains('hidden')) {
      if (tournamentTimer) clearTimeout(tournamentTimer);
      tournament.classList.add('hidden');
      return;
    }
    if (!sell.classList.contains('hidden')) {
      post('sellCancel', {});
    }
  }
});
