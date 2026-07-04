const dbus = require('dbus-next');
const { Interface, method, property, signal } = dbus.interface;

// Helper to manually apply decorators to ES6 classes (to avoid needing Babel/TypeScript)
function applyMethod(klass, name, options = {}) {
  const originalFn = klass.prototype[name];
  const decorator = method(options);
  const fakeDescriptor = { key: name, descriptor: { value: originalFn } };
  const resultDescriptor = decorator(fakeDescriptor);
  if (resultDescriptor.finisher) resultDescriptor.finisher(klass);
}

function applyProperty(klass, name, signature, access = 'readwrite') {
  const decorator = property({ signature, access });
  const fakeDescriptor = { key: name, descriptor: {} };
  const resultDescriptor = decorator(fakeDescriptor);
  if (resultDescriptor.finisher) resultDescriptor.finisher(klass);
}

function applySignal(klass, name, signature) {
  const originalFn = klass.prototype[name];
  const decorator = signal({ signature });
  const fakeDescriptor = { key: name, descriptor: { value: originalFn } };
  const resultDescriptor = decorator(fakeDescriptor);
  klass.prototype[name] = resultDescriptor.descriptor.value;
  if (resultDescriptor.finisher) resultDescriptor.finisher(klass);
}

// 1. Define org.mpris.MediaPlayer2 Interface
class RootInterface extends Interface {
  constructor() {
    super('org.mpris.MediaPlayer2');
  }

  Raise() {
    console.log('MPRIS: Raise called');
  }

  Quit() {
    console.log('MPRIS: Quit called');
    process.exit(0);
  }

  get CanQuit() { return true; }
  get Fullscreen() { return false; }
  set Fullscreen(val) {}
  get CanSetFullscreen() { return false; }
  get CanRaise() { return false; }
  get HasTrackList() { return false; }
  get Identity() { return 'Aether Player'; }
  get DesktopEntry() { return 'aether'; }
  get SupportedUriSchemes() { return ['file']; }
  get SupportedMimeTypes() { return ['audio/mpeg', 'audio/ogg', 'audio/flac', 'audio/mp4']; }
}

applyMethod(RootInterface, 'Raise');
applyMethod(RootInterface, 'Quit');
applyProperty(RootInterface, 'CanQuit', 'b', 'read');
applyProperty(RootInterface, 'Fullscreen', 'b', 'readwrite');
applyProperty(RootInterface, 'CanSetFullscreen', 'b', 'read');
applyProperty(RootInterface, 'CanRaise', 'b', 'read');
applyProperty(RootInterface, 'HasTrackList', 'b', 'read');
applyProperty(RootInterface, 'Identity', 's', 'read');
applyProperty(RootInterface, 'DesktopEntry', 's', 'read');
applyProperty(RootInterface, 'SupportedUriSchemes', 'as', 'read');
applyProperty(RootInterface, 'SupportedMimeTypes', 'as', 'read');


// 2. Define org.mpris.MediaPlayer2.Player Interface
class PlayerInterface extends Interface {
  constructor(appState, onCommand) {
    super('org.mpris.MediaPlayer2.Player');
    this.appState = appState;
    this.onCommand = onCommand; // callback to send SSE events to frontend
  }

  Next() {
    console.log('MPRIS: Next called');
    this.onCommand({ action: 'next' });
  }

  Previous() {
    console.log('MPRIS: Previous called');
    this.onCommand({ action: 'previous' });
  }

  Pause() {
    console.log('MPRIS: Pause called');
    this.onCommand({ action: 'pause' });
  }

  PlayPause() {
    console.log('MPRIS: PlayPause called');
    this.onCommand({ action: 'playpause' });
  }

  Stop() {
    console.log('MPRIS: Stop called');
    this.onCommand({ action: 'stop' });
  }

  Play() {
    console.log('MPRIS: Play called');
    this.onCommand({ action: 'play' });
  }

  Seek(offsetMicroseconds) {
    console.log('MPRIS: Seek called with offset:', offsetMicroseconds);
    // Convert microseconds (BigInt or Number) to seconds
    const offsetSeconds = Number(offsetMicroseconds) / 1000000;
    this.onCommand({ action: 'seek', value: offsetSeconds });
  }

