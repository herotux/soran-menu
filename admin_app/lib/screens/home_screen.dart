import 'package:flutter/material.dart';

import '../models/menu_models.dart';
import '../services/menu_repository.dart';
import 'product_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MenuRepository repo = LocalMenuRepository();

  MenuData? menu;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در بارگذاری منو: $e'),
        ),
      );
    }
  }

  int get totalProducts {
    if (menu == null) return 0;

    return menu!.categories.fold(
      0,
      (total, category) => total + category.items.length,
    );
  }

  Future<void> _addProduct(MenuCategory category) async {
    final item = await Navigator.push<MenuItemModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProductFormScreen(),
      ),
    );

    if (item == null || menu == null) return;

    setState(() {
      category.items.add(item);
    });

    await repo.save(menu!);
  }

  Future<void> _editProduct(
    MenuCategory category,
    int index,
  ) async {
    final result = await Navigator.push<MenuItemModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(
          item: category.items[index],
        ),
      ),
    );

    if (result == null || menu == null) return;

    setState(() {
      category.items[index] = result;
    });

    await repo.save(menu!);
  }

  Future<void> _deleteProduct(
    MenuCategory category,
    int index,
  ) async {
    final item = category.items[index];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('حذف محصول'),
          content: Text(
            'آیا «${item.name}» حذف شود؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('لغو'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || menu == null) return;

    setState(() {
      category.items.removeAt(index);
    });

    await repo.save(menu!);
  }

  Future<void> _toggleAvailability(
    MenuCategory category,
    int index,
  ) async {
    if (menu == null) return;

    setState(() {
      category.items[index].available =
          !category.items[index].available;
    });

    await repo.save(menu!);
  }

  String _formatPrice(int price) {
    final value = price.toString();

    final buffer = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) {
        buffer.write(',');
      }

      buffer.write(value[i]);
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مدیریت منو'),
          centerTitle: false,
          actions: [
            IconButton(
              tooltip: 'بازخوانی',
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'تنظیمات',
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        floatingActionButton: menu == null ||
                menu!.categories.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () {
                  _addProduct(menu!.categories.first);
                },
                icon: const Icon(Icons.add),
                label: const Text('محصول جدید'),
              ),
        body: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : menu == null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'بارگذاری منو انجام نشد',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final restaurant = menu!.restaurant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        100,
      ),
      children: [
        _buildRestaurantCard(restaurant),
        const SizedBox(height: 12),
        _buildStatistics(),
        const SizedBox(height: 12),
        ...menu!.categories.map(
          (category) => _buildCategoryCard(category),
        ),
      ],
    );
  }

  Widget _buildRestaurantCard(
    Restaurant restaurant,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(
                Icons.restaurant,
                size: 30,
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
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.description,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.category_outlined,
            title: 'دسته‌ها',
            value: menu!.categories.length.toString(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.fastfood_outlined,
            title: 'محصولات',
            value: totalProducts.toString(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            icon: Icons.check_circle_outline,
            title: 'فعال',
            value: menu!.categories
                .expand((category) => category.items)
                .where((item) => item.available)
                .length
                .toString(),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    MenuCategory category,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          category.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        subtitle: Text(
          '${category.items.length} محصول',
        ),
        children: [
          if (category.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'این دسته محصولی ندارد.',
              ),
            ),
          ...List.generate(
            category.items.length,
            (index) {
              return _buildProductTile(
                category,
                index,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _addProduct(category);
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  'افزودن محصول',
                ),
              ),
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
        horizontal: 12,
        vertical: 4,
      ),
      leading: CircleAvatar(
        child: Icon(
          item.available
              ? Icons.fastfood
              : Icons.visibility_off,
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
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (item.description.isNotEmpty)
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
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
                  _formatPrice(item.oldPrice!),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    decoration:
                        TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'toggle':
              _toggleAvailability(
                category,
                index,
              );
              break;

            case 'edit':
              _editProduct(
                category,
                index,
              );
              break;

            case 'delete':
              _deleteProduct(
                category,
                index,
              );
              break;
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'toggle',
            child: Text(
              item.available
                  ? 'غیرفعال کردن'
                  : 'فعال کردن',
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Text('ویرایش'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }
}
