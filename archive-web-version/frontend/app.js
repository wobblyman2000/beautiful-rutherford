// Aether Music Player - Frontend Controller

const API_BASE = 'http://localhost:3000';

// App state
const state = {
  tracks: [],
  albums: [],
  artists: [],
  collections: [],
  
  // Playback state
  queue: [],
  queueIndex: -1,
  playbackStatus: 'Stopped', // Playing, Paused, Stopped
  shuffle: false,
  loopStatus: 'None', // None, Track, Playlist
  volume: 0.8,
  
  // Audio element
  audio: new Audio(),
  positionInterval: null
};

// Elements cache
const el = {
  navAlbums: document.getElementById('nav-albums'),
  navArtists: document.getElementById('nav-artists'),
  navGenres: document.getElementById('nav-genres'),
  navCollections: document.getElementById('nav-collections'),
  navSettings: document.getElementById('nav-settings'),
  
  pageAlbums: document.getElementById('page-albums'),
  pageArtists: document.getElementById('page-artists'),
  pageGenres: document.getElementById('page-genres'),
  pageCollections: document.getElementById('page-collections'),
  pageSettings: document.getElementById('page-settings'),
  
  albumsGrid: document.getElementById('albums-grid'),
  artistsList: document.getElementById('artists-list'),
  genresGrid: document.getElementById('genres-grid'),
  collectionsGrid: document.getElementById('collections-grid'),
  
  albumsAz: document.getElementById('albums-az'),
  artistsAz: document.getElementById('artists-az'),
  genresAz: document.getElementById('genres-az'),
  
  searchInput: document.getElementById('search-input'),
  scanIndicator: document.getElementById('scan-indicator'),
  
  // Settings
  formAddDir: document.getElementById('form-add-dir'),
  dirInput: document.getElementById('dir-input'),
  dirsList: document.getElementById('dirs-list'),
  btnScanLibrary: document.getElementById('btn-scan-library'),
  
  // Player bar
  playerCover: document.getElementById('player-cover'),
  playerCoverFallback: document.getElementById('player-cover-fallback'),
  playerTitle: document.getElementById('player-title'),
  playerArtist: document.getElementById('player-artist'),
  btnPlayPause: document.getElementById('btn-play-pause'),
  playIcon: document.getElementById('play-icon'),
  btnPrev: document.getElementById('btn-prev'),
  btnNext: document.getElementById('btn-next'),
  btnShuffle: document.getElementById('btn-shuffle'),
  btnRepeat: document.getElementById('btn-repeat'),
  timeCurrent: document.getElementById('time-current'),
  timeTotal: document.getElementById('time-total'),
  progressBar: document.getElementById('progress-bar'),
  progressFill: document.getElementById('progress-fill'),
  btnMute: document.getElementById('btn-mute'),
  volumeIcon: document.getElementById('volume-icon'),
  volumeBar: document.getElementById('volume-bar'),
  volumeFill: document.getElementById('volume-fill'),
  
  // Album detail modal
  modalAlbum: document.getElementById('modal-album'),
  btnCloseAlbumModal: document.getElementById('btn-close-album-modal'),
  detailAlbumCover: document.getElementById('detail-album-cover'),
  detailAlbumCoverFallback: document.getElementById('detail-album-cover-fallback'),
  btnPlayAlbumOverlay: document.getElementById('btn-play-album-overlay'),
  detailAlbumName: document.getElementById('detail-album-name'),
  detailAlbumArtist: document.getElementById('detail-album-artist'),
  detailAlbumYear: document.getElementById('detail-album-year'),
  detailAlbumGenre: document.getElementById('detail-album-genre'),
  detailAlbumTracksCount: document.getElementById('detail-album-tracks-count'),
  detailAlbumDuration: document.getElementById('detail-album-duration'),
  albumTracksContainer: document.getElementById('album-tracks-container'),
  
  // Collection modal
  modalCollection: document.getElementById('modal-collection'),
  btnCloseCollectionModal: document.getElementById('btn-close-collection-modal'),
  btnNewCollection: document.getElementById('btn-new-collection'),
  btnQuickCollection: document.getElementById('btn-quick-collection'),
  formCollection: document.getElementById('form-collection'),
  collectionEditId: document.getElementById('collection-edit-id'),
  collectionName: document.getElementById('collection-name'),
  collectionCover: document.getElementById('collection-cover'),
  rulesContainer: document.getElementById('rules-container'),
  btnAddRule: document.getElementById('btn-add-rule'),
  btnCancelCollection: document.getElementById('btn-cancel-collection'),
  btnSaveCollection: document.getElementById('btn-save-collection')
};

// Initialize
window.addEventListener('DOMContentLoaded', () => {
  setupNavigation();
  setupAudioEngine();
  setupEventListeners();
  setupRemoteEvents();
  
  // Load data
  loadLibrary();
  loadSettings();
  loadCollections();
  
  // Poll scanner status
  startScannerPolling();
});

// -------------------------------------------------------------
// Navigation Routing
// -------------------------------------------------------------
function setupNavigation() {
  const handleRouting = () => {
    const hash = window.location.hash || '#albums';
    
    // Deactivate all nav items and pages
    [el.navAlbums, el.navArtists, el.navGenres, el.navCollections, el.navSettings].forEach(nav => nav && nav.classList.remove('active'));
    [el.pageAlbums, el.pageArtists, el.pageGenres, el.pageCollections, el.pageSettings].forEach(page => page && page.classList.add('hidden'));
    
    if (hash === '#albums') {
      el.navAlbums.classList.add('active');
      el.pageAlbums.classList.remove('hidden');
      renderAlbums();
    } else if (hash === '#artists') {
      el.navArtists.classList.add('active');
      el.pageArtists.classList.remove('hidden');
      renderArtists();
    } else if (hash === '#genres') {
      el.navGenres.classList.add('active');
      el.pageGenres.classList.remove('hidden');
      renderGenres();
    } else if (hash === '#collections') {
      el.navCollections.classList.add('active');
      el.pageCollections.classList.remove('hidden');
      renderCollections();
    } else if (hash === '#settings') {
      el.navSettings.classList.add('active');
      el.pageSettings.classList.remove('hidden');
    }
  };
  
  window.addEventListener('hashchange', handleRouting);
  handleRouting();
}

