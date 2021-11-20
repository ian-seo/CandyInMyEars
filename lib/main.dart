import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:record/record.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VoiceHome(),
    );
  }
}

class VoiceHome extends StatefulWidget {
  final void Function(String path) onStop;

  const VoiceHome({@required this.onStop});

  @override
  _VoiceHomeState createState() => _VoiceHomeState();
}

class _VoiceHomeState extends State<VoiceHome> {
  bool _isAvailable = false;
  bool _isListening = false;
  bool _isFinishOnce = false;
  bool _isError = false;
  bool _logEvents = true;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;

  String previousText = '';
  String resultText = '';
  int previousElapsedListenMillis = 0;
  int currentElapsedListenMillis = 0;

  String lastWord = '';
  String lastError = '';
  String lastStatus = '';
  String _currentLocaleId = '';
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  Timer _timer;
  Timer _ampTimer;
  final _audioRecorder = Record();
  Amplitude _amplitude;


  String resultTxtSentence = "";
  List<int> elapsedMillisArray = [];
  List<String> wordArray = [];
  List<String> badWords = ['시발', '씨발', '썅년', '썅놈', '개새', '쌍놈', '쌍년', '지랄', '병신', '18', '바보', '쉣', '멍청'];

  AudioCache audioCache = AudioCache();

  @override
  void initState() {
    super.initState();
    initSpeechState();
  }

  /// This initializes SpeechToText. That only has to be done
  /// once per application, though calling it again is harmless
  /// it also does nothing. The UX of the sample app ensures that
  /// it can only be called once.
  Future<void> initSpeechState() async {
    _logEvent('Initialize');
    var hasSpeech = await speech.initialize(
      onError: errorListener,
      onStatus: statusListener,
      debugLogging: true,
    );
    if (hasSpeech) {
      _localeNames = await speech.locales();

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale?.localeId ?? '';
    }

    if (!mounted) return;

    setState(() {
      _isAvailable = hasSpeech;
    });
  }

  int count = 0;

  Future<void> _startRecord() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start();

        bool isRecording = await _audioRecorder.isRecording();
        setState(() {
          _isRecording = isRecording;
          _recordDuration = 0;
        });

//        _startTimer();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stopRecord() async {
    _timer?.cancel();
    _ampTimer?.cancel();
    final path = await _audioRecorder.stop();

//    widget.onStop(path!);

