import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:exam1_software_movil/src/models/book_model.dart';
import 'package:exam1_software_movil/src/models/category_model.dart';
import 'package:exam1_software_movil/src/services/library_service.dart';
import 'package:exam1_software_movil/src/services/category_service.dart';
import 'package:exam1_software_movil/src/widgets/book_card.dart';
import 'package:exam1_software_movil/src/pages/loading_page.dart';
import 'package:exam1_software_movil/src/widgets/custom_gradient_background.dart';
import 'package:exam1_software_movil/src/widgets/nova_logo.dart';

class BooksPage extends StatefulWidget {
  const BooksPage({Key? key}) : super(key: key);

  @override
  State<BooksPage> createState() => _BooksPageState();
}

class _BooksPageState extends State<BooksPage> {
  String _searchQuery = '';
  int? _selectedCategoryId;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize providers if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryService>(context, listen: false).loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryService = Provider.of<LibraryService>(context);
    final categoryService = Provider.of<CategoryService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // Filter books by search query and selected category
    List<Book> filteredBooks = libraryService.books.where((book) {
      // Filter by search query
      final matchesSearch = _searchQuery.isEmpty ||
          book.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          book.descripcion.toLowerCase().contains(_searchQuery.toLowerCase());

      // Debug category information
      if (_selectedCategoryId != null) {
        print('Selected category ID: $_selectedCategoryId');
        print(
            'Book ${book.id} - Category: ${book.categoria?.id ?? 'null'}, Name: ${book.categoria?.nombre ?? 'null'}');
      }

      // Filter by category
      final matchesCategory = _selectedCategoryId == null ||
          (book.categoria != null && book.categoria!.id == _selectedCategoryId);

      if (_selectedCategoryId != null) {
        print('Book ${book.id} matches category: $matchesCategory');
      }

      return matchesSearch && matchesCategory;
    }).toList();

    // Show loading indicator while fetching data
    if (libraryService.isLoading) {
      return const LoadingPage();
    }

    // Show error if there's an issue fetching books
    if (libraryService.hasError) {
      return _ErrorView(
        errorMessage: libraryService.errorMessage,
        onRetry: () => libraryService.refreshBooks(),
      );
    }

    // Show empty state if no books are available
    if (libraryService.books.isEmpty) {
      return _EmptyBooksView(onRefresh: () => libraryService.refreshBooks());
    }

    // Show books in a grid view
    return CustomGradientBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          heroTag: "refreshBooksBtn",
          onPressed: () => libraryService.refreshBooks(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: colorScheme.primary,
          child: Icon(Icons.refresh, color: colorScheme.onPrimary),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NovaLogo(
                      size: 32,
                      isDark: isDark,
                    ),
                    const Spacer(),
                    Text(
                      "Catálogo",
                      style: theme.textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    const SizedBox(width: 32), // Balance the logo
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar libros...',
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.primary,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon:
                                  Icon(Icons.clear, color: colorScheme.primary),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Category chips
              categoryService.isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            // "All" category
                            _buildCategoryChip(
                              context: context,
                              label: 'Todos',
                              isSelected: _selectedCategoryId == null,
                              onSelected: (_) {
                                setState(() {
                                  _selectedCategoryId = null;
                                });
                              },
                            ),
                            // Dynamic categories
                            ...categoryService.categories
                                .where((category) => category.isActive)
                                .map((category) => _buildCategoryChip(
                                      context: context,
                                      label: category.nombre,
                                      isSelected:
                                          _selectedCategoryId == category.id,
                                      onSelected: (_) {
                                        setState(() {
                                          _selectedCategoryId = category.id;
                                        });
                                      },
                                    )),
                          ],
                        ),
                      ),
                    ),

              // Books grid
              Expanded(
                child: filteredBooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron libros',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Intenta con otra búsqueda o categoría',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: RefreshIndicator(
                          onRefresh: () async => libraryService.refreshBooks(),
                          child: MasonryGridView.builder(
                            itemCount: filteredBooks.length,
                            gridDelegate:
                                const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                            ),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            itemBuilder: (context, index) {
                              return BookCard(book: filteredBooks[index]);
                            },
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required void Function(bool)? onSelected,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: theme.colorScheme.surface,
        selectedColor: theme.colorScheme.primary,
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CustomGradientBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NovaLogo(
                    size: 48,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar los libros',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBooksView extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyBooksView({
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CustomGradientBackground(
      isDark: isDark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NovaLogo(
                    size: 48,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 32),
                  Icon(
                    Icons.auto_stories_rounded,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay libros disponibles',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No se encontraron libros en nuestro catálogo',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
