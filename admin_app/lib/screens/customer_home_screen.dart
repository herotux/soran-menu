import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final api = ApiService();
  List restaurants = [];
  int? selectedId;
  Map<String, dynamic>? menu;
  Map<String, dynamic>? loyalty;
  List announcements = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRestaurants();
  }

  Future<void> loadRestaurants() async {
    setState(() => loading = true);
    try {
      restaurants = await api.get('/api/public/restaurants') as List;
      if (restaurants.isNotEmpty) await selectRestaurant(restaurants.first as Map);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> selectRestaurant(Map restaurant) async {
    final id = restaurant['id'] as int;
    setState(() { selectedId = id; menu = null; loyalty = null; announcements = []; });
    try {
      final slug = Uri.encodeComponent(restaurant['slug'] as String);
      final results = await Future.wait([
        api.get('/api/public/restaurants/$slug/menu'),
        api.get('/api/customer/restaurants/$id/announcements'),
        api.get('/api/customer/restaurants/$id/loyalty'),
      ]);
      if (!mounted) return;
      setState(() { menu = results[0] as Map<String, dynamic>; announcements = results[1] as List; loyalty = results[2] as Map<String, dynamic>; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && restaurants.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('SoranSib')),
      body: RefreshIndicator(
        onRefresh: loadRestaurants,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              value: selectedId,
              decoration: const InputDecoration(labelText: 'رستوران'),
              items: restaurants.map((r) => DropdownMenuItem<int>(value: r['id'] as int, child: Text(r['name'] as String))).toList(),
              onChanged: (id) { final r = restaurants.firstWhere((x) => x['id'] == id); selectRestaurant(r as Map); },
            ),
            const SizedBox(height: 16),
            if (loyalty != null) Card(child: ListTile(
              leading: const Icon(Icons.stars),
              title: Text('${loyalty!['tier']?['name'] ?? 'برنزی'} — ${loyalty!['discount_percent']}٪ تخفیف'),
              subtitle: Text('خرید قبلی: ${loyalty!['total_spent']} | سفارش‌ها: ${loyalty!['completed_orders']}'),
            )),
            if (announcements.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('اطلاعیه‌ها', style: Theme.of(context).textTheme.titleLarge),
              ...announcements.map((a) => Card(child: ListTile(leading: const Icon(Icons.campaign), title: Text(a['title']), subtitle: Text(a['body'])))),
            ],
            const SizedBox(height: 12),
            if (menu != null) ...[
              Text('منو', style: Theme.of(context).textTheme.titleLarge),
              ...((menu!['categories'] as List).map((category) => ExpansionTile(
                title: Text(category['name']),
                children: (category['items'] as List).map((item) => ListTile(
                  title: Text(item['name']),
                  subtitle: Text(item['description'] ?? ''),
                  trailing: Text('${item['price']}'),
                )).toList(),
              ))),
            ],
          ],
        ),
      ),
    );
  }
}
