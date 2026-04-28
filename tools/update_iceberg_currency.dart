import 'dart:io';

const rootPath = r'C:\Users\knrib\Flutter\iceberg_app';

void main() {
  writeCurrencyUtility();

  updateFile(
    relativePath: r'lib\src\features\pos\presentation\pos_screen.dart',
    importAnchor: "import 'package:go_router/go_router.dart';",
    importLine: "import '../../../core/utils/currency.dart';",
    replacements: {
      r"'\$${cart.totalPrice.toStringAsFixed(2)}'":
          'formatCurrency(cart.totalPrice)',
      r"'\$${product.price.toStringAsFixed(2)}'":
          'formatCurrency(product.price)',
      r"'\$${item.subtotal.toStringAsFixed(2)}'":
          'formatCurrency(item.subtotal)',
    },
  );

  updateFile(
    relativePath:
        r'lib\src\features\pos\presentation\widgets\modifier_modal.dart',
    importAnchor: "import 'package:flutter/material.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      'Waffle Cone (+0.50)': r'Waffle Cone (+\u20B10.50)',
      r"'\$${widget.product.price.toStringAsFixed(2)}'":
          'formatCurrency(widget.product.price)',
    },
  );

  updateFile(
    relativePath:
        r'lib\src\features\pos\presentation\widgets\receipt_dialog.dart',
    importAnchor: "import 'package:intl/intl.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      r"'\$${item.subtotal.toStringAsFixed(2)}'":
          'formatCurrency(item.subtotal)',
      r"'\$${order.totalPrice.toStringAsFixed(2)}'":
          'formatCurrency(order.totalPrice)',
    },
  );

  updateFile(
    relativePath:
        r'lib\src\features\pos\presentation\widgets\payment_dialog.dart',
    importAnchor: "import 'package:flutter/material.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      r"'\$${widget.totalAmount.toStringAsFixed(2)}'":
          'formatCurrency(widget.totalAmount)',
      r"'\$${_change.abs().toStringAsFixed(2)}'":
          'formatCurrency(_change.abs())',
      r"'\$$amount'": 'formatCurrency(amount, decimalDigits: 0)',
      "prefixText: 'â‚± ',": r"prefixText: '\u20B1 ',",
      "prefixText: '₱ ',": r"prefixText: '\u20B1 ',",
    },
  );

  updateFile(
    relativePath: r'lib\src\features\pos\presentation\clock_out_screen.dart',
    importAnchor: "import 'package:iceberg_app/src/core/theme/iceberg_theme.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      r"'\$${systemTotal.toStringAsFixed(2)}'":
          'formatCurrency(systemTotal)',
      r"'\$${cashTotal.toStringAsFixed(2)}'": 'formatCurrency(cashTotal)',
      r"'\$${gcashTotal.toStringAsFixed(2)}'": 'formatCurrency(gcashTotal)',
      r"'\$${cardTotal.toStringAsFixed(2)}'": 'formatCurrency(cardTotal)',
      r"'\$0.00'": 'formatCurrency(0)',
      r"'\$${(systemTotal / todaysOrders.length).toStringAsFixed(2)}'":
          'formatCurrency(systemTotal / todaysOrders.length)',
      r"'\$${discrepancy.abs().toStringAsFixed(2)}'":
          'formatCurrency(discrepancy.abs())',
      "prefixText: 'â‚± ',": r"prefixText: '\u20B1 ',",
      "prefixText: '₱ ',": r"prefixText: '\u20B1 ',",
    },
  );

  updateFile(
    relativePath:
        r'lib\src\features\admin\presentation\widgets\admin_overview_content.dart',
    importAnchor: "import 'package:flutter_riverpod/flutter_riverpod.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      r"'\$${p.revenue.toStringAsFixed(2)}'": 'formatCurrency(p.revenue)',
      r"'\$${analytics.todaysSales.toStringAsFixed(2)}'":
          'formatCurrency(analytics.todaysSales)',
      r"'\$${analytics.averageOrderValue.toStringAsFixed(2)}'":
          'formatCurrency(analytics.averageOrderValue)',
      'Icons.attach_money': 'Icons.payments_outlined',
    },
  );

  updateFile(
    relativePath:
        r'lib\src\features\admin\presentation\widgets\order_history_content.dart',
    importAnchor: "import 'package:intl/intl.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      r"'Total: \$${orders.fold(0.0, (sum, o) => sum + o.totalPrice).toStringAsFixed(2)}'":
          r"'Total: ${formatCurrency(orders.fold(0.0, (sum, o) => sum + o.totalPrice))}'",
      r"'\$${order.totalPrice.toStringAsFixed(2)}'":
          'formatCurrency(order.totalPrice)',
    },
  );

  updateFile(
    relativePath:
        r'lib\src\features\admin\presentation\widgets\order_detail_dialog.dart',
    importAnchor: "import 'package:intl/intl.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      r"'\$${item.subtotal.toStringAsFixed(2)}'":
          'formatCurrency(item.subtotal)',
      r"'\$${order.totalPrice.toStringAsFixed(2)}'":
          'formatCurrency(order.totalPrice)',
    },
  );

  updateFile(
    relativePath:
        r'lib\src\features\admin\presentation\widgets\product_management_content.dart',
    importAnchor: "import 'package:flutter_riverpod/flutter_riverpod.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      r"'\$${product.price.toStringAsFixed(2)}'":
          'formatCurrency(product.price)',
      r"'Cost: \$${product.cost.toStringAsFixed(2)}'":
          r"'Cost: ${formatCurrency(product.cost)}'",
    },
  );

  updateFile(
    relativePath:
        r'lib\src\features\admin\presentation\widgets\sales_line_chart.dart',
    importAnchor: "import 'package:intl/intl.dart';",
    importLine: "import 'package:iceberg_app/src/core/utils/currency.dart';",
    replacements: {
      r"'\$${value.toInt()}'": 'formatCompactCurrency(value)',
      r"'\$${spot.y.toStringAsFixed(2)}'": 'formatCurrency(spot.y)',
    },
  );

  stdout.writeln('Iceberg peso patch applied.');
}

