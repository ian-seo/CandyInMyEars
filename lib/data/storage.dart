import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class Storage {
  firebase_storage.FirebaseStorage storage =
      firebase_storage.FirebaseStorage.instance;

  Future<void> listExample() async {

    firebase_storage.ListResult result = await storage.ref('test').listAll();

    result.items.forEach((firebase_storage.Reference ref) {
      print('Found file: $ref');
    });
  }

  Future<void> uploadFile(String fileName) async {
    var data = await rootBundle.load('assets/$fileName');
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String filePath = '${appDocDir.absolute.path}/$fileName';
    await File(filePath).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    File file = File(filePath);
    try {
      await firebase_storage.FirebaseStorage.instance
          .ref('test/$fileName')
          .putFile(file);
    } on firebase_core.FirebaseException catch (e) {
      print(e);
    }
  }
}
