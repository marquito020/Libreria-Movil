import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:exam1_software_movil/src/providers/shopping_cart_provider.dart';
import 'package:exam1_software_movil/src/widgets/custom_gradient_background.dart';
import 'package:exam1_software_movil/src/widgets/nova_logo.dart';
import 'package:exam1_software_movil/src/share_preferens/user_preferences.dart';
import 'package:exam1_software_movil/src/routes/routes.dart';

class CartPage extends StatefulWidget {
  const CartPage({Key? key}) : super(key: key);

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isLoading = true;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    print('CartPage: initState called');
    // Use addPostFrameCallback to safely load data after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('CartPage: Running post-frame callback');
      _loadCart();
    });
  }

  @override
  void dispose() {
    print('CartPage: dispose called');
    _mounted = false;
    super.dispose();
  }

  Future<void> _loadCart() async {
    print('CartPage: _loadCart called, mounted: $_mounted');
    if (!_mounted) {
      print('CartPage: Not mounted, skipping cart load');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final cartProvider =
        Provider.of<ShoppingCartProvider>(context, listen: false);
    print('CartPage: Calling loadCart() on provider');
    await cartProvider.loadCart();

    if (!_mounted) {
      print('CartPage: Not mounted after loadCart, skipping state update');
      return;
    }

    print(
        'CartPage: Cart loaded, items: ${cartProvider.items.length}, error: ${cartProvider.errorMessage}');
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _updateQuantity(CartItem item, int newQuantity) async {
    print(
        'CartPage: _updateQuantity called for item ${item.id}, new quantity: $newQuantity');
    if (!_mounted) {
      print('CartPage: Not mounted, skipping quantity update');
      return;
    }

    final cartProvider =
        Provider.of<ShoppingCartProvider>(context, listen: false);
    if (newQuantity <= 0) {
      print('CartPage: Removing item ${item.id} (quantity <= 0)');
      await cartProvider.removeCartItem(item.id!);
    } else {
      print('CartPage: Updating quantity for item ${item.id} to $newQuantity');
      await cartProvider.updateCartItemQuantity(item.id!, newQuantity);
    }
  }

  Future<void> _removeItem(int itemId) async {
    print('CartPage: _removeItem called for item $itemId');
    if (!_mounted) {
      print('CartPage: Not mounted, skipping item removal');
      return;
    }

    final cartProvider =
        Provider.of<ShoppingCartProvider>(context, listen: false);
    await cartProvider.removeCartItem(itemId);
  }

  @override
  Widget build(BuildContext context) {
    print('CartPage: build called, isLoading: $_isLoading');
    final cartProvider = Provider.of<ShoppingCartProvider>(context);
    final cartItems = cartProvider.items;
    print(
        'CartPage: Current items count: ${cartItems.length}, provider isLoading: ${cartProvider.isLoading}');

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Show loading view if we're still loading or if provider is loading and we have no items
    if (_isLoading || (cartProvider.isLoading && cartItems.isEmpty)) {
      print('CartPage: Showing loading view');
      return _LoadingView();
    }

    // Show empty view only if we're not loading and there are no items
    if (cartItems.isEmpty) {
      print('CartPage: Showing empty cart view');
      return _EmptyCartView(onRefresh: _loadCart);
    }

    print('CartPage: Showing cart with ${cartItems.length} items');
    return CustomGradientBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NovaLogo(
                      size: 32,
                      isDark: isDark,
                    ),
                    const Spacer(),
                    Text(
                      "Mi Carrito",
                      style: theme.textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    const SizedBox(width: 32), // Balance the logo
                  ],
                ),
              ),

              // Loading indicator at the top when refreshing but we already have items
              if (cartProvider.isLoading && cartItems.isNotEmpty)
                LinearProgressIndicator(
                  backgroundColor: colorScheme.primary.withOpacity(0.2),
                  color: colorScheme.primary,
                ),

              // Error message if any
              if (cartProvider.errorMessage != null)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cartProvider.errorMessage!,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: colorScheme.error),
                        onPressed: _loadCart,
                      ),
                    ],
                  ),
                ),

              // Cart items
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadCart,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final cartItem = cartItems[index];
                      print(
                          'CartPage: Building item at index $index, id: ${cartItem.id}');
                      return _CartItemCard(
                        cartItem: cartItem,
                        onUpdateQuantity: (newQuantity) =>
                            _updateQuantity(cartItem, newQuantity),
                        onRemove: () => _removeItem(cartItem.id!),
                      );
                    },
                  ),
                ),
              ),

              // Cart summary
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total:',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          '\$${_calculateTotal(cartItems).toStringAsFixed(2)}',
                          style: theme.textTheme.titleLarge!.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Checkout button
                    ElevatedButton(
                      onPressed: cartProvider.isLoading
                          ? null
                          : () {
                              print('CartPage: Checkout button pressed');
                              Navigator.of(context).pushNamed(Routes.PAYMENT);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: cartProvider.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Proceder al pago',
                              style: theme.textTheme.labelLarge!.copyWith(
                                color: colorScheme.onPrimary,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateTotal(List<CartItem> items) {
    print('CartPage: Calculating total for ${items.length} items');
    return items.fold(
        0,
        (sum, item) =>
            sum + (item.quantity! * (double.tryParse(item.book.precio) ?? 0)));
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    print('LoadingView: Building loading view');
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return CustomGradientBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NovaLogo(
                      size: 32,
                      isDark: isDark,
                    ),
                    const Spacer(),
                    Text(
                      "Mi Carrito",
                      style: theme.textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    const SizedBox(width: 32), // Balance the logo
                  ],
                ),
              ),

              // Loading animation
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cargando carrito...',
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCartView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyCartView({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    return CustomGradientBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async => onRefresh(),
            child: CustomScrollView(
              slivers: [
                // Logo and Title
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NovaLogo(
                          size: 32,
                          isDark: isDark,
                        ),
                        const Spacer(),
                        Text(
                          "Mi Carrito",
                          style: theme.textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        const SizedBox(width: 32), // Balance the logo
                      ],
                    ),
                  ),
                ),

                // Empty state
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tu carrito está vacío',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Explora la librería para agregar libros',
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            print('EmptyCartView: Browse books button pressed');
                            Navigator.pushReplacementNamed(context, '/books');
                          },
                          icon: const Icon(Icons.book_outlined),
                          label: const Text('Explorar Librería'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            print('EmptyCartView: Refresh button pressed');
                            onRefresh();
                          },
                          child: const Text('Actualizar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem cartItem;
  final Function(int) onUpdateQuantity;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.cartItem,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    print('CartItemCard: Building card for item ${cartItem.id}');
    final book = cartItem.book;
    if (book == null) {
      print('CartItemCard: Warning - book is null for item ${cartItem.id}');
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 80,
                height: 120,
                child: Image.network(
                  book.imagen,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/placeholder_book.jpg',
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Book details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.nombre,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${book.precio}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cantidad: ${cartItem.quantity}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),

                  // Action buttons
                  Row(
                    children: [
                      // Update quantity
                      OutlinedButton.icon(
                        onPressed: () {
                          // Show quantity selector dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Actualizar cantidad'),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Selecciona la nueva cantidad:'),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: cartItem.quantity > 1
                                            ? () => onUpdateQuantity(
                                                cartItem.quantity! - 1)
                                            : null,
                                        icon: const Icon(Icons.remove),
                                      ),
                                      Text(
                                        '${cartItem.quantity}',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                      IconButton(
                                        onPressed:
                                            cartItem.quantity! < book.stock
                                                ? () => onUpdateQuantity(
                                                    cartItem.quantity! + 1)
                                                : null,
                                        icon: const Icon(Icons.add),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Aceptar'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Remove button
                      OutlinedButton.icon(
                        onPressed: onRemove,
                        icon: Icon(Icons.delete_outline,
                            size: 16, color: colorScheme.error),
                        label: Text('Eliminar',
                            style: TextStyle(color: colorScheme.error)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 36),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
