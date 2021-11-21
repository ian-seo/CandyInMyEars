import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:validators/validators.dart';

class Settings extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstController = TextEditingController();
  final TextEditingController _secondController = TextEditingController();
  final TextEditingController _thirdController = TextEditingController();
  final TextEditingController _forthController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final database = FirebaseDatabase.instance.reference();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _firstController,
              decoration: const InputDecoration(
                  icon: Icon(Icons.confirmation_number_sharp),
                  labelText: "First"),
              validator: (String value) {
                if (!isNumeric(value)) {
                  return "Please input numbers ";
                }
                return null;
              },
            ),
            TextFormField(
              controller: _secondController,
              decoration: const InputDecoration(
                  icon: Icon(Icons.confirmation_number_sharp),
                  labelText: "Second"),
              validator: (String value) {
                if (!isNumeric(value)) {
                  return "Please input numbers ";
                }
                return null;
              },
            ),
            TextFormField(
              controller: _thirdController,
              decoration: const InputDecoration(
                  icon: Icon(Icons.confirmation_number_sharp),
                  labelText: "Third"),
              validator: (String value) {
                if (!isNumeric(value)) {
                  return "Please input numbers ";
                }
                return null;
              },
            ),
            TextFormField(
              controller: _forthController,
              decoration: const InputDecoration(
                  icon: Icon(Icons.confirmation_number_sharp),
                  labelText: "Forth"),
              validator: (String value) {
                if (!isNumeric(value)) {
                  return "Please input numbers ";
                }
                return null;
              },
            ),
            TextFormField(
              controller: _volumeController,
              decoration: const InputDecoration(
                  icon: Icon(Icons.confirmation_number_sharp),
                  labelText: "silenceVolume"),
              validator: (String value) {
                if (!isNumeric(value)) {
                  return "Please input numbers ";
                }
                return null;
              },
            ),
            FlatButton(
                onPressed: () async {
                  if (_formKey.currentState.validate()) {
                    await database.child('/test').set({
                      'first': int.parse(_firstController.value.text),
                      'second': int.parse(_secondController.value.text),
                      'third': int.parse(_thirdController.value.text),
                      'forth': int.parse(_forthController.value.text),
                      'volume': double.parse(_volumeController.value.text),
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Settings Updated")));
                  }
                },
                child: const Text("Update Settings"))
          ],
        ),
      ),
    );
  }
}
