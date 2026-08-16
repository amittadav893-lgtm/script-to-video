import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
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
    text: 'Ek nayi shuruat karne ke liye kisi khaas din ka intezar mat karo. Aaj ka din hi sabse behtar hai.',
  );
  
  bool _isGenerating = false;
  String? _statusMessage;
  String? _errorMessage;
  String? _videoPath;

  // Free Online TTS function using Google Translate Voice (NO API KEY REQUIRED)
  Future<File> _downloadOnlineTts(String text) async {
    final dir = await getTemporaryDirectory();
    final audioFile = File('${dir.path}/online_voiceover.mp3');

    // Auto-detect Hindi or English
    bool containsHindi = RegExp(r'[\u0900-\u097F]').hasMatch(text);
    String lang = containsHindi ? 'hi' : 'en';

    final uri = Uri.parse(
      'https://translate.google.com/translate_tts?ie=UTF-8&q=${Uri.encodeComponent(text)}&tl=$lang&client=tw-ob',
    );

    final response = await http.get(
      uri,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      },
    );

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      await audioFile.writeAsBytes(response.bodyBytes);
      return audioFile;
    } else {
      throw Exception('Online Voiceover Download Failed (Status: ${response.statusCode})');
    }
  }

  Future<void> _generateVideo() async {
    if (_controller.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Kripya pehle script likhein!';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _videoPath = null;
      _statusMessage = 'Voiceover download ho raha hai...';
    });

    try {
      final dir = await getTemporaryDirectory();
      final imagePath = '${dir.path}/visual.jpg';
      final outputPath = '${dir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // 1. Download Online Voiceover Audio (FREE - NO API KEY)
      final audioFile = await _downloadOnlineTts(_controller.text);

      setState(() {
        _statusMessage = 'Visual Image generate ho rahi hai...';
      });

      // 2. Fetch Visual Image from Pollinations AI (FREE - NO API KEY)
      final imageUrl = Uri.parse(
        'https://image.pollinations.ai/prompt/${Uri.encodeComponent(_controller.text)}?width=720&height=1280&nologo=true',
      );
      
      final imageResponse = await http.get(imageUrl).timeout(const Duration(seconds: 25));
      if (imageResponse.statusCode == 200) {
        await File(imagePath).writeAsBytes(imageResponse.bodyBytes);
      } else {
        throw Exception('Image generate nahi ho paayi. Internet connection check karein.');
      }

      setState(() {
        _statusMessage = 'Video render ho rahi hai...';
      });

      // 3. Render MP4 Video via FFmpeg
      final ffmpegCmd =
          '-loop 1 -i "$imagePath" -i "${audioFile.path}" -c:v libx264 -tune stillimage -c:a aac -b:a 192k -pix_fmt yuv420p -shortest -y "$outputPath"';

      final session = await FFmpegKit.execute(ffmpegCmd);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        setState(() {
          _videoPath = outputPath;
          _statusMessage = 'Video safaltapoorvak ban gayi!';
        });
      } else {
        throw Exception('FFmpeg video rendering fail ho gayi.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
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
      appBar: AppBar(
        title: const Text('Script to Video'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.stretch,
          children: [
            const Text(
              'Turn words into a video',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Online voiceover + AI visual + MP4 Rendering. No API key required!',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelText: 'Your Script',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateVideo,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isGenerating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Generating Video...'),
                      ],
                    )
                  : const Text(
                      'Generate Video',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            if (_isGenerating && _statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w500),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            if (_videoPath != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 48),
                    const SizedBox(height: 8),
                    const Text(
                      'Video Ban Gayi Hai!',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Location: $_videoPath',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
