import 'package:flutter/material.dart';
import 'package:boanerges1714/config/theme.dart';
import 'package:boanerges1714/models/content_block.dart';

class ContentBlockEditor extends StatelessWidget {
  final List<ContentBlock> blocks;
  final ValueChanged<List<ContentBlock>> onChanged;
  final Future<String?> Function() onUploadImage;

  const ContentBlockEditor({
    required this.blocks,
    required this.onChanged,
    required this.onUploadImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Wrap(
              spacing: 4,
              children: [
                _ToolbarBtn(
                    icon: Icons.text_fields,
                    tooltip: 'Párrafo',
                    onTap: () => _addBlock('paragraph')),
                _ToolbarBtn(
                    icon: Icons.title,
                    tooltip: 'Título',
                    onTap: () => _addBlock('heading')),
                _ToolbarBtn(
                    icon: Icons.format_list_bulleted,
                    tooltip: 'Lista',
                    onTap: () => _addBlock('list')),
                _ToolbarBtn(
                    icon: Icons.format_quote,
                    tooltip: 'Cita',
                    onTap: () => _addBlock('quote')),
                _ToolbarBtn(
                    icon: Icons.image,
                    tooltip: 'Subir imagen al contenido',
                    onTap: () => _addImageBlock()),
                _ToolbarBtn(
                    icon: Icons.horizontal_rule,
                    tooltip: 'Separador',
                    onTap: () => _addBlock('divider')),
                _ToolbarBtn(
                    icon: Icons.highlight,
                    tooltip: 'Bloque destacado',
                    onTap: () => _addBlock('highlight')),
              ],
            ),
          ),

          // Blocks
          if (blocks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Usa la barra de herramientas para añadir bloques de contenido.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: blocks.length,
            onReorder: (oldIndex, newIndex) {
              final updated = List<ContentBlock>.from(blocks);
              if (oldIndex < newIndex) newIndex--;
              final item = updated.removeAt(oldIndex);
              updated.insert(newIndex, item);
              onChanged(updated);
            },
            itemBuilder: (context, index) {
              final block = blocks[index];
              return _ContentBlockEditor(
                key: ValueKey('block_$index'),
                block: block,
                index: index,
                onChanged: (updated) {
                  final list = List<ContentBlock>.from(blocks);
                  list[index] = updated;
                  onChanged(list);
                },
                onDelete: () {
                  final list = List<ContentBlock>.from(blocks);
                  list.removeAt(index);
                  onChanged(list);
                },
                onUploadImage: onUploadImage,
              );
            },
          ),
        ],
      ),
    );
  }

  void _addBlock(String type) {
    final updated = List<ContentBlock>.from(blocks);
    updated.add(ContentBlock(type: type));
    onChanged(updated);
  }

  Future<void> _addImageBlock() async {
    final url = await onUploadImage();
    if (url != null && url.isNotEmpty) {
      final updated = List<ContentBlock>.from(blocks);
      updated.add(ContentBlock(type: 'image', imageUrl: url));
      onChanged(updated);
    }
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolbarBtn(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _ContentBlockEditor extends StatelessWidget {
  final ContentBlock block;
  final int index;
  final ValueChanged<ContentBlock> onChanged;
  final VoidCallback onDelete;
  final Future<String?> Function() onUploadImage;

  const _ContentBlockEditor({
    super.key,
    required this.block,
    required this.index,
    required this.onChanged,
    required this.onDelete,
    required this.onUploadImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(top: 8, right: 4),
              child: Icon(Icons.drag_handle, size: 18, color: Colors.grey),
            ),
          ),
          Expanded(child: _buildEditor()),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    switch (block.type) {
      case 'heading':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Título',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const Spacer(),
                DropdownButton<int>(
                  value: block.level,
                  underline: const SizedBox(),
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('H1')),
                    DropdownMenuItem(value: 2, child: Text('H2')),
                    DropdownMenuItem(value: 3, child: Text('H3')),
                  ],
                  onChanged: (v) => onChanged(ContentBlock(
                      type: 'heading', text: block.text, level: v ?? 1)),
                ),
              ],
            ),
            TextField(
              controller: TextEditingController(text: block.text),
              decoration:
                  const InputDecoration(hintText: 'Texto del título...'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: block.level == 1
                    ? 22
                    : block.level == 2
                        ? 18
                        : 15,
              ),
              onChanged: (v) => onChanged(
                  ContentBlock(type: 'heading', text: v, level: block.level)),
            ),
          ],
        );

      case 'list':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lista',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            TextField(
              controller: TextEditingController(text: block.items.join('\n')),
              decoration: const InputDecoration(
                hintText: 'Un elemento por línea...',
              ),
              maxLines: 5,
              onChanged: (v) => onChanged(ContentBlock(
                type: 'list',
                items: v.split('\n').where((l) => l.isNotEmpty).toList(),
              )),
            ),
          ],
        );

      case 'quote':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cita',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            TextField(
              controller: TextEditingController(text: block.text),
              decoration: const InputDecoration(
                hintText: 'Texto de la cita...',
              ),
              maxLines: 3,
              style: const TextStyle(fontStyle: FontStyle.italic),
              onChanged: (v) => onChanged(ContentBlock(type: 'quote', text: v)),
            ),
          ],
        );

      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Imagen del contenido',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            if ((block.imageUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  block.imageUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Text(
                      'Error cargando imagen',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 16),
                    label: const Text('Reemplazar',
                        style: TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final url = await onUploadImage();
                      if (url != null && url.isNotEmpty) {
                        onChanged(ContentBlock(type: 'image', imageUrl: url));
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    label: const Text('Quitar',
                        style: TextStyle(fontSize: 12, color: Colors.red)),
                    onPressed: () =>
                        onChanged(ContentBlock(type: 'image', imageUrl: '')),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Subir imagen al contenido'),
                onPressed: () async {
                  final url = await onUploadImage();
                  if (url != null && url.isNotEmpty) {
                    onChanged(ContentBlock(type: 'image', imageUrl: url));
                  }
                },
              ),
            ],
          ],
        );

      case 'divider':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(),
        );

      case 'highlight':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bloque destacado',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(color: AppTheme.primaryColor, width: 3),
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: TextEditingController(text: block.text),
                decoration: const InputDecoration(
                  hintText: 'Texto destacado...',
                  border: InputBorder.none,
                ),
                maxLines: 3,
                onChanged: (v) =>
                    onChanged(ContentBlock(type: 'highlight', text: v)),
              ),
            ),
          ],
        );

      default: // paragraph
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Párrafo',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            TextField(
              controller: TextEditingController(text: block.text),
              decoration: const InputDecoration(
                hintText: 'Escribe aquí...',
              ),
              maxLines: 4,
              onChanged: (v) =>
                  onChanged(ContentBlock(type: 'paragraph', text: v)),
            ),
          ],
        );
    }
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================
