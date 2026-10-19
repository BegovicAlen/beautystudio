import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'form_support.dart';
import 'services/beauty_studio_api.dart';

class ContentEditorPage extends StatefulWidget {
  const ContentEditorPage({super.key, required this.token});
  final String token;
  @override
  State<ContentEditorPage> createState() => _ContentEditorPageState();
}

class _ContentEditorPageState extends State<ContentEditorPage> {
  late Future<_ContentData> data;
  String search = '';
  int? filterCategory;
  Timer? debounce;
  @override
  void initState() {
    super.initState();
    data = load();
  }

  @override
  void dispose() {
    debounce?.cancel();
    super.dispose();
  }

  Future<_ContentData> load() async {
    final results = await Future.wait<Object>([
      BeautyStudioApi.managedGallery(
        widget.token,
        search: search,
        categoryId: filterCategory,
      ),
      BeautyStudioApi.managedBlogPosts(
        widget.token,
        search: search,
        categoryId: filterCategory,
      ),
      BeautyStudioApi.managedCategories(widget.token),
    ]);
    return _ContentData(
      results[0] as List<ManagedGalleryContentItem>,
      results[1] as List<ManagedBlogContentItem>,
      results[2] as List<ManagedServiceCategory>,
    );
  }

  Future<void> reload() async {
    if (mounted) {
      setState(() {
        data = load();
      });
    }
    await data;
  }

