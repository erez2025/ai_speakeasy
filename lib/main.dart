import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:record/record.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(TranslatorApp());
}

class TranslatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Translator MVP',
      theme: ThemeData.dark(),
      home: TranslatorHome(),
    );
  }
}

class TranslatorHome extends StatefulWidget {
  @override
  _TranslatorHomeState createState() => _TranslatorHomeState();
}

class _TranslatorHomeState extends State<TranslatorHome> {
  final TextEditingController _controller = TextEditingController();
  String _translatedText = '';
  String _selectedDirection = 'Hebrew';

  final recorder = Record();

  final String elevenLabsApiKey = ''; // תשאיר ריק - נשים אחר כך בצורה בטוחה
  final String elevenLabsVoiceId = '1f8V5azldZ2o9mrtuH1H';
  final String openAiApiKey = ''; // גם ריק

  Future<void> _startRecording() async {
    if (await recorder.hasPermission()) {
      Directory tempDir = await getTemporaryDirectory();
      String path = '${tempDir.path}/recording.m4a';
      await recorder.start(path: path);
    }
  }

  Future<void> _stopRecordingAndTranslate() async {
    final path = await recorder.stop();
    if (path != null) {
      await _sendToWhisperAndSpeak(File(path));
    }
  }

  Future<void> _sendToWhisperAndSpeak(File audioFile) async {
    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    var request =
        http.MultipartRequest('POST', url)
          ..headers['Authorization'] = 'Bearer $openAiApiKey'
          ..fields['model'] = 'whisper-1'
          ..fields['language'] = 'auto'
          ..fields['response_format'] = 'text'
          ..files.add(
            await http.MultipartFile.fromPath('file', audioFile.path),
          );

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      setState(() {
        _translatedText = responseBody.trim();
      });
      await _translateAndSpeak(responseBody.trim());
    } else {
      print('Failed to transcribe: ${response.statusCode}');
    }
  }

  Future<String> _translateText(String text, String direction) async {
    String prompt =
        "Translate this text into $direction, preserving slang and casual tone:\n\n$text";

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $openAiApiKey',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        "messages": [
          {"role": "user", "content": prompt},
        ],
      }),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['choices'][0]['message']['content'].toString().trim();
    } else {
      print('Translation failed');
      return '';
    }
  }

  Future<void> _translateAndSpeak(String inputText) async {
    final translated = await _translateText(inputText, _selectedDirection);

    setState(() {
      _translatedText = translated;
    });

    await _speakText(translated);
  }

  Future<void> _speakText(String text) async {
    final url = Uri.parse(
      'https://api.elevenlabs.io/v1/text-to-speech/$elevenLabsVoiceId',
    );
    final response = await http.post(
      url,
      headers: {
        'accept': 'audio/mpeg',
        'xi-api-key': elevenLabsApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "text": text,
        "model_id": "eleven_monolingual_v1",
        "voice_settings": {"stability": 0.5, "similarity_boost": 0.7},
      }),
    );

    if (response.statusCode == 200) {
      // תכנות נגן קול לאנדרואיד/אייפון (בהמשך נוסיף)
      print('Audio ready');
    } else {
      print('Failed to fetch audio: ${response.statusCode}');
    }
  }

  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Translator Mic')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _isRecording
                  ? 'Recording... Press again to stop'
                  : 'Press mic to record',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                if (!_isRecording) {
                  await _startRecording();
                } else {
                  await _stopRecordingAndTranslate();
                }
                setState(() {
                  _isRecording = !_isRecording;
                });
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 30),
            Text(
              _translatedText,
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
