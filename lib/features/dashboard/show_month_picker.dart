import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import 'month_picker_sheet.dart';

/// Opens the month picker wired to [AppState].
Future<void> showMonthPicker(BuildContext context) {
  final state = context.read<AppState>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => MonthPickerSheet(
      initialMonth: state.month,
      onSelected: state.setMonth,
    ),
  );
}
