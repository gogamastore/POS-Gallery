import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;

class SoundService {
  // Satu instance AudioPlayer untuk seluruh aplikasi
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Pre-load path ke file suara
  final AssetSource _successSound = AssetSource('sounds/success.mp3');
  final AssetSource _errorSound = AssetSource('sounds/error.mp3');

  SoundService() {
    // Mengatur mode rilis agar sumber daya dilepaskan setelah pemutaran selesai
    _audioPlayer.setReleaseMode(ReleaseMode.release);
  }

  Future<void> playSuccessSound() async {
    try {
      await _audioPlayer.play(_successSound);
      developer.log('Successfully played success sound.', name: 'SoundService');
    } catch (e, stackTrace) {
      developer.log(
        'Error playing success sound.',
        name: 'SoundService',
        error: e,
        stackTrace: stackTrace,
        level: 1000, // SEVERE
      );
      // Jika suara gagal diputar, aplikasi tidak akan crash
    }
  }

  Future<void> playErrorSound() async {
    try {
      await _audioPlayer.play(_errorSound);
      developer.log('Successfully played error sound.', name: 'SoundService');
    } catch (e, stackTrace) {
      developer.log(
        'Error playing error sound.',
        name: 'SoundService',
        error: e,
        stackTrace: stackTrace,
        level: 1000, // SEVERE
      );
    }
  }

  // Panggil metode ini saat aplikasi ditutup untuk membersihkan sumber daya
  void dispose() {
    _audioPlayer.dispose();
  }
}
