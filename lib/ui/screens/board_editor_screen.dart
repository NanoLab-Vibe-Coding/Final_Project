// lib/ui/screens/board_editor_screen.dart
// 보드/카드 편집기: 관리자용으로 카드 추가/삭제/수정 후 SharedPreferences에 저장

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../domain/models/board_model.dart';
import '../../domain/models/card_model.dart';

class BoardEditorScreen extends StatefulWidget {
  const BoardEditorScreen({super.key});
  @override
  State<BoardEditorScreen> createState() => _BoardEditorScreenState();
}

class _BoardEditorScreenState extends State<BoardEditorScreen> {
  Board? _board;
  bool _inited = false;
  @override
  void initState() { super.initState(); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) { _inited = true; _load(); }
  }

  Future<void> _load() async {
    final prefs = AppScope.of(context).prefs;
    final custom = prefs.getString('boardJson');
    if (custom != null && custom.isNotEmpty) {
      _board = Board.fromJson(jsonDecode(custom) as Map<String, dynamic>);
    } else {
      // 기본 템플릿 생성
      _board = Board(locale: 'ko', pages: ListBoardPages([
        BoardPage(title: '사용자 보드', grid: '3x2', cards: []),
      ]));
    }
    setState(() {});
  }

  Future<void> _save() async {
    final prefs = AppScope.of(context).prefs;
    await prefs.setString('boardJson', jsonEncode(_board!.toJson()));
    if (mounted) Navigator.pop(context);
  }

  void _addCard() async {
    final page = _board!.pages.first;
    final newItem = await showDialog<CardItem>(
      context: context,
      builder: (_) => const _EditCardDialog(),
    );
    if (newItem != null) {
      setState(() => page.cards.add(newItem));
    }
  }

  void _editCard(int index) async {
    final page = _board!.pages.first;
    final edited = await showDialog<CardItem>(
      context: context,
      builder: (_) => _EditCardDialog(item: page.cards[index]),
    );
    if (edited != null) {
      setState(() => page.cards[index] = edited);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_board == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final page = _board!.pages.first;
    return Scaffold(
      appBar: AppBar(
        title: const Text('보드 편집'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCard,
        child: const Icon(Icons.add),
      ),
      body: ListView.separated(
        itemCount: page.cards.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = page.cards[i];
          return ListTile(
            title: Text('${c.label} (${c.id})'),
            subtitle: Text(c.speak + (c.sos ? '  [SOS]' : '')),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => _editCard(i), icon: const Icon(Icons.edit)),
              IconButton(onPressed: () => setState(() => page.cards.removeAt(i)), icon: const Icon(Icons.delete)),
            ]),
          );
        },
      ),
    );
  }
}

class _EditCardDialog extends StatefulWidget {
  final CardItem? item;
  const _EditCardDialog({this.item});
  @override
  State<_EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<_EditCardDialog> {
  final _id = TextEditingController();
  final _label = TextEditingController();
  final _speak = TextEditingController();
  final _call = TextEditingController();
  final _sms = TextEditingController();
  bool _sos = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _id.text = it.id;
      _label.text = it.label;
      _speak.text = it.speak;
      _sos = it.sos;
      _call.text = it.call ?? '';
      _sms.text = it.sms ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? '카드 추가' : '카드 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _id, decoration: const InputDecoration(labelText: 'id')), 
            TextField(controller: _label, decoration: const InputDecoration(labelText: '라벨')),
            TextField(controller: _speak, decoration: const InputDecoration(labelText: '발화 텍스트')),
            SwitchListTile(value: _sos, onChanged: (v) => setState(() => _sos = v), title: const Text('SOS 카드')),
            if (_sos) ...[
              TextField(controller: _call, decoration: const InputDecoration(labelText: '전화번호(예: 112)')),
              TextField(controller: _sms, decoration: const InputDecoration(labelText: 'SMS 템플릿')),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            final item = CardItem(
              id: _id.text.trim(),
              label: _label.text.trim(),
              speak: _speak.text.trim(),
              sos: _sos,
              call: _call.text.trim().isEmpty ? null : _call.text.trim(),
              sms: _sms.text.trim().isEmpty ? null : _sms.text.trim(),
            );
            Navigator.pop(context, item);
          },
          child: const Text('저장'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _id.dispose();
    _label.dispose();
    _speak.dispose();
    _call.dispose();
    _sms.dispose();
    super.dispose();
  }
}
