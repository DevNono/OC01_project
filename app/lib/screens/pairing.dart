import 'dart:async';

import 'package:app/constant.dart';
import 'package:app/controllers/pairing.dart';
import 'package:app/controllers/main.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gradient_borders/gradient_borders.dart';

class Pairing extends StatefulWidget {
  const Pairing({Key? key}) : super(key: key);

  @override
  State<Pairing> createState() => _PairingState();
}

class _PairingState extends State<Pairing> {
  final mainController = Get.find<MainController>();
  final pairingController = Get.find<PairingController>();
  var _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    if (mainController.box.hasData('setup') &&
        mainController.box.read('setup')) {
      Future.delayed(Duration.zero, () {
        Get.offAllNamed('/home');
      });
    } else {
      pairingController.startBluetooth();
      pairingController.startScan();
    }
  }

  @override
  void dispose() {
    pairingController.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Obx(() => Text(
                pairingController.stepToText(),
                style: const TextStyle(fontSize: 30, color: Colors.white),
              )),
          // Input with gradient outline
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Obx(() => (() {
                    switch (pairingController.step.value) {
                      case 2:
                        return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'WiFi SSID',
                                  border: GradientOutlineInputBorder(
                                    gradient: LinearGradient(
                                      colors: [Colors.white12, Colors.white12],
                                    ),
                                    width: 2,
                                  ),
                                  focusedBorder: GradientOutlineInputBorder(
                                    gradient: LinearGradient(
                                      colors: [startGradient, endGradient],
                                    ),
                                    width: 2,
                                  ),
                                  labelStyle: TextStyle(
                                    color: startGradient,
                                  ),
                                ),
                                initialValue: pairingController.ssid,
                                onChanged: (value) {
                                  pairingController.setSSID(value);
                                },
                              ),
                              const SizedBox(
                                height: 16,
                              ),
                              TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'WiFi Password',
                                  border: const GradientOutlineInputBorder(
                                    gradient: LinearGradient(
                                      colors: [Colors.white12, Colors.white12],
                                    ),
                                    width: 2,
                                  ),
                                  focusedBorder:
                                      const GradientOutlineInputBorder(
                                    gradient: LinearGradient(
                                      colors: [startGradient, endGradient],
                                    ),
                                    width: 2,
                                  ),
                                  labelStyle: const TextStyle(
                                    color: startGradient,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: startGradient,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      });
                                    },
                                  ),
                                ),
                                initialValue: pairingController.password,
                                onChanged: (value) {
                                  pairingController.setPassword(value);
                                },
                                obscureText: !_passwordVisible,
                                enableSuggestions: false,
                                autocorrect: false,
                              ),
                            ]);
                      case 3:
                        return TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Server Address',
                            border: GradientOutlineInputBorder(
                              gradient: LinearGradient(
                                colors: [Colors.white12, Colors.white12],
                              ),
                              width: 2,
                            ),
                            focusedBorder: GradientOutlineInputBorder(
                              gradient: LinearGradient(
                                colors: [startGradient, endGradient],
                              ),
                              width: 2,
                            ),
                            labelStyle: TextStyle(
                              color: startGradient,
                            ),
                          ),
                          initialValue: pairingController.url,
                          onChanged: (value) {
                            pairingController.setURL(value);
                          },
                        );
                      default:
                        return const SizedBox(
                          height: 0,
                          width: 0,
                        );
                    }
                  }()))),
        ]);
  }
}
