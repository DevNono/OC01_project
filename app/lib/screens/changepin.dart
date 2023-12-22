import 'package:app/controllers/main.dart';
import 'package:app/controllers/pin.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ChangePin extends StatefulWidget {
  const ChangePin({Key? key}) : super(key: key);

  @override
  State<ChangePin> createState() => _ChangePinState();
}

class _ChangePinState extends State<ChangePin> {
  final mainController = Get.find<MainController>();
  final pinController = Get.put(PinController());

  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(4, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _focusNodes[0].requestFocus();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 64.0),
      const Text(
        'Enter new PIN',
        style: TextStyle(fontSize: 24.0),
      ),
      const SizedBox(height: 64.0),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (index) => SizedBox(
            width: 50,
            child: Obx(
              () => TextField(
                controller: _controllers[index],
                keyboardType: TextInputType.number,
                maxLength: 1,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24.0),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '●',
                  hintStyle: const TextStyle(fontSize: 24.0),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: Colors.blue,
                      width: 2.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          pinController.error.value ? Colors.red : Colors.grey,
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty && index < 3) {
                    _focusNodes[index].unfocus();
                    _focusNodes[index + 1].requestFocus();
                  } else if (value.isEmpty && index > 0) {
                    _focusNodes[index].unfocus();
                    _focusNodes[index - 1].requestFocus();
                  }
                  if (value.isNotEmpty && index == 3) {
                    _focusNodes[index].unfocus();
                    String pin = _controllers[0].text +
                        _controllers[1].text +
                        _controllers[2].text +
                        _controllers[3].text;
                    pinController.changePin(pin);
                  }
                },
                focusNode: _focusNodes[index],
              ),
            ),
          ),
        ),
      )
    ]);
  }
}
