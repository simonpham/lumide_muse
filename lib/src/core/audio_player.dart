import 'dart:async';

/// Thrown when the audio engine cannot be loaded. [message] is shown to the
/// user as is.
class AudioEngineException implements Exception {
  const AudioEngineException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The audio backend used by `MusicService`.
///
/// The streams are broadcast streams that can be listened to before
/// [initialize] runs; they start emitting once the engine is up.
abstract class BaseAudioPlayer {
  /// Loads the engine. Safe to call more than once; throws
  /// [AudioEngineException] when the engine is unavailable.
  Future<void> initialize();

  /// Opens [path] and starts playing it.
  Future<void> open(String path);

  Future<void> playOrPause();

  /// Seeks to [progress], a fraction of the track between 0 and 1.
  Future<void> seek(double progress);

  Future<void> dispose();

  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;
  Stream<bool> get completed;
}
