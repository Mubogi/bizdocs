import 'dart:convert';
import 'package:crypto/crypto.dart';

// Money is stored as INTEGER minor units (whole UGX shillings by default).

enum DocType {
  invoice, receipt, quotation, letter,
  estimate, deliveryNote, proforma, uraReceipt, reminder
}

enum DocStatus { draft, issued, partial, paid, signed, locked, cancelled }

DocType docTypeFromString(String v) =>
    DocType.values.firstWhere((e) => e.name == v.toUpperCase());

String docTypeLabel(DocType t) => {
  DocType.invoice: 'Invoice',
  DocType.receipt: 'Receipt',
  DocType.quotation: 'Quotation',
  DocType.letter: 'Letter',
  DocType.estimate: 'Estimate',
  DocType.deliveryNote: 'Delivery Note',
  DocType.proforma: 'Proforma Invoice',
  DocType.uraReceipt: 'E-Receipt (URA)',
  DocType.reminder: 'Payment Reminder',
}[t]!;

String docTypePrefix(DocType t) => {
  DocType.invoice: 'INV',
  DocType.receipt: 'RCT',
  DocType.quotation: 'QTO',
  DocType.letter: 'LTR',
  DocType.estimate: 'EST',
  DocType.deliveryNote: 'DLV',
  DocType.proforma: 'PRF',
  DocType.uraReceipt: 'URA',
  DocType.reminder: 'REM',
}[t]!;

const List<DocType> kItemDocTypes = [
  DocType.invoice, DocType.receipt, DocType.quotation,
  DocType.estimate, DocType.proforma, DocType.uraReceipt,
  DocType.deliveryNote
];

String wordsToEnglish(int value) {
  const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven',
    'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen',
    'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty',
    'Sixty', 'Seventy', 'Eighty', 'Ninety'];
  String two(int n) {
    if (n < 20) return ones[n];
    final t = n ~/ 10, r = n % 10;
    return r == 0 ? tens[t] : '${tens[t]}-${ones[r]}';
  }
  String three(int n) {
    final h = n ~/ 100, r = n % 100;
    var out = '';
    if (h > 0) out = '${ones[h]} Hundred';
    if (r > 0) out = out.isEmpty ? two(r) : '$out ${two(r)}';
    return out;
  }
  if (value == 0) return 'Zero';
  String result = '';
  int v = value;
  final scales = [1000000000000, 1000000000, 1000000, 1000];
  final names = ['Trillion', 'Billion', 'Million', 'Thousand'];
  for (var i = 0; i < scales.length; i++) {
    final chunk = v ~/ scales[i];
    if (chunk > 0) result +=
        '${result.isEmpty ? '' : ' '}${three(chunk)} ${names[i]}';
    v %= scales[i];
  }
  if (v > 0) result += result.isEmpty ? three(v) : ' ${three(v)}';
  return result;
}

class Business {
  String id;
  String name;
  String? tin;
  String? address;
  String? phone;
  String? whatsapp;
  String? email;
  String? logoPath;
  String? bankName;
  String? bankAccountName;
  String? bankAccountNo;
  String? mobileMoneyNumber;
  String? mobileMoneyProvider;
  String? merchantCode;
  String? templateJson;
  String currency;
  String language;
  String? termsTemplate;
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
    this.logoPath,
    this.bankName,
    this.bankAccountName,
    this.bankAccountNo,
    this.mobileMoneyNumber,
    this.mobileMoneyProvider,
    this.merchantCode,
    this.templateJson,
    this.currency = 'UGX',
    this.language = 'en',
    this.termsTemplate,
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
        logoPath: m['logo_path'] as String?,
        bankName: m['bank_name'] as String?,
        bankAccountName: m['bank_account_name'] as String?,
        bankAccountNo: m['bank_account_no'] as String?,
        mobileMoneyNumber: m['mobile_money_number'] as String?,
        mobileMoneyProvider: m['mobile_money_provider'] as String?,
        merchantCode: m['merchant_code'] as String?,
        templateJson: m['template_json'] as String?,
        currency: (m['currency'] as String?) ?? 'UGX',
        language: (m['language'] as String?) ?? 'en',
        termsTemplate: m['terms_template'] as String?,
        defaultTaxPercent: (m['default_tax_percent'] as num?)?.toDouble() ?? 0,
        createdAt: m['created_at'] as int,
        updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'tin': tin, 'address': address, 'phone': phone,
        'whatsapp': whatsapp, 'email': email, 'logo_path': logoPath,
        'bank_name': bankName, 'bank_account_name': bankAccountName,
        'bank_account_no': bankAccountNo,
        'mobile_money_number': mobileMoneyNumber,
        'mobile_money_provider': mobileMoneyProvider,
        'merchant_code': merchantCode,
        'template_json': templateJson,
        'currency': currency,
        'language': language,
        'terms_template': termsTemplate,
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
  String? barcode;
  String? description;
  int unitPrice;
  int? costPrice;
  double? taxPercent;
  bool trackStock;
  double? stockQty;
  int createdAt;
  int updatedAt;

