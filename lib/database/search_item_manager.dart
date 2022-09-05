import 'dart:convert';

import 'package:eso/api/api_manager.dart';
import 'package:eso/profile.dart';
import 'package:eso/utils.dart';
import 'chapter_item.dart';
import 'search_item.dart';
import '../global.dart';

class SearchItemManager {
  static Set<SearchItem> _searchItem;
  static Set<SearchItem> get searchItem => _searchItem;
  static String get key => Global.searchItemKey;

  static String genChapterKey(int id) => "chapter$id";

  /// 根据类型和排序规则取出收藏
  static List<SearchItem> getSearchItemByType(
      int contentType, SortType sortType) {
    final searchItem = <SearchItem>[];
    _searchItem.forEach((element) {
      if (element.ruleContentType == contentType) searchItem.add(element);
    });
    //排序
    switch (sortType) {
      case SortType.CREATE:
        searchItem.sort((a, b) => b.createTime.compareTo(a.createTime));
        break;
      case SortType.UPDATE:
        searchItem.sort((a, b) => b.updateTime.compareTo(a.updateTime));
        break;
      case SortType.LASTREAD:
        searchItem.sort((a, b) => b.lastReadTime.compareTo(a.lastReadTime));
        break;
    }
    return searchItem;
  }

  static bool isFavorite(String originTag, String url) {
    return _searchItem.any((item) =>
        item.originTag == originTag &&
        item.url == url &&
        item.group.split(',').contains(Profile().currentGroup));
  }

  static Future<bool> toggleFavorite(SearchItem searchItem) {
    if (isFavorite(searchItem.originTag, searchItem.url)) {
      return removeSearchItem(searchItem.id);
    } else {
      //添加时间信息
      searchItem.createTime = DateTime.now().microsecondsSinceEpoch;
      searchItem.updateTime = DateTime.now().microsecondsSinceEpoch;
      searchItem.lastReadTime = DateTime.now().microsecondsSinceEpoch;
      searchItem.group = Profile().currentGroup;

      return addSearchItem(searchItem);
    }
  }

  static Future<bool> addSearchItem(SearchItem searchItem) async {
    _searchItem.removeWhere((element) => element.id == searchItem.id);
    _searchItem.add(searchItem);
    return await saveSearchItem() &&
        await saveChapter(searchItem.id, searchItem.chapters);
  }

  static List<ChapterItem> getChapter(int id) {
    return Global.prefs
        .getStringList(genChapterKey(id))
        .map((item) => ChapterItem.fromJson(jsonDecode(item)))
        .toList();
  }

  static void initSearchItem() {
    _searchItem = Set<SearchItem>();
    Global.prefs.getStringList(key)?.forEach(
        (item) => _searchItem.add(SearchItem.fromJson(jsonDecode(item))));
  }

  static Future<bool> removeSearchItem(int id) async {
    await Global.prefs.remove(genChapterKey(id));
    _searchItem.removeWhere((item) => item.id == id);
    return saveSearchItem();
  }

  static Future<bool> saveSearchItem() async {
    return await Global.prefs.setStringList(
        key, _searchItem.map((item) => jsonEncode(item.toJson())).toList());
  }

  static Future<bool> removeChapter(int id) {
    return Global.prefs.remove(genChapterKey(id));
  }

  static Future<bool> saveChapter(int id, List<ChapterItem> chapters) async {
    return await Global.prefs.setStringList(genChapterKey(id),
        chapters.map((item) => jsonEncode(item.toJson())).toList());
  }

  static String backupItems() {
    if (_searchItem == null || _searchItem.isEmpty) initSearchItem();
    return json.encode(_searchItem.map((item) {
      Map<String, dynamic> json = item.toJson();
      json["chapters"] = getChapter(item.id)
          .map((chapter) => jsonEncode(chapter.toJson()))
          .toList();
      return json;
    }).toList());
  }

  static Future<bool> restore(String data) async {
    List json = jsonDecode(data);
    json.forEach((item) {
      SearchItem searchItem = SearchItem.fromJson(item);
      if (!isFavorite(searchItem.originTag, searchItem.url)) {
        List<ChapterItem> chapters = (jsonDecode('${item["chapters"]}') as List)
            .map((chapter) => ChapterItem.fromJson(chapter))
            .toList();
        saveChapter(searchItem.id, chapters);
        _searchItem.add(searchItem);
      }
    });
    saveSearchItem();
    return true;
  }

  static Future<void> refreshAll() async {
    // 先用单并发，加延时5s判定
    for (var item in _searchItem) {
      if (item.group.split(',').contains(Profile().currentGroup)) {
        print("刷新章节:${item.name},group:${item.group}");
        var current = item.name;
        await Future.any([
          refreshItem(item),
          (SearchItem temp) async {
            await Future.delayed(Duration(seconds: 5), () {
              if (current == temp.name) Utils.toast("${temp.name} 章节更新超时");
            });
          }(item),
        ]);
        current = null;
      }
    }
    return;
  }

  static Future<void> refreshItem(SearchItem item) async {
    if (item.chapters.isEmpty) {
      item.chapters = SearchItemManager.getChapter(item.id);
    }
    List<ChapterItem> chapters;
    try {
      chapters = await APIManager.getChapter(item.originTag, item.url);
    } catch (e) {
      Utils.toast("${item.name} 章节获取失败");
      return;
    }
    if (chapters.isEmpty) {
      Utils.toast("${item.name} 章节为空");
      return;
    }
    final newCount = chapters.length - item.chapters.length;
    if (newCount > 0) {
      Utils.toast("${item.name} 新增 $newCount 章节");
      item.chapters = chapters;
      item.chapter = chapters.last?.name;
      item.chaptersCount = chapters.length;
      await SearchItemManager.saveChapter(item.id, item.chapters);
    } else {
      Utils.toast("${item.name} 无新增章节");
    }
    return;
  }
}

enum SortType { UPDATE, CREATE, LASTREAD }
