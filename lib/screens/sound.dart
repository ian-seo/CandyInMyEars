import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:candy_in_my_ears/data/storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_database/firebase_database.dart';

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
  int _firstInterval = 0;
  int _secondInterval = 0;
  int _thirdInterval = 0;
  int _forthInterval = 0;
  double _volumeControl = 0;

  void startInit() async {
    super.initState();

    fileName = 'temp.aac';
    localFileName = 'candy.aac';
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
    database.child("test").child("first").onValue.listen((event) {
      setState(() {
        _firstInterval = event.snapshot.value;
      });
    });
    database.child("test").child("second").onValue.listen((event) {
      setState(() {
        _secondInterval = event.snapshot.value;
      });
    });
    database.child("test").child("third").onValue.listen((event) {
      setState(() {
        _thirdInterval = event.snapshot.value;
      });
    });
    database.child("test").child("forth").onValue.listen((event) {
      setState(() {
        _forthInterval = event.snapshot.value;
      });
    });
    database.child("test").child("volume").onValue.listen((event) {
      setState(() {
        _volumeControl = double.parse(event.snapshot.value.toString());
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

  Future<void> _recodeFunc() async {
    if (!check) {
      setState(() {
        viewTxt = "Recoding...";
      });
      File outputFile = File('$filePath/$fileName');
      await myRecorder.startRecorder(
          toFile: outputFile.path, codec: Codec.aacADTS);
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
    await storage.uploadFile(filePath, fileName).then((value) =>
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("file uploaded"))));
    // await database.child('/test').set({'first': 2000, 'second': 3000});

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
            codec: Codec.aacADTS,
            whenFinished: () {
              print('Play finished');
              setState(() {});
              playCheck = !playCheck;
            });
        print('first interval: $_firstInterval');
        print('second interval: $_secondInterval');
        Future.delayed(Duration(milliseconds: _firstInterval), () {})
            .then((value) => setVolume(_volumeControl));
        Future.delayed(Duration(milliseconds: _secondInterval), () {})
            .then((value) => setVolume(100));
        Future.delayed(Duration(milliseconds: _thirdInterval), () {})
            .then((value) => setVolume(_volumeControl));
        Future.delayed(Duration(milliseconds: _forthInterval), () {})
            .then((value) => setVolume(100));
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
          height: size.height * 0.1,
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
