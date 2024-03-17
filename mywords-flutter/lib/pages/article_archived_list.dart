import 'package:flutter/material.dart';
import 'package:mywords/common/global_event.dart';
import 'package:mywords/libso/funcs.dart';

import 'package:mywords/widgets/article_list.dart';

class ArticleArchivedPage extends StatefulWidget {
  const ArticleArchivedPage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _State();
  }
}

class _State extends State<ArticleArchivedPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("已归档文章"),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
                onPressed: () {
                  // 归档置顶
                  addToGlobalEvent(GlobalEvent(
                      eventType: GlobalEventType.articleListScrollToTop,
                      param: 2));
                },
                icon: const Icon(Icons.vertical_align_top_outlined))
          ],
        ),
        body: const ArticleListView(
          getFileInfos: getArchivedFileInfoList,
          toEndSlide: ToEndSlide.unarchive,
          leftLabel: '恢复',
          leftIconData: Icons.restore,
          pageNo: 2,
        ));
  }
}
