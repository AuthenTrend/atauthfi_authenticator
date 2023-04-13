import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AccountMetadata {
  final String rp;
  final String email;
  AccountMetadata(this.rp, this.email);
  AccountMetadata.fromJson(Map<String, dynamic> json): rp = json['rp'], email = json['email'];
  Map<String, dynamic> toJson() => {'rp': rp, 'email': email};
}

class AccountData {

  static final AccountData _instance = AccountData._internal();

  static const String _keyIdList = "id_list";
  SharedPreferences? _pref;

  AccountData._internal();

  static Future<AccountData> getInstance() async {
    _instance._pref ??= await SharedPreferences.getInstance();
    return _instance;
  }

  List<AccountMetadata> get() {
    final pref = _pref!;
    final idList = pref.getStringList(_keyIdList) ?? [];
    List<AccountMetadata> accounts = [];
    for (var id in idList) {
      var jsonStr = pref.getString(id);
      if (jsonStr != null) {
        Map<String, dynamic> json = jsonDecode(jsonStr);
        accounts.add(AccountMetadata.fromJson(json));
      }
    }
    accounts.sort((a, b) => a.rp.compareTo(b.rp));
    return accounts;
  }

  Future<bool> set(AccountMetadata metadata) async {
    if (metadata.rp.isEmpty || metadata.email.isEmpty) return false;
    final pref = _pref!;
    var idList = pref.getStringList(_keyIdList) ?? [];
    var id = '${metadata.rp}:${metadata.email}';
    if (!idList.contains(id)) {
      idList.add(id);
      await pref.setStringList(_keyIdList, idList);
    }
    return pref.setString(id, jsonEncode(metadata.toJson()));
  }

  Future<bool> remove(AccountMetadata metadata) async {
    if (metadata.rp.isEmpty || metadata.email.isEmpty) return false;
    final pref = _pref!;
    var idList = pref.getStringList(_keyIdList) ?? [];
    var id = '${metadata.rp}:${metadata.email}';
    if (!idList.contains(id)) return true;
    idList.remove(id);
    await pref.setStringList(_keyIdList, idList);
    return pref.remove(id);
  }

}