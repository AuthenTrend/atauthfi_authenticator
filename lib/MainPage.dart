import 'dart:async';

import 'package:atauthfi_authenticator/AccountData.dart';
import 'package:atauthfi_authenticator/Extensions.dart';
import 'package:atauthfi_authenticator/widgets/CustomListTiles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_browser/flutter_web_browser.dart';
import 'package:localization/localization.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter/services.dart' show PlatformException;

import 'Extensions.dart';

const String _appUrlScheme = "atauthficator";
bool _initialUriIsHandled = false;

enum _MethodType {
  registration,
  verification,
}

extension _MethodTypeExt on _MethodType {
  String toName() {
    return toString().split('.').last;
  }
}

class MainPage extends StatefulWidget {

  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  List<Map<String, dynamic>> _listItems = [];
  AccountMetadata? _selectedAccount;
  StreamSubscription? _uriLinkSub;
  StreamSubscription<BrowserEvent>? _browserEvents;
  bool _isBrowserOpened = false;

  Future<void> _updateList() async {
    List<Map<String, dynamic>> items = [];
    var accountData = await AccountData.getInstance();
    var accounts = accountData.get();
    // for test only
    if (kDebugMode && accounts.isEmpty) {
      for (var index in List.generate(20, (index) => index)) {
        await accountData.set(AccountMetadata('www.test${index % 5}.com', 'user${index.toString().padLeft(2, '0')}@test${index % 5}.com'));
      }
    }
    //////////
    Map<String, List<AccountMetadata>> rpAccounts = {};
    for (var account in accounts) {
      rpAccounts[account.rp] ??= [];
      rpAccounts[account.rp]?.add(account);
    }
    var rps = rpAccounts.keys.toList();
    rps.sort();
    for (var rp in rps) {
      items.add({'type': ListTileType.header, 'title': rp});
      var accountList = rpAccounts[rp] ?? [];
      accountList.sort((a, b) => a.email.compareTo(b.email));
      for (var account in accountList) {
        items.add({'type': ListTileType.item, 'title': account.email, 'metadata': account});
      }
    }
    if (items.length != _listItems.length) setState(() { _listItems = items;});
  }

