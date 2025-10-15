// lib/domain/models/board_model.dart

import 'dart:collection';
import 'card_model.dart';

class BoardPage {
  final String title;
  final String grid; // e.g., "3x2"
  final List<CardItem> cards;

  BoardPage({required this.title, required this.grid, required this.cards});

  factory BoardPage.fromJson(Map<String, dynamic> j) => BoardPage(
        title: j['title'] as String,
        grid: j['grid'] as String,
        cards: (j['cards'] as List).map((e) => CardItem.fromJson(e)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'grid': grid,
        'cards': cards.map((e) => e.toJson()).toList(),
      };
}

class Board {
  final String locale;
  final ListBoardPages pages;

  Board({required this.locale, required this.pages});

  factory Board.fromJson(Map<String, dynamic> j) => Board(
        locale: j['locale'] as String,
        pages: ListBoardPages((j['pages'] as List).map((e) => BoardPage.fromJson(e)).toList()),
      );

  Map<String, dynamic> toJson() => {
        'locale': locale,
        'pages': pages.map((e) => e.toJson()).toList(),
      };
}

class ListBoardPages extends ListBase<BoardPage> {
  final List<BoardPage> _inner;
  ListBoardPages(this._inner);
  @override
  int get length => _inner.length;
  @override
  set length(int newLength) => _inner.length = newLength;
  @override
  BoardPage operator [](int index) => _inner[index];
  @override
  void operator []=(int index, BoardPage value) => _inner[index] = value;
}
