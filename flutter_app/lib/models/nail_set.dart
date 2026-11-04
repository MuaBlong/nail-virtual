import 'package:flutter/material.dart';

const fingerOrder = ['thumb', 'index', 'middle', 'ring', 'pinky'];

class NailSet {
  final String id;
  final String name;
  final List<String> images;
  final String category;
  final String pattern;
  final List<Color> palette;

  const NailSet({
    required this.id,
    required this.name,
    this.images = const [],
    this.category = 'Bộ mẫu',
    this.pattern = 'solid',
    this.palette = const [Color(0xFFE9A3B6)],
  });

  factory NailSet.fromJson(Map<String, dynamic> json) {
    final designs = json['designs'];
    final images = designs is Map
        ? fingerOrder
              .map((finger) => designs[finger]?.toString() ?? '')
              .toList()
        : (json['images'] as List? ?? []).map((e) => e.toString()).toList();
    final plain =
        images.isEmpty &&
        json['pattern'] == 'solid' &&
        json['palette'] is List &&
        (json['palette'] as List).isNotEmpty;
    if (!plain && (images.length != 5 || images.any((p) => p.isEmpty))) {
      throw const FormatException('Bộ mẫu phải có đủ ảnh cho 5 ngón');
    }
    return NailSet(
      id: json['id'].toString(),
      name: json['name'].toString(),
      category: json['category']?.toString() ?? 'Bộ mẫu',
      images: images,
      pattern: json['pattern']?.toString() ?? 'solid',
      palette: json['palette'] is List && (json['palette'] as List).isNotEmpty
          ? (json['palette'] as List)
                .map((value) => Color(value as int))
                .toList()
          : const [Color(0xFFE9A3B6)],
    );
  }
}