  Product({
    required this.id, required this.businessId, required this.name,
    this.sku, this.barcode, this.description, required this.unitPrice,
    this.costPrice, this.taxPercent,
    this.trackStock = false, this.stockQty,
    required this.createdAt, required this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String, businessId: m['business_id'] as String,
        name: m['name'] as String, sku: m['sku'] as String?,
        barcode: m['barcode'] as String?,
        description: m['description'] as String?,
        unitPrice: m['unit_price'] as int,
        costPrice: (m['cost_price'] as num?)?.toInt(),
        taxPercent: (m['tax_percent'] as num?)?.toDouble(),
        trackStock: (m['track_stock'] as int?) == 1,
        stockQty: (m['stock_qty'] as num?)?.toDouble(),
        createdAt: m['created_at'] as int, updatedAt: m['updated_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'business_id': businessId, 'name': name, 'sku': sku,
        'barcode': barcode, 'description': description, 'unit_price': unitPrice,
        'cost_price': costPrice,
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
  int discountTotal;
  int chargeTotal;
  int total;
  String currency;
  String? convertTo;
  int? issueDate2; // reserved
  String? linkedDocId;
  String? pdfPath;
  String? hash;
  String? terms;
  String? attachmentsJson;
  bool locked;
  int createdAt;
  int updatedAt;
  bool synced;

  Document({
    required this.id, required this.businessId, this.customerId,
    required this.docType, required this.docNumber,
    this.status = 'DRAFT', this.content, required this.issueDate,
    this.dueDate, this.subtotal = 0, this.taxTotal = 0,
    this.discountTotal = 0, this.chargeTotal = 0,
    this.total = 0, this.currency = 'UGX', this.convertTo,
    this.issueDate2, this.linkedDocId, this.pdfPath, this.hash,
    this.terms, this.attachmentsJson, this.locked = false,
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
        discountTotal: (m['discount_total'] as num?)?.toInt() ?? 0,
        chargeTotal: (m['charge_total'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        currency: (m['currency'] as String?) ?? 'UGX',
        convertTo: m['convert_to'] as String?,
        linkedDocId: m['linked_doc_id'] as String?,
        pdfPath: m['pdf_path'] as String?, hash: m['hash'] as String?,
        terms: m['terms'] as String?,
        attachmentsJson: m['attachments_json'] as String?,
        locked: (m['locked'] as int?) == 1,
        createdAt: m['created_at'] as int, updatedAt: m['updated_at'] as int,
        synced: (m['synced'] as int?) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'business_id': businessId, 'customer_id': customerId,
        'doc_type': docType.name.toUpperCase(), 'doc_number': docNumber,
        'status': status, 'content': content, 'issue_date': issueDate,
        'due_date': dueDate, 'subtotal': subtotal, 'tax_total': taxTotal,
        'discount_total': discountTotal, 'charge_total': chargeTotal,
        'total': total, 'currency': currency, 'convert_to': convertTo,
        'pdf_path': pdfPath, 'hash': hash,
        'linked_doc_id': linkedDocId,
        'terms': terms, 'attachments_json': attachmentsJson,
        'locked': locked ? 1 : 0,
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
  double? discountPercent;
  int? discountAmount;
  double? taxPercent;
  int lineTotal;

  DocumentItem({
    required this.id, required this.documentId, this.productId,
    required this.description, required this.quantity,
    required this.unitPrice, this.discountPercent, this.discountAmount,
    this.taxPercent, required this.lineTotal,
  });

  factory DocumentItem.fromMap(Map<String, dynamic> m) => DocumentItem(
        id: m['id'] as String, documentId: m['document_id'] as String,
        productId: m['product_id'] as String?,
        description: m['description'] as String,
        quantity: (m['quantity'] as num).toDouble(),
        unitPrice: (m['unit_price'] as num).toInt(),
        discountPercent: (m['discount_percent'] as num?)?.toDouble(),
        discountAmount: (m['discount_amount'] as num?)?.toInt(),
        taxPercent: (m['tax_percent'] as num?)?.toDouble(),
        lineTotal: (m['line_total'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'document_id': documentId, 'product_id': productId,
        'description': description, 'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
        'tax_percent': taxPercent, 'line_total': lineTotal,
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

class Expense {
  String id;
  String businessId;
  String narration;
  int amount;
  String category;
  String currency;
  String? docId;
  int expenseAt;
  int createdAt;

  Expense({
    required this.id, required this.businessId, required this.narration,
    required this.amount, this.category = 'EXPENSE',
    this.currency = 'UGX', this.docId, required this.expenseAt,
    required this.createdAt,
  });

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as String,
        businessId: m['business_id'] as String,
        narration: m['narration'] as String,
        amount: (m['amount'] as num).toInt(),
        category: (m['category'] as String?) ?? 'EXPENSE',
        currency: (m['currency'] as String?) ?? 'UGX',
        docId: m['doc_id'] as String?,
        expenseAt: m['expense_at'] as int,
        createdAt: m['created_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'business_id': businessId, 'narration': narration,
        'amount': amount, 'category': category, 'currency': currency,
        'doc_id': docId, 'expense_at': expenseAt,
        'created_at': createdAt,
      };
}

class DocSeries {
  String businessId;
  DocType docType;
  int nextNumber;
  String prefix;

  DocSeries({
    required this.businessId, required this.docType,
    required this.nextNumber, required this.prefix,
  });

  factory DocSeries.fromMap(Map<String, dynamic> m) => DocSeries(
        businessId: m['business_id'] as String,
        docType: docTypeFromString(m['doc_type'] as String),
        nextNumber: (m['next_number'] as num).toInt(),
        prefix: (m['prefix'] as String?) ?? docTypePrefix(
            docTypeFromString(m['doc_type'] as String)),
      );
}

class RecurringInvoice {
  String id;
  String businessId;
  String? customerId;
  String docType;
  String itemsJson;
  String currency;
  int amount;
  int intervalDays;
  int nextDue;
  bool active;
  int createdAt;

  RecurringInvoice({
    required this.id, required this.businessId, this.customerId,
    required this.docType, required this.itemsJson,
    this.currency = 'UGX', required this.amount,
    this.intervalDays = 30, required this.nextDue,
    this.active = true, required this.createdAt,
  });

  factory RecurringInvoice.fromMap(Map<String, dynamic> m) => RecurringInvoice(
        id: m['id'] as String, businessId: m['business_id'] as String,
        customerId: m['customer_id'] as String?,
        docType: (m['doc_type'] as String?) ?? 'INVOICE',
        itemsJson: m['items_json'] as String,
        currency: (m['currency'] as String?) ?? 'UGX',
        amount: (m['amount'] as num).toInt(),
        intervalDays: (m['interval_days'] as num?)?.toInt() ?? 30,
        nextDue: m['next_due'] as int,
        active: (m['active'] as int?) == 1,
        createdAt: m['created_at'] as int,
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'business_id': businessId, 'customer_id': customerId,
        'doc_type': docType, 'items_json': itemsJson, 'currency': currency,
        'amount': amount, 'interval_days': intervalDays, 'next_due': nextDue,
        'active': active ? 1 : 0, 'created_at': createdAt,
      };
}

String shortContentHash(Document d, List<DocumentItem> items) {
  final payload = jsonEncode({
    'doc': d.toMap(),
    'items': items.map((i) => i.toMap()).toList(),
  });
  return hashString(payload);
}

String hashString(String s) => sha256.convert(utf8.encode(s)).toString();
