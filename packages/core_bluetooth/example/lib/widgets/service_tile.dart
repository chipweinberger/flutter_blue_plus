import 'package:flutter/material.dart';
import 'package:core_bluetooth/core_bluetooth.dart';

import "characteristic_tile.dart";

class ServiceTile extends StatelessWidget {
  final CBService service;
  final List<CharacteristicTile> characteristicTiles;

  const ServiceTile({super.key, required this.service, required this.characteristicTiles});

  Widget buildUuid(BuildContext context) {
    String uuid = service.uuid.uuidString.toUpperCase();
    return Text(uuid, style: TextStyle(fontSize: 13));
  }

  @override
  Widget build(BuildContext context) {
    return characteristicTiles.isNotEmpty
        ? ExpansionTile(
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Service', style: TextStyle(color: Theme.of(context).primaryColor)),
                buildUuid(context),
              ],
            ),
            children: characteristicTiles,
          )
        : ListTile(
            title: const Text('Service'),
            subtitle: buildUuid(context),
          );
  }
}
