import 'package:app/api.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PinController extends GetxController {
  late Api api;
  var error = false.obs;

  @override
  void onInit() {
    super.onInit();

    api = Api();
  }

  void changePin(String pin) {
    api.sendWithCallback('changepin', {'pin': pin}, (response) {
      print(response['status']);
      if (response['status']) {
        Get.snackbar(
          "Error",
          response['data']['message'],
          colorText: Colors.white,
          backgroundColor: Colors.lightBlue,
          icon: const Icon(Icons.add_alert),
        );

        error.value = true;
      } else {
        Get.snackbar(
          "Success",
          response['data']['message'],
          colorText: Colors.white,
          backgroundColor: Colors.lightBlue,
          icon: const Icon(Icons.add_alert),
        );

        error.value = false;

        Get.offAllNamed('/settings');
      }
    });
  }
}
