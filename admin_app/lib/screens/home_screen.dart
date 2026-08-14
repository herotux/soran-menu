import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../models/menu_models.dart';
import '../services/app_settings.dart';
import '../services/github_service.dart';
import '../services/menu_repository.dart';
import '../services/menu_cache.dart';
import '../widgets/remote_image.dart';
import 'product_form_screen.dart';
import 'restaurant_settings_screen.dart';
import 'settings_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MenuRepository repo = RemoteMenuRepository();

  MenuData? menu;

  bool loading = true;
  String? error;

  String? _selectedCategoryId;

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
        await _load();
      } else {
        setState(() {
          loading = false;
          error = 'برنامه هنوز راه‌اندازی نشده است.';
        });
      }

      return;
    }

    await _load();
  }

  static const String _menuCacheKey = 'cached_menu_json';

  Future<MenuData?> _loadCachedMenu() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_menuCacheKey);

      if (cached == null || cached.trim().isEmpty) {
        return null;
      }

      final json = jsonDecode(cached) as Map<String, dynamic>;
      return MenuData.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveMenuCache(MenuData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _menuCacheKey,
        jsonEncode(data.toJson()),
      );
    } catch (_) {}
  }

  Future<void> _load() async {
    final cached = await MenuCache.load();

    if (cached != null && mounted) {
      String? selectedId = _selectedCategoryId;

      if (cached.categories.isNotEmpty) {
        final exists = cached.categories.any(
          (category) => category.id == selectedId,
        );

        if (!exists) {
          selectedId = cached.categories.first.id;
        }
      } else {
        selectedId = null;
      }

      setState(() {
        menu = cached;
        _selectedCategoryId = selectedId;
        loading = false;
        error = null;
      });
    } else if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final data = await repo.load();

      await MenuCache.save(data);

      if (!mounted) return;

      String? selectedId = _selectedCategoryId;

      if (data.categories.isNotEmpty) {
        final exists = data.categories.any(
          (category) => category.id == selectedId,
        );

        if (!exists) {
          selectedId = data.categories.first.id;
        }
      } else {
        selectedId = null;
      }

      setState(() {
        menu = data;
        _selectedCategoryId = selectedId;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (menu != null) {
        setState(() {
          loading = false;
          error = null;
        });

        _showMessage(
          'نسخه محلی منو نمایش داده شد؛ دریافت نسخه جدید ناموفق بود.',
        );
      } else {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
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
          initialCategoryId: _selectedCategoryId,
        ),
      ),
    );

    if (result == null || !mounted) return;

    final category = currentMenu.categories.firstWhere(
      (c) => c.id == result.categoryId,
    );

    setState(() {
      category.items.add(result.item);
      _selectedCategoryId = category.id;
    });

    try {
      await repo.save(currentMenu);
      await MenuCache.save(currentMenu);
      _showMessage(
        'محصول به «${category.name}» اضافه و در GitHub ذخیره شد.',
      );
    } catch (e) {
      _showMessage(
        'محصول اضافه شد ولی ذخیره در GitHub ناموفق بود: $e',
      );
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

      _selectedCategoryId = targetCategory.id;
    });

    try {
      await repo.save(currentMenu);
      await MenuCache.save(currentMenu);
      _showMessage('محصول ویرایش و در GitHub ذخیره شد.');
    } catch (e) {
      _showMessage(
        'تغییر اعمال شد ولی ذخیره در GitHub ناموفق بود: $e',
      );
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

    final currentMenu = menu;

    if (currentMenu == null) return;

    setState(() {
      category.items.removeAt(index);
    });

    try {
      await repo.save(currentMenu);
      await MenuCache.save(currentMenu);
      _showMessage('محصول حذف و در GitHub ذخیره شد.');
    } catch (e) {
      _showMessage(
        'محصول حذف شد ولی ذخیره در GitHub ناموفق بود: $e',
      );
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

      _selectedCategoryId = id;
    });

    try {
      await repo.save(menu!);
      await MenuCache.save(menu!);
      _showMessage(
        'دسته «$name» ایجاد و در GitHub ذخیره شد.',
      );
    } catch (e) {
      _showMessage(
        'دسته ایجاد شد ولی ذخیره در GitHub ناموفق بود: $e',
      );
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
      await MenuCache.save(menu!);
      _showMessage(
        'دسته ویرایش و در GitHub ذخیره شد.',
      );
    } catch (e) {
      _showMessage(
        'تغییر اعمال شد ولی ذخیره در GitHub ناموفق بود: $e',
      );
    }
  }

  Future<void> _deleteCategory(MenuCategory category) async {
    final currentMenu = menu;

    if (currentMenu == null) return;

    final message = category.items.isEmpty
        ? 'دسته «${category.name}» خالی است.\nآیا حذف شود؟'
        : 'دسته «${category.name}» شامل ${category.items.length} محصول است.\n'
            'با حذف دسته، محصولات آن نیز از منوی فعلی حذف می‌شوند.\n\n'
            'آیا مطمئن هستید؟';

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

      if (currentMenu.categories.isEmpty) {
        _selectedCategoryId = null;
      } else if (_selectedCategoryId == category.id) {
        _selectedCategoryId =
            currentMenu.categories.first.id;
      }
    });

    try {
      await repo.save(currentMenu);
      await MenuCache.save(currentMenu);
      _showMessage(
        'دسته حذف و در GitHub ذخیره شد.',
      );
    } catch (e) {
      _showMessage(
        'دسته حذف شد ولی ذخیره در GitHub ناموفق بود: $e',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
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

  MenuCategory? get _selectedCategory {
    final currentMenu = menu;

    if (currentMenu == null) return null;

    for (final category in currentMenu.categories) {
      if (category.id == _selectedCategoryId) {
        return category;
      }
    }

    return currentMenu.categories.isNotEmpty
        ? currentMenu.categories.first
        : null;
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
      return _buildErrorScreen();
    }

    final currentMenu = menu!;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildTopBar(),
              ),

              SliverToBoxAdapter(
                child: _buildRestaurantHeader(
                  currentMenu.restaurant,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildSectionTitle(),
              ),

              SliverToBoxAdapter(
                child: _buildCategorySelector(
                  currentMenu.categories,
                ),
              ),

              SliverToBoxAdapter(
                child: _buildProductsHeader(),
              ),

              if (_selectedCategory == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyMenu(),
                )
              else if (_selectedCategory!.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyProducts(
                    _selectedCategory!,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    110,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final category = _selectedCategory!;

                        return _buildProductCard(
                          category,
                          index,
                        );
                      },
                      childCount:
                          _selectedCategory!.items.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildAddProductButton(),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'مدیریت منو',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),

          _topActionButton(
            icon: Icons.refresh_rounded,
            tooltip: 'بارگذاری مجدد',
            onPressed: _load,
          ),

          const SizedBox(width: 6),

          _topActionButton(
            icon: Icons.settings_outlined,
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
          ),
        ],
      ),
    );
  }

  Widget _topActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: const Color(0xFF202124)),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader(Restaurant restaurant) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFF1F1F1),
            ),
            clipBehavior: Clip.antiAlias,
            child: restaurant.logo.trim().isNotEmpty
                ? RemoteImage(
                    path: restaurant.logo,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    error: const Icon(
                      Icons.restaurant_rounded,
                      size: 34,
                    ),
                  )
                : const Icon(
                    Icons.restaurant_rounded,
                    size: 34,
                  ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (restaurant.description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    restaurant.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final currentMenu = menu;

                    if (currentMenu == null) return;

                    final result =
                        await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RestaurantSettingsScreen(
                          menu: currentMenu,
                          repository: repo,
                        ),
                      ),
                    );

                    if (result == true && mounted) {
                      await _load();
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 17,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'ویرایش اطلاعات رستوران',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    final count = menu?.categories.length ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        10,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'دسته‌بندی منو',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          Text(
            '$count دسته',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 8),

          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _addCategory,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8E8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    size: 18,
                    color: Color(0xFFE53935),
                  ),
                  SizedBox(width: 3),
                  Text(
                    'دسته جدید',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector(
    List<MenuCategory> categories,
  ) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          8,
        ),
        child: _buildEmptyCategories(),
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];

          final selected =
              category.id == _selectedCategoryId;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryId = category.id;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 108,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFE6E6)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFE53935)
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(13),
                        color: const Color(0xFFF1F1F1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: category.image.isNotEmpty
                          ? RemoteImage(
                              path: category.image,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              error: const Icon(
                                Icons.category_outlined,
                                size: 30,
                              ),
                            )
                          : const Icon(
                              Icons.category_outlined,
                              size: 30,
                            ),
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsHeader() {
    final category = _selectedCategory;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        22,
        16,
        8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category?.name ?? 'محصولات',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          if (category != null)
            PopupMenuButton<String>(
              tooltip: 'مدیریت دسته',
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
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 10),
                      Text('ویرایش دسته'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 10),
                      Text('حذف دسته'),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.more_horiz,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    MenuCategory category,
    int index,
  ) {
    final item = category.items[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFF2F2F2),
              ),
              clipBehavior: Clip.antiAlias,
              child: item.image.isNotEmpty
                  ? RemoteImage(
                      path: item.image,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      error: Icon(
                        item.available
                            ? Icons.fastfood_outlined
                            : Icons
                                .visibility_off_outlined,
                        size: 35,
                        color: Colors.grey,
                      ),
                    )
                  : Icon(
                      item.available
                          ? Icons.fastfood_outlined
                          : Icons
                              .visibility_off_outlined,
                      size: 35,
                      color: Colors.grey,
                    ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 3,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w800,
                              decoration:
                                  item.available
                                      ? null
                                      : TextDecoration
                                          .lineThrough,
                            ),
                          ),
                        ),

                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editProduct(
                                category,
                                index,
                              );
                            } else if (value == 'delete') {
                              _deleteProduct(
                                category,
                                index,
                              );
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .edit_outlined,
                                  ),
                                  SizedBox(width: 10),
                                  Text('ویرایش'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .delete_outline,
                                  ),
                                  SizedBox(width: 10),
                                  Text('حذف'),
                                ],
                              ),
                            ),
                          ],
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_vert,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],

                    const SizedBox(height: 9),

                    Row(
                      children: [
                        Text(
                          '${_formatPrice(item.price)} تومان',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        if (item.oldPrice != null) ...[
                          const SizedBox(width: 7),
                          Text(
                            _formatPrice(item.oldPrice!),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              decoration:
                                  TextDecoration
                                      .lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (!item.available) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius:
                              BorderRadius.circular(7),
                        ),
                        child: const Text(
                          'ناموجود',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProductButton() {
    return FloatingActionButton.extended(
      onPressed: _addProduct,
      backgroundColor: const Color(0xFFE53935),
      foregroundColor: Colors.white,
      elevation: 5,
      icon: const Icon(Icons.add),
      label: const Text(
        'محصول جدید',
        style: TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyCategories() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: 54,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'هنوز دسته‌ای وجود ندارد.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('افزودن دسته'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProducts(
    MenuCategory category,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              'در «${category.name}» محصولی وجود ندارد.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('افزودن محصول'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMenu() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu_outlined,
              size: 70,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'منوی رستوران هنوز خالی است.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addCategory,
              icon: const Icon(Icons.add),
              label: const Text('ایجاد اولین دسته'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('مدیریت منو'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 60,
                color: Colors.grey.shade500,
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
  State<_CategoryDialog> createState() =>
      _CategoryDialogState();
}

class _CategoryDialogState
    extends State<_CategoryDialog> {
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
          content: Text(
            'انتخاب عکس ناموفق بود:\n$e',
          ),
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
      final bytes =
          await selectedImage!.readAsBytes();

      final id = idController.text.trim();

      final extension =
          selectedImage!.name.contains('.')
              ? selectedImage!.name
                  .split('.')
                  .last
                  .toLowerCase()
              : 'jpg';

      final fileName =
          'category_$id.$extension';

      final uploadedPath = await GitHubService.uploadImage(
        fileName: fileName,
        bytes: bytes,
      );

      imagePath = uploadedPath;

      return uploadedPath;
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
          content: Text(
            'نام دسته را وارد کنید',
          ),
        ),
      );
      return;
    }

    if (widget.allowIdEdit && id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'شناسه دسته را وارد کنید',
          ),
        ),
      );
      return;
    }

    setState(() {
      uploading = true;
    });

    try {
      final finalImage =
          await uploadImage();

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
          content: Text(
            'آپلود عکس ناموفق بود:\n$e',
          ),
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
        borderRadius: BorderRadius.circular(14),
        child: Image.file(
          File(selectedImage!.path),
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (imagePath.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: Colors.grey.shade500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
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
              onPressed:
                  uploading ? null : pickImage,
              icon: const Icon(
                Icons.photo_library_outlined,
              ),
              label: const Text(
                'انتخاب عکس دسته',
              ),
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
          onPressed:
              uploading ? null : submit,
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
