import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/favorites_service.dart';
import 'package:mealprep_flutter/screens/product_screen.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  // ── Thema kleuren (zelfde als de rest van de app) ──
  final Color brandGreen = const Color(0xFF00BFA5);
  final Color textDark = const Color(0xFF345069);
  final Color bgGrey = const Color(0xFFF5F7F9);

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final favorites = await FavoritesService.getFavorites();
      setState(() => _favorites = favorites);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij laden: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(String productId, String productName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verwijderen'),
        content: Text('$productName verwijderen uit favorieten?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuleren', style: TextStyle(color: textDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FavoritesService.removeFavorite(productId);
        await _loadFavorites();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verwijderd uit favorieten'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e')),
        );
      }
    }
  }

  Color _nutriscoreColor(String? grade) {
    switch (grade?.toLowerCase()) {
      case 'a':
        return const Color(0xFF2E7D32);
      case 'b':
        return Colors.lightGreen.shade600;
      case 'c':
        return Colors.yellow.shade700;
      case 'd':
        return Colors.orange.shade700;
      case 'e':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: Text(
          'Mijn favorieten',
          style: TextStyle(fontWeight: FontWeight.bold, color: textDark),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textDark),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textDark),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: brandGreen))
          : _favorites.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadFavorites,
                        color: brandGreen,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _favorites.length,
                          itemBuilder: (context, index) =>
                              _buildFavoriteCard(_favorites[index]),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Header met teller ────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.favorite, color: Colors.red.shade400, size: 18),
          const SizedBox(width: 8),
          Text(
            '${_favorites.length} ${_favorites.length == 1 ? 'favoriet' : 'favorieten'}',
            style: TextStyle(
              color: textDark,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ── Favoriet kaart ───────────────────────────────────────────────────────────

  Widget _buildFavoriteCard(Map<String, dynamic> product) {
    final productId = product['product_id'] as String;
    final name = product['product_name'] ?? 'Onbekend';
    final brand = product['brand'];
    final kcal = product['energy_kcal'];
    final proteins = product['proteins_g'];
    final nutriscore = product['nutriscore_grade'];
    final imageUrl = product['image_url'];
    final barcode = product['barcode'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (barcode != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductScreen(barcode: barcode),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ── Afbeelding ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: bgGrey,
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Info ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (brand != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          brand,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      // ── Chips ──
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (kcal != null)
                            _chip(
                              '${(kcal as num).toInt()} kcal',
                              Colors.orange.shade50,
                              Colors.orange.shade700,
                            ),
                          if (proteins != null)
                            _chip(
                              '${proteins}g eiwit',
                              Colors.blue.shade50,
                              Colors.blue.shade700,
                            ),
                          if (nutriscore != null)
                            _nutriscoreChip(nutriscore),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Verwijder knop ──
                GestureDetector(
                  onTap: () => _removeFavorite(productId, name),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite,
                        color: Colors.red.shade400, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Lege staat ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: brandGreen.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_border, size: 44, color: brandGreen),
          ),
          const SizedBox(height: 20),
          Text(
            'Nog geen favorieten',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tik op het hartje bij een product\nom het hier op te slaan.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _placeholder() {
    return Container(
      color: bgGrey,
      child: Icon(Icons.fastfood, color: Colors.grey.shade400, size: 28),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _nutriscoreChip(String grade) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _nutriscoreColor(grade),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Nutriscore ${grade.toUpperCase()}',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}