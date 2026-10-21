import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/note.dart';
import '../models/recording.dart';
import '../models/song.dart';
import '../services/audio_service.dart';
import '../services/settings_store.dart';
import '../services/tone_synth.dart';
import '../services/tune_exporter.dart';

enum Transport { idle, recording, playing }

/// Owns all interactive state for the instrument: the active octave & volume,
/// the record/play transport, the captured tune, and the song being learnt.
/// Widgets listen to this and stay dumb.
class XylophoneController extends ChangeNotifier {
  final AudioService _audio;
  final SettingsStore _store;

  XylophoneController(this._audio, this._store) {
    _octave = _store.octave;
    _volume = _store.volume;
    _recording = _store.recording;
    _saved = _recording != null; // a persisted tune is, by definition, saved
    _audio.octave = _octave;
    _audio.volume = _volume;
  }

  late Octave _octave;
  late double _volume;
  Recording? _recording;
  bool _saved = false;

  Transport _transport = Transport.idle;
  final Stopwatch _watch = Stopwatch();
  final List<RecordedHit> _captured = [];
  final List<Timer> _playbackTimers = [];

  /// Pulses the index of the key being struck so the UI can flash it during
  /// playback (and on tap). Carries an incrementing token so repeated hits on
  /// the same key still notify.
  final ValueNotifier<({int index, int token})?> struck = ValueNotifier(null);
  int _token = 0;

  Song? _song;
  int _songStep = 0;
  final StreamController<Song> _songDone = StreamController.broadcast();

  // The last cleared tune, kept briefly so "Undo" can bring it back.
  Recording? _cleared;
  bool _clearedWasSaved = false;

  Octave get octave => _octave;
  double get volume => _volume;
  bool get muted => _audio.muted;
  Transport get transport => _transport;
  bool get isRecording => _transport == Transport.recording;
  bool get isPlaying => _transport == Transport.playing;
  bool get hasRecording => (_recording?.isEmpty == false);

  /// Whether the current tune has been persisted (a Pro feature).
  bool get isSaved => _saved;

  /// The song being learnt, if any.
  Song? get activeSong => _song;

  /// How many notes of [activeSong] have been played correctly so far.
  int get songStep => _songStep;

  /// The key the child should strike next (glows on the keyboard).
  int? get expectedKey {
    final song = _song;
    if (song == null || isPlaying || _songStep >= song.notes.length) {
      return null;
    }
    return song.notes[_songStep].noteIndex;
  }

  /// Fires each time the child finishes playing [activeSong].
  Stream<Song> get songCompleted => _songDone.stream;

  /// Note indices of the recorded tune, in order (used for the dots preview).
  List<int> get recordedNoteIndices =>
      _recording?.hits.map((h) => h.noteIndex).toList(growable: false) ??
      const [];

  // ── Live playing ───────────────────────────────────────────────────────────

  /// Called when the user taps a key.
  void strike(int index) {
    _audio.play(index);
    HapticFeedback.lightImpact();
    _pulse(index);
    if (_transport == Transport.recording) {
      _captured.add(RecordedHit(
        noteIndex: index,
        octave: _octave,
        atMs: _watch.elapsedMilliseconds,
      ));
    }
    _advanceSong(index);
  }

  void _advanceSong(int index) {
    final song = _song;
    if (song == null || index != expectedKey) return;
    _songStep++;
    if (_songStep >= song.notes.length) {
      _songStep = 0; // ready to play again
      HapticFeedback.heavyImpact();
      _songDone.add(song);
    }
    notifyListeners();
  }

  void _pulse(int index) {
    _token++;
    struck.value = (index: index, token: _token);
  }

  // ── Settings ─────────────────────────────────────────────────────────────────

  void setOctave(Octave o) {
    if (o == _octave) return;
    _octave = o;
    _audio.octave = o;
    _store.octave = o;
    notifyListeners();
  }

  void nudgeOctave(int dir) {
    final next = dir < 0 ? _octave.lower : _octave.higher;
    if (next != null) setOctave(next);
  }

  void setVolume(double v) {
    _volume = v;
    _audio.volume = v;
    if (_audio.muted) _audio.muted = false; // un-mute when the user drags volume
    _store.volume = v;
    notifyListeners();
  }

  void toggleMute() {
    _audio.muted = !_audio.muted;
    notifyListeners();
  }

  // ── Songs ────────────────────────────────────────────────────────────────

  void startSong(Song song) {
    stopPlayback();
    _song = song;
    _songStep = 0;
    notifyListeners();
  }

  void restartSong() {
    if (_song == null) return;
    _songStep = 0;
    notifyListeners();
  }

