class MenuItemModel {
  String id;
  String name;
  String description;
  int price;
  int? oldPrice;
  String image;
  bool available;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.image,
    this.available = true,
  });
}

class MenuCategory {
  String id;
  String name;
  List<MenuItemModel> items;

  MenuCategory({
    required this.id,
    required this.name,
    required this.items,
  });
}