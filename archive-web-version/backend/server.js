const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const db = require('./db');
const { scanMusicDirectories } = require('./scanner');
const { initMpris, updateMprisState, emitSeeked } = require('./mpris');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Serve covers from the cache directory
app.use('/api/covers', express.static(path.join(__dirname, 'cache', 'covers')));

// Serve frontend build static files in production
const frontendDistPath = path.join(__dirname, '../frontend/dist');
if (fs.existsSync(frontendDistPath)) {
  app.use(express.static(frontendDistPath));
}

// -------------------------------------------------------------
// Global Playback State (for MPRIS syncing)
// -------------------------------------------------------------
const appState = {
  playbackStatus: 'Stopped', // Playing, Paused, Stopped
  loopStatus: 'None', // None, Track, Playlist
  shuffle: false,
  volume: 1.0,
  position: 0,
  currentTrack: null
};

// SSE clients listening for remote controls (KDE MPRIS -> Frontend)
let sseClients = [];

function sendCommandToClients(command) {
  const data = JSON.stringify(command);
  sseClients.forEach(client => {
    client.write(`data: ${data}\n\n`);
  });
}

// Initialize MPRIS integration
initMpris(appState, (cmd) => {
  // Callback when KDE sends a command
  console.log('Sending remote command to frontend:', cmd);
  sendCommandToClients(cmd);
});

// SSE Endpoint for frontend to register
app.get('/api/player/events', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  sseClients.push(res);
  console.log(`Frontend client connected to events. Active: ${sseClients.length}`);

  req.on('close', () => {
    sseClients = sseClients.filter(c => c !== res);
    console.log(`Frontend client disconnected. Active: ${sseClients.length}`);
  });
});

// Update state from frontend
app.post('/api/player/state', (req, res) => {
  const { trackId, playbackStatus, loopStatus, shuffle, volume, position, seeked } = req.body;
  const changed = [];

  if (trackId !== undefined) {
    const tracks = db.getTracks();
    const track = tracks.find(t => t.id === trackId) || null;
    if (JSON.stringify(appState.currentTrack) !== JSON.stringify(track)) {
      appState.currentTrack = track;
      changed.push('currentTrack');
    }
  }
  if (playbackStatus !== undefined && appState.playbackStatus !== playbackStatus) {
    appState.playbackStatus = playbackStatus;
    changed.push('playbackStatus');
  }
  if (loopStatus !== undefined && appState.loopStatus !== loopStatus) {
    appState.loopStatus = loopStatus;
    changed.push('loopStatus');
  }
  if (shuffle !== undefined && appState.shuffle !== shuffle) {
    appState.shuffle = shuffle;
    changed.push('shuffle');
  }
  if (volume !== undefined && appState.volume !== volume) {
    appState.volume = volume;
    changed.push('volume');
  }
  if (position !== undefined) {
    appState.position = position;
    // We update position internally, but typically don't trigger PropertiesChanged on every second
  }

  if (changed.length > 0) {
    updateMprisState(changed);
  }

  if (seeked !== undefined && seeked) {
    emitSeeked(position);
  }

  res.json({ success: true });
});

// -------------------------------------------------------------
// Music Library API
// -------------------------------------------------------------
let isScanning = false;

app.get('/api/status', (req, res) => {
  const tracks = db.getTracks();
  res.json({
    scanning: isScanning,
    totalTracks: tracks.length
  });
});

app.post('/api/scan', async (req, res) => {
  if (isScanning) {
    return res.status(400).json({ error: 'Scan already in progress' });
  }

  const settings = db.getSettings();
  if (!settings.musicDirs || settings.musicDirs.length === 0) {
    return res.status(400).json({ error: 'No music directories configured' });
  }

  isScanning = true;
  res.json({ success: true, message: 'Scan started' });

  try {
    const tracks = await scanMusicDirectories(settings.musicDirs);
    db.saveTracks(tracks);
    console.log(`Scan completed. Scanned ${tracks.length} tracks.`);
  } catch (err) {
    console.error('Scanning failed:', err);
  } finally {
    isScanning = false;
  }
});

