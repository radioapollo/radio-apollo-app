/* Page With Header Widget

   This widget provides a consistent page layout
   used across multiple screens.

   It includes:
   - the Radio Apollo logo header
   - background image
   - spacing and padding
*/

import 'package:flutter/material.dart';

class PageWithHeader extends StatelessWidget {
  final Widget child;

  const PageWithHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('../lib/assets/images/Background/Watermerk.JPG'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  '../lib/assets/images/Logo/transparant.png',
                  height: 60,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 10),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}