// -------------------------------------------------------------
// Audio Engine & Playback Controls
// -------------------------------------------------------------
function setupAudioEngine() {
  state.audio.volume = state.volume;
  
  // Listen for track ending
  state.audio.addEventListener('ended', () => {
    handleTrackEnded();
  });
  
  // Position tick timer
  state.audio.addEventListener('play', () => {
    state.playbackStatus = 'Playing';
    updatePlayerBarUI();
    reportState();
    
    clearInterval(state.positionInterval);
    state.positionInterval = setInterval(() => {
      if (!state.audio.paused) {
        updateProgressUI();
        // Periodically sync position to backend
        reportState(false);
      }
    }, 1000);
  });
  
  state.audio.addEventListener('pause', () => {
    state.playbackStatus = 'Paused';
    updatePlayerBarUI();
    reportState();
    clearInterval(state.positionInterval);
  });
  
  state.audio.addEventListener('timeupdate', () => {
    updateProgressUI();
  });
}

function playTrack(trackIndex) {
  if (trackIndex < 0 || trackIndex >= state.queue.length) return;
  
  state.queueIndex = trackIndex;
  const track = state.queue[state.queueIndex];
  
  state.audio.src = `${API_BASE}/stream/${track.id}`;
  state.audio.play()
    .then(() => {
      state.playbackStatus = 'Playing';
      updatePlayerBarUI();
      reportState();
    })
    .catch(err => console.error('Error starting audio playback:', err));
}

function togglePlay() {
  if (!state.audio.src || state.queueIndex === -1) {
    // If queue is empty, play first album
    if (state.albums.length > 0) {
      playAlbumTracks(state.albums[0]);
    }
    return;
  }
  
  if (state.audio.paused) {
    state.audio.play();
  } else {
    state.audio.pause();
  }
}

function handleTrackEnded() {
  if (state.loopStatus === 'Track') {
    state.audio.currentTime = 0;
    state.audio.play();
  } else if (state.queueIndex < state.queue.length - 1) {
    playTrack(state.queueIndex + 1);
  } else if (state.loopStatus === 'Playlist') {
    playTrack(0);
  } else {
    state.playbackStatus = 'Stopped';
    updatePlayerBarUI();
    reportState();
  }
}

function nextTrack() {
  if (state.queue.length === 0) return;
  if (state.queueIndex < state.queue.length - 1) {
    playTrack(state.queueIndex + 1);
  } else if (state.loopStatus === 'Playlist') {
    playTrack(0);
  }
}

function prevTrack() {
  if (state.queue.length === 0) return;
  // If track is more than 3 seconds in, restart track
  if (state.audio.currentTime > 3) {
    state.audio.currentTime = 0;
    reportState(true);
  } else if (state.queueIndex > 0) {
    playTrack(state.queueIndex - 1);
  } else if (state.loopStatus === 'Playlist') {
    playTrack(state.queue.length - 1);
  }
}

function setVolume(val) {
  state.volume = Math.max(0, Math.min(1, val));
  state.audio.volume = state.volume;
  updateVolumeUI();
  reportState();
}

function reportState(seeked = false) {
  const current = state.queue[state.queueIndex];
  const payload = {
    trackId: current ? current.id : null,
    playbackStatus: state.playbackStatus,
    loopStatus: state.loopStatus,
    shuffle: state.shuffle,
    volume: state.volume,
    position: state.audio.currentTime || 0,
    seeked: seeked
  };
  
  fetch(`${API_BASE}/api/player/state`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  }).catch(err => console.error('Failed to sync player state to backend:', err));
}

// -------------------------------------------------------------
// D-Bus / MPRIS remote events
// -------------------------------------------------------------
function setupRemoteEvents() {
  const eventSource = new EventSource(`${API_BASE}/api/player/events`);
  
  eventSource.onmessage = (event) => {
    const cmd = JSON.parse(event.data);
    console.log('Received command from D-Bus/MPRIS:', cmd);
    
    switch (cmd.action) {
      case 'play':
        if (state.audio.paused) state.audio.play();
        break;
      case 'pause':
        if (!state.audio.paused) state.audio.pause();
        break;
      case 'playpause':
        togglePlay();
        break;
      case 'stop':
        state.audio.pause();
        state.audio.currentTime = 0;
        state.playbackStatus = 'Stopped';
        updatePlayerBarUI();
        reportState();
        break;
      case 'next':
        nextTrack();
        break;
      case 'previous':
        prevTrack();
        break;
      case 'volume':
        setVolume(cmd.value);
        break;
      case 'seek':
        state.audio.currentTime += cmd.value;
        reportState(true);
        break;
      case 'setposition':
        state.audio.currentTime = cmd.value;
        reportState(true);
        break;
      case 'shuffle':
        toggleShuffle(cmd.value);
        break;
      case 'loop':
        setLoopStatus(cmd.value);
        break;
    }
  };
  
  eventSource.onerror = (err) => {
    console.error('SSE Error, reconnecting:', err);
  };
}

function toggleShuffle(forceVal = null) {
  state.shuffle = forceVal !== null ? forceVal : !state.shuffle;
  
  el.btnShuffle.classList.toggle('active', state.shuffle);
  
  if (state.shuffle && state.queue.length > 0) {
    // Shuffle the queue (keeping current playing track at position 0)
    const current = state.queue[state.queueIndex];
    const remaining = state.queue.filter((_, idx) => idx !== state.queueIndex);
    
    // Fisher-Yates shuffle
    for (let i = remaining.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [remaining[i], remaining[j]] = [remaining[j], remaining[i]];
    }
    
    state.queue = current ? [current, ...remaining] : remaining;
    state.queueIndex = current ? 0 : -1;
  } else if (!state.shuffle && state.queueIndex !== -1) {
    // Restoring original order is tricky unless we keep an original queue.
    // For simplicity, we just keep the shuffled queue as is but disable the shuffle state indicator.
  }
  
  reportState();
}

