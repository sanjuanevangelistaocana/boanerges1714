class ContentBlock {
  final String type;
  final String text;
  final int level;
  final String? imageUrl;
  final String? linkUrl;
  final bool bold;
  final bool italic;
  final List<String> items;

  const ContentBlock({
    this.type = 'paragraph',
    this.text = '',
    this.level = 1,
    this.imageUrl,
    this.linkUrl,
    this.bold = false,
    this.italic = false,
    this.items = const [],
  });

  factory ContentBlock.fromMap(Map<String, dynamic> map) {
    return ContentBlock(
      type: map['type'] ?? 'paragraph',
      text: map['text'] ?? '',
      level: (map['level'] as num?)?.toInt() ?? 1,
      imageUrl: map['imageUrl'],
      linkUrl: map['linkUrl'],
      bold: map['bold'] ?? false,
      italic: map['italic'] ?? false,
      items: ((map['items'] as List<dynamic>?) ?? [])
          .map((item) => '$item')
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'text': text,
      'level': level,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (linkUrl != null) 'linkUrl': linkUrl,
      if (bold) 'bold': bold,
      if (italic) 'italic': italic,
      if (items.isNotEmpty) 'items': items,
    };
  }
}