void writeCurrencyUtility() {
  final file = File(
    p(r'lib\src\core\utils\currency.dart'),
  );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    '''
import 'package:intl/intl.dart';

final NumberFormat _pesoCurrencyFormatter = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '\\u20B1',
  decimalDigits: 2,
);

String formatCurrency(num amount, {int decimalDigits = 2}) {
  if (decimalDigits == 2) {
    return _pesoCurrencyFormatter.format(amount);
  }

  return NumberFormat.currency(
    locale: 'en_PH',
    symbol: '\\u20B1',
    decimalDigits: decimalDigits,
  ).format(amount);
}

String formatCompactCurrency(num amount) {
  final absoluteAmount = amount.abs();
  final sign = amount < 0 ? '-' : '';

  if (absoluteAmount >= 1000) {
    final scaled = absoluteAmount / 1000;
    final suffixValue = scaled >= 10 || scaled == scaled.roundToDouble()
        ? scaled.toStringAsFixed(0)
        : scaled.toStringAsFixed(1);
    return '\${sign}\\u20B1\${suffixValue}k';
  }

  return '\${sign}\${formatCurrency(absoluteAmount, decimalDigits: 0)}';
}
''',
  );
}

void updateFile({
  required String relativePath,
  required String importAnchor,
  required String importLine,
  required Map<String, String> replacements,
}) {
  final file = File(p(relativePath));
  var content = file.readAsStringSync();

  if (!content.contains(importLine)) {
    content = content.replaceFirst(importAnchor, '$importAnchor\n$importLine');
  }

  replacements.forEach((from, to) {
    content = content.replaceAll(from, to);
  });

  file.writeAsStringSync(content);
}

String p(String relativePath) => '$rootPath\\$relativePath';
