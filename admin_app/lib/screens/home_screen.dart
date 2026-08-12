import 'package:image_picker/image_picker.dart';
import '../services/github_service.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/menu_models.dart';
import '../widgets/remote_image.dart';
import '../services/menu_repository.dart';
import '../services/app_settings.dart';
import 'setup_screen.dart';
import 'product_form_screen.dart';
import 'settings_screen.dart';
import 'restaurant_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  final Set<String> _expandedCategories = <String>{};

  final MenuRepository repo = RemoteMenuRepository();

  MenuData? menu;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final configured = await AppSettings.isConfigured();

    if (!mounted) return;

    if (!configured) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const SetupScreen(),
        ),
      );

      if (!mounted) return;

      if (result == true) {
        _load();
      } else {
        setState(() {
          loading = false;
          error = 'برنامه هنوز راه‌اندازی نشده است.';
        });
      }

      return;
    }

    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await repo.load();

      if (!mounted) return;

      setState(() {
        menu = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _addProduct() async {
    final currentMenu = menu;
    if (currentMenu == null || currentMenu.categories.isEmpty) {
      _showMessage('ابتدا حداقل یک دسته ایجاد کنید.');
      return;
    }

    final result = await Navigator.push<ProductFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          categories: currentMenu.categories,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final category = currentMenu.categories.firstWhere(
      (c) => c.id == result.categoryId,
    );

    setState(() {
      category.items.add(result.item);
    });

    try {
      await repo.save(currentMenu);
      _showMessage('محصول به «${category.name}» اضافه و در GitHub ذخیره شد.');
    } catch (e) {
      _showMessage('محصول اضافه شد ولی ذخیره در GitHub ناموفق بود: $e');
    }
  }

  Future<void> _editProduct(
    MenuCategory category,
    int index,
  ) async {
    final currentMenu = menu;
    if (currentMenu == null) return;

    final oldItem = category.items[index];

    final result = await Navigator.push<ProductFormResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          item: oldItem,
          initialCategoryId: category.id,
          categories: currentMenu.categories,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      category.items.removeAt(index);

      final targetCategory = currentMenu.categories.firstWhere(
        (c) => c.id == result.categoryId,
      );

      targetCategory.items.add(result.item);
    });

    try {
      await repo.save(currentMenu);
      _showMessage('محصول ویرایش و در GitHub ذخیره شد.');
    } catch (e) {
      _showMessage('تغییر اعمال شد ولی ذخیره در GitHub ناموفق بود: $e');
    }
  }

  Future<void> _deleteProduct(
    MenuCategory category,
    int index,
  ) async {
    final item = category.items[index];

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف محصول'),
        content: Text(
          'آیا محصول «${item.name}» حذف شود؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() {
      category.items.removeAt(index);
    });

    final currentMenu = menu;
    if (currentMenu == null) return;

    try {
      await repo.save(currentMenu);
      _showMessage('محصول حذف و در GitHub ذخیره شد.');
    } catch (e) {
      _showMessage('محصول حذف شد ولی ذخیره در GitHub ناموفق بود: $e');
    }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CategoryDialog(
        title: 'افزودن دسته',
        confirmText: 'ایجاد دسته',
      ),
    );

    if (result == null || !mounted || menu == null) return;

    final id = result['id']!.trim();
    final name = result['name']!.trim();
    final image = result['image']?.trim() ?? '';

    if (menu!.categories.any((c) => c.id == id)) {
      _showMessage('این شناسه دسته قبلاً وجود دارد.');
      return;
    }

    setState(() {
      menu!.categories.add(
        MenuCategory(
          id: id,
          name: name,
          image: image,
          items: [],
        ),
      );
    });

    try {
      await repo.save(menu!);
      _showMessage('دسته «$name» ایجاد و در GitHub ذخیره شد.');
    } catch (e) {
      _showMessage('دسته ایجاد شد ولی ذخیره در GitHub ناموفق بود: $e');
    }
  }

  Future<void> _editCategory(MenuCategory category) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _CategoryDialog(
        title: 'ویرایش دسته',
        confirmText: 'ذخیره',
        initialId: category.id,
        initialName: category.name,
        initialImage: category.image,
        allowIdEdit: false,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      category.name = result['name']!.trim();
      category.image = result['image']?.trim() ?? '';
    });

    try {
      await repo.save(menu!);
      _showMessage('دسته ویرایش و در GitHub ذخیره شد.');
    } catch (e) {
      _showMessage('تغییر اعمال شد ولی ذخیره در GitHub ناموفق بود: $e');
    }
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    final currentMenu = menu;
    if (currentMenu == null) return;

    String message;

    if (category.items.isEmpty) {
      message =
          'دسته «${category.name}» خالی است.\nآیا حذف شود؟';
    } else {
      message =
          'دسته «${category.name}» شامل ${category.items.length} محصول است.\n'
          'با حذف دسته، محصولات آن نیز از منوی فعلی حذف می‌شوند.\n\n'
          'آیا مطمئن هستید؟';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف دسته'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    setState(() {
      currentMenu.categories.remove(category);
    });

    try {
      await repo.save(currentMenu);
      _showMessage('دسته حذف و در GitHub ذخیره شد.');
    } catch (e) {
      _showMessage('دسته حذف شد ولی ذخیره در GitHub ناموفق بود: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String _formatPrice(int price) {
    final value = price.toString();
    final buffer = StringBuffer();

    for (var i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(value[i]);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('مدیریت منو'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'خطا در بارگذاری منو',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentMenu = menu!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت منو'),
        actions: [
          IconButton(
            tooltip: 'تنظیمات',
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );

              if (changed == true && mounted) {
                await _load();
              }
            },
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: 'اطلاعات رستوران',
            onPressed: () async {
              final currentMenu = menu;
              if (currentMenu == null) return;

              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => RestaurantSettingsScreen(
                    menu: currentMenu,
                    repository: repo,
                  ),
                ),
              );

              if (result == true && mounted) {
                await _load();
              }
            },
            icon: const Icon(Icons.restaurant),
          ),
          IconButton(
            tooltip: 'بارگذاری مجدد',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('محصول جدید'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 110),
          children: [
            _buildRestaurantCard(currentMenu.restaurant),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'دسته‌بندی‌ها',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('دسته جدید'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (currentMenu.categories.isEmpty)
              _buildEmptyCategories()
            else
              ...currentMenu.categories.map(
                (category) => _buildCategory(category),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: restaurant.logo.trim().isNotEmpty
                  ? ClipOval(
                      child: RemoteImage(
                        path: restaurant.logo,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        error: const Icon(Icons.restaurant),
                      ),
                    )
                  : const Icon(Icons.restaurant),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (restaurant.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategories() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(
              Icons.category_outlined,
              size: 56,
            ),
            const SizedBox(height: 12),
            const Text(
              'هنوز دسته‌ای وجود ندارد.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add),
              label: const Text('افزودن دسته'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(MenuCategory category) {
    final expanded = _expandedCategories.contains(category.id);

    return Card(
      key: PageStorageKey<String>('category_${category.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: PageStorageKey<String>(
          'expansion_${category.id}',
        ),
        initiallyExpanded: expanded,
        onExpansionChanged: (value) {
          setState(() {
            if (value) {
              _expandedCategories.add(category.id);
            } else {
              _expandedCategories.remove(category.id);
            }
          });
        },
        title: Row(
          children: [
            if (category.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: RemoteImage(
                  path: category.image,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  error: const Icon(
                    Icons.category_outlined,
                    size: 40,
                  ),
                ),
              )
            else
              const SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  Icons.category_outlined,
                  size: 32,
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                category.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          '${category.items.length} محصول',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editCategory(category);
            } else if (value == 'delete') {
              _deleteCategory(category);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('ویرایش دسته'),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('حذف دسته'),
              ),
            ),
          ],
        ),
        children: [
          if (category.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('این دسته محصولی ندارد.'),
            )
          else
            ...List.generate(
              category.items.length,
              (index) => _buildProductTile(
                category,
                index,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductTile(
    MenuCategory category,
    int index,
  ) {
    final item = category.items[index];

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      leading: item.image.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RemoteImage(
                path: item.image,
                width: 58,
                height: 58,
                fit: BoxFit.cover,
                error: CircleAvatar(
                  child: Icon(
                    item.available
                        ? Icons.fastfood
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            )
          : CircleAvatar(
              child: Icon(
                item.available
                    ? Icons.fastfood
                    : Icons.visibility_off_outlined,
              ),
            ),
      title: Text(
        item.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: item.available
              ? null
              : TextDecoration.lineThrough,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                '${_formatPrice(item.price)} تومان',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.oldPrice != null) ...[
                const SizedBox(width: 8),
                Text(
                  '${_formatPrice(item.oldPrice!)} تومان',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') {
            _editProduct(category, index);
          } else if (value == 'delete') {
            _deleteProduct(category, index);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('ویرایش'),
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('حذف'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  final String title;
  final String confirmText;
  final String initialId;
  final String initialName;
  final String initialImage;
  final bool allowIdEdit;

  const _CategoryDialog({
    required this.title,
    required this.confirmText,
    this.initialId = '',
    this.initialName = '',
    this.initialImage = '',
    this.allowIdEdit = true,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController idController;
  late final TextEditingController nameController;

  final ImagePicker picker = ImagePicker();

  XFile? selectedImage;
  late String imagePath;

  bool uploading = false;

  @override
  void initState() {
    super.initState();

    idController = TextEditingController(
      text: widget.initialId,
    );

    nameController = TextEditingController(
      text: widget.initialName,
    );

    imagePath = widget.initialImage;
  }

  @override
  void dispose() {
    idController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    try {
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (image == null) return;

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('انتخاب عکس ناموفق بود:\n$e'),
        ),
      );
    }
  }

  Future<String> uploadImage() async {
    if (selectedImage == null) {
      return imagePath;
    }

    setState(() {
      uploading = true;
    });

    try {
      final bytes = await selectedImage!.readAsBytes();

      final id = idController.text.trim();

      final extension = selectedImage!.name.contains('.')
          ? selectedImage!.name.split('.').last.toLowerCase()
          : 'jpg';

      final fileName = 'category_$id.$extension';

      return await GitHubService.uploadImage(
        fileName: fileName,
        bytes: bytes,
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  Future<void> submit() async {
    final id = idController.text.trim();
    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نام دسته را وارد کنید'),
        ),
      );
      return;
    }

    if (widget.allowIdEdit && id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('شناسه دسته را وارد کنید'),
        ),
      );
      return;
    }

    setState(() {
      uploading = true;
    });

    try {
      final finalImage = await uploadImage();

      if (!mounted) return;

      Navigator.pop(
        context,
        {
          'id': id,
          'name': name,
          'image': finalImage,
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('آپلود عکس ناموفق بود:\n$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
        });
      }
    }
  }

  Widget imagePreview() {
    if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(selectedImage!.path),
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: RemoteImage(
          path: imagePath,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          error: const Icon(
            Icons.broken_image,
            size: 48,
          ),
        ),
      );
    }

    return Container(
      height: 130,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'نام دسته',
                hintText: 'مثلاً پیتزا',
                border: OutlineInputBorder(),
              ),
            ),

            if (widget.allowIdEdit) ...[
              const SizedBox(height: 14),

              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'شناسه دسته',
                  hintText: 'مثلاً pizza',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 18),

            imagePreview(),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: uploading ? null : pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('انتخاب عکس دسته'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: uploading
              ? null
              : () => Navigator.pop(context),
          child: const Text('لغو'),
        ),
        FilledButton(
          onPressed: uploading ? null : submit,
          child: Text(
            uploading
                ? 'در حال آپلود...'
                : widget.confirmText,
          ),
        ),
      ],
    );
  }
}