const List<NailSet> nailSets = [
  NailSet(
    id: 'plain_jelly_pink',
    name: 'Hồng thạch',
    category: 'Màu trơn',
    palette: [Color(0xFFE7B5C5)],
  ),
  NailSet(
    id: 'plain_milk_pink',
    name: 'Hồng sữa',
    category: 'Màu trơn',
    palette: [Color(0xFFF2D4DE)],
  ),
  NailSet(
    id: 'plain_peach_nude',
    name: 'Nude đào',
    category: 'Màu trơn',
    palette: [Color(0xFFE1B49E)],
  ),
  NailSet(
    id: 'plain_milk_white',
    name: 'Trắng sữa',
    category: 'Màu trơn',
    palette: [Color(0xFFF2EBDE)],
  ),
  NailSet(
    id: 'plain_cream',
    name: 'Kem vanilla',
    category: 'Màu trơn',
    palette: [Color(0xFFE9D8B5)],
  ),
  NailSet(
    id: 'plain_rose',
    name: 'Hồng đất',
    category: 'Màu trơn',
    palette: [Color(0xFFC4828D)],
  ),
  NailSet(
    id: 'plain_red',
    name: 'Đỏ cherry',
    category: 'Màu trơn',
    palette: [Color(0xFFB82B43)],
  ),
  NailSet(
    id: 'plain_wine',
    name: 'Đỏ rượu',
    category: 'Màu trơn',
    palette: [Color(0xFF76243B)],
  ),
  NailSet(
    id: 'plain_coral',
    name: 'Cam san hô',
    category: 'Màu trơn',
    palette: [Color(0xFFEB917E)],
  ),
  NailSet(
    id: 'plain_butter',
    name: 'Vàng bơ',
    category: 'Màu trơn',
    palette: [Color(0xFFE9D695)],
  ),
  NailSet(
    id: 'plain_sage',
    name: 'Xanh sage',
    category: 'Màu trơn',
    palette: [Color(0xFF9EBBA8)],
  ),
  NailSet(
    id: 'plain_mint',
    name: 'Xanh mint',
    category: 'Màu trơn',
    palette: [Color(0xFFB6DAD0)],
  ),
  NailSet(
    id: 'plain_sky',
    name: 'Xanh baby',
    category: 'Màu trơn',
    palette: [Color(0xFFB8D5ED)],
  ),
  NailSet(
    id: 'plain_navy',
    name: 'Xanh navy',
    category: 'Màu trơn',
    palette: [Color(0xFF344B72)],
  ),
  NailSet(
    id: 'plain_lavender',
    name: 'Tím lavender',
    category: 'Màu trơn',
    palette: [Color(0xFFC8B6DC)],
  ),
  NailSet(
    id: 'plain_lilac',
    name: 'Tím lilac',
    category: 'Màu trơn',
    palette: [Color(0xFFE0CEEA)],
  ),
  NailSet(
    id: 'plain_mocha',
    name: 'Nâu mocha',
    category: 'Màu trơn',
    palette: [Color(0xFF9E7868)],
  ),
  NailSet(
    id: 'plain_cocoa',
    name: 'Nâu cacao',
    category: 'Màu trơn',
    palette: [Color(0xFF694C44)],
  ),
  NailSet(
    id: 'plain_black',
    name: 'Đen bóng',
    category: 'Màu trơn',
    palette: [Color(0xFF28242C)],
  ),
  NailSet(
    id: 'plain_grey',
    name: 'Xám khói',
    category: 'Màu trơn',
    palette: [Color(0xFFA6ABB4)],
  ),
  NailSet(
    id: 'crystal_blush',
    name: 'Hồng thạch đính đá',
    category: 'Đính đá',
    palette: [Color(0xFFE8A9BC)],
    images: [
      'assets/nails/prepared/crystal_blush_0.png',
      'assets/nails/prepared/crystal_blush_1.png',
      'assets/nails/prepared/crystal_blush_2.png',
      'assets/nails/prepared/crystal_blush_3.png',
      'assets/nails/prepared/crystal_blush_4.png',
    ],
  ),
  NailSet(
    id: 'pearl_bride',
    name: 'Ngọc trai cô dâu',
    category: 'Ngọc trai & nơ',
    palette: [Color(0xFFEAD9CB)],
    images: [
      'assets/nails/prepared/pearl_bride_0.png',
      'assets/nails/prepared/pearl_bride_1.png',
      'assets/nails/prepared/pearl_bride_2.png',
      'assets/nails/prepared/pearl_bride_3.png',
      'assets/nails/prepared/pearl_bride_4.png',
    ],
  ),
  NailSet(
    id: 'lavender_blossom',
    name: 'Hoa nổi lavender',
    category: 'Hoa nổi 3D',
    palette: [Color(0xFFC9A9DF)],
    images: [
      'assets/nails/prepared/lavender_blossom_0.png',
      'assets/nails/prepared/lavender_blossom_1.png',
      'assets/nails/prepared/lavender_blossom_2.png',
      'assets/nails/prepared/lavender_blossom_3.png',
      'assets/nails/prepared/lavender_blossom_4.png',
    ],
  ),
  NailSet(
    id: 'cherry_stickers',
    name: 'Cherry ngọt ngào',
    category: 'Sticker',
    palette: [Color(0xFFEAA4A9)],
    images: [
      'assets/nails/prepared/cherry_stickers_0.png',
      'assets/nails/prepared/cherry_stickers_1.png',
      'assets/nails/prepared/cherry_stickers_2.png',
      'assets/nails/prepared/cherry_stickers_3.png',
      'assets/nails/prepared/cherry_stickers_4.png',
    ],
  ),
  NailSet(
    id: 'blue_butterfly',
    name: 'Bướm xanh pha lê',
    category: 'Sticker',
    palette: [Color(0xFFA3CCE6)],
    images: [
      'assets/nails/prepared/blue_butterfly_0.png',
      'assets/nails/prepared/blue_butterfly_1.png',
      'assets/nails/prepared/blue_butterfly_2.png',
      'assets/nails/prepared/blue_butterfly_3.png',
      'assets/nails/prepared/blue_butterfly_4.png',
    ],
  ),
  NailSet(
    id: 'rose_bow',
    name: 'Nơ hồng jelly',
    category: 'Ngọc trai & nơ',
    palette: [Color(0xFFE9A3B6)],
    images: [
      'assets/nails/prepared/rose_bow_0.png',
      'assets/nails/prepared/rose_bow_1.png',
      'assets/nails/prepared/rose_bow_2.png',
      'assets/nails/prepared/rose_bow_3.png',
      'assets/nails/prepared/rose_bow_4.png',
    ],
  ),
  NailSet(
    id: 'champagne_crystal',
    name: 'Champagne lấp lánh',
    category: 'Đính đá',
    palette: [Color(0xFFD7BF91)],
    images: [
      'assets/nails/prepared/champagne_crystal_0.png',
      'assets/nails/prepared/champagne_crystal_1.png',
      'assets/nails/prepared/champagne_crystal_2.png',
      'assets/nails/prepared/champagne_crystal_3.png',
      'assets/nails/prepared/champagne_crystal_4.png',
    ],
  ),
  NailSet(
    id: 'mermaid_shell',
    name: 'Vỏ sò ngọc ánh',
    category: 'Hoa nổi 3D',
    palette: [Color(0xFFACD7D5)],
    images: [
      'assets/nails/prepared/mermaid_shell_0.png',
      'assets/nails/prepared/mermaid_shell_1.png',
      'assets/nails/prepared/mermaid_shell_2.png',
      'assets/nails/prepared/mermaid_shell_3.png',
      'assets/nails/prepared/mermaid_shell_4.png',
    ],
  ),
  NailSet(
    id: 'milky_natural',
    name: 'Thạch nude tự nhiên',
    category: 'Tự nhiên',
    palette: [Color(0xFFE7C2B6)],
    images: [
      'assets/nails/prepared/milky_natural_0.png',
      'assets/nails/prepared/milky_natural_1.png',
      'assets/nails/prepared/milky_natural_2.png',
      'assets/nails/prepared/milky_natural_3.png',
      'assets/nails/prepared/milky_natural_4.png',
    ],
  ),
  NailSet(
    id: 'pastel_garden',
    name: 'Vườn hoa pastel',
    category: 'Hoa nổi 3D',
    palette: [Color(0xFFBBD5BF)],
    images: [
      'assets/nails/prepared/pastel_garden_0.png',
      'assets/nails/prepared/pastel_garden_1.png',
      'assets/nails/prepared/pastel_garden_2.png',
      'assets/nails/prepared/pastel_garden_3.png',
      'assets/nails/prepared/pastel_garden_4.png',
    ],
  ),
  NailSet(
    id: 'midnight_jewels',
    name: 'Pha lê đêm huyền',
    category: 'Đính đá',
    palette: [Color(0xFF5B1932)],
    images: [
      'assets/nails/prepared/midnight_jewels_0.png',
      'assets/nails/prepared/midnight_jewels_1.png',
      'assets/nails/prepared/midnight_jewels_2.png',
      'assets/nails/prepared/midnight_jewels_3.png',
      'assets/nails/prepared/midnight_jewels_4.png',
    ],
  ),
  NailSet(
    id: 'kawaii_charms',
    name: 'Gấu sữa dễ thương',
    category: 'Charm 3D',
    palette: [Color(0xFFD6B7A0)],
    images: [
      'assets/nails/prepared/kawaii_charms_0.png',
      'assets/nails/prepared/kawaii_charms_1.png',
      'assets/nails/prepared/kawaii_charms_2.png',
      'assets/nails/prepared/kawaii_charms_3.png',
      'assets/nails/prepared/kawaii_charms_4.png',
    ],
  ),
];