function setLoopStatus(status) {
  // Loop status cycle: None -> Track -> Playlist -> None
  state.loopStatus = status;
  
  el.btnRepeat.classList.remove('active');
  el.btnRepeat.innerHTML = '<i data-lucide="repeat"></i>';
  
  if (state.loopStatus === 'Track') {
    el.btnRepeat.classList.add('active');
    el.btnRepeat.innerHTML = '<i data-lucide="repeat-1"></i>';
  } else if (state.loopStatus === 'Playlist') {
    el.btnRepeat.classList.add('active');
  }
  
  lucide.createIcons();
  reportState();
}

// -------------------------------------------------------------
// UI Rendering
// -------------------------------------------------------------
function formatTime(seconds) {
  if (isNaN(seconds)) return '0:00';
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs < 10 ? '0' : ''}${secs}`;
}

function updatePlayerBarUI() {
  const current = state.queue[state.queueIndex];
  if (!current) {
    el.playerTitle.innerText = 'Not Playing';
    el.playerArtist.innerText = '';
    el.playerCover.classList.add('hidden');
    el.playerCoverFallback.classList.remove('hidden');
    el.playIcon.setAttribute('data-lucide', 'play');
    el.btnPlayPause.classList.remove('btn-pause');
    el.btnPlayPause.classList.add('btn-play');
  } else {
    el.playerTitle.innerText = current.title || 'Unknown Title';
    el.playerArtist.innerText = current.artist || 'Unknown Artist';
    
    if (current.coverPath) {
      el.playerCover.src = `${API_BASE}${current.coverPath}`;
      el.playerCover.classList.remove('hidden');
      el.playerCoverFallback.classList.add('hidden');
    } else {
      el.playerCover.classList.add('hidden');
      el.playerCoverFallback.classList.remove('hidden');
    }
    
    if (state.playbackStatus === 'Playing') {
      el.playIcon.setAttribute('data-lucide', 'pause');
      el.btnPlayPause.classList.add('btn-pause');
      el.btnPlayPause.classList.remove('btn-play');
    } else {
      el.playIcon.setAttribute('data-lucide', 'play');
      el.btnPlayPause.classList.remove('btn-pause');
      el.btnPlayPause.classList.add('btn-play');
    }
  }
  
  lucide.createIcons();
}

function updateProgressUI() {
  const duration = state.audio.duration || 0;
  const current = state.audio.currentTime || 0;
  
  el.timeCurrent.innerText = formatTime(current);
  el.timeTotal.innerText = formatTime(duration);
  
  if (duration > 0) {
    const percent = (current / duration) * 100;
    el.progressBar.value = percent;
    el.progressFill.style.width = `${percent}%`;
  } else {
    el.progressBar.value = 0;
    el.progressFill.style.width = `0%`;
  }
}

function updateVolumeUI() {
  const val = state.volume * 100;
  el.volumeBar.value = val;
  el.volumeFill.style.width = `${val}%`;
  
  if (state.volume === 0) {
    el.volumeIcon.setAttribute('data-lucide', 'volume-x');
  } else if (state.volume < 0.4) {
    el.volumeIcon.setAttribute('data-lucide', 'volume');
  } else if (state.volume < 0.7) {
    el.volumeIcon.setAttribute('data-lucide', 'volume-1');
  } else {
    el.volumeIcon.setAttribute('data-lucide', 'volume-2');
  }
  
  lucide.createIcons();
}

// -------------------------------------------------------------
// Playback Actions
// -------------------------------------------------------------
function playAlbumTracks(album, startTrackId = null) {
  let tracks = [...album.tracks];
  
  if (state.shuffle) {
    // Shuffle all tracks, but if startTrackId is specified, place that one first
    let startTrack = null;
    if (startTrackId) {
      startTrack = tracks.find(t => t.id === startTrackId);
      tracks = tracks.filter(t => t.id !== startTrackId);
    }
    
    for (let i = tracks.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [tracks[i], tracks[j]] = [tracks[j], tracks[i]];
    }
    
    if (startTrack) {
      tracks = [startTrack, ...tracks];
    }
  }
  
  state.queue = tracks;
  
  let startIndex = 0;
  if (startTrackId && !state.shuffle) {
    startIndex = state.queue.findIndex(t => t.id === startTrackId);
    if (startIndex === -1) startIndex = 0;
  }
  
  playTrack(startIndex);
}

function playCollectionTracks(collection) {
  const matchedTracks = state.tracks.filter(t => matchCollectionRules(t, collection.rules));
  if (matchedTracks.length === 0) return;
  
  let tracks = [...matchedTracks];
  if (state.shuffle) {
    for (let i = tracks.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [tracks[i], tracks[j]] = [tracks[j], tracks[i]];
    }
  }
  
  state.queue = tracks;
  playTrack(0);
}

function playArtistTracks(artistName) {
  const artistTracks = state.tracks.filter(t => t.artist.toLowerCase() === artistName.toLowerCase());
  if (artistTracks.length === 0) return;
  
  let tracks = [...artistTracks];
  if (state.shuffle) {
    for (let i = tracks.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [tracks[i], tracks[j]] = [tracks[j], tracks[i]];
    }
  }
  
  state.queue = tracks;
  playTrack(0);
}

// -------------------------------------------------------------
// View Renderers
// -------------------------------------------------------------
function renderAzBar(azContainer, items, getName) {
  if (!azContainer) return;
  azContainer.innerHTML = '';
  
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#'.split('');
  
  // Find which letters exist in the items
  const activeLetters = new Set();
  items.forEach(item => {
    const name = getName(item) || '';
    const firstChar = name.trim().charAt(0).toUpperCase();
    if (/[A-Z]/.test(firstChar)) {
      activeLetters.add(firstChar);
    } else if (/[0-9]/.test(firstChar) || firstChar) {
      activeLetters.add('#');
    }
  });

  // Create "All" button
  const allBtn = document.createElement('div');
  allBtn.className = 'az-letter active';
  allBtn.innerText = 'All';
  allBtn.onclick = () => {
    azContainer.querySelectorAll('.az-letter').forEach(l => l.classList.remove('active'));
    allBtn.classList.add('active');
    
    const viewContainer = azContainer.closest('.view-container');
    if (viewContainer) {
      viewContainer.scrollTo({ top: 0, behavior: 'smooth' });
    }
  };
  azContainer.appendChild(allBtn);

  // Create A-Z buttons
  letters.forEach(letter => {
    const btn = document.createElement('div');
    btn.className = 'az-letter';
    btn.innerText = letter;
    
    const hasItems = activeLetters.has(letter);
    if (!hasItems) {
      btn.classList.add('disabled');
    } else {
      btn.onclick = () => {
        azContainer.querySelectorAll('.az-letter').forEach(l => l.classList.remove('active'));
        btn.classList.add('active');
        
        const targetId = `group-${azContainer.id}-${letter}`;
        const targetEl = document.getElementById(targetId);
        if (targetEl) {
          targetEl.scrollIntoView({ behavior: 'smooth' });
        }
      };
    }
    azContainer.appendChild(btn);
  });
}

function renderAlbums() {
  const query = el.searchInput.value.toLowerCase().trim();
  el.albumsGrid.innerHTML = '';
  el.albumsGrid.className = 'albums-container';
  
  const filtered = state.albums.filter(album => {
    return album.name.toLowerCase().includes(query) || 
           album.artist.toLowerCase().includes(query) ||
           album.tracks.some(t => t.title.toLowerCase().includes(query));
  });
  
  if (filtered.length === 0) {
    el.albumsGrid.innerHTML = '<div class="empty-state">No albums found.</div>';
    if (el.albumsAz) el.albumsAz.innerHTML = '';
    return;
  }
  
  // Render A-Z Bar
  renderAzBar(el.albumsAz, filtered, a => a.name);
  
  // Group albums by starting letter
  const groups = {};
  filtered.forEach(album => {
    const firstChar = album.name.trim().charAt(0).toUpperCase();
    const groupKey = /[A-Z]/.test(firstChar) ? firstChar : '#';
    if (!groups[groupKey]) groups[groupKey] = [];
    groups[groupKey].push(album);
  });
  
  // Sort group keys
  const sortedKeys = Object.keys(groups).sort((a, b) => {
    if (a === '#') return 1;
    if (b === '#') return -1;
    return a.localeCompare(b);
  });
  
  sortedKeys.forEach(letter => {
    const groupContainer = document.createElement('div');
    groupContainer.className = 'az-group';
    groupContainer.id = `group-albums-az-${letter}`;
    
    groupContainer.innerHTML = `
      <div class="az-group-header">${letter}</div>
      <div class="albums-grid grid-layout"></div>
    `;
    
    const grid = groupContainer.querySelector('.albums-grid');
    
    groups[letter].forEach(album => {
      const card = document.createElement('div');
      card.className = 'card glass-panel';
      
      const discsCount = album.discs.length;
      const discTag = discsCount > 1 ? `<div class="card-disc-tag">${discsCount} CDs</div>` : '';
      
      let coverHtml = `<div class="fallback-cover"><i data-lucide="disc"></i></div>`;
      if (album.coverPath) {
        coverHtml = `<img src="${API_BASE}${album.coverPath}" alt="${album.name}" class="card-cover" loading="lazy">`;
      }
      
      card.innerHTML = `
        <div class="card-cover-wrapper">
          ${coverHtml}
          ${discTag}
          <div class="card-play-overlay">
            <button class="btn-play-action" title="Play Album">
              <i data-lucide="play"></i>
            </button>
          </div>
        </div>
        <div class="card-title" title="${album.name}">${album.name}</div>
        <div class="card-subtitle" title="${album.artist}">${album.artist}</div>
      `;
      
      card.addEventListener('click', (e) => {
        if (e.target.closest('.btn-play-action')) {
          playAlbumTracks(album);
          return;
        }
        openAlbumModal(album);
      });
      
      card.addEventListener('dblclick', () => {
        playAlbumTracks(album);
      });
      
      grid.appendChild(card);
    });
    
    el.albumsGrid.appendChild(groupContainer);
  });
  
  lucide.createIcons();
}

function renderArtists() {
  const query = el.searchInput.value.toLowerCase().trim();
  el.artistsList.innerHTML = '';
  
  const filtered = state.artists.filter(artist => {
    return artist.name.toLowerCase().includes(query) ||
           artist.albums.some(al => al.name.toLowerCase().includes(query));
  });
  
  if (filtered.length === 0) {
    el.artistsList.innerHTML = '<div class="empty-state">No artists found.</div>';
    if (el.artistsAz) el.artistsAz.innerHTML = '';
    return;
  }
  
  // Render A-Z Bar
  renderAzBar(el.artistsAz, filtered, a => a.name);
  
  // Group artists alphabetically
  const groups = {};
  filtered.forEach(artist => {
    const firstChar = artist.name.trim().charAt(0).toUpperCase();
    const groupKey = /[A-Z]/.test(firstChar) ? firstChar : '#';
    if (!groups[groupKey]) groups[groupKey] = [];
    groups[groupKey].push(artist);
  });
  
  // Sort group keys
  const sortedKeys = Object.keys(groups).sort((a, b) => {
    if (a === '#') return 1;
    if (b === '#') return -1;
    return a.localeCompare(b);
  });
  
  sortedKeys.forEach(letter => {
    const groupContainer = document.createElement('div');
    groupContainer.className = 'az-group';
    groupContainer.id = `group-artists-az-${letter}`;
    
    groupContainer.innerHTML = `
      <div class="az-group-header">${letter}</div>
      <div class="artists-group-list"></div>
    `;
    
    const listContainer = groupContainer.querySelector('.artists-group-list');
    
    groups[letter].forEach(artist => {
      const row = document.createElement('div');
      row.className = 'artist-row';
      
      row.innerHTML = `
        <div class="artist-name-header">
          <i data-lucide="user"></i>
          <span>${artist.name}</span>
        </div>
        <div class="albums-grid grid-layout"></div>
      `;
      
      row.querySelector('.artist-name-header').addEventListener('dblclick', () => {
        playArtistTracks(artist.name);
      });
      row.querySelector('.artist-name-header').addEventListener('click', () => {
        playArtistTracks(artist.name);
      });
      
      const subGrid = row.querySelector('.albums-grid');
      
      artist.albums.forEach(albumStub => {
        const fullAlbum = state.albums.find(a => a.name.toLowerCase() === albumStub.name.toLowerCase() && a.artist.toLowerCase() === artist.name.toLowerCase());
        if (!fullAlbum) return;
        
        const card = document.createElement('div');
        card.className = 'card glass-panel';
        
        let coverHtml = `<div class="fallback-cover"><i data-lucide="disc"></i></div>`;
        if (albumStub.coverPath) {
          coverHtml = `<img src="${API_BASE}${albumStub.coverPath}" alt="${albumStub.name}" class="card-cover" loading="lazy">`;
        }
        
        card.innerHTML = `
          <div class="card-cover-wrapper">
            ${coverHtml}
            <div class="card-play-overlay">
              <button class="btn-play-action" title="Play Album">
                <i data-lucide="play"></i>
              </button>
            </div>
          </div>
          <div class="card-title" title="${albumStub.name}">${albumStub.name}</div>
          <div class="card-subtitle">${albumStub.year || ''} &bull; ${albumStub.trackCount} tracks</div>
        `;
        
        card.addEventListener('click', (e) => {
          if (e.target.closest('.btn-play-action')) {
            playAlbumTracks(fullAlbum);
            return;
          }
          openAlbumModal(fullAlbum);
        });
        
        card.addEventListener('dblclick', () => {
          playAlbumTracks(fullAlbum);
        });
        
        subGrid.appendChild(card);
      });
      
      listContainer.appendChild(row);
    });
    
    el.artistsList.appendChild(groupContainer);
  });
  
  lucide.createIcons();
}

function renderGenres() {
  if (!el.genresGrid) return;
  const query = el.searchInput.value.toLowerCase().trim();
  el.genresGrid.innerHTML = '';
  el.genresGrid.className = 'genres-container';

  // Group tracks by genre
  const genresMap = {};
  state.tracks.forEach(track => {
    if (!track.genre) return;
    const genres = track.genre.split(',').map(s => s.trim());
    genres.forEach(g => {
      if (!g) return;
      const key = g.toLowerCase();
      if (!genresMap[key]) {
        genresMap[key] = {
          name: g,
          tracks: []
        };
      }
      genresMap[key].tracks.push(track);
    });
  });

  const genresList = Object.values(genresMap);
  const filtered = genresList.filter(g => g.name.toLowerCase().includes(query));

  if (filtered.length === 0) {
    el.genresGrid.innerHTML = '<div class="empty-state">No genres found.</div>';
    if (el.genresAz) el.genresAz.innerHTML = '';
    return;
  }

  // Render A-Z Bar
  renderAzBar(el.genresAz, filtered, g => g.name);

  // Group genres alphabetically
  const groups = {};
  filtered.forEach(genre => {
    const firstChar = genre.name.trim().charAt(0).toUpperCase();
    const groupKey = /[A-Z]/.test(firstChar) ? firstChar : '#';
    if (!groups[groupKey]) groups[groupKey] = [];
    groups[groupKey].push(genre);
  });

  // Sort group keys
  const sortedKeys = Object.keys(groups).sort((a, b) => {
    if (a === '#') return 1;
    if (b === '#') return -1;
    return a.localeCompare(b);
  });

  sortedKeys.forEach(letter => {
    const groupContainer = document.createElement('div');
    groupContainer.className = 'az-group';
    groupContainer.id = `group-genres-az-${letter}`;

    groupContainer.innerHTML = `
      <div class="az-group-header">${letter}</div>
      <div class="genres-grid grid-layout"></div>
    `;

    const grid = groupContainer.querySelector('.genres-grid');

    groups[letter].forEach(genre => {
      const card = document.createElement('div');
      card.className = 'card glass-panel';

      const coverTrack = genre.tracks.find(t => t.coverPath);
      let coverHtml = `<div class="fallback-cover"><i data-lucide="tag"></i></div>`;
      if (coverTrack && coverTrack.coverPath) {
        coverHtml = `<img src="${API_BASE}${coverTrack.coverPath}" alt="${genre.name}" class="card-cover" loading="lazy">`;
      }

      card.innerHTML = `
        <div class="card-cover-wrapper">
          ${coverHtml}
          <div class="card-play-overlay">
            <button class="btn-play-action" title="Play Genre">
              <i data-lucide="play"></i>
            </button>
          </div>
        </div>
        <div class="card-title" title="${genre.name}">${genre.name}</div>
        <div class="card-subtitle">${genre.tracks.length} track${genre.tracks.length === 1 ? '' : 's'}</div>
      `;

      card.addEventListener('click', (e) => {
        if (e.target.closest('.btn-play-action')) {
          playGenreTracks(genre.name);
          return;
        }
        openGenreDetailsModal(genre);
      });

      card.addEventListener('dblclick', () => {
        playGenreTracks(genre.name);
      });

      grid.appendChild(card);
    });

    el.genresGrid.appendChild(groupContainer);
  });

  lucide.createIcons();
}

function openGenreDetailsModal(genre) {
  const mockAlbum = {
    id: `genre-${genre.name.toLowerCase()}`,
    name: genre.name,
    artist: 'Genre Section',
    year: '',
    genre: '',
    coverPath: (genre.tracks.find(t => t.coverPath) || {}).coverPath || null,
    tracks: genre.tracks,
    discs: [1],
    totalDuration: genre.tracks.reduce((acc, t) => acc + (t.duration || 0), 0)
  };
  
  openAlbumModal(mockAlbum);
  el.modalAlbum.querySelector('.detail-metadata .tag').innerText = 'Genre';
  el.btnPlayAlbumOverlay.onclick = () => {
    playGenreTracks(genre.name);
  };
}

function playGenreTracks(genreName) {
  const genreTracks = state.tracks.filter(t => {
    if (!t.genre) return false;
    const genres = t.genre.split(',').map(s => s.trim().toLowerCase());
    return genres.includes(genreName.toLowerCase());
  });
  if (genreTracks.length === 0) return;
  
  let tracks = [...genreTracks];
  if (state.shuffle) {
    for (let i = tracks.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [tracks[i], tracks[j]] = [tracks[j], tracks[i]];
    }
  }
  
  state.queue = tracks;
  playTrack(0);
}

function renderCollections() {
  const query = el.searchInput.value.toLowerCase().trim();
  el.collectionsGrid.innerHTML = '';
  
  const filtered = state.collections.filter(col => {
    return col.name.toLowerCase().includes(query);
  });
  
  filtered.forEach(col => {
    const card = document.createElement('div');
    card.className = 'card glass-panel';
    
    let coverHtml = `<div class="fallback-cover"><i data-lucide="folder-heart"></i></div>`;
    if (col.coverPath) {
      coverHtml = `<img src="${col.coverPath}" alt="${col.name}" class="card-cover" loading="lazy">`;
    }
    
    const matchedCount = state.tracks.filter(t => matchCollectionRules(t, col.rules)).length;
    
    card.innerHTML = `
      <div class="card-cover-wrapper">
        ${coverHtml}
        <div class="card-play-overlay">
          <button class="btn-play-action" title="Play Collection">
            <i data-lucide="play"></i>
          </button>
        </div>
      </div>
      <div class="card-title" title="${col.name}">${col.name}</div>
      <div class="card-subtitle">${matchedCount} matching tracks</div>
      <div class="form-actions" style="margin-top: 10px; border-top: none; padding-top: 0; display: flex; justify-content: flex-end; gap: 8px;">
        <button class="btn-icon btn-edit-col" title="Edit Rules" style="width: 28px; height: 28px;">
          <i data-lucide="edit-3" style="width: 14px; height: 14px;"></i>
        </button>
        <button class="btn-icon btn-delete-col" title="Delete Collection" style="width: 28px; height: 28px; color: var(--text-muted);">
          <i data-lucide="trash-2" style="width: 14px; height: 14px;"></i>
        </button>
      </div>
    `;
    
    card.addEventListener('click', (e) => {
      if (e.target.closest('.btn-play-action')) {
        playCollectionTracks(col);
        return;
      }
      if (e.target.closest('.btn-edit-col')) {
        openCollectionModal(col);
        return;
      }
      if (e.target.closest('.btn-delete-col')) {
        if (confirm(`Delete the collection "${col.name}"?`)) {
          deleteCollection(col.id);
        }
        return;
      }
      
      openCollectionDetailsModal(col);
    });
    
    card.addEventListener('dblclick', () => {
      playCollectionTracks(col);
    });
    
    el.collectionsGrid.appendChild(card);
  });
  
  lucide.createIcons();
}

// -------------------------------------------------------------
// Album Details Modal
// -------------------------------------------------------------
function openAlbumModal(album) {
  // Setup header
  if (album.coverPath) {
    el.detailAlbumCover.src = `${API_BASE}${album.coverPath}`;
    el.detailAlbumCover.classList.remove('hidden');
    el.detailAlbumCoverFallback.classList.add('hidden');
  } else {
    el.detailAlbumCover.classList.add('hidden');
    el.detailAlbumCoverFallback.classList.remove('hidden');
  }
  
  el.detailAlbumName.innerText = album.name;
  el.detailAlbumArtist.innerText = album.artist;
  el.detailAlbumYear.innerText = album.year || 'Unknown Year';
  el.detailAlbumGenre.innerText = album.genre || 'Unknown Genre';
  el.detailAlbumTracksCount.innerText = `${album.tracks.length} track${album.tracks.length === 1 ? '' : 's'}`;
  
  const min = Math.round(album.totalDuration / 60);
  el.detailAlbumDuration.innerText = `${min} min`;
  
  // Render tracks grouped by CD
  el.albumTracksContainer.innerHTML = '';
  
  // Group by disc
  const groupedByDisc = {};
  album.tracks.forEach(track => {
    const disc = track.discNo || 1;
    if (!groupedByDisc[disc]) groupedByDisc[disc] = [];
    groupedByDisc[disc].push(track);
  });
  
  const discs = Object.keys(groupedByDisc).sort((a, b) => a - b);
  
  discs.forEach(discNo => {
    const discSection = document.createElement('div');
    discSection.className = 'disc-section';
    
    // Add disc title only if there's multiple discs
    const showDiscTitle = discs.length > 1;
    const discTitleHtml = showDiscTitle ? `<div class="disc-group-title">CD ${discNo}</div>` : '';
    
    let tracksHtml = '';
    groupedByDisc[discNo].forEach((track, idx) => {
      // Is track active?
      const currentTrack = state.queue[state.queueIndex];
      const isActive = currentTrack && currentTrack.id === track.id;
      
      tracksHtml += `
        <div class="track-row ${isActive ? 'active' : ''}" data-track-id="${track.id}">
          <div class="track-num">${track.trackNo || idx + 1}</div>
          <div class="track-title-cell">${track.title || 'Unknown Title'}</div>
          <div class="track-duration-cell">${formatTime(track.duration)}</div>
        </div>
      `;
    });
    
    discSection.innerHTML = `
      ${discTitleHtml}
      <div class="tracks-list-table">
        ${tracksHtml}
      </div>
    `;
    
    // Click track to play
    discSection.querySelectorAll('.track-row').forEach(row => {
      row.addEventListener('click', () => {
        const trackId = row.getAttribute('data-track-id');
        playAlbumTracks(album, trackId);
        
        // Mark active
        discSection.querySelectorAll('.track-row').forEach(r => r.classList.remove('active'));
        row.classList.add('active');
      });
      row.addEventListener('dblclick', () => {
        const trackId = row.getAttribute('data-track-id');
        playAlbumTracks(album, trackId);
      });
    });
    
    el.albumTracksContainer.appendChild(discSection);
  });
  
  // Setup play album overlay button
  el.btnPlayAlbumOverlay.onclick = () => {
    playAlbumTracks(album);
  };
  
  el.modalAlbum.classList.remove('hidden');
  lucide.createIcons();
}

function openCollectionDetailsModal(collection) {
  const matchedTracks = state.tracks.filter(t => matchCollectionRules(t, collection.rules));
  
  // Package matched tracks as a mock "album" object so we can reuse the modal UI!
  const mockAlbum = {
    id: collection.id,
    name: collection.name,
    artist: 'Smart Collection',
    year: '',
    genre: '',
    coverPath: collection.coverPath ? collection.coverPath.replace(API_BASE, '') : null,
    tracks: matchedTracks,
    discs: [1],
    totalDuration: matchedTracks.reduce((acc, t) => acc + (t.duration || 0), 0)
  };
  
  openAlbumModal(mockAlbum);
  
  // Override label to say "Collection"
  el.modalAlbum.querySelector('.detail-metadata .tag').innerText = 'Smart Collection';
  
  // Override overlay play
  el.btnPlayAlbumOverlay.onclick = () => {
    playCollectionTracks(collection);
  };
}

// -------------------------------------------------------------
// Smart Collection Rules Validator (AND logic)
// -------------------------------------------------------------
function matchCollectionRules(track, rules) {
  if (!rules || rules.length === 0) return false;
  
  // A track must match ALL rules (AND logic)
  for (const rule of rules) {
    const val = (track[rule.field] || '').toString().toLowerCase();
    const criteria = rule.value.toLowerCase();
    
    let isMatch = false;
    switch (rule.operator) {
      case 'contains':
        isMatch = val.includes(criteria);
        break;
      case 'is':
        isMatch = (val === criteria);
        break;
      case 'starts_with':
        isMatch = val.startsWith(criteria);
        break;
      case 'ends_with':
        isMatch = val.endsWith(criteria);
        break;
      case 'not_contains':
        isMatch = !val.includes(criteria);
        break;
    }
    
    if (!isMatch) return false; // Fails AND check
  }
  
  return true;
}

// -------------------------------------------------------------
// Collection Modal (CRUD)
// -------------------------------------------------------------
function openCollectionModal(collection = null) {
  el.rulesContainer.innerHTML = '';
  
  if (collection) {
    document.getElementById('collection-modal-title').innerText = 'Edit Smart Collection';
    el.collectionEditId.value = collection.id;
    el.collectionName.value = collection.name;
    el.collectionCover.value = collection.coverPath || '';
    
    collection.rules.forEach(rule => addRuleRow(rule));
  } else {
    document.getElementById('collection-modal-title').innerText = 'Create Smart Collection';
    el.collectionEditId.value = '';
    el.collectionName.value = '';
    el.collectionCover.value = '';
    
    // Add one empty rule by default
    addRuleRow();
  }
  
  el.modalCollection.classList.remove('hidden');
  lucide.createIcons();
}

function addRuleRow(rule = null) {
  const row = document.createElement('div');
  row.className = 'rule-row';
  
  const fieldVal = rule ? rule.field : 'album';
  const opVal = rule ? rule.operator : 'contains';
  const inputVal = rule ? rule.value : '';
  
  row.innerHTML = `
    <select class="rule-select rule-field">
      <option value="album" ${fieldVal === 'album' ? 'selected' : ''}>Album</option>
      <option value="artist" ${fieldVal === 'artist' ? 'selected' : ''}>Artist</option>
      <option value="genre" ${fieldVal === 'genre' ? 'selected' : ''}>Genre</option>
      <option value="title" ${fieldVal === 'title' ? 'selected' : ''}>Song Title</option>
      <option value="filePath" ${fieldVal === 'filePath' ? 'selected' : ''}>File Path</option>
    </select>
    <select class="rule-select rule-operator">
      <option value="contains" ${opVal === 'contains' ? 'selected' : ''}>Contains</option>
      <option value="is" ${opVal === 'is' ? 'selected' : ''}>Is Equal To</option>
      <option value="starts_with" ${opVal === 'starts_with' ? 'selected' : ''}>Starts With</option>
      <option value="ends_with" ${opVal === 'ends_with' ? 'selected' : ''}>Ends With</option>
      <option value="not_contains" ${opVal === 'not_contains' ? 'selected' : ''}>Does Not Contain</option>
    </select>
    <input type="text" class="rule-input" placeholder="Value" value="${inputVal}" required>
    <button type="button" class="btn-remove-rule" title="Remove Condition">
      <i data-lucide="minus-circle"></i>
    </button>
  `;
  
  row.querySelector('.btn-remove-rule').onclick = () => {
    // Keep at least one rule
    if (el.rulesContainer.children.length > 1) {
      row.remove();
    }
  };
  
  el.rulesContainer.appendChild(row);
  lucide.createIcons();
}

function saveCollection(e) {
  e.preventDefault();
  
  const id = el.collectionEditId.value;
  const name = el.collectionName.value.trim();
  const coverPath = el.collectionCover.value.trim();
  
  // Gather rules
  const rules = [];
  const rows = el.rulesContainer.querySelectorAll('.rule-row');
  rows.forEach(row => {
    rules.push({
      field: row.querySelector('.rule-field').value,
      operator: row.querySelector('.rule-operator').value,
      value: row.querySelector('.rule-input').value.trim()
    });
  });
  
  const payload = { name, rules, coverPath: coverPath || null };
  const method = id ? 'PUT' : 'POST';
  const url = id ? `${API_BASE}/api/collections/${id}` : `${API_BASE}/api/collections`;
  
  fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })
    .then(res => res.json())
    .then(() => {
      el.modalCollection.classList.add('hidden');
      loadCollections();
    })
    .catch(err => console.error('Error saving collection:', err));
}

function deleteCollection(id) {
  fetch(`${API_BASE}/api/collections/${id}`, { method: 'DELETE' })
    .then(() => loadCollections())
    .catch(err => console.error('Error deleting collection:', err));
}

// -------------------------------------------------------------
// Settings & Library Sync
// -------------------------------------------------------------
function loadSettings() {
  fetch(`${API_BASE}/api/settings`)
    .then(res => res.json())
    .then(settings => {
      renderSettingsDirs(settings.musicDirs || []);
    })
    .catch(err => console.error('Error loading settings:', err));
}

function renderSettingsDirs(dirs) {
  el.dirsList.innerHTML = '';
  if (dirs.length === 0) {
    el.dirsList.innerHTML = '<li class="empty-state">No directories configured.</li>';
    return;
  }
  
  dirs.forEach(dir => {
    const li = document.createElement('li');
    li.innerHTML = `
      <span class="dir-path">${dir}</span>
      <button class="btn-delete-dir" title="Remove Folder">
        <i data-lucide="trash-2"></i>
      </button>
    `;
    
    li.querySelector('.btn-delete-dir').onclick = () => {
      const updatedDirs = dirs.filter(d => d !== dir);
      saveSettingsDirs(updatedDirs);
    };
    
    el.dirsList.appendChild(li);
  });
  
  lucide.createIcons();
}

function saveSettingsDirs(dirs) {
  fetch(`${API_BASE}/api/settings`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ musicDirs: dirs })
  })
    .then(() => loadSettings())
    .catch(err => console.error('Error saving directories:', err));
}

function triggerScan() {
  fetch(`${API_BASE}/api/scan`, { method: 'POST' })
    .then(res => res.json())
    .then(() => {
      startScannerPolling();
    })
    .catch(err => console.error('Error triggering scan:', err));
}

let scanPollInterval = null;
function startScannerPolling() {
  if (scanPollInterval) return;
  
  scanPollInterval = setInterval(() => {
    fetch(`${API_BASE}/api/status`)
      .then(res => res.json())
      .then(status => {
        if (status.scanning) {
          el.scanIndicator.classList.remove('hidden');
          el.btnScanLibrary.disabled = true;
          el.btnScanLibrary.innerHTML = '<div class="spinner"></div> Scanning...';
        } else {
          el.scanIndicator.classList.add('hidden');
          el.btnScanLibrary.disabled = false;
          el.btnScanLibrary.innerHTML = '<i data-lucide="refresh-cw"></i> Scan Library Now';
          lucide.createIcons();
          
          if (scanPollInterval) {
            clearInterval(scanPollInterval);
            scanPollInterval = null;
            // Scan finished, reload library
            loadLibrary();
          }
        }
      })
      .catch(err => {
        console.error('Error polling scanner status:', err);
        clearInterval(scanPollInterval);
        scanPollInterval = null;
      });
  }, 2000);
}

// -------------------------------------------------------------
// Data Loading
// -------------------------------------------------------------
function loadLibrary() {
  // Fetch tracks
  fetch(`${API_BASE}/api/tracks`)
    .then(res => res.json())
    .then(tracks => {
      state.tracks = tracks;
      if (window.location.hash === '#genres') {
        renderGenres();
      }
    })
    .catch(err => console.error('Error loading tracks:', err));

  // Fetch albums
  fetch(`${API_BASE}/api/albums`)
    .then(res => res.json())
    .then(albums => {
      state.albums = albums;
      if (window.location.hash === '#albums' || !window.location.hash) {
        renderAlbums();
      }
    })
    .catch(err => console.error('Error loading albums:', err));
    
  // Fetch artists
  fetch(`${API_BASE}/api/artists`)
    .then(res => res.json())
    .then(artists => {
      state.artists = artists;
      if (window.location.hash === '#artists') {
        renderArtists();
      }
    })
    .catch(err => console.error('Error loading artists:', err));
}

function loadCollections() {
  fetch(`${API_BASE}/api/collections`)
    .then(res => res.json())
    .then(collections => {
      state.collections = collections;
      if (window.location.hash === '#collections') {
        renderCollections();
      }
    })
    .catch(err => console.error('Error loading collections:', err));
}

// -------------------------------------------------------------
// Event Listeners Configuration
// -------------------------------------------------------------
function setupEventListeners() {
  // Search
  el.searchInput.oninput = () => {
    const hash = window.location.hash || '#albums';
    if (hash === '#albums') renderAlbums();
    if (hash === '#artists') renderArtists();
    if (hash === '#genres') renderGenres();
    if (hash === '#collections') renderCollections();
  };
  
  // Settings form
  el.formAddDir.onsubmit = (e) => {
    e.preventDefault();
    const newDir = el.dirInput.value.trim();
    if (!newDir) return;
    
    fetch(`${API_BASE}/api/settings`)
      .then(res => res.json())
      .then(settings => {
        const currentDirs = settings.musicDirs || [];
        if (!currentDirs.includes(newDir)) {
          currentDirs.push(newDir);
          saveSettingsDirs(currentDirs);
        }
        el.dirInput.value = '';
      });
  };
  
  el.btnScanLibrary.onclick = triggerScan;
  
  // Playback Buttons
  el.btnPlayPause.onclick = togglePlay;
  el.btnNext.onclick = nextTrack;
  el.btnPrev.onclick = prevTrack;
  el.btnShuffle.onclick = () => toggleShuffle();
  el.btnRepeat.onclick = () => {
    let nextLoop = 'None';
    if (state.loopStatus === 'None') nextLoop = 'Playlist';
    else if (state.loopStatus === 'Playlist') nextLoop = 'Track';
    setLoopStatus(nextLoop);
  };
  
  // Seek bar scrub interactions
  el.progressBar.oninput = (e) => {
    const duration = state.audio.duration || 0;
    if (duration > 0) {
      const targetTime = (e.target.value / 100) * duration;
      el.timeCurrent.innerText = formatTime(targetTime);
      el.progressFill.style.width = `${e.target.value}%`;
    }
  };
  
  el.progressBar.onchange = (e) => {
    const duration = state.audio.duration || 0;
    if (duration > 0) {
      state.audio.currentTime = (e.target.value / 100) * duration;
      reportState(true);
    }
  };
  
  // Volume bar interactions
  el.volumeBar.oninput = (e) => {
    const val = e.target.value / 100;
    setVolume(val);
  };
  
  // Mute toggle
  let prevVolume = 0.8;
  el.btnMute.onclick = () => {
    if (state.volume > 0) {
      prevVolume = state.volume;
      setVolume(0);
    } else {
      setVolume(prevVolume);
    }
  };
  
  // Modals close
  el.btnCloseAlbumModal.onclick = () => el.modalAlbum.classList.add('hidden');
  el.btnCloseCollectionModal.onclick = () => el.modalCollection.classList.add('hidden');
  
  // Close modals clicking outside content
  [el.modalAlbum, el.modalCollection].forEach(modal => {
    modal.onclick = (e) => {
      if (e.target === modal) {
        modal.classList.add('hidden');
      }
    };
  });
  
  // Collections creation
  const handleOpenNewCol = () => openCollectionModal();
  el.btnNewCollection.onclick = handleOpenNewCol;
  el.btnQuickCollection.onclick = handleOpenNewCol;
  el.btnAddRule.onclick = () => addRuleRow();
  el.formCollection.onsubmit = saveCollection;
  el.btnCancelCollection.onclick = () => el.modalCollection.classList.add('hidden');
}
