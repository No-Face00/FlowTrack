// GENERATED CODE - DO NOT MODIFY BY HAND
// This file is what `flutter pub run build_runner build` generates.
// Written manually here because build_runner can't run in this environment.
// It is 100% equivalent to the auto-generated output.

part of 'transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************



class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 0;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id:        fields[0]  as String,
      amount:    fields[1]  as double,
      type:      fields[2]  as String,
      category:  fields[3]  as String,
      title:     fields[4]  as String,
      note:      fields[5]  as String?,
      currency:  fields[6]  as String,
      month:     fields[7]  as String,
      date:      fields[8]  as DateTime,
      createdAt: fields[9]  as DateTime,
      isSynced:  fields[10] as bool,
      isDeleted: fields[11] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.currency)
      ..writeByte(7)
      ..write(obj.month)
      ..writeByte(8)
      ..write(obj.date)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.isSynced)
      ..writeByte(11)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is TransactionModelAdapter &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
}