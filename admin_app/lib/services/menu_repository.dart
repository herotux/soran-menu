import '../models/menu_models.dart';

abstract class MenuRepository {
  Future<MenuData> load();
  Future<void> save(MenuData menu);
}

class LocalMenuRepository implements MenuRepository {
  MenuData _data = MenuData(
    restaurant: Restaurant(
      name: 'خانه سیب‌زمینی (سوران)',
      description: 'منوی آنلاین خانه سیب‌زمینی (سوران)',
      logo: '/images/logo.jpg',
      theme: RestaurantTheme(
        background: '#000000',
        accent: '#62FF00',
        secondary: '#FFFC36',
      ),
    ),
    categories: [
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
            image: '/images/1708799418819.jpeg',
          ),
          MenuItemModel(
            id: '65763',
            name: 'سیب پنیری',
            description: 'سیب‌زمینی بلژیکی با پنیر و سس',
            price: 250,
            oldPrice: 300,
            image: '/images/1708799694662.jpeg',
          ),
        ],
      ),
    ],
  );

  @override
  Future<MenuData> load() async {
    return _data;
  }

  @override
  Future<void> save(MenuData menu) async {
    _data = menu;
  }
}
