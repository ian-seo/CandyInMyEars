import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:firebase_database/firebase_database.dart';

class Storage {
  firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instance;
  final database = FirebaseDatabase.instance.reference();

  Future<void> listExample() async {

    firebase_storage.ListResult result = await storage.ref('test').listAll();

    result.items.forEach((firebase_storage.Reference ref) {
      print('Found file: $ref');
    });
  }

  Future<void> uploadFile(String filePath, String fileName) async {
    File file = File('$filePath/$fileName');
    try {
      await firebase_storage.FirebaseStorage.instance
          .ref('test/$fileName')
          .putFile(file);
    } on firebase_core.FirebaseException catch (e) {
      print(e);
    }

  }

  Future<void> downloadFile(String filePath, String fileName, String localFileName) async {
    File file = File('$filePath/$localFileName');
    try {
      await firebase_storage.FirebaseStorage.instance
          .ref('test/$fileName')
          .writeToFile(file);
    } on firebase_core.FirebaseException catch (e) {
      print(e);
    }
  }
}
