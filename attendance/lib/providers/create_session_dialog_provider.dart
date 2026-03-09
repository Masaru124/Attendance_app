import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateSessionDialogProvider extends StateNotifier<Map<String, dynamic>> {
  CreateSessionDialogProvider() : super({});

  // Getters for accessing dialog state
  TimeOfDay? get selectedLateUntilTime => state['selectedLateUntilTime'];
  bool get useTimeOnly => state['useTimeOnly'];

  // Setters for updating dialog state
  void setSelectedLateUntilTime(TimeOfDay? time) {
    state = {...state, 'selectedLateUntilTime': time};
  }

  void setUseTimeOnly(bool value) {
    state = {...state, 'useTimeOnly': value};
  }
}

final createSessionDialogProvider =
    StateNotifierProvider<CreateSessionDialogProvider, Map<String, dynamic>>(
      (ref) => CreateSessionDialogProvider(),
    );
