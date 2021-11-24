import 'package:candy_in_my_ears/data/storage.dart';
import 'package:candy_in_my_ears/screens/settings.dart';
import 'package:candy_in_my_ears/screens/sound.dart';
import 'package:candy_in_my_ears/screens/voice.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MainPage extends StatelessWidget {
  final String email;

  MainPage({this.email});

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final Storage storage = Storage();
    // TODO: implement build
    return Scaffold(

      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
//          Container(
//              alignment: Alignment.topRight,
//              child: Float  ingActionButton(
//                heroTag: "settings",
//                onPressed: () {
//                  Navigator.push(
//                      context,
//                      MaterialPageRoute(
//                          builder: (context) => Settings()));
//                },
//                child: Icon(Icons.settings_sharp),
//              )),
          _candyImage,
          MyHomePage(),
        ],
      ),
    );
  }
}

Widget get _candyImage => const Expanded(
  child: Padding(
    padding: EdgeInsets.only(top: 0, left: 24, right: 24),
    child: FittedBox(
      fit: BoxFit.contain,
      child:
      // CircleAvatar(backgroundImage: AssetImage("assets/images/candy.gif")),
      CircleAvatar(backgroundImage: AssetImage("assets/images/candies.gif")),
    ),
  ),
);
