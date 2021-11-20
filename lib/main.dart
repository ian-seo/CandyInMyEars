import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VoiceHome(),
    );
  }
}

class VoiceHome extends StatefulWidget {
  @override
  _VoiceHomeState createState() => _VoiceHomeState();
}

class _VoiceHomeState extends State<VoiceHome> {

  // Speech-to-text variables //
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

  String resultTxtSentence = "";
  List<int> elapsedMillisArray = [];
  List<String> wordArray = [];
  List<bool> validWordArray = [];
  int validWordCount = 0;
  List<String> badWords = ['시발', '씨발', '썅년', '썅놈', '개새', '쌍놈', '쌍년', '지랄', '병신', '18', '바보', '쉣', '멍청'];

  // Recording variables //
  bool _isRecording = false;
  bool _isPaused = false;
  int _recordDuration = 0;
  Timer _timer;
  Timer _ampTimer;
  final _audioRecorder = Record();
  Amplitude _amplitude;
  String recordUriPath = '';

  // Audio play variables
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

  void _startTimer() {
    _timer?.cancel();
    _ampTimer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });

    _ampTimer =
        Timer.periodic(const Duration(milliseconds: 200), (Timer t) async {
          _amplitude = await _audioRecorder.getAmplitude();
          setState(() {});
        });
  }

  Future<String> get _localPath async {
    final directory = await getExternalStorageDirectory();

    return directory.path;
  }

  Future<void> _startRecord() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final path = await _localPath;

        DateTime now = new DateTime.now();
        String date = '${now.year}-${now.month}-${now.day}_${now.hour}h${now.minute}m${now.second}s';

        _logEvent('start recording path - $date:$path');

        await _audioRecorder.start(
          path: '$path/recorded_$date.m4a', // required
          encoder: AudioEncoder.AAC, // by default
          bitRate: 128000, // by default
          samplingRate: 44100, // by default
        );

        bool isRecording = await _audioRecorder.isRecording();
        setState(() {
          _isRecording = isRecording;
          _recordDuration = 0;
        });

        _startTimer();
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _stopRecord() async {
    _timer?.cancel();
    _ampTimer?.cancel();
    recordUriPath  = await _audioRecorder.stop();
    _logEvent('stop recording path:$recordUriPath');

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

//    _startRecord();
    _isListening = true;
    _isError = false;

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
//      _stopRecord();
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
        bool isValid = lastWord != '';
        validWordArray.add(isValid);
        if (isValid) validWordCount++;
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
                      validWordArray.clear();
                      validWordCount = 0;
                      recordUriPath = '';
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
                '[${validWordCount.toString()} words] ${wordArray.join(".")}\n\n[${validWordCount.toString()} words] ${elapsedMillisArray.join("ms ")}ms',
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
