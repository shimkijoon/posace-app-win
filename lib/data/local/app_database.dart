import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'models/taxes_models.dart';
import 'models/options_models.dart';
import 'models/bundle_models.dart';

class AppDatabase {
  static const _databaseName = 'posace.db';
  static const _databaseVersion = 13;

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
        updatedAt TEXT NOT NULL,
        allowProductDiscount INTEGER NOT NULL DEFAULT 1,
        kitchenStationId TEXT,
        isKitchenPrintEnabled INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'SINGLE',
        price INTEGER NOT NULL,
        barcode TEXT,
        stockEnabled INTEGER NOT NULL,
        stockQuantity INTEGER,
        isActive INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        kitchenStationId TEXT,
        isKitchenPrintEnabled INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE taxes (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        rate REAL NOT NULL,
        isInclusive INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE product_taxes (
        productId TEXT NOT NULL,
        taxId TEXT NOT NULL,
        PRIMARY KEY (productId, taxId)
      )
    ''');

    await db.execute('''
      CREATE TABLE product_option_groups (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        name TEXT NOT NULL,
        isRequired INTEGER NOT NULL,
        isMultiSelect INTEGER NOT NULL,
        sortOrder INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE product_options (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        name TEXT NOT NULL,
        priceAdjustment REAL NOT NULL,
        sortOrder INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE bundle_items (
        id TEXT PRIMARY KEY,
        parentProductId TEXT NOT NULL,
        componentProductId TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        priceAdjustment REAL NOT NULL
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
        updatedAt TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 0,
        productIds TEXT,
        categoryIds TEXT,
        method TEXT NOT NULL DEFAULT 'PERCENTAGE'
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        points INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        clientSaleId TEXT,
        storeId TEXT NOT NULL,
        posId TEXT,
        memberId TEXT,
        totalAmount INTEGER NOT NULL,
        paidAmount INTEGER NOT NULL,
        taxAmount INTEGER NOT NULL DEFAULT 0,
        discountAmount INTEGER NOT NULL DEFAULT 0,
        cartDiscountsJson TEXT,
        memberPointsEarned INTEGER NOT NULL DEFAULT 0,
        paymentMethod TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        syncedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        productId TEXT NOT NULL,
        qty INTEGER NOT NULL,
        price INTEGER NOT NULL,
        discountAmount INTEGER NOT NULL,
        discountsJson TEXT,
        FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE suspended_sales (
        id TEXT PRIMARY KEY,
        totalAmount INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE suspended_sale_items (
        id TEXT PRIMARY KEY,
        suspendedSaleId TEXT NOT NULL,
        productId TEXT NOT NULL,
        qty INTEGER NOT NULL,
        price INTEGER NOT NULL,
        discountAmount INTEGER NOT NULL,
        optionsJson TEXT,
        FOREIGN KEY (suspendedSaleId) REFERENCES suspended_sales (id) ON DELETE CASCADE
      )
    ''');

    // Version 8: New POS Features
    await db.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        isActive INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pos_sessions (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        posId TEXT NOT NULL,
        employeeId TEXT,
        openingAmount INTEGER NOT NULL,
        closingAmount INTEGER,
        expectedAmount INTEGER,
        variance INTEGER,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        closedAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_payments (
        id TEXT PRIMARY KEY,
        saleId TEXT NOT NULL,
        method TEXT NOT NULL,
        amount INTEGER NOT NULL,
        cardApproval TEXT,
        cardLast4 TEXT,
        FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE table_layouts (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        sortOrder INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE restaurant_tables (
        id TEXT PRIMARY KEY,
        layoutId TEXT NOT NULL,
        name TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        width REAL NOT NULL,
        height REAL NOT NULL,
        FOREIGN KEY (layoutId) REFERENCES table_layouts (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE table_orders (
        id TEXT PRIMARY KEY,
        tableId TEXT NOT NULL,
        storeId TEXT NOT NULL,
        sessionId TEXT,
        employeeId TEXT,
        guestCount INTEGER NOT NULL,
        status TEXT NOT NULL,
        version INTEGER NOT NULL,
        note TEXT,
        createdAt TEXT NOT NULL,
        closedAt TEXT,
        saleId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE table_order_items (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        productId TEXT NOT NULL,
        qty INTEGER NOT NULL,
        price INTEGER NOT NULL,
        options TEXT,
        note TEXT,
        FOREIGN KEY (orderId) REFERENCES table_orders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE kitchen_stations (
        id TEXT PRIMARY KEY,
        storeId TEXT NOT NULL,
        name TEXT NOT NULL,
        deviceType TEXT NOT NULL DEFAULT 'PRINTER',
        deviceConfig TEXT,
        isDefault INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE sales (
          id TEXT PRIMARY KEY,
          clientSaleId TEXT,
          storeId TEXT NOT NULL,
          posId TEXT,
          totalAmount INTEGER NOT NULL,
          paidAmount INTEGER NOT NULL,
          paymentMethod TEXT NOT NULL,
          status TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          syncedAt TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE sale_items (
          id TEXT PRIMARY KEY,
          saleId TEXT NOT NULL,
          productId TEXT NOT NULL,
          qty INTEGER NOT NULL,
          price INTEGER NOT NULL,
          discountAmount INTEGER NOT NULL,
          FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN barcode TEXT');
      } catch (e) {
        // 이미 컬럼이 존재하는 경우 무시
      }
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE taxes (
          id TEXT PRIMARY KEY,
          storeId TEXT NOT NULL,
          name TEXT NOT NULL,
          rate REAL NOT NULL,
          isInclusive INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE product_taxes (
          productId TEXT NOT NULL,
          taxId TEXT NOT NULL,
          PRIMARY KEY (productId, taxId)
        )
      ''');

      await db.execute('''
        CREATE TABLE product_option_groups (
          id TEXT PRIMARY KEY,
          productId TEXT NOT NULL,
          name TEXT NOT NULL,
          isRequired INTEGER NOT NULL,
          isMultiSelect INTEGER NOT NULL,
          sortOrder INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE product_options (
          id TEXT PRIMARY KEY,
          groupId TEXT NOT NULL,
          name TEXT NOT NULL,
          priceAdjustment REAL NOT NULL,
          sortOrder INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE bundle_items (
          id TEXT PRIMARY KEY,
          parentProductId TEXT NOT NULL,
          componentProductId TEXT NOT NULL,
          quantity INTEGER NOT NULL,
          priceAdjustment REAL NOT NULL
        )
      ''');

      try {
        await db.execute('ALTER TABLE sales ADD COLUMN taxAmount INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        // 이미 존재하는 경우 무시
      }
    }

    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE products ADD COLUMN type TEXT NOT NULL DEFAULT 'SINGLE'");
      } catch (e) {
        // 이미 존재하는 경우 무시
      }
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE suspended_sales (
          id TEXT PRIMARY KEY,
          totalAmount INTEGER NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE suspended_sale_items (
          id TEXT PRIMARY KEY,
          suspendedSaleId TEXT NOT NULL,
          productId TEXT NOT NULL,
          qty INTEGER NOT NULL,
          price INTEGER NOT NULL,
          discountAmount INTEGER NOT NULL,
          optionsJson TEXT,
          FOREIGN KEY (suspendedSaleId) REFERENCES suspended_sales (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE members (
          id TEXT PRIMARY KEY,
          storeId TEXT NOT NULL,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          points INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      try {
        await db.execute('ALTER TABLE sales ADD COLUMN memberId TEXT');
        await db.execute('ALTER TABLE sales ADD COLUMN memberPointsEarned INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        // 이미 존재하는 경우 무시
      }
    }

    if (oldVersion < 8) {
      // Update sales table
      try {
        await db.execute('ALTER TABLE sales ADD COLUMN sessionId TEXT');
        await db.execute('ALTER TABLE sales ADD COLUMN employeeId TEXT');
        await db.execute('ALTER TABLE sales ALTER COLUMN paymentMethod DROP NOT NULL');
      } catch (e) {
        // SQLite doesn't support DROP NOT NULL easily, but adding nullable columns is fine
        try {
          await db.execute('ALTER TABLE sales ADD COLUMN sessionId TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE sales ADD COLUMN employeeId TEXT');
        } catch (_) {}
      }

      // New tables
      await db.execute('''
        CREATE TABLE employees (
          id TEXT PRIMARY KEY,
          storeId TEXT NOT NULL,
          name TEXT NOT NULL,
          role TEXT NOT NULL,
          isActive INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE pos_sessions (
          id TEXT PRIMARY KEY,
          storeId TEXT NOT NULL,
          posId TEXT NOT NULL,
          employeeId TEXT,
          openingAmount INTEGER NOT NULL,
          closingAmount INTEGER,
          expectedAmount INTEGER,
          variance INTEGER,
          status TEXT NOT NULL,
          createdAt TEXT NOT NULL,
          closedAt TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE sale_payments (
          id TEXT PRIMARY KEY,
          saleId TEXT NOT NULL,
          method TEXT NOT NULL,
          amount INTEGER NOT NULL,
          cardApproval TEXT,
          cardLast4 TEXT,
          FOREIGN KEY (saleId) REFERENCES sales (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE table_layouts (
          id TEXT PRIMARY KEY,
          storeId TEXT NOT NULL,
          name TEXT NOT NULL,
          sortOrder INTEGER NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE restaurant_tables (
          id TEXT PRIMARY KEY,
          layoutId TEXT NOT NULL,
          name TEXT NOT NULL,
          x REAL NOT NULL,
          y REAL NOT NULL,
          width REAL NOT NULL,
          height REAL NOT NULL,
          FOREIGN KEY (layoutId) REFERENCES table_layouts (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE table_orders (
          id TEXT PRIMARY KEY,
          tableId TEXT NOT NULL,
          storeId TEXT NOT NULL,
          sessionId TEXT,
          employeeId TEXT,
          guestCount INTEGER NOT NULL,
          status TEXT NOT NULL,
          version INTEGER NOT NULL,
          note TEXT,
          createdAt TEXT NOT NULL,
          closedAt TEXT,
          saleId TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE table_order_items (
          id TEXT PRIMARY KEY,
          orderId TEXT NOT NULL,
          productId TEXT NOT NULL,
          qty INTEGER NOT NULL,
          price INTEGER NOT NULL,
          options TEXT,
          note TEXT,
          FOREIGN KEY (orderId) REFERENCES table_orders (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE categories ADD COLUMN allowProductDiscount INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE discounts ADD COLUMN priority INTEGER NOT NULL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE discounts ADD COLUMN productIds TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE discounts ADD COLUMN categoryIds TEXT');
      } catch (_) {}
    }

    if (oldVersion < 10) {
      try {
        await db.execute("ALTER TABLE discounts ADD COLUMN method TEXT NOT NULL DEFAULT 'PERCENTAGE'");
      } catch (_) {}
    }

    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE sale_items ADD COLUMN discountsJson TEXT");
      } catch (_) {}
    }

    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE kitchen_stations (
          id TEXT PRIMARY KEY,
          storeId TEXT NOT NULL,
          name TEXT NOT NULL,
          deviceType TEXT NOT NULL DEFAULT 'PRINTER',
          deviceConfig TEXT,
          isDefault INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');

      try {
        await db.execute('ALTER TABLE categories ADD COLUMN kitchenStationId TEXT');
        await db.execute('ALTER TABLE categories ADD COLUMN isKitchenPrintEnabled INTEGER NOT NULL DEFAULT 1');
        await db.execute('ALTER TABLE products ADD COLUMN kitchenStationId TEXT');
        await db.execute('ALTER TABLE products ADD COLUMN isKitchenPrintEnabled INTEGER NOT NULL DEFAULT 1');
      } catch (_) {}
    }
  }

  Future<void> init() async {
    await database;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('categories');
    await db.delete('products');
    await db.delete('taxes');
    await db.delete('product_taxes');
    await db.delete('product_option_groups');
    await db.delete('product_options');
    await db.delete('bundle_items');
    await db.delete('discounts');
    await db.delete('sale_payments');
    await db.delete('sale_items');
    await db.delete('sales');
    await db.delete('table_order_items');
    await db.delete('table_orders');
    await db.delete('restaurant_tables');
    await db.delete('table_layouts');
    await db.delete('kitchen_stations');
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
    await db.transaction((txn) async {
      for (final product in products) {
        await txn.insert(
          'products',
          product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Taxes junction
        await txn.delete('product_taxes', where: 'productId = ?', whereArgs: [product.id]);
        for (final tax in product.taxes) {
          await txn.insert('product_taxes', {
            'productId': product.id,
            'taxId': tax.id,
          });
        }

        // Option Groups
        await txn.delete('product_option_groups', where: 'productId = ?', whereArgs: [product.id]);
        for (final group in product.optionGroups) {
          await txn.insert('product_option_groups', group.toMap());
          
          await txn.delete('product_options', where: 'groupId = ?', whereArgs: [group.id]);
          for (final option in group.options) {
            await txn.insert('product_options', option.toMap());
          }
        }

        // Bundle Items
        await txn.delete('bundle_items', where: 'parentProductId = ?', whereArgs: [product.id]);
        for (final item in product.bundleItems) {
          await txn.insert('bundle_items', item.toMap());
        }
      }
    });
  }

  Future<List<ProductModel>> getProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'createdAt DESC');
    
    List<ProductModel> products = [];
    for (final map in maps) {
      final product = await _populateProduct(db, map);
      products.add(product);
    }
    return products;
  }

  Future<List<ProductModel>> getProductsByCategory(String categoryId) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'categoryId = ? AND isActive = 1',
      whereArgs: [categoryId],
      orderBy: 'createdAt DESC',
    );
    
    List<ProductModel> products = [];
    for (final map in maps) {
      final product = await _populateProduct(db, map);
      products.add(product);
    }
    return products;
  }

  Future<ProductModel> _populateProduct(Database db, Map<String, dynamic> map) async {
    final productId = map['id'] as String;

    // Load Taxes
    final taxMaps = await db.rawQuery('''
      SELECT t.* FROM taxes t
      INNER JOIN product_taxes pt ON t.id = pt.taxId
      WHERE pt.productId = ?
    ''', [productId]);
    final taxes = taxMaps.map((m) => TaxModel.fromMap(m)).toList();

    // Load Option Groups
    final groupMaps = await db.query('product_option_groups', where: 'productId = ?', whereArgs: [productId], orderBy: 'sortOrder ASC');
    List<ProductOptionGroupModel> groups = [];
    for (final gMap in groupMaps) {
      final optionsMap = await db.query('product_options', where: 'groupId = ?', whereArgs: [gMap['id']], orderBy: 'sortOrder ASC');
      final options = optionsMap.map((o) => ProductOptionModel.fromMap(o)).toList();
      groups.add(ProductOptionGroupModel.fromMap(gMap, options: options));
    }

    // Load Bundle Items
    final bundleMaps = await db.query('bundle_items', where: 'parentProductId = ?', whereArgs: [productId]);
    List<BundleItemModel> bundleItems = [];
    for (final bMap in bundleMaps) {
      // 컴포넌트 상품 정보도 필요할 수 있음 (선택사항)
      bundleItems.add(BundleItemModel.fromMap(bMap));
    }

    // JSON 형태로 변환하여 ProductModel.fromMap에 전달 (이미 구현된 fromMap이 List를 기대하므로)
    final productMap = Map<String, dynamic>.from(map);
    productMap['taxes'] = taxes.map((t) => t.toMap()).toList();
    productMap['optionGroups'] = groups.map((g) => {
      ...g.toMap(),
      'options': g.options.map((o) => o.toMap()).toList(),
    }).toList();
    productMap['bundleItems'] = bundleItems.map((b) => b.toMap()).toList();

    return ProductModel.fromMap(productMap);
  }

  // Taxes
  Future<void> upsertTaxes(List<TaxModel> taxes) async {
    final db = await database;
    final batch = db.batch();
    for (final tax in taxes) {
      batch.insert(
        'taxes',
        tax.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<TaxModel>> getTaxes() async {
    final db = await database;
    final maps = await db.query('taxes', orderBy: 'createdAt ASC');
    return maps.map((map) => TaxModel.fromMap(map)).toList();
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

  // Sales
  Future<void> insertSale(SaleModel sale, List<SaleItemModel> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sales', sale.toMap());
      for (final item in items) {
        await txn.insert('sale_items', item.toMap());
      }
      for (final payment in sale.payments) {
        await txn.insert('sale_payments', payment.toMap());
      }
    });
  }

  Future<List<SaleModel>> getUnsyncedSales() async {
    final db = await database;
    final maps = await db.query(
      'sales',
      where: 'syncedAt IS NULL',
      orderBy: 'createdAt ASC',
    );
    
    List<SaleModel> sales = [];
    for (final map in maps) {
      final saleId = map['id'] as String;
      final paymentMaps = await db.query('sale_payments', where: 'saleId = ?', whereArgs: [saleId]);
      final payments = paymentMaps.map((m) => SalePaymentModel.fromMap(m)).toList();
      sales.add(SaleModel.fromMap(map, payments: payments));
    }
    return sales;
  }

  Future<List<SaleItemModel>> getSaleItems(String saleId) async {
    final db = await database;
    final maps = await db.query(
      'sale_items',
      where: 'saleId = ?',
      whereArgs: [saleId],
    );
    return maps.map((map) => SaleItemModel.fromMap(map)).toList();
  }

  Future<void> markSaleAsSynced(String saleId, {DateTime? syncedAt}) async {
    final db = await database;
    await db.update(
      'sales',
      {
        'syncedAt': (syncedAt ?? DateTime.now()).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }

  // Suspended Sales
  Future<void> insertSuspendedSale(String id, int totalAmount, List<Map<String, dynamic>> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('suspended_sales', {
        'id': id,
        'totalAmount': totalAmount,
        'createdAt': DateTime.now().toIso8601String(),
      });

      for (final item in items) {
        await txn.insert('suspended_sale_items', {
          ...item,
          'suspendedSaleId': id,
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> getSuspendedSales() async {
    final db = await database;
    return await db.query('suspended_sales', orderBy: 'createdAt DESC');
  }

  Future<List<Map<String, dynamic>>> getSuspendedSaleItems(String suspendedSaleId) async {
    final db = await database;
    return await db.query('suspended_sale_items', where: 'suspendedSaleId = ?', whereArgs: [suspendedSaleId]);
  }

  Future<void> deleteSuspendedSale(String id) async {
    final db = await database;
    await db.delete('suspended_sales', where: 'id = ?', whereArgs: [id]);
  }

  // Members
  Future<List<MemberModel>> getMembers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('members', orderBy: 'name ASC');
    return List.generate(maps.length, (i) => MemberModel.fromMap(maps[i]));
  }

  Future<List<MemberModel>> searchMembersByPhone(String phone) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'members',
      where: 'phone LIKE ?',
      whereArgs: ['%$phone%'],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => MemberModel.fromMap(maps[i]));
  }

  Future<void> upsertMember(MemberModel member) async {
    final db = await database;
    await db.insert(
      'members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMemberPoints(String id, int points) async {
    final db = await database;
    await db.update(
      'members',
      {'points': points},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Employees
  Future<void> upsertEmployees(List<EmployeeModel> employees) async {
    final db = await database;
    final batch = db.batch();
    for (final employee in employees) {
      batch.insert('employees', employee.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<EmployeeModel>> getEmployees() async {
    final db = await database;
    final maps = await db.query('employees', where: 'isActive = 1', orderBy: 'name ASC');
    return maps.map((m) => EmployeeModel.fromMap(m)).toList();
  }

  // POS Sessions
  Future<void> upsertSession(PosSessionModel session) async {
    final db = await database;
    await db.insert('pos_sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<PosSessionModel?> getActiveSession() async {
    final db = await database;
    final maps = await db.query('pos_sessions', where: "status = 'OPEN'", limit: 1);
    if (maps.isEmpty) return null;
    return PosSessionModel.fromMap(maps.first);
  }

  // Tables & Layouts
  Future<void> upsertTableLayouts(List<Map<String, dynamic>> layouts) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final layout in layouts) {
        await txn.insert('table_layouts', {
          'id': layout['id'],
          'storeId': layout['storeId'],
          'name': layout['name'],
          'sortOrder': layout['sortOrder'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        if (layout['tables'] != null) {
          for (final table in layout['tables']) {
            await txn.insert('restaurant_tables', {
              'id': table['id'],
              'layoutId': layout['id'],
              'name': table['name'],
              'x': table['x'],
              'y': table['y'],
              'width': table['width'],
              'height': table['height'],
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });
  }

  Future<List<Map<String, dynamic>>> getTableLayouts() async {
    final db = await database;
    final layoutMaps = await db.query('table_layouts', orderBy: 'sortOrder ASC');
    
    List<Map<String, dynamic>> results = [];
    for (final lMap in layoutMaps) {
      final tables = await db.query('restaurant_tables', where: 'layoutId = ?', whereArgs: [lMap['id']]);
      results.add({
        ...lMap,
        'tables': tables,
      });
    }
    return results;
  }

  // Weekly Sales for Chart - Returns last 7 days from today
  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    final db = await database;
    final now = DateTime.now();
    
    // Create a map to store sales by date
    final salesByDate = <String, double>{};
    
    // Query sales for the last 7 days
    final sevenDaysAgo = now.subtract(const Duration(days: 6)); // 6 days ago + today = 7 days
    final result = await db.rawQuery('''
      SELECT 
        DATE(createdAt) as date,
        SUM(totalAmount) as total
      FROM sales
      WHERE DATE(createdAt) >= DATE(?) AND status = 'COMPLETED'
      GROUP BY DATE(createdAt)
    ''', [sevenDaysAgo.toIso8601String()]);
    
    // Store actual sales data
    for (var row in result) {
      final dateStr = row['date'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      salesByDate[dateStr] = total;
    }
    
    // Generate all 7 days from 6 days ago to today
    final weekData = <Map<String, dynamic>>[];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      weekData.add({
        'date': dateStr,
        'total': salesByDate[dateStr] ?? 0.0,
      });
    }
    
    return weekData;
  }

  // Kitchen Stations
  Future<void> upsertKitchenStations(List<KitchenStationModel> stations) async {
    final db = await database;
    final batch = db.batch();
    for (final station in stations) {
      batch.insert(
        'kitchen_stations',
        station.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<KitchenStationModel>> getKitchenStations() async {
    final db = await database;
    final maps = await db.query('kitchen_stations', orderBy: 'isDefault DESC, name ASC');
    return maps.map((map) => KitchenStationModel.fromMap(map)).toList();
  }

  Future<KitchenStationModel?> getDefaultKitchenStation() async {
    final db = await database;
    final maps = await db.query('kitchen_stations', where: 'isDefault = 1', limit: 1);
    if (maps.isNotEmpty) {
      return KitchenStationModel.fromMap(maps.first);
    }
    return null;
  }
}
