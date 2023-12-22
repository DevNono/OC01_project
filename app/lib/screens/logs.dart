import 'package:app/controllers/logs.dart';
import 'package:app/controllers/main.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Logs extends StatefulWidget {
  const Logs({Key? key}) : super(key: key);

  @override
  State<Logs> createState() => _LogsState();
}

class _LogsState extends State<Logs> {
  final mainController = Get.find<MainController>();
  final logsController = Get.put(LogsController());

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (var log in logsController.logs) Text(log['name']),
            ]));
  }
}
