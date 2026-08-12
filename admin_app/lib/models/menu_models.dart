class RestaurantTheme {
  String background;
  String accent;
  String secondary;

  RestaurantTheme({
    required this.background,
    required this.accent,
    required this.secondary,
  });

  factory RestaurantTheme.fromJson(Map<String, dynamic> json) {
    return RestaurantTheme(
      background: json['background']?.toString() ?? '#000000',
      accent: json['accent']?.toString() ?? '#62FF00',
      secondary: json['secondary']?.toString() ?? '#FFFC36',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'background': background,
      'accent': accent,
      'secondary': secondary,
    };
  }
}

class Restaurant {
  String name;
  String description;
  String logo;
  String phone;
  String mobile;
  String address;
  String instagram;
  String telegram;
  RestaurantTheme theme;

  Restaurant({
    required this.name,
    required this.description,
    required this.logo,
    this.phone = '',
    this.mobile = '',
    this.address = '',
    this.instagram = '',
    this.telegram = '',
    required this.theme,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      instagram: json['instagram']?.toString() ?? '',
      telegram: json['telegram']?.toString() ?? '',
      theme: RestaurantTheme.fromJson(
        Map<String, dynamic>.from(json['theme'] ?? {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'logo': logo,
      'phone': phone,
      'mobile': mobile,
      'address': address,
      'instagram': instagram,
      'telegram': telegram,
      'theme': theme.toJson(),
    };
  }
}

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

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      oldPrice: (json['oldPrice'] as num?)?.toInt(),
      image: json['image']?.toString() ?? '',
      available: json['available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'oldPrice': oldPrice,
      'image': image,
      'available': available,
    };
  }
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

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (item) => MenuItemModel.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

class MenuData {
  Restaurant restaurant;
  List<MenuCategory> categories;

  MenuData({
    required this.restaurant,
    required this.categories,
  });

  factory MenuData.fromJson(Map<String, dynamic> json) {
    return MenuData(
      restaurant: Restaurant.fromJson(
        Map<String, dynamic>.from(json['restaurant'] ?? {}),
      ),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map(
            (category) => MenuCategory.fromJson(
              Map<String, dynamic>.from(category),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurant': restaurant.toJson(),
      'categories': categories.map((category) => category.toJson()).toList(),
    };
  }
}
