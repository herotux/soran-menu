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
  Map<String, dynamic>? dashboard;
  List orders = [];
  Map<String, dynamic>? wallet;
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
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> selectRestaurant(Map restaurant) async {
    final id = restaurant['id'] as int;
    setState(() {
      selectedId = id;
      menu = null;
      dashboard = null;
      orders = [];
      wallet = null;
      loading = true;
    });
    try {
      final slug = Uri.encodeComponent(restaurant['slug'] as String);
      final results = await Future.wait([
        api.get('/api/public/restaurants/$slug/menu'),
        api.get('/api/customer/$id/dashboard'),
        api.get('/api/customer/$id/orders'),
        api.get('/api/customer/$id/wallet'),
      ]);
      if (!mounted) return;
      setState(() {
        menu = results[0] as Map<String, dynamic>;
        dashboard = results[1] as Map<String, dynamic>;
        orders = results[2] as List;
        wallet = results[3] as Map<String, dynamic>;
      });
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _error(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
  }

  @override
  Widget build(BuildContext context) {
    if (loading && restaurants.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SoranSib'),
          bottom: const TabBar(tabs: [
            Tab(text: 'خانه', icon: Icon(Icons.home_outlined)),
            Tab(text: 'منو', icon: Icon(Icons.restaurant_menu)),
            Tab(text: 'سفارش‌ها', icon: Icon(Icons.receipt_long)),
            Tab(text: 'باشگاه', icon: Icon(Icons.stars_outlined)),
          ]),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DropdownButtonFormField<int>(
                value: selectedId,
                decoration: const InputDecoration(labelText: 'رستوران', border: OutlineInputBorder()),
                items: restaurants.map((r) => DropdownMenuItem<int>(value: r['id'] as int, child: Text(r['name'] as String))).toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final restaurant = restaurants.firstWhere((x) => x['id'] == id) as Map;
                  selectRestaurant(restaurant);
                },
              ),
            ),
            if (loading) const LinearProgressIndicator(),
            Expanded(child: TabBarView(children: [_home(), _menu(), _orders(), _club()])),
          ],
        ),
      ),
    );
  }

  Widget _home() {
    final customer = dashboard?['customer'] as Map?;
    final notifications = dashboard?['notifications'] as List? ?? [];
    final discounts = dashboard?['discounts'] as List? ?? [];
    return RefreshIndicator(
      onRefresh: () async {
        if (selectedId == null) return;
        final restaurant = restaurants.firstWhere((x) => x['id'] == selectedId) as Map;
        await selectRestaurant(restaurant);
      },
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (customer != null) Card(child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.stars)),
          title: Text('سطح ${_tierName(customer['tier'])}'),
          subtitle: Text('امتیاز: ${customer['points']}  |  خرید: ${customer['total_spent']}  |  مراجعه: ${customer['visit_count']}'),
        )),
        if (discounts.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('تخفیف‌های شما', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ...discounts.map((d) => Card(child: ListTile(leading: const Icon(Icons.local_offer), title: Text(d['title']), subtitle: Text('${d['code']} — ${d['amount']}${d['discount_type'] == 'percent' ? '٪' : ''}')))),
        ],
        if (notifications.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('اطلاعیه‌ها', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ...notifications.map((n) => Card(child: ListTile(leading: const Icon(Icons.campaign), title: Text(n['title']), subtitle: Text(n['body'])))),
        ],
        if (wallet != null) ...[
          const SizedBox(height: 12),
          Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('کیف پول'), subtitle: Text('موجودی: ${wallet!['balance']}'))),
        ],
      ]),
    );
  }

  Widget _menu() {
    if (menu == null) return const Center(child: Text('منو در دسترس نیست'));
    final categories = menu!['categories'] as List;
    return ListView(padding: const EdgeInsets.all(12), children: categories.map((category) => ExpansionTile(
      title: Text(category['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
      children: (category['items'] as List).map((item) => ListTile(
        title: Text(item['name']),
        subtitle: Text(item['description'] ?? ''),
        trailing: Text('${item['price']}'),
        enabled: item['available'] == true,
      )).toList(),
    )).toList());
  }

  Widget _orders() {
    if (orders.isEmpty) return const Center(child: Text('هنوز سفارشی ثبت نشده است'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, index) {
        final order = orders[index] as Map;
        return Card(child: ExpansionTile(
          title: Text('سفارش #${order['id']}'),
          subtitle: Text('${_statusName(order['status'])} — ${order['total']}'),
          children: (order['items'] as List).map((item) => ListTile(title: Text(item['name']), trailing: Text('× ${item['quantity']}'))).toList(),
        ));
      },
    );
  }

  Widget _club() {
    final customer = dashboard?['customer'] as Map?;
    if (customer == null) return const Center(child: Text('باشگاه مشتریان در دسترس نیست'));
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const Icon(Icons.workspace_premium), title: Text('سطح ${_tierName(customer['tier'])}'), subtitle: Text('${customer['points']} امتیاز'))),
      const SizedBox(height: 8),
      const Text('با خرید بیشتر، سطح باشگاه و تخفیف‌های شما افزایش پیدا می‌کند.'),
      if (wallet != null) Card(child: ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('کیف پول'), subtitle: Text('موجودی ${wallet!['balance']}'))),
    ]);
  }

  String _tierName(Object? value) => const {'bronze': 'برنزی', 'silver': 'نقره‌ای', 'gold': 'طلایی', 'platinum': 'پلاتینیوم'}[value] ?? 'برنزی';
  String _statusName(Object? value) => const {'pending': 'در انتظار', 'confirmed': 'تأیید شده', 'completed': 'تکمیل شده', 'cancelled': 'لغو شده'}[value] ?? 'نامشخص';
}
