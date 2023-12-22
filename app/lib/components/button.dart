import 'package:app/constant.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:outline_gradient_button/outline_gradient_button.dart';

class GradientOutlineButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  const GradientOutlineButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlineGradientButton(
      gradient: const LinearGradient(
        colors: [startGradient, endGradient],
      ),
      strokeWidth: 2,
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14),
      radius: const Radius.circular(99),
      onTap: onTap,
      child: Text(text,
          style: GoogleFonts.figtree(
            textStyle: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          )),
    );
  }
}
