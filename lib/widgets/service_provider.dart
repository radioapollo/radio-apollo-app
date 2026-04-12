/* Service Provider

   An InheritedWidget that makes shared services available to the
   entire widget tree without importing main.dart or using globals.

   Usage in any widget:
     final audio   = ServiceProvider.of(context).audioHandler;
     final current = ServiceProvider.of(context).currentProgramService;
*/

import 'package:flutter/material.dart';
import '../services/audio_handler.dart';
import '../services/program/current_program_service.dart';

class ServiceProvider extends InheritedWidget {
  final RadioAudioHandler audioHandler;
  final CurrentProgramService currentProgramService;

  const ServiceProvider({
    super.key,
    required this.audioHandler,
    required this.currentProgramService,
    required super.child,
  });

  static ServiceProvider of(BuildContext context) {
    final result =
        context.dependOnInheritedWidgetOfExactType<ServiceProvider>();
    assert(result != null, 'No ServiceProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ServiceProvider oldWidget) => false;
}