
import 'dart:convert';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:localization/localization.dart';

extension StringExt on String {
  void log() {
    debugPrint(this);
  }

  String base64UrlDecode() {
    Codec<String, String> stringToBase64Url = utf8.fuse(base64Url);
    return stringToBase64Url.decode(const Base64Codec().normalize(this));
  }

  String base64UrlEncode() {
    Codec<String, String> stringToBase64Url = utf8.fuse(base64Url);
    return stringToBase64Url.encode(this).replaceAll('=', '');
  }

  void asAlert(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
            content: Text(this, textAlign: TextAlign.center),
            contentPadding: const EdgeInsets.only(left: 20, right: 20, top: 30),
            actions: [
              TextButton(
                child: Text('ok'.i18n()),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
    );
  }
  void asToast() {
    Fluttertoast.showToast(
      msg: this,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

}
