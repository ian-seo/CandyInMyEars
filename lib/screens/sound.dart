import 'dart:io';
import 'dart:typed_data';
import 'package:candy_in_my_ears/data/storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String viewTxt = "Recorde Player";
  final Storage storage = Storage();
  FlutterSoundRecorder myRecorder;
  FlutterSoundPlayer myPlayer;
  String filePath;
  String fileName;
  bool check = false;
  bool playCheck = false;

  GlobalKey<ScaffoldState> _key = GlobalKey<ScaffoldState>();

  void startInit() async {
    super.initState();

    fileName = 'temp.aac';
    filePath = '/sdcard/Download';

    myRecorder = FlutterSoundRecorder();
    myPlayer = FlutterSoundPlayer();
    await myRecorder.openAudioSession();
    await myRecorder.setSubscriptionDuration(Duration(milliseconds: 10));
    await myPlayer.openAudioSession();
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

  Future<void> _recodeFunc() async {
    setState(() {
      viewTxt = "Recoding ~";
    });
    File outputFile = File('$filePath/$fileName');
    if (!check) {
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
    await storage.uploadFile(filePath, fileName);
    return;
  }

  Future<void> playMyFile() async {
    if (!playCheck) {
      Directory tempDir = await getTemporaryDirectory();
      File inFile = File('$filePath/$fileName');
      try {
        Uint8List dataBuffer = await inFile.readAsBytes();
        print("dataBuffer $dataBuffer");
        setState(() {
          playCheck = !playCheck;
        });
        await this.myPlayer.startPlayer(
            fromDataBuffer: dataBuffer,
            codec: Codec.aacADTS,
            whenFinished: () {
              print('Play finished');
              setState(() {});
            });
      } catch (e) {
        print(" NO Data");
        _key.currentState.showSnackBar(SnackBar(
          content: Text("NO DATA!!!!!!"),
        ));
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          viewTxt,
          style: Theme.of(context).textTheme.headline4,
        ),
        Container(
          margin: EdgeInsets.all(20.0),
          child: FloatingActionButton(
              onPressed: _recodeFunc,
              tooltip: 'Increment',
              child: check ? Icon(Icons.stop) : Icon(Icons.mic)),
        ),
        Container(
          padding: EdgeInsets.all(20.0),
          decoration: BoxDecoration(
              border: Border.all(width: 2.0, color: Colors.grey[200]),
              borderRadius: BorderRadius.circular(15.0)),
          child: Column(
            children: <Widget>[
              Text("Play Controller\n(Recorde File)"),
              IconButton(
                icon: playCheck
                    ? Icon(Icons.stop)
                    : Icon(Icons.play_circle_filled),
                onPressed: () async {
                  await playMyFile();
                },
              ),
              FlatButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                },
                child: const Text("Logout"),
              )
            ],
          ),
        )
      ],
    );
  }
}
