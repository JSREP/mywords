
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mywords/common/prefs/prefs.dart';
import 'package:mywords/libso/funcs.dart';
import 'package:mywords/pages/article_page.dart';
import 'package:mywords/pages/stastics_chart.dart';
import 'package:mywords/libso/types.dart';
import 'package:mywords/util/navigator.dart';
import 'package:mywords/util/util.dart';

import '../widgets/article_list.dart';

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({super.key});

  @override
  State<ArticleListPage> createState() => _State();
}

class _State extends State<ArticleListPage> with AutomaticKeepAliveClientMixin {
  TextEditingController controller = TextEditingController();
  ValueNotifier<bool> valueNotifier = ValueNotifier(false);

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
    focus.dispose();
    valueNotifierChart.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  List<FileInfo> get fileInfos => showFileInfoList().data ?? [];

  void search() async {
    if (controller.text == "") {
      myToast(context, "网址不能为空");
      return;
    }
    if (valueNotifier.value) {
      return;
    }
    final uri = Uri.tryParse(controller.text);
    if (uri == null) {
      myToast(context, "not a url");
      return;
    }
    final www = controller.text.trim();
    final idx = fileInfos.indexWhere((element) => element.sourceUrl == www);
    if (idx != -1) {
      final fileName = fileInfos[idx].fileName;
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('您已经解析过该网址，是否重新解析？'),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          pushTo(context, ArticlePage(fileName: fileName))
                              .then((value) {
                            valueNotifierChart.value = UniqueKey();
                          });
                        },
                        child: const Text("查看")),
                    ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          computeParse(www);
                        },
                        child: const Text("重新解析")),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text("取消")),
                  ],
                )
              ],
            );
          });
      focus.unfocus();
      return;
    }
    focus.unfocus();
    computeParse(www);
  }

  void computeParse(String www) async {
    valueNotifier.value = true;
    final result = await compute(parseAndSaveArticleFromSourceUrl, www);
    valueNotifier.value = false;
    if (result != "") {
      if (!context.mounted) return;
      myToast(context, result);
      return;
    }
    controller.text = "";
  }

  FocusNode focus = FocusNode();

  Widget textField() {
    //   "https://www.nytimes.com/2024/01/13/world/asia/china-taiwan-election-result-analysis.html"
    return TextField(
      controller: controller,
      focusNode: focus,
      decoration: InputDecoration(
          hintText: "请输入一个英语文章页面网址",
          prefixIcon: IconButton(
              onPressed: () {
                controller.text = '';
              },
              icon: const Icon(
                Icons.clear,
                color: Colors.red,
              )),
          suffixIcon: ValueListenableBuilder(
              valueListenable: valueNotifier,
              builder: (BuildContext context, bool value, Widget? child) {
                return IconButton(
                    onPressed: value ? null : search,
                    icon: value
                        ? const Icon(Icons.access_time)
                        : const Icon(Icons.search));
              })),
    );
  }

  Widget get todaySubtitle {
    final style =prefs.isDark?TextStyle(color:Colors.orange.shade300): TextStyle(color: Theme.of(context).primaryColor);
    return RichText(
        text: TextSpan(
            text: "1级:",
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            children: [
          TextSpan(text: '${todayCountMap['1'] ?? 0}', style: style),
          const TextSpan(text: "  2级:"),
          TextSpan(text: '${todayCountMap['2'] ?? 0}', style: style),
          const TextSpan(text: "  3级:"),
          TextSpan(text: '${todayCountMap['3'] ?? 0}', style: style),
        ]));
  }

  Widget buildBody() {
    List<Widget> colChildren = [
      ValueListenableBuilder(
          valueListenable: valueNotifierChart,
          builder: (BuildContext context, Key value, Widget? child) {
            return ListTile(
              // leading: toolTipToday,
              title: const Text("今日学习单词数量"),
              subtitle: todaySubtitle,
              // subtitle: Text(
              //     "1级:${todayCountMap['1'] ?? 0} 2级:${todayCountMap['2'] ?? 0} 3级:${todayCountMap['3'] ?? 0}"),
              onTap: () {
                pushTo(context, const WordChart()).then((value) {
                  valueNotifierChart.value = UniqueKey();
                });
              },
              trailing: const Icon(Icons.area_chart),
            );
          }),
      textField(),
      ValueListenableBuilder(
          valueListenable: valueNotifier,
          builder: (BuildContext context, bool value, Widget? child) {
            if (value) {
              return const SizedBox(
                  height: 5, child: LinearProgressIndicator());
            }
            return const SizedBox(height: 5);
          }),
      Expanded(
          child: ArticleListView(
        refresh: () {
          myPrint("刷新图标数据");
          valueNotifierChart.value = UniqueKey();
        },
        getFileInfos: showFileInfoList,
        toEndSlide: ToEndSlide.archive,
        leftLabel: '归档',
        leftIconData: Icons.archive,
      )),
    ];

    return Padding(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Column(children: colChildren));
  }



  ValueNotifier<Key> valueNotifierChart = ValueNotifier(UniqueKey());

  Map<String, dynamic> get todayCountMap {
    final respData = getToadyChartDateLevelCountMap();
    if (respData.code != 0) {
      myToast(context, respData.message);
      return {};
    }
    final data = respData.data ?? {};
    return data;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return buildBody();
  }

  @override
  bool get wantKeepAlive => true;
}