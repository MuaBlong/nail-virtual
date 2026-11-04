import 'package:flutter/material.dart';
import '../models/nail_set.dart';
import '../services/api.dart';
import 'nail_artwork.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_storage.dart';
import '../services/auth_service.dart';

class NailCatalog extends StatefulWidget {
  final ValueChanged<NailSet> onSelect;
  final String? selectedId;
  const NailCatalog({super.key, required this.onSelect, this.selectedId});
  @override
  State<NailCatalog> createState() => _NailCatalogState();
}

class _NailCatalogState extends State<NailCatalog> {
  late Future<NailCatalogResult> catalog;
  String category = 'Tất cả';
  String query = '';
  String tone = 'Tất cả màu';
  bool favoritesOnly = false;
  Set<String> favorites = {};
  String normalized(String value) {
    var text = value.toLowerCase();
    const groups = [
      'àáạảãâầấậẩẫăằắặẳẵ',
      'èéẹẻẽêềếệểễ',
      'ìíịỉĩ',
      'òóọỏõôồốộổỗơờớợởỡ',
      'ùúụủũưừứựửữ',
      'ỳýỵỷỹ',
      'đ',
    ];
    const replacements = ['a', 'e', 'i', 'o', 'u', 'y', 'd'];
    for (var i = 0; i < groups.length; i++) {
      text = text.replaceAll(RegExp('[${groups[i]}]'), replacements[i]);
    }
    return text;
  }

  String colorGroup(NailSet set) {
    final color = HSVColor.fromColor(set.palette.first);
    if (color.saturation < .12 || color.value < .2) return 'Trung tính';
    if (color.hue < 20 || color.hue >= 340) return 'Đỏ / Hồng';
    if (color.hue >= 280) return 'Tím / Hồng';
    if (color.hue >= 170 && color.hue < 280) return 'Xanh dương';
    if (color.hue >= 65 && color.hue < 170) return 'Xanh lá';
    return 'Nude / Vàng';
  }

  Future<void> loadFavorites() async {
    try {
      final storageKey = userStorageKey('favorite_nails');
      final prefs = await SharedPreferences.getInstance();
      if (mounted && storageKey == userStorageKey('favorite_nails')) {
        setState(
          () => favorites = (prefs.getStringList(storageKey) ?? []).toSet(),
        );
      }
    } catch (_) {
      /* catalog remains usable without storage */
    }
  }

  Future<void> toggleFavorite(String id) async {
    final storageKey = userStorageKey('favorite_nails');
    final next = {...favorites};
    if (!next.add(id)) next.remove(id);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setStringList(storageKey, next.toList())) {
        throw StateError('storage full');
      }
      if (mounted && storageKey == userStorageKey('favorite_nails')) {
        setState(() => favorites = next);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa lưu được mục yêu thích trên thiết bị này.'),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    catalog = NailCatalogApi.load();
    AuthService.instance.addListener(loadFavorites);
    loadFavorites();
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(loadFavorites);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<NailCatalogResult>(
    future: catalog,
    builder: (context, snapshot) {
      final sets = snapshot.data?.sets ?? nailSets;
      final categories = ['Tất cả', ...sets.map((s) => s.category).toSet()];
      final shown = sets
          .where(
            (s) =>
                (category == 'Tất cả' || s.category == category) &&
                (tone == 'Tất cả màu' || colorGroup(s) == tone) &&
                (!favoritesOnly || favorites.contains(s.id)) &&
                normalized(
                  '${s.name} ${s.category} ${s.pattern}',
                ).contains(normalized(query)),
          )
          .toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (snapshot.connectionState != ConnectionState.done)
            const LinearProgressIndicator(),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Tìm French, mắt mèo, hoa, nude...',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: categories
                .map(
                  (c) => ChoiceChip(
                    label: Text(c),
                    selected: category == c,
                    onSelected: (_) => setState(() => category = c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: tone,
                items:
                    const [
                          'Tất cả màu',
                          'Đỏ / Hồng',
                          'Tím / Hồng',
                          'Xanh dương',
                          'Xanh lá',
                          'Nude / Vàng',
                          'Trung tính',
                        ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (value) => setState(() => tone = value!),
              ),
              FilterChip(
                label: const Text('Yêu thích'),
                avatar: const Icon(Icons.favorite_border, size: 18),
                selected: favoritesOnly,
                onSelected: (value) => setState(() => favoritesOnly = value),
              ),
              Text('${shown.length} bộ mẫu'),
            ],
          ),
          if (snapshot.data?.message != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    snapshot.data!.message!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Tải lại kho mẫu',
                  onPressed: () =>
                      setState(() => catalog = NailCatalogApi.load()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Chưa có mẫu phù hợp. Hãy thử từ khóa hoặc bộ lọc khác.',
              ),
            ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 3 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 240,
            ),
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final set = shown[index];
              return Semantics(
                button: true,
                selected: widget.selectedId == set.id,
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: widget.selectedId == set.id
                          ? Colors.pink
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => widget.onSelect(set),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: List.generate(
                                5,
                                (finger) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: SizedBox(
                                      height: finger == 4
                                          ? 65
                                          : (finger == 2 ? 100 : 85),
                                      child: NailArtwork(
                                        set: set,
                                        finger: finger,
                                        preview: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            set.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            set.category,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Chọn bộ mẫu',
                                  style: TextStyle(color: Colors.pink),
                                ),
                              ),
                              IconButton(
                                tooltip: favorites.contains(set.id)
                                    ? 'Bỏ yêu thích'
                                    : 'Thêm yêu thích',
                                onPressed: () => toggleFavorite(set.id),
                                icon: Icon(
                                  favorites.contains(set.id)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.pink,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    },
  );
}
