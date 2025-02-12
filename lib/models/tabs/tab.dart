/* this is a representation of the tabs that could be open in the app.
a tab is either a pdf book or a text book, or a full text search window*/

import 'package:otzaria/models/tabs/pdf_tab.dart';
import 'package:otzaria/models/tabs/searching_tab.dart';
import 'package:otzaria/models/tabs/text_tab.dart';

abstract class OpenedTab {
  String title;
  OpenedTab(this.title);

  factory OpenedTab.from(OpenedTab tab) {
    if (tab is TextBookTab) {
      return TextBookTab(
        index: tab.index,
        book: tab.book,
        commentators: tab.commentatorsToShow.value,
      );
    } else if (tab is PdfBookTab) {
      return PdfBookTab(
        tab.book,
        tab.pageNumber,
      );
    }
    return tab;
  }

  factory OpenedTab.fromJson(Map<String, dynamic> json) {
    String type = json['type'];
    if (type == 'TextBookTab') {
      return TextBookTab.fromJson(json);
    } else if (type == 'PdfBookTab') {
      return PdfBookTab.fromJson(json);
    }
    return SearchingTab.fromJson(json);
  }
  Map<String, dynamic> toJson();
}