  SetPosition(trackId, positionMicroseconds) {
    console.log('MPRIS: SetPosition called:', trackId, positionMicroseconds);
    const positionSeconds = Number(positionMicroseconds) / 1000000;
    this.onCommand({ action: 'setposition', value: positionSeconds });
  }

  OpenUri(uri) {
    console.log('MPRIS: OpenUri called:', uri);
  }

  // Properties
  get PlaybackStatus() {
    return this.appState.playbackStatus || 'Stopped'; // Playing, Paused, Stopped
  }

  get LoopStatus() {
    return this.appState.loopStatus || 'None'; // None, Track, Playlist
  }
  set LoopStatus(val) {
    this.appState.loopStatus = val;
    this.onCommand({ action: 'loop', value: val });
  }

  get Rate() { return 1.0; }
  set Rate(val) {}

  get Shuffle() {
    return !!this.appState.shuffle;
  }
  set Shuffle(val) {
    this.appState.shuffle = val;
    this.onCommand({ action: 'shuffle', value: val });
  }

  get Metadata() {
    const track = this.appState.currentTrack;
    if (!track) {
      return {};
    }

    // MPRIS metadata format uses specific keys and variant types
    const mprisMetadata = {};

    // Track ID - must be a valid D-Bus object path.
    // We sanitize our MD5 track ID to fit /org/mpris/MediaPlayer2/Track/<id>
    mprisMetadata['mpris:trackid'] = new dbus.Variant('o', `/org/mpris/MediaPlayer2/Track/${track.id}`);
    
    // Length in microseconds
    if (track.duration) {
      const lengthUs = BigInt(Math.round(track.duration * 1000000));
      mprisMetadata['mpris:length'] = new dbus.Variant('x', lengthUs);
    }

    mprisMetadata['xesam:title'] = new dbus.Variant('s', track.title || 'Unknown Title');
    mprisMetadata['xesam:artist'] = new dbus.Variant('as', [track.artist || 'Unknown Artist']);
    mprisMetadata['xesam:album'] = new dbus.Variant('s', track.album || 'Unknown Album');

    if (track.coverPath) {
      // MPRIS expects an absolute URL or local path.
      // Since it's run locally, we serve the absolute url pointing to our server.
      const port = process.env.PORT || 3000;
      const absoluteCoverUrl = `http://localhost:${port}${track.coverPath}`;
      mprisMetadata['mpris:artUrl'] = new dbus.Variant('s', absoluteCoverUrl);
    }

    return mprisMetadata;
  }

  get Volume() {
    return this.appState.volume !== undefined ? this.appState.volume : 1.0;
  }
  set Volume(val) {
    this.appState.volume = val;
    this.onCommand({ action: 'volume', value: val });
  }

  get Position() {
    // Current position in microseconds
    const posSec = this.appState.position || 0;
    return BigInt(Math.round(posSec * 1000000));
  }

  get MinimumRate() { return 1.0; }
  get MaximumRate() { return 1.0; }
  get CanGoNext() { return true; }
  get CanGoPrevious() { return true; }
  get CanPlay() { return true; }
  get CanPause() { return true; }
  get CanSeek() { return true; }
  get CanControl() { return true; }

  // Signal
  Seeked(positionMicroseconds) {
    return positionMicroseconds;
  }
}

applyMethod(PlayerInterface, 'Next');
applyMethod(PlayerInterface, 'Previous');
applyMethod(PlayerInterface, 'Pause');
applyMethod(PlayerInterface, 'PlayPause');
applyMethod(PlayerInterface, 'Stop');
applyMethod(PlayerInterface, 'Play');
applyMethod(PlayerInterface, 'Seek', { inSignature: 'x' });
applyMethod(PlayerInterface, 'SetPosition', { inSignature: 'ox' });
applyMethod(PlayerInterface, 'OpenUri', { inSignature: 's' });

