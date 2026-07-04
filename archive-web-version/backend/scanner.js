const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const musicMetadata = require('music-metadata');

// Supported audio extensions
const AUDIO_EXTENSIONS = new Set([
  '.mp3', '.m4a', '.ogg', '.flac', '.wav', '.aac', '.opus', '.wma'
]);

// Caches directory for covers
const COVERS_CACHE_DIR = path.join(__dirname, 'cache', 'covers');
if (!fs.existsSync(COVERS_CACHE_DIR)) {
  fs.mkdirSync(COVERS_CACHE_DIR, { recursive: true });
}

/**
 * Normalizes an album name and extracts the disc number.
 * e.g., "The Wall (CD 1)" -> { name: "The Wall", discNo: 1 }
 */
function normalizeAlbum(albumName, filePath, tagDiscNo) {
  if (!albumName) {
    return { name: 'Unknown Album', discNo: 1 };
  }

  let name = albumName.trim();
  let discNo = tagDiscNo || 1;

  // Regex to match (CD 1), [CD1], (Disc 2), - Disc 2, CD2, etc. at the end of the name
  const discRegex = /\s*[\(\[-]?\s*(?:CD|Disc|Disk|Disque)\s*(\d+)[\)\]]?\s*$/i;
  const match = name.match(discRegex);
  if (match) {
    discNo = parseInt(match[1], 10);
    name = name.replace(discRegex, '').trim();
  } else {
    // If not found in name, check the folder path (parent directory)
    const parentDir = path.basename(path.dirname(filePath));
    const parentMatch = parentDir.match(/^(?:CD|Disc|Disk|CD\s*|Disc\s*|Disk\s*)(\d+)$/i);
    if (parentMatch) {
      discNo = parseInt(parentMatch[1], 10);
    }
  }

  // If name becomes empty after stripping, restore the original
  if (!name) {
    name = albumName;
  }

  return { name, discNo };
}

/**
 * Finds all audio files in a directory recursively.
 */
function getAudioFiles(dir, files = []) {
  try {
    const list = fs.readdirSync(dir);
    for (const file of list) {
      const fullPath = path.join(dir, file);
      const stat = fs.statSync(fullPath);
      if (stat && stat.isDirectory()) {
        getAudioFiles(fullPath, files);
      } else {
        const ext = path.extname(file).toLowerCase();
        if (AUDIO_EXTENSIONS.has(ext)) {
          files.push(fullPath);
        }
      }
    }
  } catch (err) {
    console.error(`Error reading directory ${dir}:`, err);
  }
  return files;
}

/**
 * Scans directories, extracts metadata, saves covers, and returns tracks.
 */
async function scanMusicDirectories(directories, onProgress) {
  const tracks = [];
  const files = [];

  for (const dir of directories) {
    if (fs.existsSync(dir)) {
      getAudioFiles(dir, files);
    }
  }

  const totalFiles = files.length;
  console.log(`Found ${totalFiles} audio files to scan.`);

  for (let i = 0; i < totalFiles; i++) {
    const filePath = files[i];
    try {
      const metadata = await musicMetadata.parseFile(filePath);
      const { common, format } = metadata;

      // Extract raw metadata
      const rawAlbum = common.album || 'Unknown Album';
      const artist = common.artist || common.albumartist || 'Unknown Artist';
      const title = common.title || path.basename(filePath, path.extname(filePath));
      const trackNo = common.track && common.track.no ? common.track.no : null;
      const tagDiscNo = common.disk && common.disk.no ? common.disk.no : null;
      const year = common.year || null;
      const genre = common.genre && common.genre.length ? common.genre.join(', ') : 'Unknown';
      const duration = format.duration || 0;

      // Normalize album and get disc number
      const { name: album, discNo } = normalizeAlbum(rawAlbum, filePath, tagDiscNo);

      // Generate a unique ID for the track
      const trackId = crypto.createHash('md5').update(filePath).digest('hex');

      // Unique ID for the album (for caching cover art per-album)
      const albumKey = crypto.createHash('md5').update(`${album}::${artist}`).digest('hex');

      // Check if cover art exists or extract it
      let coverPath = null;
      const cachedCoverName = `${albumKey}.jpg`;
      const cachedCoverPath = path.join(COVERS_CACHE_DIR, cachedCoverName);

      if (fs.existsSync(cachedCoverPath)) {
        coverPath = `/api/covers/${cachedCoverName}`;
      } else {
        let coverBuffer = null;
        let mimeType = 'image/jpeg';

        // 1. Try embedded picture
        if (common.picture && common.picture.length > 0) {
          coverBuffer = common.picture[0].data;
          mimeType = common.picture[0].format || 'image/jpeg';
        }

        // 2. Try directory cover fallback
        if (!coverBuffer) {
          const parentDir = path.dirname(filePath);
          const dirFiles = fs.readdirSync(parentDir);
          const coverFile = dirFiles.find(f => {
            const name = f.toLowerCase();
            return name === 'cover.jpg' || name === 'cover.png' ||
                   name === 'folder.jpg' || name === 'folder.png' ||
                   name === 'album.jpg' || name === 'album.png';
          });
          if (coverFile) {
            const coverFullPath = path.join(parentDir, coverFile);
            coverBuffer = fs.readFileSync(coverFullPath);
            mimeType = coverFile.endsWith('.png') ? 'image/png' : 'image/jpeg';
          }
        }

        // Save cover buffer if found
        if (coverBuffer) {
          fs.writeFileSync(cachedCoverPath, coverBuffer);
          coverPath = `/api/covers/${cachedCoverName}`;
        }
      }

      tracks.push({
        id: trackId,
        filePath,
        title,
        artist,
        album,
        genre,
        year,
        trackNo,
        discNo,
        duration,
        coverPath
      });
    } catch (err) {
      console.error(`Error parsing metadata for file: ${filePath}`, err);
    }

    if (onProgress) {
      onProgress(i + 1, totalFiles);
    }
  }

  return tracks;
}

module.exports = {
  scanMusicDirectories
};
