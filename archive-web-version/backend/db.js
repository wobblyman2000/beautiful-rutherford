const fs = require('fs');
const path = require('path');

const DB_FILE = path.join(__dirname, '../db.json');

const defaultData = {
  settings: {
    musicDirs: []
  },
  tracks: [],
  collections: []
};

function readDb() {
  try {
    if (!fs.existsSync(DB_FILE)) {
      writeDb(defaultData);
      return defaultData;
    }
    const content = fs.readFileSync(DB_FILE, 'utf8');
    return JSON.parse(content);
  } catch (err) {
    console.error('Error reading database file, returning default schema:', err);
    return defaultData;
  }
}

function writeDb(data) {
  try {
    fs.writeFileSync(DB_FILE, JSON.stringify(data, null, 2), 'utf8');
  } catch (err) {
    console.error('Error writing database file:', err);
  }
}

module.exports = {
  getSettings() {
    return readDb().settings || { musicDirs: [] };
  },
  saveSettings(settings) {
    const data = readDb();
    data.settings = settings;
    writeDb(data);
  },
  getTracks() {
    return readDb().tracks || [];
  },
  saveTracks(tracks) {
    const data = readDb();
    data.tracks = tracks;
    writeDb(data);
  },
  getCollections() {
    return readDb().collections || [];
  },
  saveCollections(collections) {
    const data = readDb();
    data.collections = collections;
    writeDb(data);
  }
};
