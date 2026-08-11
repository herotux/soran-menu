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
  List<MenuCategory> categories = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await repo.load();
    setState(() {
      categories = data;
      loading = false;
    });
  }

  Future<void> _addProduct(MenuCategory category) async {
    final item = await Navigator.push<MenuItemModel>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    if (item == null) return;
    setState(() => category.items.add(item));
    await repo.save(categories);
  }

  Future<void> _editProduct(MenuCategory category, int index) async {
    final result = await Navigator.push<MenuItemModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(item: category.items[index]),
      ),
    );
    if (result == null) return;
    setState(() => category.items[index] = result);
    await repo.save(categories);
  }

  Future<void> _deleteProduct(MenuCategory category, int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف محصول'),
        content: Text('«${category.items[index].name}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => category.items.removeAt(index));
    await repo.save(categories);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت منو'),
        actions: [
          IconButton(
            tooltip: 'تنظیمات',
            onPressed: () {},
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: categories.isEmpty ? null : () => _addProduct(categories.first),
        icon: const Icon(Icons.add),
        label: const Text('محصول جدید'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        itemCount: categories.length,
        itemBuilder: (_, ci) {
          final category = categories[ci];
          return Card(
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              children: [
                ...List.generate(category.items.length, (i) {
                  final item = category.items[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.fastfood)),
                    title: Text(item.name),
                    subtitle: Text('${item.price.toString()} هزار تومان'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: () => _editProduct(category, i),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _deleteProduct(category, i),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  );
                }),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: OutlinedButton.icon(
                    onPressed: () => _addProduct(category),
                    icon: const Icon(Icons.add),
                    label: const Text('افزودن محصول'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}