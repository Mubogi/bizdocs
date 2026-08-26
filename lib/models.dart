import 'dart:convert';
import 'package:crypto/crypto.dart';

// Money is stored as INTEGER minor units (whole UGX shillings by default).

enum DocType { invoice, receipt, quotation, letter }

enum DocStatus { draft, issued, partial, paid, signed, locked, cancelled }

DocType docTypeFromString(String v) =>
    DocType.values.firstWhere((e) => e.name == v.toUpperCase());

String docTypeLabel(DocType t) =>
    {DocType.invoice: 'Invoice', DocType.receipt: 'Receipt', DocType.quotation: 'Quotation', DocType.letter: 'Letter'}[t]!;

String docTypePrefix(DocType t) =>
    {DocType.invoice: 'INV', DocType.receipt: 'RCT', DocType.quotation: 'QTO', DocType.letter: 'LTR'}[t]!;

class Business {
  String id;
  String name;
  String? tin;
  String? address;
  String? phone;
  String? whatsapp;
  String? email;
  String currency;
  double defaultTaxPercent;
  int createdAt;
  int updatedAt;

  Business({
    required this.id,
    required this.name,
    this.tin,
    this.address,
    this.phone,
    this.whatsapp,
    this.email,
    this.currency = 'UGX',
    this.defaultTaxPercent = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Business.fromMap(Map<String, dynamic> m) => Business(
        id: m['id'] as String,
        name: m['name'] as String,
        tin: m['tin'] as String?,
        address: m['address'] as String?,
        phone: m['phone'] as String?,
        whatsapp: m['whatsapp'] as String?,
        email: m['email'] as String?,
        currency: (m['currency'] as String?) ?? 'UGX',
        defaultTaxPercent: (m['default_tax_percent'] as num?)?.toDouble() ?? 0,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'tin': tin, 'address': address, 'phone': phone,
        'whatsapp': whatsapp, 'email': email, 'currency': currency,
        'default_tax_percent': defaultTaxPercent,
        'created_at': createdAt, 'updated_at': updatedAt,
      };
}

class Customer {
  String id;
  String businessId;
  String name;
  String? phone;
  String? whatsapp;
  String? email;
  String? address;
  String? tin;
  int createdAt;
  int updatedAt;

  Customer({
    required this.id, required this.businessId, required this.name,
    this.phone, this.whatsapp, this.email, this.address, this.tin,
    required this.createdAt, required this.updatedAt,
  });

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as String, businessId: m['business_id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?, whatsapp: m['whatsapp'] as String?,
        email: m['email'] as String?, address: m['address'] as String?,
        tin: m['tin'] as String?,
        createdAt: m['created_at'] as int, updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'business_id': businessId, 'name': name, 'phone': phone,
        'whatsapp': whatsapp, 'email': email, 'address': address, 'tin': tin,
        'created_at': createdAt, 'updated_at': updatedAt,
      };
}

class Product {
  String id;
  String businessId;
  String name;
  String? sku;
  String? description;
  int unitPrice;
  double? taxPercent;
  bool trackStock;
  double? stockQty;
  int createdAt;
  int updatedAt;

  Product({
    required this.id, required this.businessId, required this.name,
    this.sku, this.description, required this.unitPrice, this.taxPercent,
    this.trackStock = false, this.stockQty,
    required this.createdAt, required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String, businessId: m['business_id'] as String,
        name: m['name'] as String, sku: m['sku'] as String?,
        description: m['description'] as String?,
        unitPrice: m['unit_price'] as int,
        taxPercent: (m['tax_percent'] as num?)?.toDouble(),
        trackStock: (m['track_stock'] as int?) == 1,
        stockQty: (m['stock_qty'] as num?)?.toDouble(),
        createdAt: m['created_at'] as int, updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'business_id': businessId, 'name': name, 'sku': sku,
        'description': description, 'unit_price': unitPrice,
        'tax_percent': taxPercent, 'track_stock': trackStock ? 1 : 0,
        'stock_qty': stockQty, 'created_at': createdAt, 'updated_at': updatedAt,
      };
}

class Document {
  String id;
  String businessId;
  String? customerId;
  DocType docType;
  String docNumber;
  String status;
  String? content;
  int issueDate;
  int? dueDate;
  int subtotal;
  int taxTotal;
  int total;
  String? pdfPath;
  String? hash;
  String? linkedDocId;
  bool locked;
  int createdAt;
  int updatedAt;
  bool synced;

  Document({
    required this.id, required this.businessId, this.customerId,
    required this.docType, required this.docNumber,
    this.status = 'DRAFT', this.content, required this.issueDate,
    this.dueDate, this.subtotal = 0, this.taxTotal = 0, this.total = 0,
    this.pdfPath, this.hash, this.linkedDocId, this.locked = false,
    required this.createdAt, required this.updatedAt, this.synced = false,
  });

  factory Document.fromMap(Map<String, dynamic> m) => Document(
        id: m['id'] as String, businessId: m['business_id'] as String,
        customerId: m['customer_id'] as String?,
        docType: docTypeFromString(m['doc_type'] as String),
        docNumber: m['doc_number'] as String,
        status: (m['status'] as String?) ?? 'DRAFT',
        content: m['content'] as String?,
        issueDate: m['issue_date'] as int,
        dueDate: m['due_date'] as int?,
        subtotal: (m['subtotal'] as num?)?.toInt() ?? 0,
        taxTotal: (m['tax_total'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        pdfPath: m['pdf_path'] as String?, hash: m['hash'] as String?,
        linkedDocId: m['linked_doc_id'] as String?,
        locked: (m['locked'] as int?) == 1,
        createdAt: m['created_at'] as int, updatedAt: m['updated_at'] as int,
        synced: (m['synced'] as int?) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'business_id': businessId, 'customer_id': customerId,
        'doc_type': docType.name.toUpperCase(), 'doc_number': docNumber,
        'status': status, 'content': content, 'issue_date': issueDate,
        'due_date': dueDate, 'subtotal': subtotal, 'tax_total': taxTotal,
        'total': total, 'pdf_path': pdfPath, 'hash': hash,
        'linked_doc_id': linkedDocId, 'locked': locked ? 1 : 0,
        'created_at': createdAt, 'updated_at': updatedAt,
        'synced': synced ? 1 : 0,
      };
}

class DocumentItem {
  String id;
  String documentId;
  String? productId;
  String description;
  double quantity;
  int unitPrice;
  double? taxPercent;
  int lineTotal;

  DocumentItem({
    required this.id, required this.documentId, this.productId,
    required this.description, required this.quantity,
    required this.unitPrice, this.taxPercent, required this.lineTotal,
  });

  factory DocumentItem.fromMap(Map<String, dynamic> m) => DocumentItem(
        id: m['id'] as String, documentId: m['document_id'] as String,
        productId: m['product_id'] as String?,
        description: m['description'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitPrice: (m['unit_price'] as num).toInt(),
        taxPercent: (m['tax_percent'] as num?)?.toDouble(),
        lineTotal: (m['line_total'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'document_id': documentId, 'product_id': productId,
        'description': description, 'quantity': quantity,
        'unit_price': unitPrice, 'tax_percent': taxPercent,
        'line_total': lineTotal,
      };
}

class Payment {
  String id;
  String documentId;
  int amount;
  String method;
  String? reference;
  int paidAt;

  Payment({
    required this.id, required this.documentId, required this.amount,
    required this.method, this.reference, required this.paidAt,
  });

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'] as String, documentId: m['document_id'] as String,
        amount: (m['amount'] as num).toInt(),
        method: m['method'] as String,
        reference: m['reference'] as String?,
        paidAt: m['paid_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'document_id': documentId, 'amount': amount,
        'method': method, 'reference': reference, 'paid_at': paidAt,
      };
}

class DocSignature {
  String id;
  String documentId;
  String? signerName;
  String imagePath;
  String hash;
  int signedAt;

  DocSignature({
    required this.id, required this.documentId, this.signerName,
    required this.imagePath, required this.hash, required this.signedAt,
  });

  factory DocSignature.fromMap(Map<String, dynamic> m) => DocSignature(
        id: m['id'] as String,
        documentId: m['document_id'] as String,
        signerName: m['signer_name'] as String?,
        imagePath: m['image_path'] as String,
        hash: m['hash'] as String,
        signedAt: m['signed_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'document_id': documentId, 'signer_name': signerName,
        'image_path': imagePath, 'hash': hash, 'signed_at': signedAt,
      };
}

class OutboxEntry {
  String id;
  String documentId;
  String channel;
  String recipient;
  String status;
  int attempts;
  String? lastError;
  int createdAt;
  int updatedAt;

  OutboxEntry({
    required this.id, required this.documentId, required this.channel,
    required this.recipient, this.status = 'PENDING', this.attempts = 0,
    this.lastError, required this.createdAt, required this.updatedAt,
  });

  factory OutboxEntry.fromMap(Map<String, dynamic> m) => OutboxEntry(
        id: m['id'] as String, documentId: m['document_id'] as String,
        channel: m['channel'] as String, recipient: m['recipient'] as String,
        status: (m['status'] as String?) ?? 'PENDING',
        attempts: (m['attempts'] as num?)?.toInt() ?? 0,
        lastError: m['last_error'] as String?,
        createdAt: m['created_at'] as int, updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'document_id': documentId, 'channel': channel,
        'recipient': recipient, 'status': status, 'attempts': attempts,
        'last_error': lastError, 'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class SubscriptionState {
  String plan;
  int? validUntil;
  String? provider;
  int? lastVerifiedAt;

  SubscriptionState({
    this.plan = 'FREE', this.validUntil, this.provider, this.lastVerifiedAt,
  });

  factory SubscriptionState.fromMap(Map<String, dynamic>? m) => m == null
      ? SubscriptionState()
      : SubscriptionState(
          plan: (m['plan'] as String?) ?? 'FREE',
          validUntil: (m['valid_until'] as num?)?.toInt(),
          provider: m['provider'] as String?,
          lastVerifiedAt: (m['last_verified_at'] as num?)?.toInt(),
        );

  Map<String, dynamic> toMap() => {
        'id': 1, 'plan': plan, 'valid_until': validUntil,
        'provider': provider, 'last_verified_at': lastVerifiedAt,
      };

  bool get isPro {
    if (plan != 'PRO') return false;
    if (validUntil == null) return true;
    return validUntil! > DateTime.now().millisecondsSinceEpoch;
  }
}

String shortContentHash(Document d, List<DocumentItem> items) {
  final payload = jsonEncode({
    'doc': d.toMap(),
    'items': items.map((i) => i.toMap()).toList(),
  });
  return hashString(payload);
}

String hashString(String s) => sha256.convert(utf8.encode(s)).toString();