app.get('/api/settings', (req, res) => {
  res.json(db.getSettings());
});

app.post('/api/settings', (req, res) => {
  const { musicDirs } = req.body;
  if (!Array.isArray(musicDirs)) {
    return res.status(400).json({ error: 'musicDirs must be an array' });
  }
  db.saveSettings({ musicDirs });
  res.json({ success: true });
});

app.get('/api/tracks', (req, res) => {
  res.json(db.getTracks());
});

// Get albums grouped, combined (e.g. CD1 and CD2 as one album)
app.get('/api/albums', (req, res) => {
  const tracks = db.getTracks();
  const albumsMap = {};

  for (const track of tracks) {
    const artist = track.artist || 'Unknown Artist';
    const albumName = track.album || 'Unknown Album';
    // Use artist + album as unique identifier for combining CDs
    const key = `${albumName}::${artist}`.toLowerCase();

    if (!albumsMap[key]) {
      albumsMap[key] = {
        id: key,
        name: albumName,
        artist: artist,
        year: track.year,
        genre: track.genre,
        coverPath: track.coverPath,
        tracks: []
      };
    }

    // Capture the first valid cover path found for the album
    if (!albumsMap[key].coverPath && track.coverPath) {
      albumsMap[key].coverPath = track.coverPath;
    }
    // Update year if not set
    if (!albumsMap[key].year && track.year) {
      albumsMap[key].year = track.year;
    }

    albumsMap[key].tracks.push(track);
  }

  // Convert to array and sort tracks inside each album
  const albums = Object.values(albumsMap).map(album => {
    // Sort tracks by Disc Number, then Track Number, then Title
    album.tracks.sort((a, b) => {
      if (a.discNo !== b.discNo) {
        return (a.discNo || 1) - (b.discNo || 1);
      }
      if (a.trackNo !== b.trackNo) {
        return (a.trackNo || 0) - (b.trackNo || 0);
      }
      return a.title.localeCompare(b.title);
    });

    // Extract unique discs available
    const discsSet = new Set(album.tracks.map(t => t.discNo || 1));
    album.discs = Array.from(discsSet).sort((a, b) => a - b);
    album.totalDuration = album.tracks.reduce((acc, t) => acc + (t.duration || 0), 0);

    return album;
  });

  // Sort albums alphabetically by name
  albums.sort((a, b) => a.name.localeCompare(b.name));

  res.json(albums);
});

// Get artists view (grouped by artist)
app.get('/api/artists', (req, res) => {
  const tracks = db.getTracks();
  const artistsMap = {};

  for (const track of tracks) {
    const artist = track.artist || 'Unknown Artist';
    const key = artist.toLowerCase();

    if (!artistsMap[key]) {
      artistsMap[key] = {
        name: artist,
        albums: {}
      };
    }

    const albumName = track.album || 'Unknown Album';
    const albumKey = albumName.toLowerCase();

    if (!artistsMap[key].albums[albumKey]) {
      artistsMap[key].albums[albumKey] = {
        name: albumName,
        coverPath: track.coverPath,
        year: track.year,
        trackCount: 0
      };
    }

    if (!artistsMap[key].albums[albumKey].coverPath && track.coverPath) {
      artistsMap[key].albums[albumKey].coverPath = track.coverPath;
    }

    artistsMap[key].albums[albumKey].trackCount++;
  }

  // Convert to array format
  const artists = Object.values(artistsMap).map(artist => {
    return {
      name: artist.name,
      albums: Object.values(artist.albums).sort((a, b) => a.name.localeCompare(b.name))
    };
  });

  // Sort artists alphabetically
  artists.sort((a, b) => a.name.localeCompare(b.name));

  res.json(artists);
});

// -------------------------------------------------------------
// Smart Collections API
// -------------------------------------------------------------
app.get('/api/collections', (req, res) => {
  res.json(db.getCollections());
});

