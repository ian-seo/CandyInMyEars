import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MainPage extends StatelessWidget {
  final String email;
  MainPage({this.email});

  @override
  Widget build(BuildContext context) {




    // return Scaffold(
    //   appBar: AppBar(
    //     title: Text(email),
    //   ),
    //   body: Container(
    //     child: FlatButton(onPressed: () {
    //       FirebaseAuth.instance.signOut();
    //     }, child: Text("Logout"),),),
    // );
  }
}
