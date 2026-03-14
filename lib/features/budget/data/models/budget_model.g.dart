// GENERATED CODE - DO NOT MODIFY BY HAND
//
// ARCHITECTURE: Auto-generated Hive adapter.
// Normally produced by: flutter pub run build_runner build
// Written manually here — identical output to what build_runner
// would generate for the @HiveField annotations above.
//
// HOW Hive binary serialization works:
//   write() is called when saving to disk.
//     writeByte(8)   → tells Hive: "8 fields follow"
//     writeByte(0)   → field index (matches @HiveField(0))
//     write(obj.id)  → the actual value
//   read() is called when loading from disk.
//     readByte()     → reads the field count
//     loop reads     → builds a map of fieldIndex → value
//   Field indices are the permanent binary contract. Adding new
//   fields is safe (append new index). Reordering breaks old data.

part of 'budget_model.dart';

class BudgetModelAdapter extends TypeAdapter<BudgetModel> {
  @override
  final int typeId = 1;

  @override
  BudgetModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BudgetModel(
      id:          fields[0] as String,
      category:    fields[1] as String,
      label:       fields[2] as String,
      emoji:       fields[3] as String,
      limitAmount: fields[4] as double,
      currency:    fields[5] as String,
      month:       fields[6] as int,
      year:        fields[7] as int,
    );
  }

  @override
  void write(BinaryWriter writer, BudgetModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.label)
      ..writeByte(3)
      ..write(obj.emoji)
      ..writeByte(4)
      ..write(obj.limitAmount)
      ..writeByte(5)
      ..write(obj.currency)
      ..writeByte(6)
      ..write(obj.month)
      ..writeByte(7)
      ..write(obj.year);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is BudgetModelAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}