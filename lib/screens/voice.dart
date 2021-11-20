import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class Voice extends StatefulWidget {
  @override
  _VoiceState createState() => _VoiceState();
}

class _VoiceState extends State<Voice> {
  bool _isAvailable = false;
  bool _isListening = false;
  bool _isFinishOnce = false;
  bool _isError = false;
  bool _logEvents = true;
  double level = 0.0;
  double minSoundLevel = 50.0;
  double maxSoundLevel = -50.0;

  String previousText = '';
  String resultText = '';
  String lastWord = '';
  String lastError = '';
  String lastStatus = '';
  String _currentLocaleId = '';
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();

  String resultTxtSentence = "";
  List<String> wordArray = [];
  List<String> badWords = [
    '시발',
    '씨발',
    '썅년',
    '썅놈',
    '개새',
    '쌍놈',
    '쌍년',
    '지랄',
    '병신',
    '18',
    '바보',
    '쉣',
    '멍청'
  ];

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

  doVibrate() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate();
    }
  }

  playBeepSound() async {
    await audioCache.play("beep_sound/beep-01a.mp3",
        mode: PlayerMode
            .LOW_LATENCY); // audioPlayer.play("/assets/beep_sound/beep-01a.mp3", isLocal: true);
  }

  bool checkBadWord(String word) {
    for (int i = 0; i < badWords.length; i++) {
      if (word.contains(badWords[i])) {
        return true;
      }
    }
    return false;
  }

  void startListening() {
    _logEvent('start listening');
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

      lastWord = resultText.substring(previousText.length, resultText.length);
      if (checkBadWord(lastWord)) {
        playBeepSound();
      }

      if (previousText != resultText) {
        wordArray.add(lastWord);
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
    _logEvent('sound level $level: $minSoundLevel ~ $maxSoundLevel ');
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
    return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
                width: 208,
                height: 200,
                child: Image.asset('assets/images/lollipop.jpg')),
            const Padding(
              padding: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 20.0),
              child: Text(
                '',
                style: TextStyle(fontSize: 5, fontWeight: FontWeight.bold),
              ),
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
              child: _isListening
                  ? Text(
                      "[" + lastWord + "]\n" + resultTxtSentence,
                      style: TextStyle(fontSize: 24.0),
                    )
                  : const Text(
                      "",
                      style: TextStyle(fontSize: 22.0),
                    ),
            ),
            Center(
              child: _isListening
                  ? const Text(
                      "\nListening",
                      style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent),
                    )
                  : const Text(
                      "\nNot listening",
                      style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
            ),
            Center(
              child: _isListening
                  ? const Text(
                      "",
                      style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent),
                    )
                  : Text(
                      wordArray.join("."),
                      style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
            ),
            Center(
              child: _isError
                  ? const Text(
                      "\nStop and start the record again",
                      style: TextStyle(
                          fontSize: 22.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrangeAccent),
                    )
                  : const Text(
                      "",
                      style: TextStyle(fontSize: 22.0),
                    ),
            ),
            FlatButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              child: const Text("Logout"),
            )
          ],
        );
  }
}
