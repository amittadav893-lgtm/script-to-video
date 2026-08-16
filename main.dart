
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Script to Video',
      theme: ThemeData.dark(),
      home: const VideoGeneratorScreen(),
    );
  }
}

class VideoGeneratorScreen extends StatefulWidget {
  const VideoGeneratorScreen({super.key});

  @override
  State<VideoGeneratorScreen> createState() => _VideoGeneratorScreenState();
}

class _VideoGeneratorScreenState extends State<VideoGeneratorScreen> {
  final TextEditingController _controller = TextEditingController(
    text: 'A quiet mountain lake reflects the first light of dawn.',
  );
  final FlutterTts _tts = FlutterTts();
  bool _isGenerating = false;
  String? _errorMessage;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _generateVideo() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _videoPath = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final audioPath = '${dir.path}/voiceover.wav';
      final imagePath = '${dir.path}/visual.jpg';
      final outputPath = '${dir.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // 1. Generate Voiceover
      await _tts.synthesizeToFile(_controller.text, 'voiceover.wav');
      await Future.delayed(const Duration(seconds: 3));

      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw Exception('TTS engine failed to create audio file.');
      }

      // 2. Fetch Visual Image
      final imageUrl = Uri.parse('https://image.pollinations.ai/prompt/${Uri.encodeComponent(_controller.text)}');
      final response = await http.get(imageUrl);
      if (response.statusCode == 200) {
        await File(imagePath).writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('Failed to download image.');
      }

      // 3. Render Video via FFmpeg
      final ffmpegCmd = '-loop 1 -i "$imagePath" -i "$audioPath" -c:v libx264 -tune stillimage -c:a aac -b:a 192k -pix_fmt yuv420p -shortest "$outputPath"';
      final session = await FFmpegKit.execute(ffmpegCmd);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        setState(() {
          _videoPath = outputPath;
        });
      } else {
        throw Exception('FFmpeg video rendering failed.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Script to Video')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Your Script',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateVideo,
              child: _isGenerating
                  ? const CircularProgressIndicator()
                  : const Text('Generate Video'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            if (_videoPath != null) ...[
              const SizedBox(height: 16),
              Text('Video Generated: $_videoPath', style: const TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }
}