    setState(() => _isRecording = false);
  }

  doVibrate() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate();
    }
  }

  playBeepSound() async {
    await audioCache.play("beep_sound/beep-01a.mp3", mode: PlayerMode.LOW_LATENCY); // audioPlayer.play("/assets/beep_sound/beep-01a.mp3", isLocal: true);
  }

  bool checkBadWord(String word) {
    for (int i = 0 ; i < badWords.length ; i++) {
      if (word.contains(badWords[i])) {
        return true;
      }
    }
    return false;
  }

  void startListening() {
    _logEvent('start listening');
    previousElapsedListenMillis = 0;
    currentElapsedListenMillis = 0;
    resultText = '';
    previousText = '';
    lastWord = '';
    lastError = '';

    speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 180),
        pauseFor: Duration(seconds: 60),
        partialResults: true,
        localeId: _currentLocaleId,
        onSoundLevelChange: soundLevelListener,
        cancelOnError: true,
        listenMode: ListenMode.search); // search mode is faster than others
    setState(() {
      _isListening = true;
      _isError = false;
    });
  }

  void stopListening() {
    _logEvent('stop');
    doVibrate();
    speech.stop();
    setState(() {
      level = 0.0;
      _isListening = false;
      _isError = false;
      resultTxtSentence = "";
    });
  }

  void cancelListening() {
    _logEvent('cancel');
    doVibrate();
    speech.cancel();
    setState(() {
      level = 0.0;
      _isListening = false;
      _isError = false;
      resultTxtSentence = "";
    });
  }

  void resultListener(SpeechRecognitionResult result) {
    _logEvent(
        'Result listener final: ${result.finalResult}, words: ${result.recognizedWords}');
    setState(() {
      _isFinishOnce = result.finalResult;

      previousText = resultText;
      resultText = '${result.recognizedWords}';
      previousElapsedListenMillis = currentElapsedListenMillis;
      currentElapsedListenMillis = speech.elapsedListenMillis;

      if (previousElapsedListenMillis != currentElapsedListenMillis) {
        _logEvent('speech.hasRecognized: ${speech.hasRecognized}, speech.lastRecognizedWords: ${speech.lastRecognizedWords}');
        _logEvent('speech.elapsedListenMillis: ${speech.elapsedListenMillis} speech.elapsedSinceSpeechEvent: ${speech.elapsedSinceSpeechEvent} speech.listenStartedAt: ${speech.listenStartedAt} speech.lastSpeechEventAt: ${speech.lastSpeechEventAt}');
        lastWord = resultText.substring(previousText.length, resultText.length);
        if (checkBadWord(lastWord)) {
          playBeepSound();
        }

        wordArray.add(lastWord);
        if (_logEvents) {
          elapsedMillisArray.add(currentElapsedListenMillis - previousElapsedListenMillis);
        }
        resultTxtSentence = resultTxtSentence + " $lastWord";
      }

      if (_isFinishOnce) {
        speech.stop();
        startListening();
      }

    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
     _logEvent('sound level $level: $minSoundLevel - $maxSoundLevel ');
    setState(() {
      this.level = level;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    _logEvent(
        'Received error status: $error, listening: ${speech.isListening}');
    setState(() {
      lastError = '${error.errorMsg} - ${error.permanent}';
      _isError = error.permanent;
    });
  }

  void statusListener(String status) {
    _logEvent(
        'Received listener status: $status, listening: ${speech.isListening}');
    setState(() {
      lastStatus = '$status'; // listening, notListening, done
    });
  }

  void _switchLang(selectedVal) {
    setState(() {
      _currentLocaleId = selectedVal;
    });
    print(selectedVal);
  }

  void _logEvent(String eventDescription) {
    if (_logEvents) {
      var eventTime = DateTime.now().toIso8601String();
      print('$eventTime $eventDescription');
    }
  }

  void _switchLogging(bool val) {
    setState(() {
      _logEvents = val ?? false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
                width: 208,
                height: 200,
                child: Image.asset('assets/images/lollipop.jpg')),
            const Padding(
              padding: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 20.0),
              child: Text('',style: TextStyle(fontSize: 5, fontWeight: FontWeight.bold),),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 55,
                  height: 55,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                          blurRadius: .26,
                          spreadRadius: level * 1.5,
                          color: Colors.pink.withOpacity(.05))
                    ],
                    color: Colors.pink,
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.mic, color: Colors.white),
                    onPressed: () {
                      if (!_isAvailable) {
                        initSpeechState();
                        _isAvailable = true;
                        _isListening = false;
                      }
                      wordArray.clear();
                      elapsedMillisArray.clear();
                      if (_isAvailable && !_isListening) {
                        resultTxtSentence = "";
                        startListening();
                        doVibrate();
                      }
                    },
                  ),
                ),
                FloatingActionButton(
                  child: Icon(Icons.stop),
                  mini: true,
                  backgroundColor: Colors.deepOrange,
                  onPressed: () {
                    if (_isListening) {
                      stopListening();
                    }
                  },
                ),
              ],
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(6.0),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 12.0,
              ),
              child: _isListening ? Text("[" + lastWord + "]\n" + resultTxtSentence,
                style: TextStyle(fontSize: 24.0),
              ) : const Text(
                "",
                style: TextStyle(fontSize: 22.0),
              ),
            ),
            Center(
              child: _isListening ? const Text(
                "\nListening",
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ) : const Text(
                "\nNot listening",
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            Center(
              child: _isListening ? const Text(
                "",
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ) : Text(
                '[${wordArray.length} words] ${wordArray.join(".")}\n\n[${elapsedMillisArray.length} words] ${elapsedMillisArray.join("ms ")}',
                style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            Center(
              child: _isError ?
              const Text("\nStop and start the record again", style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: Colors.deepOrangeAccent),)
                  : const Text("", style: TextStyle(fontSize: 22.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
