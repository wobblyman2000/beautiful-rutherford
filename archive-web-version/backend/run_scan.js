const db = require('./db');
const { scanMusicDirectories } = require('./scanner');

const settings = db.getSettings();
console.log('Running scan on directories:', settings.musicDirs);

scanMusicDirectories(settings.musicDirs)
  .then(tracks => {
    db.saveTracks(tracks);
    console.log(`Scan complete! Saved ${tracks.length} tracks.`);
    process.exit(0);
  })
  .catch(err => {
    console.error('Scan failed:', err);
    process.exit(1);
  });
