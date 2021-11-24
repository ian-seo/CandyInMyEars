import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:candy_in_my_ears/data/storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_speech/google_speech.dart';
import 'package:google_speech/speech_client_authenticator.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

const String candyInMyEars = "Candy In My Ears";

class _MyHomePageState extends State<MyHomePage> {
  String viewTxt = candyInMyEars;
  final Storage storage = Storage();
  final database = FirebaseDatabase.instance.reference();
  FlutterSoundRecorder myRecorder;
  FlutterSoundPlayer myPlayer;
  String filePath;
  String fileName;
  String localFileName;
  bool check = false;
  bool playCheck = false;
  double _mVolume1 = 100.0;
  int _thirdInterval = 0;
  int _forthInterval = 0;
  double _volumeControl = 0;

  final int MILLISECONDS = 1000;
  final double VOLUME_DOWN = 5.0;

  List<String> words = [];
  List<int> intervals = [];
  List<double> volumes = [];
  String display_word = '';

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
  '멍청',
  '닥쳐',
  '꺼져',
  '미친'
  ];

  bool checkBadWord(String word) {
    for (int i = 0; i < badWords.length; i++) {
      if (word.contains(badWords[i])) {
        return true;
      }
    }
    return false;
  }

  void startInit() async {
    super.initState();

    fileName = 'badWords.wav';
    localFileName = 'badWords_filtered.wav';
    Directory tempDir = await getTemporaryDirectory();
    filePath = tempDir.path;

    myRecorder = FlutterSoundRecorder();
    myPlayer = FlutterSoundPlayer();
    await myRecorder.openAudioSession();
    await myRecorder.setSubscriptionDuration(Duration(milliseconds: 10));
    await myPlayer.openAudioSession();
    _activateListners();
  }

  void _activateListners() {
    database.child("word_infos").child("words").onValue.listen((event) {
      setState(() {
        String string_words = event.snapshot.value;
        words = string_words.split(";");
      });
    });
    database.child("word_infos").child("intervals").onValue.listen((event) {
      setState(() {
        String string_intervals = event.snapshot.value;
        intervals = string_intervals.split(";").map((data) => int.parse(data)).toList();
      });
    });
    database.child("word_infos").child("volumes").onValue.listen((event) {
      setState(() {
        String string_volumes = event.snapshot.value;
        volumes = string_volumes.split(";").map((data) => double.parse(data)).toList();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    startInit();
  }

  @override
  void dispose() {
    if (myRecorder != null) {
      myRecorder.closeAudioSession();
      myPlayer.closeAudioSession();

      myRecorder = null;
      myPlayer = null;
    }
    super.dispose();
  }

  Future<void> setVolume(double v) async // v is between 0.0 and 100.0
  {
    v = v > 100.0 ? 100.0 : v;
    _mVolume1 = v;
    setState(() {});
    //await _mPlayer!.setVolume(v / 100, fadeDuration: Duration(milliseconds: 5000));
    await myPlayer.setVolume(
      v / 100,
    );
  }

  Future<List<int>> _getAudioContent(String path, String name) async {
    final audio_path = path + '/$name';
    return File(audio_path).readAsBytesSync().toList();
  }

  Future<void> _recodeFunc() async {
    if (!check) {
      setState(() {
        viewTxt = "Recoding...";
      });
      File outputFile = File('$filePath/$fileName');
      await myRecorder.startRecorder(
          toFile: outputFile.path, codec: Codec.pcm16WAV, sampleRate: 44100);
      print("START");
      setState(() {
        check = !check;
      });
      return;
    }
    print("STOP");
    setState(() {
      check = !check;
      viewTxt = "await...";
    });
    await myRecorder.stopRecorder();

    ////////////////////////////////////////////////
    // Get a timestamp of words using Google apis //
    ////////////////////////////////////////////////
    final AssetBundle rootBundle = DefaultAssetBundle.of(context);
    final serviceAccount = ServiceAccount.fromString(
        '${(await rootBundle.loadString('assets/candy-in-my-ears-bcceec5d21d4.json'))}');
    final speechToText = SpeechToText.viaServiceAccount(serviceAccount);
    final config = RecognitionConfig(
        encoding: AudioEncoding.LINEAR16,
        model: RecognitionModel.basic,
        enableWordTimeOffsets: true,
        sampleRateHertz: 44100,
        languageCode: 'ko-KR');
    final audio = await _getAudioContent(filePath, fileName);
    final response = await speechToText.recognize(config, audio);

    words.clear();
    intervals.clear();
    volumes.clear();

    for (var item in response.results) {
      for (var sentence in item.alternatives) {
        for (var word in sentence.words) {
          if (checkBadWord(word.word)) {
            words.add(word.word.replaceRange(1, word.word.length, "*"));
            words.add(word.word.replaceRange(1, word.word.length, "*"));

            intervals.add(word.startTime.seconds.toInt()*MILLISECONDS + (word.startTime.nanos / (MILLISECONDS*MILLISECONDS)).toInt() + 300);
            volumes.add(VOLUME_DOWN);

            intervals.add(word.endTime.seconds.toInt()*MILLISECONDS + (word.endTime.nanos / (MILLISECONDS*MILLISECONDS)).toInt() + 50);
            volumes.add(100.0);
            print('startTime: ${word.startTime} endTime: ${word.endTime}');
          } else {
            words.add(word.word);
            words.add(word.word);

            intervals.add(word.startTime.seconds.toInt()*MILLISECONDS + (word.startTime.nanos / (MILLISECONDS*MILLISECONDS)).toInt() + 300);
            volumes.add(100.0);
            intervals.add(word.endTime.seconds.toInt()*MILLISECONDS + (word.endTime.nanos / (MILLISECONDS*MILLISECONDS)).toInt() + 50);
            volumes.add(100.0);
          }
          print(word.word);
        }
      }
    }

    ////////////////////////////////////////////////
    ////////////////////////////////////////////////

    await storage.uploadFile(filePath, fileName).then((value) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("file uploaded"))));
     await database.child('/word_infos').set({'words': words.join(";"), 'intervals': intervals.join(";"), 'volumes': volumes.join(";")});

    setState(() {
      viewTxt = candyInMyEars;
    });
    return;
  }

  Future<void> playMyFile() async {
    if (!playCheck) {
      await storage.downloadFile(filePath, fileName, localFileName).then(
          (value) => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text("file downloaded"))));
      File inFile = File('$filePath/$localFileName');
      try {
        Uint8List dataBuffer = await inFile.readAsBytes();
        print("dataBuffer $dataBuffer");
        setState(() {
          playCheck = !playCheck;
        });
        this.myPlayer.startPlayer(
            fromDataBuffer: dataBuffer,
            codec: Codec.pcm16WAV,
            sampleRate: 44100,
            whenFinished: () {
              print('Play finished');
              setState(() {});
              playCheck = !playCheck;
            });
        print('intervals.length:${intervals.length}');
        for (int i = 0 ; i < intervals.length ; i++) {
          print('[${i}] interval:${intervals[i]} volume: ${volumes[i]}');
          Future.delayed(Duration(milliseconds: intervals[i]), () {})
              .then((value) {
                setVolume(volumes[i]);
                display_word = words[i];
          });
        }
      } catch (e) {
        print(" NO Data");
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No Data")));
      }
      return;
    }
    await myPlayer.stopPlayer();
    setState(() {
      playCheck = !playCheck;
    });
    print("PLAY STOP!!");
    return;
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          viewTxt,
          style: Theme.of(context).textTheme.headline4,
        ),
        Container(
          height: 8,
        ),
        Padding(
          padding: EdgeInsets.only(left: size.width*0.3,right: size.width*0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                  heroTag: "mic",
                  onPressed: _recodeFunc,
                  child: check ? Icon(Icons.stop) : Icon(Icons.mic)),
              FloatingActionButton(
                heroTag: "play",
                child:
                    playCheck ? Icon(Icons.stop) : Icon(Icons.play_circle_filled),
                onPressed: () async {
                  await playMyFile();
                },
              ),
            ],
          ),
        ),
        Container(
          height: size.height * 0.05,
        ),
        Container(
          child: Text(display_word)
        ),
        Container(
          height: size.height * 0.05,
        ),
        Container(
            padding: EdgeInsets.all(0.1),
            decoration: BoxDecoration(
                border: Border.all(width: 2.0, color: Colors.grey[200]),
                borderRadius: BorderRadius.circular(50.0)),
            child: FlatButton(
              onPressed: () {
                FirebaseAuth.instance.signOut();
              },
              child: const Text("Logout"),
            )),
        Container(
          height: size.height * 0.02,
        ),
      ],
    );
  }
}
