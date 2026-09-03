import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../platform/picked.dart';
import '../theme.dart';
import '../widgets.dart';

/// 应用内相册（安卓用）：直接读系统媒体库，多选时显示选择顺序。
/// 返回 [PickedImage] 列表（按选择顺序），取消返回 null。
class GalleryPickerPage extends StatefulWidget {
  const GalleryPickerPage({super.key});

  static Future<List<PickedImage>?> open(BuildContext context) =>
      Navigator.of(context).push<List<PickedImage>>(MaterialPageRoute(builder: (_) => const GalleryPickerPage()));

  @override
  State<GalleryPickerPage> createState() => _GalleryPickerPageState();
}

class _GalleryPickerPageState extends State<GalleryPickerPage> {
  PermissionState? _perm;
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _album;
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selected = [];
  final Map<String, Uint8List> _thumbs = {};
  bool _loading = true;
  bool _finishing = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;
    setState(() => _perm = ps);
    if (!ps.hasAccess) {
      setState(() => _loading = false);
      return;
    }
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image, hasAll: true);
    if (!mounted) return;
    _albums = albums;
    await _loadAlbum(albums.isEmpty ? null : albums.first);
  }

  Future<void> _loadAlbum(AssetPathEntity? album) async {
    setState(() {
      _album = album;
      _loading = true;
      _assets = [];
    });
    if (album == null) {
      setState(() => _loading = false);
      return;
    }
    final total = await album.assetCountAsync;
    final list = await album.getAssetListRange(start: 0, end: total.clamp(0, 2000));
    if (!mounted) return;
    setState(() {
      _total = total;
      _assets = list;
      _loading = false;
    });
  }

  Future<Uint8List?> _thumb(AssetEntity a) async {
    final cached = _thumbs[a.id];
    if (cached != null) return cached;
    final d = await a.thumbnailDataWithSize(const ThumbnailSize.square(220), quality: 80);
    if (d != null) _thumbs[a.id] = d;
    return d;
  }

  void _toggle(AssetEntity a) {
    setState(() {
      if (!_selected.remove(a)) _selected.add(a);
    });
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final out = <PickedImage>[];
    for (final a in _selected) {
      final f = await a.originFile ?? await a.file;
      if (f == null) continue;
      final name = a.title ?? f.path.split('/').last;
      out.add(PickedImage(id: f.path, name: name, mtime: a.modifiedDateTime));
    }
    if (!mounted) return;
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tone.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Row(
                children: [
                  SoftButton(label: '取消', small: true, onPressed: () => Navigator.of(context).pop()),
                  const SizedBox(width: 10),
                  Expanded(child: _albumSelector()),
                  const SizedBox(width: 10),
                  SoftButton(
                    label: _finishing ? '准备中…' : '完成 (${_selected.length})',
                    small: true,
                    primary: true,
                    onPressed: _selected.isEmpty || _finishing ? null : _finish,
                  ),
                ],
              ),
            ),
            const HeaderRule(),
            Expanded(child: _body()),
            if (_selected.isNotEmpty) ...[
              const HeaderRule(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: Text('已选 ${_selected.length} 张，按点选顺序编号 1…${_selected.length}', style: Tone.bodySoft)),
                    SoftButton(label: '清空', small: true, onPressed: () => setState(_selected.clear)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _albumSelector() {
    if (_albums.isEmpty) return Text('相册', style: Tone.h3);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Tone.paper, borderRadius: BorderRadius.circular(Tone.rSmall), border: Border.all(color: Tone.hair)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AssetPathEntity>(
          value: _album,
          isExpanded: true,
          isDense: true,
          style: Tone.body,
          dropdownColor: Tone.paper,
          borderRadius: BorderRadius.circular(12),
          items: [for (final a in _albums) DropdownMenuItem(value: a, child: Text(a.isAll ? '全部照片' : a.name, overflow: TextOverflow.ellipsis))],
          onChanged: (a) => _loadAlbum(a),
        ),
      ),
    );
  }

  Widget _body() {
    if (_perm != null && !_perm!.hasAccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('需要相册权限', style: Tone.h2),
              const SizedBox(height: 8),
              Text('SENDIT 只在本机读取你选择的图片，不会上传。', style: Tone.bodySoft, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SoftButton(label: '去设置开启', primary: true, onPressed: PhotoManager.openSetting),
            ],
          ),
        ),
      );
    }
    if (_loading) return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
    if (_assets.isEmpty) return Center(child: Text('这个相册里没有图片', style: Tone.bodySoft));
    return Column(
      children: [
        if (_total > _assets.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('只显示最近 ${_assets.length} 张（共 $_total 张）', style: Tone.bodySoft),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
            itemCount: _assets.length,
            itemBuilder: (_, i) {
              final a = _assets[i];
              final idx = _selected.indexOf(a);
              return GestureDetector(
                onTap: () => _toggle(a),
                child: Container(
                  decoration: BoxDecoration(
                    color: Tone.paper,
                    borderRadius: BorderRadius.circular(Tone.rSmall),
                    border: Border.all(color: idx >= 0 ? Tone.ink : Tone.hairSoft, width: idx >= 0 ? 2 : 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FutureBuilder<Uint8List?>(
                        future: _thumb(a),
                        builder: (_, snap) => snap.data == null
                            ? const SizedBox()
                            : Image.memory(snap.data!, fit: BoxFit.cover, gaplessPlayback: true),
                      ),
                      if (idx >= 0) ...[
                        Container(color: Tone.ink.withValues(alpha: 0.12)),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Tone.ink, borderRadius: BorderRadius.circular(999)),
                            child: Text('${idx + 1}', style: Tone.num.copyWith(color: Tone.paper, fontSize: 13)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
