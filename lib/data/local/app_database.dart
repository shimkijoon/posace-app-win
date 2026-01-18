import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class AppDatabase {
  static const _databaseName = 'posace.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Windows에서 sqflite_common_ffi 초기화
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        sortOrder INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        stockEnabled INTEGER NOT NULL,
        stockQuantity INTEGER,
        isActive INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE discounts (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        type TEXT NOT NULL,
        targetId TEXT,
        name TEXT NOT NULL,
        rateOrAmount INTEGER NOT NULL,
        startsAt TEXT,
        endsAt TEXT,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // TODO: Handle database migrations
  }

  Future<void> init() async {
    await database;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('categories');
    await db.delete('products');
    await db.delete('discounts');
    await db.delete('sync_metadata');
  }

  // Categories
  Future<void> upsertCategories(List<CategoryModel> categories) async {
    final db = await database;
    final batch = db.batch();
    for (final category in categories) {
      batch.insert(
        'categories',
        category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CategoryModel>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'sortOrder ASC, createdAt DESC');
    return maps.map((map) => CategoryModel.fromMap(map)).toList();
  }

  // Products
  Future<void> upsertProducts(List<ProductModel> products) async {
    final db = await database;
    final batch = db.batch();
    for (final product in products) {
      batch.insert(
        'products',
        product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ProductModel>> getProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'createdAt DESC');
    return maps.map((map) => ProductModel.fromMap(map)).toList();
  }

  Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'categoryId = ? AND isActive = 1',
      whereArgs: [categoryId],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => ProductModel.fromMap(map)).toList();
  }

  // Discounts
  Future<void> upsertDiscounts(List<DiscountModel> discounts) async {
    final db = await database;
    final batch = db.batch();
    for (final discount in discounts) {
      batch.insert(
        'discounts',
        discount.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<DiscountModel>> getDiscounts() async {
    final db = await database;
    final maps = await db.query('discounts', orderBy: 'createdAt DESC');
    return maps.map((map) => DiscountModel.fromMap(map)).toList();
  }

  // Sync metadata
  Future<void> setSyncMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'sync_metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSyncMetadata(String key) async {
    final db = await database;
    final maps = await db.query(
      'sync_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }
}
