double parseDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

int parseInt(dynamic v) =>
    v is int ? v : v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
