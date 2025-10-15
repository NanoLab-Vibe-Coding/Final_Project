// lib/ui/screens/board_screen.dart
// 단독 보드 보기(디버그/테스트용). CameraScreen에서 주로 사용.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/board_model.dart';
import '../../domain/models/card_model.dart';
import '../widgets/card_grid.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  BoardPage? _page;
  Map<String, Rect> _rects = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await rootBundle.loadString('assets/boards/cards_default.json');
    final j = jsonDecode(data) as Map<String, dynamic>;
    final board = Board.fromJson(j);
    setState(() => _page = board.pages.first);
  }

  @override
  Widget build(BuildContext context) {
    if (_page == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(_page!.title)),
      body: CardGrid(
        page: _page!,
        fontScale: 1.0,
        highContrast: false,
        onRectsReady: (r) => _rects = r,
        onCardTap: (c) => _onCardTap(context, c),
      ),
    );
  }

  void _onCardTap(BuildContext context, CardItem c) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.label} / ${c.id}')));
  }
}