  void exitSong() {
    if (_song == null) return;
    if (isPlaying) stopPlayback();
    _song = null;
    _songStep = 0;
    notifyListeners();
  }

  /// Plays [activeSong] once as a demonstration, flashing each key.
  void playSongDemo() {
    final song = _song;
    if (song == null || _transport != Transport.idle) return;
    _transport = Transport.playing;
    notifyListeners();

    const beatMs = 430;
    var at = 0;
    for (final note in song.notes) {
      _playbackTimers.add(Timer(Duration(milliseconds: at), () {
        _audio.play(note.noteIndex);
        _pulse(note.noteIndex);
      }));
      at += (note.beats * beatMs).round();
    }
    _playbackTimers.add(Timer(Duration(milliseconds: at + 300), stopPlayback));
  }

  // ── Record / play transport ──────────────────────────────────────────────────

  void toggleRecord() {
    switch (_transport) {
      case Transport.recording:
        _stopRecording();
        break;
      case Transport.playing:
        stopPlayback();
        _startRecording();
        break;
      case Transport.idle:
        _startRecording();
        break;
    }
  }

  void _startRecording() {
    _captured.clear();
    _watch
      ..reset()
      ..start();
    _transport = Transport.recording;
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  void _stopRecording() {
    _watch.stop();
    _transport = Transport.idle;
    _recording = _captured.isEmpty ? null : Recording(List.of(_captured));
    _lastSavedPath = null; // any exported file belongs to the previous tune
    // A fresh recording is held in memory only; persisting it ("Save") is a Pro
    // feature handled by [saveRecording]. Replacing the previous tune drops its
    // saved copy so a free user can't keep an old saved tune around.
    _saved = false;
    _store.recording = null;
    HapticFeedback.mediumImpact();
    notifyListeners();
  }

  /// Persist the current tune so it survives app restarts. Pro-only — the UI
  /// must check entitlement (and offer the upsell) before calling this.
  void saveRecording() {
    if (_recording == null || _recording!.isEmpty || _saved) return;
    _store.recording = _recording;
    _saved = true;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  String? _lastSavedPath;

  /// Render the current tune to a `.wav` audio file in local storage (Pro
  /// feature). Returns the save result, or null if there's nothing to export.
  Future<TuneSaveResult?> exportRecordingToFile() async {
    final rec = _recording;
    if (rec == null || rec.isEmpty) return null;
    final notes = rec.hits
        .map((h) => (
              freq: ToneSynth.baseFreqs[h.noteIndex] * h.octave.rate,
              atMs: h.atMs,
            ))
        .toList(growable: false);
    final wav = ToneSynth.renderTuneWav(notes);
    final result = await TuneExporter.save(wav);
    _lastSavedPath = result.filePath;
    return result;
  }

  /// Share the tune as an audio file via the system share sheet (exports first
  /// if it hasn't been rendered to a file yet this session).
  Future<void> shareTune() async {
    if (_lastSavedPath == null) {
      await exportRecordingToFile();
    }
    final path = _lastSavedPath;
    if (path == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'My Xylophone tune 🎵'),
    );
  }

  void playRecording() {
    final rec = _recording;
    if (rec == null || rec.isEmpty || _transport == Transport.playing) return;
    _transport = Transport.playing;
    notifyListeners();

    for (final hit in rec.hits) {
      _playbackTimers.add(Timer(Duration(milliseconds: hit.atMs), () {
        _audio.play(hit.noteIndex, octave: hit.octave);
        _pulse(hit.noteIndex);
      }));
    }
    // End-of-tune: settle back to idle a beat after the last note.
    _playbackTimers.add(Timer(
      Duration(milliseconds: rec.durationMs + 400),
      stopPlayback,
    ));
  }

  void stopPlayback() {
    for (final t in _playbackTimers) {
      t.cancel();
    }
    _playbackTimers.clear();
    if (_transport == Transport.playing) {
      _transport = Transport.idle;
      // Reset the live octave on players after playback may have changed it.
      _audio.octave = _octave;
      notifyListeners();
    }
  }

  void clearRecording() {
    stopPlayback();
    _cleared = _recording;
    _clearedWasSaved = _saved;
    _recording = null;
    _saved = false;
    _lastSavedPath = null;
    _store.recording = null;
    notifyListeners();
  }

  /// Brings back the tune removed by the last [clearRecording], if no new
  /// tune has been recorded since.
  void undoClear() {
    final rec = _cleared;
    _cleared = null;
    if (rec == null || hasRecording || isRecording) return;
    _recording = rec;
    _saved = _clearedWasSaved;
    if (_saved) _store.recording = rec;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPlayback();
    _songDone.close();
    struck.dispose();
    super.dispose();
  }
}
