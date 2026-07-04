const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const libraryPath = path.join(__dirname, '../mock_music_library');

console.log('Generating mock music library at:', libraryPath);

// Create root directory
if (!fs.existsSync(libraryPath)) {
  fs.mkdirSync(libraryPath, { recursive: true });
}

// Helper to generate a solid color JPEG cover using ffmpeg
function generateCover(colorName, filename) {
  const targetPath = path.join(libraryPath, filename);
  if (!fs.existsSync(targetPath)) {
    try {
      execSync(`ffmpeg -y -f lavfi -i color=c=${colorName}:s=400x400 -frames:v 1 "${targetPath}"`, { stdio: 'ignore' });
      console.log(`Generated cover image: ${filename} (${colorName})`);
    } catch (err) {
      console.error(`Failed to generate cover image ${colorName}:`, err.message);
    }
  }
  return targetPath;
}

// Generate colors
const redCover = generateCover('red', 'cover_red.jpg');
const greenCover = generateCover('green', 'cover_green.jpg');
const blueCover = generateCover('blue', 'cover_blue.jpg');
const yellowCover = generateCover('yellow', 'cover_yellow.jpg');

// Helper to generate a silent audio file with metadata (and optional embedded cover)
function generateAudioTrack({ subDir, filename, title, artist, album, trackNo, discNo, year, genre, coverImage }) {
  const dir = path.join(libraryPath, subDir);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  
  const destPath = path.join(dir, filename);
  if (fs.existsSync(destPath)) return;

  try {
    // 1. Create a raw silent audio source with metadata
    // 2. Map the cover image if provided
    let cmd = '';
    if (coverImage && fs.existsSync(coverImage)) {
      cmd = `ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=stereo -i "${coverImage}" ` +
            `-map 0:a -map 1:v -c:a mp3 -c:v copy -t 3 -id3v2_version 3 ` +
            `-metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" ` +
            `-metadata title="${title}" -metadata artist="${artist}" -metadata album="${album}" ` +
            `-metadata track="${trackNo}" -metadata disc="${discNo}" -metadata date="${year}" ` +
            `-metadata genre="${genre}" "${destPath}"`;
    } else {
      cmd = `ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=stereo -t 3 -c:a mp3 ` +
            `-metadata title="${title}" -metadata artist="${artist}" -metadata album="${album}" ` +
            `-metadata track="${trackNo}" -metadata disc="${discNo}" -metadata date="${year}" ` +
            `-metadata genre="${genre}" "${destPath}"`;
    }
    
    execSync(cmd, { stdio: 'ignore' });
    console.log(`Generated track: ${subDir}/${filename}`);
  } catch (err) {
    console.error(`Failed to generate track ${filename}:`, err.message);
  }
}

// --- 1. Album: Fleetwood Mac - Rumours (Folder Cover Fallback) ---
const album1Dir = 'Fleetwood Mac - Rumours';
fs.mkdirSync(path.join(libraryPath, album1Dir), { recursive: true });
fs.copyFileSync(redCover, path.join(libraryPath, album1Dir, 'cover.jpg'));

generateAudioTrack({
  subDir: album1Dir,
  filename: '01 - Second Hand News.mp3',
  title: 'Second Hand News',
  artist: 'Fleetwood Mac',
  album: 'Rumours',
  trackNo: 1,
  discNo: 1,
  year: 1977,
  genre: 'Rock'
});
generateAudioTrack({
  subDir: album1Dir,
  filename: '02 - Dreams.mp3',
  title: 'Dreams',
  artist: 'Fleetwood Mac',
  album: 'Rumours',
  trackNo: 2,
  discNo: 1,
  year: 1977,
  genre: 'Rock'
});

// --- 2. Album: John Williams - Home Alone OST (Multi-Disc + Embedded Cover + Compound Genre) ---
// CD1
generateAudioTrack({
  subDir: 'John Williams - Home Alone OST/CD 1',
  filename: '01 - Main Title.mp3',
  title: 'Main Title (Somewhere in My Memory)',
  artist: 'John Williams',
  album: 'Home Alone OST',
  trackNo: 1,
  discNo: 1,
  year: 1990,
  genre: 'Soundtrack, Christmas',
  coverImage: greenCover
});
generateAudioTrack({
  subDir: 'John Williams - Home Alone OST/CD 1',
  filename: '02 - Somewhere in My Memory.mp3',
  title: 'Somewhere in My Memory',
  artist: 'John Williams',
  album: 'Home Alone OST',
  trackNo: 2,
  discNo: 1,
  year: 1990,
  genre: 'Soundtrack, Christmas',
  coverImage: greenCover
});

// CD2
generateAudioTrack({
  subDir: 'John Williams - Home Alone OST/CD 2',
  filename: '01 - Carol of the Bells.mp3',
  title: 'Carol of the Bells',
  artist: 'John Williams',
  album: 'Home Alone OST (CD 2)', // Test stripped suffix normalization
  trackNo: 1,
  discNo: 2,
  year: 1990,
  genre: 'Soundtrack, Christmas',
  coverImage: greenCover
});
generateAudioTrack({
  subDir: 'John Williams - Home Alone OST/CD 2',
  filename: '02 - Star of Bethlehem.mp3',
  title: 'Star of Bethlehem',
  artist: 'John Williams',
  album: 'Home Alone OST [CD 2]', // Test alternative bracket suffix normalization
  trackNo: 2,
  discNo: 2,
  year: 1990,
  genre: 'Soundtrack, Christmas',
  coverImage: greenCover
});

// --- 3. Album: The Beatles - Abbey Road (Embedded Cover) ---
generateAudioTrack({
  subDir: 'The Beatles - Abbey Road',
  filename: '01 - Come Together.mp3',
  title: 'Come Together',
  artist: 'The Beatles',
  album: 'Abbey Road',
  trackNo: 1,
  discNo: 1,
  year: 1969,
  genre: 'Pop, Rock',
  coverImage: blueCover
});
generateAudioTrack({
  subDir: 'The Beatles - Abbey Road',
  filename: '02 - Something.mp3',
  title: 'Something',
  artist: 'The Beatles',
  album: 'Abbey Road',
  trackNo: 2,
  discNo: 1,
  year: 1969,
  genre: 'Pop, Rock',
  coverImage: blueCover
});

// --- 4. Album: The Beatles - Help! (Folder Cover Fallback - folder.jpg) ---
const album4Dir = 'The Beatles - Help!';
fs.mkdirSync(path.join(libraryPath, album4Dir), { recursive: true });
fs.copyFileSync(yellowCover, path.join(libraryPath, album4Dir, 'folder.jpg'));

generateAudioTrack({
  subDir: album4Dir,
  filename: '01 - Help!.mp3',
  title: 'Help!',
  artist: 'The Beatles',
  album: 'Help!',
  trackNo: 1,
  discNo: 1,
  year: 1965,
  genre: 'Pop, Soundtrack'
});
generateAudioTrack({
  subDir: album4Dir,
  filename: '02 - The Night Before.mp3',
  title: 'The Night Before',
  artist: 'The Beatles',
  album: 'Help!',
  trackNo: 2,
  discNo: 1,
  year: 1965,
  genre: 'Pop, Rock'
});

// Clean up temporary root covers
['cover_red.jpg', 'cover_green.jpg', 'cover_blue.jpg', 'cover_yellow.jpg'].forEach(f => {
  const p = path.join(libraryPath, f);
  if (fs.existsSync(p)) fs.unlinkSync(p);
});

console.log('Mock music library generation finished.');