applyProperty(PlayerInterface, 'PlaybackStatus', 's', 'read');
applyProperty(PlayerInterface, 'LoopStatus', 's', 'readwrite');
applyProperty(PlayerInterface, 'Rate', 'd', 'readwrite');
applyProperty(PlayerInterface, 'Shuffle', 'b', 'readwrite');
applyProperty(PlayerInterface, 'Metadata', 'a{sv}', 'read');
applyProperty(PlayerInterface, 'Volume', 'd', 'readwrite');
applyProperty(PlayerInterface, 'Position', 'x', 'read');
applyProperty(PlayerInterface, 'MinimumRate', 'd', 'read');
applyProperty(PlayerInterface, 'MaximumRate', 'd', 'read');
applyProperty(PlayerInterface, 'CanGoNext', 'b', 'read');
applyProperty(PlayerInterface, 'CanGoPrevious', 'b', 'read');
applyProperty(PlayerInterface, 'CanPlay', 'b', 'read');
applyProperty(PlayerInterface, 'CanPause', 'b', 'read');
applyProperty(PlayerInterface, 'CanSeek', 'b', 'read');
applyProperty(PlayerInterface, 'CanControl', 'b', 'read');

applySignal(PlayerInterface, 'Seeked', 'x');


let bus = null;
let rootIface = null;
let playerIface = null;

function initMpris(appState, onCommand) {
  try {
    bus = dbus.sessionBus();
    
    rootIface = new RootInterface();
    playerIface = new PlayerInterface(appState, onCommand);

    const objectPath = '/org/mpris/MediaPlayer2';
    
    bus.export(objectPath, rootIface);
    bus.export(objectPath, playerIface);

    const busName = 'org.mpris.MediaPlayer2.aether';
    
    bus.requestName(busName)
      .then(() => {
        console.log(`MPRIS: Registered successfully on D-Bus as ${busName}`);
      })
      .catch(err => {
        console.error('MPRIS: Failed to request name on D-Bus (are you running in a GUI session?):', err.message);
      });

  } catch (err) {
    console.error('MPRIS: Could not initialize D-Bus / MPRIS. Running in fallback mode without media keys support.', err.message);
  }
}

function updateMprisState(changedProps) {
  if (!playerIface || !bus) return;

  try {
    // Collect changed properties to emit PropertiesChanged signal
    const body = {};
    const invalidated = [];

    // Map changed properties to their D-Bus representation
    for (const key of changedProps) {
      if (key === 'playbackStatus') {
        body['PlaybackStatus'] = new dbus.Variant('s', playerIface.PlaybackStatus);
      } else if (key === 'loopStatus') {
        body['LoopStatus'] = new dbus.Variant('s', playerIface.LoopStatus);
      } else if (key === 'shuffle') {
        body['Shuffle'] = new dbus.Variant('b', playerIface.Shuffle);
      } else if (key === 'volume') {
        body['Volume'] = new dbus.Variant('d', playerIface.Volume);
      } else if (key === 'currentTrack') {
        body['Metadata'] = new dbus.Variant('a{sv}', playerIface.Metadata);
      } else if (key === 'position') {
        // Position changes fast, but we typically don't flood PropertiesChanged
        body['Position'] = new dbus.Variant('x', playerIface.Position);
      }
    }

    if (Object.keys(body).length > 0) {
      // Emit the org.freedesktop.DBus.Properties.PropertiesChanged signal
      // Signature is: s (interface_name), a{sv} (changed_properties), as (invalidated_properties)
      const signalMsg = dbus.Message.newSignal('/org/mpris/MediaPlayer2', 'org.freedesktop.DBus.Properties', 'PropertiesChanged', 'sa{sv}as', [
        'org.mpris.MediaPlayer2.Player',
        body,
        invalidated
      ]);
      bus.send(signalMsg);
    }
  } catch (err) {
    console.error('MPRIS: Error emitting PropertiesChanged signal:', err);
  }
}

function emitSeeked(positionSeconds) {
  if (!playerIface) return;
  try {
    const positionUs = BigInt(Math.round(positionSeconds * 1000000));
    playerIface.Seeked(positionUs);
  } catch (err) {
    console.error('MPRIS: Error emitting Seeked signal:', err);
  }
}

module.exports = {
  initMpris,
  updateMprisState,
  emitSeeked
};
