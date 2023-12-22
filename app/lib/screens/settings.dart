import 'package:app/controllers/main.dart';
import 'package:app/controllers/settings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final mainController = Get.find<MainController>();
  final settingsController = Get.put(SettingsController());

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height / 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: ListView(children: <Widget>[
          Card(
              child: ElevatedButton(
            child: const ListTile(
              leading: FlutterLogo(),
              title: Text('Change Pin'),
            ),
            onPressed: () {
              Get.toNamed('/change-pin');
            },
          )),
          Card(
              child: ElevatedButton(
            child: const ListTile(
              leading: FlutterLogo(),
              title: Text('Logs'),
            ),
            onPressed: () {
              Get.toNamed('/logs');
            },
          )),
          Card(
            child: ElevatedButton(
              child: const ListTile(
                leading: FlutterLogo(),
                title: Text('Unpair Device'),
              ),
              onPressed: () {
                settingsController.unpairDevice();
              },
            ),
          ),
          Card(
            child: ElevatedButton(
              child: const ListTile(
                leading: FlutterLogo(),
                title: Text('Disconnect App'),
              ),
              onPressed: () {
                settingsController.disconnectApp();
              },
            ),
          ),
        ]),
      ),
    );
  }
}
