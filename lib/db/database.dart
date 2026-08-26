import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models.dart';
import 'package:uuid/uuid.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  static const _uuid = Uuid();
  static String newId() => _uuid.v4();

  Future<Database> get db async {
    _db ??= await openDatabase(
      join(await getDatabasesPath(), 'bizdocs.db'),
      version: 1,
      onCreate: (db, v) async => _createSchema(db),
    );
    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE businesses (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  tin TEXT,
  address TEXT,
  phone TEXT,
  whatsapp TEXT,
  email TEXT,
  logo_path TEXT,
  currency TEXT DEFAULT 'UGX',
  default_tax_percent REAL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');
    await db.execute('''
CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  name TEXT NOT NULL,
  phone TEXT,
  whatsapp TEXT,
  email TEXT,
  address TEXT,
  tin TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');
    await db.execute('''
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL REFERENCES businesses(id),
  name TEXT NOT NULL,
  sku TEXT,
  description TEXT,
  unit_price INTEGER NOT NULL,
  tax_percent REAL,
  track_stock INTEGER DEFAULT 0,
  stock_qty REAL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');
    await db.execute('''
CREATE TABLE templates (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  doc_type TEXT NOT NULL,
  paper_size TEXT NOT NULL,
  layout_json TEXT NOT NULL,
  is_builtin INTEGER DEFAULT 0
)''');
    await db.execute('''
CREATE TABLE document_sequences (
  business_id TEXT NOT NULL,
  doc_type TEXT NOT NULL,
  prefix TEXT,
  next_number INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY (business_id, doc_type)
)''');
    await db.execute('''
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL,
  customer_id TEXT,
  doc_type TEXT NOT NULL,
  doc_number TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'DRAFT',
  content TEXT,
  issue_date INTEGER NOT NULL,
  due_date INTEGER,
  subtotal INTEGER NOT NULL DEFAULT 0,
  tax_total INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 0,
  template_id TEXT,
  pdf_path TEXT,
  hash TEXT,
  linked_doc_id TEXT,
  locked INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  synced INTEGER NOT NULL DEFAULT 0,
  UNIQUE (business_id, doc_type, doc_number)
)''');
    await db.execute('''
CREATE TABLE document_items (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  product_id TEXT,
  description TEXT NOT NULL,
  quantity REAL NOT NULL,
  unit_price INTEGER NOT NULL,
  tax_percent REAL,
  line_total INTEGER NOT NULL
)''');
    await db.execute('''
CREATE TABLE payments (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  amount INTEGER NOT NULL,
  method TEXT NOT NULL,
  reference TEXT,
  paid_at INTEGER NOT NULL
)''');
    await db.execute('''
CREATE TABLE signatures (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL UNIQUE,
  signer_name TEXT,
  image_path TEXT NOT NULL,
  hash TEXT NOT NULL,
  signed_at INTEGER NOT NULL
)''');
    await db.execute('''
CREATE TABLE outbox (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  channel TEXT NOT NULL,
  recipient TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING',
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');
    await db.execute('''
CREATE TABLE subscription_state (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  plan TEXT NOT NULL DEFAULT 'FREE',
  valid_until INTEGER,
  provider TEXT,
  last_verified_at INTEGER
)''');
    await db.execute('''
CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id TEXT,
  action TEXT NOT NULL,
  at INTEGER NOT NULL,
  detail TEXT
)''');
    await db.execute('''
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT
)''');
    await db.execute(
        'CREATE INDEX idx_docs_business ON documents(business_id, status, issue_date)');
    await db.execute(
        'CREATE INDEX idx_items_document ON document_items(document_id)');
    await db.execute('CREATE INDEX idx_outbox_pending ON outbox(status)');
    await db.execute('CREATE INDEX idx_customers_business ON customers(business_id)');
    await db.execute('CREATE INDEX idx_products_business ON products(business_id)');

    // Built-in templates
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final t in [
      ['INVOICE', 'A4'], ['RECEIPT', '80MM'], ['QUOTATION', 'A4'], ['LETTER', 'A4']
    ]) {
      final docType = t[0];
      final paper = t[1];
      await db.insert('templates', {
        'id': newId(),
        'name': 'Default ${docType[0]}${docType.toLowerCase().substring(1)}',
        'doc_type': docType,
        'paper_size': paper,
        'layout_json': '{}',
        'is_builtin': 1,
      });
    }
  }

  // ------------------ Business ------------------

  Future<Business?> getBusiness() async {
    final rows = await (await db).query('businesses', limit: 1);
    return rows.isEmpty ? null : Business.fromMap(rows.first);
  }

  Future<String> upsertBusiness(Business b) async {
    b.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await (await db).insert('businesses', b.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return b.id;
  }

  Future<List<Customer>> listCustomers(String businessId) async {
    final rows = await (await db)
        .query('customers', where: 'business_id = ?', whereArgs: [businessId], orderBy: 'name');
    return rows.map(Customer.fromMap).toList();
  }

  Future<void> upsertCustomer(Customer c) async {
    c.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await (await db).insert('customers', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCustomer(String id) async =>
      (await db).delete('customers', where: 'id = ?', whereArgs: [id]);

  Future<List<Product>> listProducts(String businessId) async {
    final rows = await (await db)
        .query('products', where: 'business_id = ?', whereArgs: [businessId], orderBy: 'name');
    return rows.map(Product.fromMap).toList();
  }

  Future<void> upsertProduct(Product p) async {
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await (await db).insert('products', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProduct(String id) async =>
      (await db).delete('products', where: 'id = ?', whereArgs: [id]);

  // ------------------ Documents ------------------

  Future<String> nextDocNumber(String businessId, DocType type) async {
    final prefix = docTypePrefix(type);
    return (await db).transaction<String>((txn) async {
      final existing = await txn.query('document_sequences',
          where: 'business_id = ? AND doc_type = ?',
          whereArgs: [businessId, type.name.toUpperCase()]);
      int next;
      String p;
      if (existing.isEmpty) {
        next = 1;
        p = prefix;
        await txn.insert('document_sequences', {
          'business_id': businessId,
          'doc_type': type.name.toUpperCase(),
          'prefix': p,
          'next_number': 2,
        });
      } else {
        next = (existing.first['next_number'] as num).toInt();
        p = (existing.first['prefix'] as String?) ?? prefix;
        await txn.rawUpdate(
            'UPDATE document_sequences SET next_number = ? WHERE business_id = ? AND doc_type = ?',
            [next + 1, businessId, type.name.toUpperCase()]);
      }
      return '$p-${next.toString().padLeft(4, '0')}';
    });
  }

  Future<void> saveDocument(Document doc, List<DocumentItem> items) async {
    doc.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await (await db).transaction((txn) async {
      await txn.insert('documents', doc.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('document_items',
          where: 'document_id = ?', whereArgs: [doc.id]);
      for (final item in items) {
        await txn.insert('document_items', item.toMap());
      }
    });
  }

  Future<List<Document>> listDocuments(String businessId,
      {DocType? type, String? status}) async {
    final where = StringBuffer('business_id = ?');
    final args = <dynamic>[businessId];
    if (type != null) {
      where.write(' AND doc_type = ?');
      args.add(type.name.toUpperCase());
    }
    if (status != null) {
      where.write(' AND status = ?');
      args.add(status);
    }
    final rows = await (await db).query('documents',
        where: where.toString(), whereArgs: args, orderBy: 'created_at DESC');
    return rows.map(Document.fromMap).toList();
  }

  Future<List<DocumentItem>> documentItems(String docId) async {
    final rows = await (await db)
        .query('document_items', where: 'document_id = ?', whereArgs: [docId]);
    return rows.map(DocumentItem.fromMap).toList();
  }

  Future<void> updateDocumentTotals(String docId) async {
    final items = await documentItems(docId);
    int subtotal = 0;
    int taxTotal = 0;
    for (final it in items) {
      subtotal += it.lineTotal;
      taxTotal += (((it.taxPercent ?? 0) / 100) * it.lineTotal).round();
    }
    await (await db).update(
        'documents',
        {'subtotal': subtotal, 'tax_total': taxTotal, 'total': subtotal + taxTotal, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [docId]);
  }

  Future<void> setDocumentStatus(String docId, String status) async {
    await (await db).update(
        'documents',
        {'status': status, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [docId]);
    await audit(docId, 'STATUS_$status', null);
  }

  Future<void> updateDocumentPdf(String docId, String pdfPath, String hash) async {
    await (await db).update(
        'documents',
        {'pdf_path': pdfPath, 'hash': hash, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [docId]);
  }

  // ------------------ Payments ------------------

  Future<void> addPayment(Payment p) async {
    await (await db).insert('payments', p.toMap());
    final paid = await totalPaid(p.documentId);
    final totalRow = await (await db).query('documents',
        columns: ['total'], where: 'id = ?', whereArgs: [p.documentId]);
    final total = (totalRow.first['total'] as num).toInt();
    final status = paid >= total ? 'PAID' : 'PARTIAL';
    await setDocumentStatus(p.documentId, status);
  }

  Future<int> totalPaid(String docId) async {
    final row = await (await db).rawQuery(
        'SELECT COALESCE(SUM(amount), 0) as paid FROM payments WHERE document_id = ?',
        [docId]);
    return (row.first['paid'] as num).toInt();
  }

  Future<List<Payment>> listPayments(String docId) async {
    final rows = await (await db)
        .query('payments', where: 'document_id = ?', whereArgs: [docId]);
    return rows.map(Payment.fromMap).toList();
  }

  // ------------------ Signatures ------------------

  Future<void> saveSignature(DocSignature sig) async {
    await (await db).transaction((txn) async {
      await txn.insert('signatures', sig.toMap());
      await txn.rawUpdate(
          "UPDATE documents SET status = 'SIGNED', locked = 1, updated_at = ? WHERE id = ?",
          [DateTime.now().millisecondsSinceEpoch, sig.documentId]);
      await txn.insert('audit_log', {
        'document_id': sig.documentId,
        'action': 'SIGNED',
        'at': DateTime.now().millisecondsSinceEpoch,
        'detail': 'hash=${sig.hash}',
      });
    });
  }

  Future<DocSignature?> getSignature(String docId) async {
    final rows = await (await db)
        .query('signatures', where: 'document_id = ?', whereArgs: [docId], limit: 1);
    return rows.isEmpty ? null : DocSignature.fromMap(rows.first);
  }

  // ------------------ Outbox ------------------

  Future<void> enqueueOutbox(OutboxEntry e) async {
    await (await db).insert('outbox', e.toMap());
  }

  Future<List<OutboxEntry>> listOutbox({String? status}) async {
    final rows = await (await db).query('outbox',
        where: status != null ? 'status = ?' : null,
        whereArgs: status != null ? [status] : null,
        orderBy: 'created_at ASC');
    return rows.map(OutboxEntry.fromMap).toList();
  }

  Future<void> markOutbox(OutboxEntry e, String status, {String? lastError}) async {
    e.status = status;
    e.attempts += 1;
    e.updatedAt = DateTime.now().millisecondsSinceEpoch;
    e.lastError = lastError;
    await (await db).update('outbox', e.toMap(), where: 'id = ?', whereArgs: [e.id]);
  }

  // ------------------ Month lock ------------------

  Future<int> monthLock(String businessId, int year, int month) async {
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    int count = 0;
    await (await db).transaction((txn) async {
      final rows = await txn.rawQuery(
          'SELECT id FROM documents WHERE business_id = ? AND issue_date >= ? AND issue_date < ? AND locked = 0',
          [businessId, start, end]);
      for (final r in rows) {
        await txn.rawUpdate(
            "UPDATE documents SET locked = 1, status = 'LOCKED', updated_at = ? WHERE id = ?",
            [DateTime.now().millisecondsSinceEpoch, r['id']]);
        count++;
      }
      await txn.insert('audit_log', {
        'document_id': null,
        'action': 'MONTH_LOCK',
        'at': DateTime.now().millisecondsSinceEpoch,
        'detail': '$year-$month locked $count documents',
      });
    });
    return count;
  }

  Future<SubscriptionState> subscription() async {
    final rows = await (await db).query('subscription_state', limit: 1);
    return rows.isEmpty
        ? SubscriptionState()
        : SubscriptionState.fromMap(rows.first);
  }

  Future<void> setSubscription(SubscriptionState s) async {
    await (await db).insert('subscription_state', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final rows = await (await db).query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await (await db).delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await (await db).insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> audit(String? docId, String action, String? detail) async {
    await (await db).insert('audit_log', {
      'document_id': docId,
      'action': action,
      'at': DateTime.now().millisecondsSinceEpoch,
      'detail': detail,
    });
  }

  Future<List<Map<String, dynamic>>> auditLog({int limit = 200}) async =>
      (await db).query('audit_log', orderBy: 'at DESC', limit: limit);
}
