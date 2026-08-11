import '../models/menu_models.dart';

abstract class MenuRepository {
  Future<List<MenuCategory>> load();
  Future<void> save(List<MenuCategory> categories);
}

/// Local MVP repository. Replace with GitHub/Worker implementation.
class LocalMenuRepository implements MenuRepository {
  List<MenuCategory> _data = [
    MenuCategory(
      id: 'potato',
      name: 'سیب‌زمینی',
      items: [
        MenuItemModel(
          id: '65762',
          name: 'سیب ساده',
          description: 'سیب‌زمینی بلژیکی با سس مخصوص',
          price: 160,
          oldPrice: 200,
          image: '',
        ),
        MenuItemModel(
          id: '65763',
          name: 'سیب پنیری',
          description: 'سیب‌زمینی باژیکی با پنیر و سس',
          price: 250,
          oldPrice: 300,
          image: '',
        ),
      ],
    ),
  ];

  @override
  Future<List<MenuCategory>> load() async => _data;

  @override
  Future<void> save(List<MenuCategory> categories) async {
    _data = categories;
  }
}