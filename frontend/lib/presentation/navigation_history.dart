/// @file
/// @brief

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void goBackOrHome(BuildContext context) {
  if (context.canPop()) {
    context.pop();
    return;
  }

  context.go('/');
}
