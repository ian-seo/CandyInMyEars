import 'package:candy_in_my_ears/data/storage.dart';
import 'package:candy_in_my_ears/screens/sound.dart';
import 'package:candy_in_my_ears/screens/voice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MainPage extends StatelessWidget {
  final String email;

  MainPage({this.email});

  @override
  Widget build(BuildContext context) {
    final Storage storage = Storage();
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        title: Text("Candy In My Ears"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(child: MyHomePage()),
          Container(
              child: ElevatedButton(
            onPressed: () {
              storage.listExample();
            },
            child: Text('Check Uploaded Files'),
          ))
        ],
      ),
    );
  }
}