app.post('/api/collections', (req, res) => {
  const { name, rules, coverPath } = req.body;
  if (!name || !Array.isArray(rules)) {
    return res.status(400).json({ error: 'name and rules (array) are required' });
  }

  const collections = db.getCollections();
  const newCollection = {
    id: `col-${Date.now()}`,
    name,
    rules,
    coverPath: coverPath || null
  };

  collections.push(newCollection);
  db.saveCollections(collections);
  res.status(201).json(newCollection);
});

app.put('/api/collections/:id', (req, res) => {
  const { id } = req.params;
  const { name, rules, coverPath } = req.body;
  
  const collections = db.getCollections();
  const idx = collections.findIndex(c => c.id === id);
  if (idx === -1) {
    return res.status(404).json({ error: 'Collection not found' });
  }

  if (name !== undefined) collections[idx].name = name;
  if (rules !== undefined) collections[idx].rules = rules;
  if (coverPath !== undefined) collections[idx].coverPath = coverPath;

  db.saveCollections(collections);
  res.json(collections[idx]);
});

app.delete('/api/collections/:id', (req, res) => {
  const { id } = req.params;
  let collections = db.getCollections();
  
  if (!collections.some(c => c.id === id)) {
    return res.status(404).json({ error: 'Collection not found' });
  }

  collections = collections.filter(c => c.id !== id);
  db.saveCollections(collections);
  res.json({ success: true });
});

// -------------------------------------------------------------
// Audio Streaming Endpoint (supports HTTP Range requests for seeking)
// -------------------------------------------------------------
app.get('/stream/:trackId', (req, res) => {
  const { trackId } = req.params;
  const tracks = db.getTracks();
  const track = tracks.find(t => t.id === trackId);

  if (!track) {
    return res.status(404).json({ error: 'Track not found' });
  }

  const filePath = track.filePath;
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'Audio file not found on disk' });
  }

  try {
    const stat = fs.statSync(filePath);
    const totalSize = stat.size;
    const range = req.headers.range;

    // Detect MIME type
    const ext = path.extname(filePath).toLowerCase();
    let mimeType = 'audio/mpeg';
    if (ext === '.ogg' || ext === '.opus') mimeType = 'audio/ogg';
    if (ext === '.flac') mimeType = 'audio/flac';
    if (ext === '.wav') mimeType = 'audio/wav';
    if (ext === '.m4a') mimeType = 'audio/mp4';

    if (range) {
      const parts = range.replace(/bytes=/, "").split("-");
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : totalSize - 1;

      if (start >= totalSize || end >= totalSize) {
        res.writeHead(416, { 'Content-Range': `bytes */${totalSize}` });
        return res.end();
      }

      const chunksize = (end - start) + 1;
      const fileStream = fs.createReadStream(filePath, { start, end });
      const head = {
        'Content-Range': `bytes ${start}-${end}/${totalSize}`,
        'Accept-Ranges': 'bytes',
        'Content-Length': chunksize,
        'Content-Type': mimeType,
      };
      res.writeHead(206, head);
      fileStream.pipe(res);
    } else {
      const head = {
        'Content-Length': totalSize,
        'Content-Type': mimeType,
      };
      res.writeHead(200, head);
      fs.createReadStream(filePath).pipe(res);
    }
  } catch (err) {
    console.error(`Streaming error for track ${trackId}:`, err);
    res.status(500).json({ error: 'Internal streaming error' });
  }
});

// Fallback to index.html for frontend routing
app.get('*', (req, res) => {
  if (fs.existsSync(path.join(frontendDistPath, 'index.html'))) {
    res.sendFile(path.join(frontendDistPath, 'index.html'));
  } else {
    res.status(404).send('Frontend not built yet. Run build or start dev server.');
  }
});

app.listen(PORT, () => {
  console.log(`==================================================`);
  console.log(`  Aether Player Backend Running on http://localhost:${PORT}`);
  console.log(`==================================================`);
  
  // Auto-open browser in Linux (KDE)
  const { exec } = require('child_process');
  exec(`xdg-open http://localhost:${PORT}`, (err) => {
    if (err) {
      console.log('Could not auto-open browser via xdg-open. Please open http://localhost:' + PORT + ' manually.');
    }
  });
});
