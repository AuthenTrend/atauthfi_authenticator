import 'package:flutter/material.dart';

import 'CustomIconButton.dart';

enum ListTileType {
  header,
  item,
}

class ListTileHeader extends StatelessWidget {

  final String _title;

  const ListTileHeader({Key? key, required String title}) : _title = title, super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 5, top: 20, bottom: 5),
      child: Text(_title),
    );
  }

}

class ListTileItem extends StatelessWidget {

  final int _index;
  final String _title;
  final Function(BuildContext context, int index)? _onItemPressed;
  final Function(BuildContext context, int index)? _onButtonPressed;

  const ListTileItem({Key? key, required int index, required String title, Function(BuildContext context, int index)? onItemPressed, Function(BuildContext context, int index)? onButtonPressed}) :
        _index = index, _title = title, _onItemPressed = onItemPressed, _onButtonPressed = onButtonPressed, super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: const StadiumBorder(),
      color: const Color.fromARGB(0x50, 0xFF, 0xFF, 0xFF),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 25, right: 10, top: 5, bottom: 5),
        shape: const StadiumBorder(),
        title: Text(_title, style: const TextStyle(fontSize: 18)),
        trailing: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.qr_code_scanner, size: 26.0),
            ),
            CustomIconButton(
              splashRadius: 24,
              icon: const Icon(Icons.more_horiz, size: 26.0),
              onPressed: (context) => {
                if (_onButtonPressed != null) _onButtonPressed!(context, _index)
              },
            ),
          ],
        ),
        onTap: () {
          if (_onItemPressed != null) _onItemPressed!(context, _index);
        },
      ),
    );
  }
  
}