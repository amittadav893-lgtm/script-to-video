import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScriptToVideoApp());
}

class ScriptToVideoApp extends StatelessWidget {
  const ScriptToVideoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF8B5CF6),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Script to Video',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F1020),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF191A2F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scriptController = TextEditingController();
  final _tts = FlutterTts();

  bool _isProcessing = false;
  String _status = 'Ready to create your video.';
  String? _videoPath;
  double _progress = 0;

  @override
  void dispose() {
    _scriptController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<String> _generateVoiceover(String text, String directory) async {
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);

    final audioPath = '$directory/voiceover.wav';
    final result = await _tts.synthesizeToFile(text, audioPath);
    if (result != 1 && result != true) {
      throw StateError('The Android text-to-speech engine could not create audio.');
    }

    final audioFile = File(audioPath);
    for (var attempt = 0; attempt < 20; attempt++) {
      if (await audioFile.exists() && await audioFile.length() > 1024) {
        return audioPath;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw StateError('The voiceover file was not created by the device TTS engine.');
  }

  Future<String> _downloadVisual(String prompt, String directory) async {
    final visualPrompt = Uri.encodeComponent(
      'cinematic vertical video background, no text, no watermark: $prompt',
    );
    final uri = Uri.parse(
      'https://image.pollinations.ai/prompt/$visualPrompt?width=720&height=1280&nologo=true&model=flux',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Pollinations returned HTTP ${response.statusCode}.');
    }

    final imagePath = '$directory/visual.jpg';
    final imageFile = File(imagePath);
    await imageFile.writeAsBytes(response.bodyBytes, flush: true);
    if (!await imageFile.exists() || await imageFile.length() < 1024) {
      throw StateError('The generated visual was empty or invalid.');
    }
    return imagePath;
  }

  String _quote(String path) => "'${path.replaceAll("'", "'\\''")}'";

  Future<String> _renderVideo({
    required String imagePath,
    required String audioPath,
    required String directory,
  }) async {
    final outputPath = '$directory/script_to_video.mp4';
    final command = [
      '-y',
      '-loop 1',
      '-framerate 30',
      '-i ${_quote(imagePath)}',
      '-i ${_quote(audioPath)}',
      '-vf scale=720:1280:force_original_aspect_ratio=decrease,pad=720:1280:(ow-iw)/2:(oh-ih)/2,format=yuv420p',
      '-c:v libx264',
      '-preset veryfast',
      '-tune stillimage',
      '-c:a aac',
      '-b:a 192k',
      '-shortest',
      _quote(outputPath),
    ].join(' ');

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getOutput();
      throw StateError('FFmpeg failed. ${logs ?? 'No FFmpeg log was returned.'}');
    }
    return outputPath;
  }

  Future<void> _createVideo() async {
    final script = _scriptController.text.trim();
    if (script.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _videoPath = null;
      _progress = 0.05;
      _status = 'Preparing local workspace…';
    });

    try {
      final directory = (await getTemporaryDirectory()).path;
      final audioPath = await _generateVoiceover(script, directory);
      if (!mounted) return;
      setState(() {
        _progress = 0.35;
        _status = 'Voiceover created locally. Generating visual…';
      });

      final imagePath = await _downloadVisual(script, directory);
      if (!mounted) return;
      setState(() {
        _progress = 0.65;
        _status = 'Rendering MP4 on this device…';
      });

      final videoPath = await _renderVideo(
        imagePath: imagePath,
        audioPath: audioPath,
        directory: directory,
      );
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _videoPath = videoPath;
        _status = 'Video created successfully.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _progress = 0;
        _status = 'Could not create the video: $error';
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _loadExample() {
    _scriptController.text =
        'A quiet mountain lake reflects the first light of dawn. '
        'Mist moves slowly across the water as the world wakes up. '
        'Take a breath, slow down, and notice the beauty of this moment.';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Script to Video'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton.icon(
            onPressed: _isProcessing ? null : _loadExample,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Example'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Turn words into a video',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Native voiceover, a generated visual, and on-device MP4 rendering. No paid API key is required.',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _scriptController,
              enabled: !_isProcessing,
              minLines: 8,
              maxLines: 14,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Your script',
                hintText: 'Write or paste the narration for your video…',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 112),
                  child: Icon(Icons.subject),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isProcessing ? null : _createVideo,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              icon: _isProcessing
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.movie_creation_outlined),
              label: Text(_isProcessing ? 'Creating video…' : 'Generate video'),
            ),
            const SizedBox(height: 18),
            if (_isProcessing || _progress > 0) ...[
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: 12),
            ],
            Text(_status, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
            if (_videoPath != null) ...[
              const SizedBox(height: 20),
              Card(
                color: const Color(0xFF1B2434),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.greenAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Saved in the app cache:\n$_videoPath',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            const _InfoTile(
              icon: Icons.record_voice_over_outlined,
              title: 'Local TTS',
              body: 'Uses the Android device voice engine; narration is generated without a cloud voice API.',
            ),
            const _InfoTile(
              icon: Icons.image_outlined,
              title: 'Pollinations visual',
              body: 'Downloads one portrait visual from the public Pollinations image endpoint.',
            ),
            const _InfoTile(
              icon: Icons.settings_outlined,
              title: 'On-device rendering',
              body: 'FFmpeg combines the still image and voiceover into an H.264/AAC MP4 locally.',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(body),
    );
  }
}