  Future<void> editor({
    ManagedGalleryContentItem? gallery,
    ManagedBlogContentItem? blog,
    bool isBlog = false,
  }) async {
    final current = await data;
    final categories = current.categories.where((x) => x.isActive).toList();
    if (categories.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prvo dodajte aktivnu kategoriju u katalogu.'),
          ),
        );
      }
      return;
    }
    if (blog != null) {
      blog = await BeautyStudioApi.managedBlog(widget.token, blog.id);
    }
    if (!mounted) return;
    final title = TextEditingController(
      text: isBlog ? blog?.title : gallery?.title,
    );
    final content = TextEditingController(text: blog?.content);
    final description = TextEditingController(text: gallery?.description);
    final image = TextEditingController(
      text: isBlog ? blog?.imageUrl : gallery?.imageUrl,
    );
    var category = isBlog ? blog?.categoryId : gallery?.categoryId;
    if (!categories.any((x) => x.id == category)) {
      category = categories.first.id;
    }
    var active = isBlog ? blog?.isPublished ?? true : gallery?.isActive ?? true;
    List<int>? bytes;
    String? filename;
    final save = await showCompletedDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => FormDialog(
          title: isBlog ? 'Blog članak' : 'Rad u galeriji',
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    validator: (v) => Validators.requiredText(v, max: 150),
                    decoration: const InputDecoration(labelText: 'Naslov'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: category,
                    validator: (v) =>
                        v == null ? 'Odaberite kategoriju.' : null,
                    items: categories
                        .map(
                          (x) => DropdownMenuItem(
                            value: x.id,
                            child: Text(x.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setDialog(() => category = v),
                    decoration: const InputDecoration(labelText: 'Kategorija'),
                  ),
                  if (!isBlog)
                    TextFormField(
                      controller: description,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: 3000,
                      validator: (v) => (v?.trim().length ?? 0) > 3000
                          ? 'Opis može imati najviše 3000 znakova.'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Opis slike',
                      ),
                    ),
                  if (isBlog)
                    TextFormField(
                      controller: content,
                      maxLines: 8,
                      validator: (v) => Validators.requiredText(v, max: 10000),
                      decoration: const InputDecoration(
                        labelText: 'Tekst članka',
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final file = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        withData: true,
                      );
                      if (file?.files.single.bytes != null) {
                        setDialog(() {
                          bytes = file!.files.single.bytes;
                          filename = file.files.single.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.image),
                    label: Text(filename ?? 'Odaberite sliku'),
                  ),
                  TextFormField(
                    controller: image,
                    validator: (v) {
                      if (bytes != null) return null;
                      if ((v ?? '').trim().isEmpty) {
                        return 'Odaberite sliku ili unesite URL.';
                      }
                      return v!.startsWith('/uploads/') ||
                              Uri.tryParse(v)?.hasScheme == true
                          ? null
                          : 'Unesite validan URL slike.';
                    },
                    decoration: const InputDecoration(
                      labelText: 'URL slike ili postojeća slika',
                    ),
                  ),
                  SwitchListTile(
                    title: Text(isBlog ? 'Objavljeno' : 'Vidljivo u galeriji'),
                    value: active,
                    onChanged: (v) => setDialog(() => active = v),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (save == true) {
      try {
        final url = bytes == null
            ? image.text.trim()
            : await BeautyStudioApi.uploadContentImage(
                widget.token,
                bytes: bytes!,
                fileName: filename!,
              );
        if (isBlog) {
          if (blog == null) {
            await BeautyStudioApi.createBlogPost(
              widget.token,
              title: title.text.trim(),
              content: content.text.trim(),
              imageUrl: url,
              isPublished: active,
              categoryId: category!,
            );
          } else {
            await BeautyStudioApi.updateBlogPost(
              widget.token,
              blog.id,
              title: title.text.trim(),
              content: content.text.trim(),
              imageUrl: url,
              isPublished: active,
              categoryId: category!,
            );
          }
        } else {
          if (gallery == null) {
            await BeautyStudioApi.createGalleryItem(
              widget.token,
              title: title.text.trim(),
              description: description.text.trim(),
              imageUrl: url,
              isActive: active,
              categoryId: category!,
            );
          } else {
            await BeautyStudioApi.updateGalleryItem(
              widget.token,
              gallery.id,
              title: title.text.trim(),
              description: description.text.trim(),
              imageUrl: url,
              isActive: active,
              categoryId: category!,
            );
          }
        }
        await reload();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sadržaj je sačuvan.')));
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    title.dispose();
    content.dispose();
    description.dispose();
    image.dispose();
  }

  Widget thumbnail(String? url) => url == null
      ? const Icon(Icons.image)
      : ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            BeautyStudioApi.contentImageUrl(url),
            width: 60,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) =>
                const Icon(Icons.image_not_supported),
          ),
        );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Upravljanje sadržajem'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Galerija'),
            Tab(text: 'Blog'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) {
                search = v;
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 300), reload);
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Pretražite naslov',
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<_ContentData>(
              future: data,
              builder: (context, s) {
                if (s.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (s.hasError) {
                  return Center(
                    child: TextButton(
                      onPressed: reload,
                      child: Text(s.error.toString()),
                    ),
                  );
                }
                final d = s.data!;
                Widget panel(bool blog) => Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: filterCategory,
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('Sve kategorije'),
                                ),
                                ...d.categories.map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(c.name),
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                filterCategory = v;
                                reload();
                              },
                              decoration: const InputDecoration(
                                labelText: 'Filtrirajte kategoriju',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: d.categories.any((x) => x.isActive)
                                ? () => editor(isBlog: blog)
                                : null,
                            icon: const Icon(Icons.add),
                            label: const Text('Dodajte'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            dataRowMinHeight: 64,
                            dataRowMaxHeight: 72,
                            columns: const [
                              DataColumn(label: Text('Slika')),
                              DataColumn(label: Text('Naslov')),
                              DataColumn(label: Text('Kategorija')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Uređivanje')),
                            ],
                            rows: blog
                                ? d.blog
                                      .map(
                                        (x) => DataRow(
                                          cells: [
                                            DataCell(thumbnail(x.imageUrl)),
                                            DataCell(Text(x.title)),
                                            DataCell(Text(x.categoryName)),
                                            DataCell(
                                              Text(
                                                x.isPublished
                                                    ? 'Objavljeno'
                                                    : 'Skriveno',
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                tooltip:
                                                    'Uredite ili deaktivirajte',
                                                onPressed: () => editor(
                                                  blog: x,
                                                  isBlog: true,
                                                ),
                                                icon: const Icon(Icons.edit),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList()
                                : d.gallery
                                      .map(
                                        (x) => DataRow(
                                          cells: [
                                            DataCell(thumbnail(x.imageUrl)),
                                            DataCell(Text(x.title)),
                                            DataCell(Text(x.category)),
                                            DataCell(
                                              Text(
                                                x.isActive
                                                    ? 'Vidljivo'
                                                    : 'Skriveno',
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                tooltip:
                                                    'Uredite ili deaktivirajte',
                                                onPressed: () =>
                                                    editor(gallery: x),
                                                icon: const Icon(Icons.edit),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
                return TabBarView(children: [panel(false), panel(true)]);
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContentData {
  const _ContentData(this.gallery, this.blog, this.categories);
  final List<ManagedGalleryContentItem> gallery;
  final List<ManagedBlogContentItem> blog;
  final List<ManagedServiceCategory> categories;
}
