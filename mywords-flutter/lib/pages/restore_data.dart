import 'dart:convert';

import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywords/common/prefs/prefs.dart';
import 'package:path_provider/path_provider.dart';
import '../libso/funcs.dart';
import '../libso/resp_data.dart';
import '../util/path.dart';
import '../util/util.dart';
import '../widgets/private_ip.dart';
import '../widgets/restart_app.dart';

class RestoreData extends StatefulWidget {
  const RestoreData({super.key});

  @override
  State createState() {
    return _RestoreDataState();
  }
}

class _RestoreDataState extends State<RestoreData> {
  TextEditingController controllerPort = TextEditingController();
  TextEditingController controllerIP = TextEditingController();
  TextEditingController controllerCode = TextEditingController();
  TextEditingController controllerBackUpZipName =
      TextEditingController(text: "mywords-backupdata");
  String defaultDownloadDir = '';

  @override
  void initState() {
    super.initState();
    defaultDownloadDir = getDefaultDownloadDir() ?? '';
    initController();
  }

  final defaultPort = 18964;
  final defaultCode = 890604;

  void initController() {
    final ss = prefs.syncIpPortCode;
    myPrint(ss);
    if (ss.length != 3) {
      controllerPort.text = '$defaultPort';
      controllerCode.text = '$defaultCode';
      return;
    }
    final ip = ss[0];
    final p = int.tryParse(ss[1]);
    final c = int.tryParse(ss[2]);
    if (p != null && c != null) {
      controllerIP.text = ip;
      controllerPort.text = p.toString();
      controllerCode.text = c.toString();
    } else {
      controllerPort.text = '$defaultPort';
      controllerCode.text = '$defaultCode';
      controllerIP.text = '';
    }
  }

  @override
  void dispose() {
    super.dispose();
    controllerPort.dispose();
    controllerCode.dispose();
    controllerIP.dispose();
    controllerBackUpZipName.dispose();
  }


  Future<int> syncShareData() async {
    if (controllerIP.text == "") {
      myToast(context, "IP/域名不能为空");
      return -1;
    }
    if (controllerPort.text == "") {
      myToast(context, "端口号不能为空");
      return -1;
    }
    if (controllerCode.text == "") {
      myToast(context, "Code码不能为空");
      return -1;
    }
    setState(() {
      isSyncing = true;
    });
    final port = int.parse(controllerPort.text);
    final code = int.parse(controllerCode.text);
    final dir = await getTemporaryDirectory();
    final tempDir = dir.path;
    final respData = await compute(
        (message) => computeRestoreFromShareServer(message), <String, dynamic>{
      'ip': controllerIP.text,
      'port': port,
      'code': code,
      'tempDir': tempDir,
      'syncToadyWordCount': syncToadyWordCount,
    });
    setState(() {
      isSyncing = false;
    });

    if (respData.code != 0) {
      myToast(context, respData.message);
      return -1;
    }
    prefs.syncIpPortCode = [
      controllerIP.text,
      controllerPort.text,
      controllerCode.text
    ];
    myToast(context, "同步成功!");
    return 0;
  }

  bool isSyncing = false;

  Widget syncShareDataBuild() {
    return ElevatedButton.icon(
      onPressed: isSyncing ? null : syncShareData,
      icon: const Icon(Icons.sync),
      label: const Text("开始同步"),
    );
  }

  void restoreFromFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        initialDirectory: getDefaultDownloadDir(),
        allowMultiple: false,
        withReadStream: true,
        type: FileType.custom,
        allowedExtensions: ['zip']);
    if (result == null) {
      return;
    }
    final files = result.files;
    if (files.isEmpty) {
      return;
    }
    final file = files[0];
    if (file.path == null) {
      return;
    }
    final respData =
        await compute((message) => _restoreFromBackUpData(message), file.path!);
    if (respData.code != 0) {
      myToast(context, "恢复失败!\n${respData.message}");
      return;
    }
    myToast(context, "恢复成功");
    Navigator.pop(context);
    RestartApp.restart(context);
  }

  Widget textFieldCode() {
    return TextField(
      keyboardType: TextInputType.number,
      controller: controllerCode,
      decoration: const InputDecoration(
        labelText: "Code码",
        isDense: true,
      ),
      inputFormatters: [
        LengthLimitingTextInputFormatter(6),
        FilteringTextInputFormatter(RegExp("[0-9]"), allow: true)
      ],
    );
  }

  Widget textFieldPort() {
    return TextField(
      controller: controllerPort,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: "端口",
        isDense: true,
      ),
      inputFormatters: [
        LengthLimitingTextInputFormatter(5),
        FilteringTextInputFormatter(RegExp("[0-9]"), allow: true)
      ],
    );
  }

  Widget textFieldIP() {
    return TextField(
      controller: controllerIP,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: "IP/域名",
        // border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  bool syncToadyWordCount = prefs.syncToadyWordCount;

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      const PrivateIP(),
      SwitchListTile(
        value: syncToadyWordCount,
        onChanged: (v) {
          syncToadyWordCount = v;
          prefs.syncToadyWordCount = v;
          setState(() {});
        },
        title: const Text("同步单词每日统计"),
      ),
      ListTile(
        title: const Text("从本地同步"),
        leading: const Tooltip(
          message: "从本地选择文件进行数据同步",
          triggerMode: TooltipTriggerMode.tap,
          child: Icon(Icons.info_outline),
        ),
        trailing: IconButton(
          onPressed: restoreFromFile,
          icon: Icon(
            Icons.file_open,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
      ListTile(title: textFieldIP()),
      Row(
        children: [
          Flexible(
            child: ListTile(title: textFieldPort()),
          ),
          Flexible(child: ListTile(title: textFieldCode())),
        ],
      ),
      ListTile(
        trailing: syncShareDataBuild(),
        title: isSyncing ? const LinearProgressIndicator() : null,
        leading: const Tooltip(
          message: "本地数据不会丢失，同步数据将与本地数据进行合并",
          triggerMode: TooltipTriggerMode.tap,
          child: Icon(Icons.info),
        ),
      ),
    ];

    final body = Column(children: children);

    final appBar = AppBar(
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      title: const Text("同步数据"),
    );
    return Scaffold(
      appBar: appBar,
      body: Padding(padding: const EdgeInsets.all(10), child: body),
    );
  }
}

RespData<void> _restoreFromBackUpData(String zipPath) {
  final pathC = zipPath.toNativeUtf8();
  final resultC = restoreFromBackUpData(pathC);
  final respData =
      RespData.fromJson(jsonDecode(resultC.toDartString()), (json) => null);
  malloc.free(pathC);
  malloc.free(resultC);
  return respData;
}

Future<RespData<void>> computeRestoreFromShareServer(
    Map<String, dynamic> param) async {
  final ip = param['ip'] as String;
  final port = param['port'] as int;
  final code = param['code'] as int;
  final tempDir = param['tempDir'] as String;
  final syncToadyWordCount = param['syncToadyWordCount'] as bool;
  return restoreFromShareServer(ip, port, code, tempDir, syncToadyWordCount);
}