  Future<void> _showAbout() async {
    var packageInfo = await PackageInfo.fromPlatform();
    var version = packageInfo.version;
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
            title: Text('app_name'.i18n(), textAlign: TextAlign.center),
            content: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    style: const TextStyle(fontSize: 16),
                    text: '${'version'.i18n()} $version\n\n${'copyright'.i18n()}\n\n\n',
                  ),
                  TextSpan(
                    style: const TextStyle(fontSize: 16, color: Colors.blue),
                    text: 'website_url'.i18n(),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () { launchUrlString('website_url'.i18n(), mode: LaunchMode.externalApplication); },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ok'.i18n())
              ),
            ],
          );
        });
  }

  Future<void> _showDialog(String message, {Function()? onOkPressed, Function()? onCancelPressed}) async {
    return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(25))),
            content: Text(message, textAlign: TextAlign.center),
            contentPadding: const EdgeInsets.only(top: 30),
            actions: [
              TextButton(
                child: Text('cancel'.i18n()),
                onPressed: () {
                  Navigator.pop(context);
                  if (onCancelPressed != null) onCancelPressed();
                },
              ),
              TextButton(
                child: Text('ok'.i18n()),
                onPressed: () {
                  Navigator.pop(context);
                  if (onOkPressed != null) onOkPressed();
                },
              ),
            ],
          );
        });
  }

  Future<void> _showScanner() async {
    var cameraController = MobileScannerController(facing: CameraFacing.back, torchEnabled: false);
    return showModalBottomSheet(
        context: context,
        enableDrag: false,
        isDismissible: false,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25))),
        builder: (BuildContext context) {
          return FractionallySizedBox(
            heightFactor: 0.9,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                title: Text('scan_qr_code'.i18n()),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  splashRadius: 24,
                  iconSize: 24,
                  icon: ValueListenableBuilder(
                    valueListenable: cameraController.torchState,
                    builder: (context, state, child) {
                      switch (state as TorchState) {
                        case TorchState.off:
                          return const Icon(Icons.flash_off);
                        case TorchState.on:
                          return const Icon(Icons.flash_on);
                      }
                    },
                  ),
                  onPressed: () => cameraController.toggleTorch(),
                ),
                actions: [
                  IconButton(
                    splashRadius: 24,
                    iconSize: 24,
                    icon: const Icon(Icons.flip_camera_ios),
                    onPressed: () => cameraController.switchCamera(),
                  ),
                ],
              ),
              body: MobileScanner(
                  allowDuplicates: false,
                  controller: cameraController,
                  onDetect: (result, args) {
                    if (result.type == BarcodeType.url && result.rawValue != null) {
                      final urlStr = result.rawValue!;
                      'QR code: $urlStr'.log();
                      try {
                        var uri = Uri.parse(urlStr);
                        _handleUniversalLink(uri);
                        Navigator.pop(context);
                      } catch(err) {
                        'Error: $err'.log();
                      }
                    }
                  }),
              floatingActionButton: TextButton(
                style: ButtonStyle(backgroundColor: MaterialStateProperty.all(const Color.fromARGB(0x55, 0, 0, 0))),
                child: Text('cancel'.i18n(), textAlign: TextAlign.center),
                onPressed: () {
                  _selectedAccount = null;
                  Navigator.pop(context);
                },
              ),
            ),
          );
        });
  }

  Future<void> _showItemMenu(BuildContext context, int index) async {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(const Offset(0, 0));
    final left = offset.dx;
    final top = offset.dy + renderBox.size.height;
    final right = left + renderBox.size.width;
    final RelativeRect position = RelativeRect.fromLTRB(left, top, right, 0);
    showMenu(
      context: context,
      position: position,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
      items: <PopupMenuItem<String>>[
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            const Padding(padding: EdgeInsets.only(right: 15), child: Icon(Icons.person_remove)),
            Text('delete'.i18n()),
          ],),
          onTap: () {
            'delete $index'.log();
            Future.delayed(const Duration(seconds: 0), () => _showDialog('delete_account_msg'.i18n(), onOkPressed: () {
              AccountData.getInstance().then((accountData) {
                accountData.remove(_listItems[index]['metadata']);
                _updateList();
              });
            }));
          },
        ),
      ],
    );
  }

  Future<void> _showActionSheet(List<String> actionNames, Function(int index) onSelected) async {
    List<CupertinoActionSheetAction> actions = [];
    for (int index = 0; index < actionNames.length; index++) {
      actions.add(CupertinoActionSheetAction(child: Text(actionNames[index]), onPressed: () {
        Navigator.pop(context);
        onSelected(index);
      }));
    }
    actions.add(CupertinoActionSheetAction(child: Text('cancel'.i18n()), onPressed: () {
      Navigator.pop(context);
      onSelected(-1);
    }));
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: actions,
      ),
    );
  }

  void _openBrowser(Uri uri) {
    'Open ${uri.toString()}'.log();
    _isBrowserOpened = true;
    FlutterWebBrowser.openWebPage(
      url: uri.toString(),
      customTabsOptions: const CustomTabsOptions(
        shareState: CustomTabsShareState.on,
        instantAppsEnabled: true,
        showTitle: false,
        urlBarHidingEnabled: true,
      ),
      // FIXME: if using UIModalPresentationStyle.pageSheet and dragging down to close the browser, the close event will never be received.
      safariVCOptions: const SafariViewControllerOptions(
        barCollapsingEnabled: true,
        dismissButtonStyle: SafariViewControllerDismissButtonStyle.close,
        modalPresentationCapturesStatusBarAppearance: true,
        modalPresentationStyle: UIModalPresentationStyle.blurOverFullScreen,
      ),
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    var status = uri.queryParameters['status'];
    if (status != "success") {
      var errMsg =  uri.queryParameters['errorMessage'];
      if (errMsg != null) {
        errMsg = errMsg.base64UrlDecode();
      }
      else {
        errMsg = 'unknown_error'.i18n();
      }
      errMsg.asAlert(context);
      return;
    }

    var method = uri.host;
    if (!_MethodType.values.map((e) => e.toName()).contains(method)) {
      'Method type mismatched'.log();
      'unknown_error'.asAlert(context);
      return;
    }
    var methodType = _MethodType.values.firstWhere((element) => (element.toName() == method));
    if (methodType == _MethodType.verification) {
      'verification_success'.asToast();
      return;
    }

    var user = uri.queryParameters['user'];
    var rp = uri.queryParameters['rp'];
    if (user == null || user.isEmpty || rp == null || rp.isEmpty) {
      'invalid_response'.asAlert(context);
      return;
    }

    var accountData = await AccountData.getInstance();
    await accountData.set(AccountMetadata(rp.base64UrlDecode(), user.base64UrlDecode()));
    _updateList();
  }

  Future<void> _handleUniversalLink(Uri uri) async {
    var hostname = uri.queryParameters['r'];
    var path = uri.queryParameters['p'];
    var token = uri.queryParameters['t'];
    var method = uri.queryParameters['m'];
    if (hostname == null || path == null || token == null || method == null) return;

    hostname = hostname.base64UrlDecode().split('').reversed.join();
    path = path.base64UrlDecode();
    var methodType = _MethodType.values.firstWhere((element) => (element.toName() == method));
    var redirectUrlStr = "$_appUrlScheme://${methodType.toName()}".base64UrlEncode();
    var rpUriStr = "https://$hostname$path?t=$token&redirect=$redirectUrlStr";
    if (methodType == _MethodType.verification) {
      if (_selectedAccount == null) {
        var accounts = (await AccountData.getInstance()).get();
        List<String> emails = [];
        for (var account in accounts) {
          if (!emails.contains(account.email)) emails.add(account.email);
        }
        if (emails.isEmpty) {
          return;
        }
        else if (emails.length == 1) {
          _selectedAccount = accounts[0];
        }
        else if (emails.length > 1) {
          _showActionSheet(emails, (index) {
            if (index < 0 || index >= emails.length) return;
            var email = emails[index].base64UrlEncode();
            rpUriStr += '&email=$email';
            try {
              var rpUri = Uri.parse(rpUriStr);
              _openBrowser(rpUri);
            } catch(err) {
              'Error: $err'.log();
            }
          });
          return;
        }
      }
      var email = _selectedAccount!.email.base64UrlEncode();
      rpUriStr += '&email=$email';
      _selectedAccount = null;
    }

    var rpUri = Uri.parse(rpUriStr);
    _openBrowser(rpUri);
  }

  /// Handle incoming links - the ones that the app will receive from the OS
  /// while already started.
  void _handleIncomingLinks() {
    if (!kIsWeb) {
      // It will handle app links while the app is already started - be it in
      // the foreground or in the background.
      _uriLinkSub = uriLinkStream.listen((Uri? uri) {
        if (uri == null || !mounted) return;
        'Incoming URI: $uri'.log();
        if (_isBrowserOpened) FlutterWebBrowser.close();
        Future.delayed(const Duration(seconds: 0), () => (uri.scheme == _appUrlScheme) ? _handleDeepLink(uri) : _handleUniversalLink(uri));
      }, onError: (Object err) {
        'Error: $err'.log();
      });
    }
  }

  /// Handle the initial Uri - the one the app was started with
  ///
  /// **ATTENTION**: `getInitialLink`/`getInitialUri` should be handled
  /// ONLY ONCE in your app's lifetime, since it is not meant to change
  /// throughout your app's life.
  ///
  /// We handle all exceptions, since it is called from initState.
  Future<void> _handleInitialUri() async {
    if (!_initialUriIsHandled) {
      _initialUriIsHandled = true;
      try {
        final uri = await getInitialUri();
        if (uri == null || !mounted) return;
        'Incoming URI: $uri'.log();
        Future.delayed(const Duration(seconds: 0), () => (uri.scheme == _appUrlScheme) ? _handleDeepLink(uri) : _handleUniversalLink(uri));
      } on PlatformException {
        'Failed to get initial uri'.log();
      } on FormatException catch (err) {
        'Malformed initial uri'.log();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
    _handleInitialUri();
    _browserEvents = FlutterWebBrowser.events().listen((event) {
      if (event is RedirectEvent) {
        // NOTE: never enter here
        var uri = event.url;
        'RedirectEvent: $uri'.log();
        if (_isBrowserOpened) FlutterWebBrowser.close();
        Future.delayed(const Duration(seconds: 0), () => (uri.scheme == _appUrlScheme) ? _handleDeepLink(uri) : _handleUniversalLink(uri));
      }
      else if (event is CloseEvent) {
        'CloseEvent'.log();
        _isBrowserOpened = false;
      }
    });
  }

  @override
  void dispose() {
    _uriLinkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var title = 'app_title'.i18n();
    const bgImage = AssetImage('assets/images/background.png');
    const logoImage = AssetImage('assets/images/app_logo.png');
    _updateList();
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(image: bgImage, fit: BoxFit.cover),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Image(image: logoImage, height: 25, alignment: Alignment.center,),
              Text(title, style: TextStyle(fontSize: 18), textAlign: TextAlign.center,),
            ],
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: IconButton(
            splashRadius: 24,
            icon: const Icon(Icons.info_outline, size: 26.0),
            onPressed: () {
              _showAbout();
            },
          ),
          actions: [
            IconButton(
              splashRadius: 24,
              icon: const Icon(Icons.qr_code_scanner, size: 26.0),
              onPressed: () => _showScanner(),
            ),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          itemCount: _listItems.length,
          itemBuilder: (context, index) {
            var item = _listItems[index];
            return (item['type'] == ListTileType.header) ?
            ListTileHeader(title: item['title']) :
            ListTileItem(
              index: index,
              title: item['title'],
              onItemPressed: (context, index) {
                _selectedAccount = _listItems[index]['metadata'];
                _showScanner();
              },
              onButtonPressed: (context, index) => _showItemMenu(context, index),
            );
          },
        ),
      ),
    );
  }
}
