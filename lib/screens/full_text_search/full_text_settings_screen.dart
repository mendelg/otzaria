import 'package:flutter/material.dart';
import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:otzaria/models/tabs/searching_tab.dart';
import 'package:toggle_switch/toggle_switch.dart';

class FullTextSettingsScreen extends StatelessWidget {
  const FullTextSettingsScreen({
    Key? key,
    required this.tab,
  }) : super(key: key);
  final SearchingTab tab;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        Expanded(
          child: ValueListenableBuilder(
              valueListenable: tab.numResults,
              builder: (context, numResults, child) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SpinBox(
                    value: numResults.toDouble(),
                    onChanged: (value) =>
                        tab.numResults.value = (value.toInt()),
                    min: 10,
                    max: 10000,
                    decoration: const InputDecoration(labelText: 'מספר תוצאות'),
                  ),
                );
              }),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ValueListenableBuilder(
                valueListenable: tab.distance,
                builder: (context, distance, child) {
                  return ValueListenableBuilder(
                      valueListenable: tab.fuzzy,
                      builder: (context, fuzzy, child) {
                        return SpinBox(
                          enabled: !fuzzy,
                          decoration: const InputDecoration(
                              labelText: 'מרווח בין מילים'),
                          min: 0,
                          max: 30,
                          value: distance.toDouble(),
                          onChanged: (value) =>
                              tab.distance.value = value.toInt(),
                        );
                      });
                }),
          ),
        ),
      ]),
      Center(
        child: ValueListenableBuilder(
            valueListenable: tab.fuzzy,
            builder: (context, aproximateSearch, child) {
              return ToggleSwitch(
                minWidth: 150,
                inactiveBgColor: Colors.grey,
                inactiveFgColor: Colors.white,
                initialLabelIndex: aproximateSearch ? 1 : 0,
                totalSwitches: 2,
                labels: const ['חיפוש מדוייק', 'חיפוש מקורב'],
                radiusStyle: true,
                onToggle: (index) {
                  tab.fuzzy.value = index != 0;
                },
              );
            }),
      ),
      Expanded(child: Container())
    ]);
  }
}