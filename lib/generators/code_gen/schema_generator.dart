import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:sqlite_orm/annotations/sqlite_annotations.dart';

class SchemaGenerator extends GeneratorForAnnotation<Schema> {
  /// The name of the class.
  late final String classname;

  /// The name of the table.
  late final String table;

  /// The tabs.
  static const String tabs = "\t\t\t\t\t\t\t";

  /// The primary key.
  String? primaryKey;

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Get the class name.
    classname = element.name.toString();
    // Get the name of the table.
    final ConstantReader reader = annotation.read("name");
    table = reader.isString ? reader.stringValue : classname;

    final StringBuffer buffer = StringBuffer();
    // Class start.
    buffer.writeln("class ${table}Provider {");
    buffer.writeln("late final Database db;");
    buffer.writeln(generateAssignDatabase);
    buffer.writeln(generateSchema(element as ClassElement));
    buffer.writeln(generateUpsertOperation);
    buffer.writeln(generateReadOperation);
    // End class.
    buffer.writeln("}");

    return buffer.toString();
  }

  /// Assign database.
  String get generateAssignDatabase {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln("void assignDb(final Database db) {");
    buffer.writeln("this.db = db;");
    buffer.writeln("return;");
    buffer.writeln("}");
    return buffer.toString();
  }

  /// Get the table schema.
  String generateSchema(final ClassElement element) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln("String get schema {");
    buffer.writeln("return '''CREATE TABLE $table IF NOT EXISTS (");
    buffer.writeln(_createFields(element));
    buffer.writeln("\t\t\t\t\t\t)''';");
    buffer.write("}");
    return buffer.toString();
  }

  /// Insert operation.
  String get generateUpsertOperation {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln("Future<void> upsert(final $classname model) async {");
    buffer.writeln("if (model.id == null) {");
    buffer.writeln(
      "await db.update('$table', model.toJson(), where: '$primaryKey = ?', whereArgs: [model.id],);",
    );
    buffer.writeln("return;");
    buffer.writeln("}");
    buffer.writeln("model.id = await db.insert('$table', model.toJson());");
    buffer.writeln("return;");
    buffer.writeln("}");
    return buffer.toString();
  }

  /// Read operation.
  String get generateReadOperation {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln("Future<List<$classname>> read({final int? id}) async {");
    buffer.writeln(
      "final List<Map<String, dynamic>> queryResult = await db.query('$table', where: id != null ? '$primaryKey = ?' : null, whereArgs: id != null ? [id] : null,);",
    );
    buffer.writeln(
      "return queryResult.map((final Map<String, dynamic> json) => $classname.fromJson(json)).toList();",
    );
    buffer.writeln("}");
    return buffer.toString();
  }

  // ------------ Private methods. ------------
  /// Create the schema fields from class fields.
  String _createFields(final ClassElement element) {
    // Foreign key checker.
    const TypeChecker foreignKeyChecker = TypeChecker.fromRuntime(ForeignKey);
    // Primary key checker.
    const TypeChecker primaryKeyChecker = TypeChecker.fromRuntime(PrimaryKey);
    // The buffer.
    final StringBuffer buffer = StringBuffer();
    final List<FieldElement> fields = element.fields;
    final Map<String, ForeignKey> foreignKeys = <String, ForeignKey>{};

    // Loop through all the class fields.
    for (int index = 0; index < fields.length; index++) {
      final FieldElement field = fields.elementAt(index);
      buffer.write("$tabs${field.name} ");
      buffer.write(_sqliteType(field.type));

      // Check if the field is a primary key or not.
      if (primaryKeyChecker.hasAnnotationOfExact(field)) {
        final DartObject? obj = primaryKeyChecker.firstAnnotationOfExact(field);
        final bool autoIncrement;
        autoIncrement = obj?.getField("autoIncrement")?.toBoolValue() ?? true;
        buffer.write(" PRIMARY KEY ${autoIncrement ? "AUTOINCREMENT" : ""}");
        primaryKey = field.name;
      }

      // Check if the field is a foreign key or not.
      if (foreignKeyChecker.hasAnnotationOfExact(field)) {
        final DartObject? obj = foreignKeyChecker.firstAnnotationOfExact(field);
        final String? table = obj?.getField("table")?.toStringValue();
        final String? column = obj?.getField("column")?.toStringValue();
        final bool? cascade = obj?.getField("onDeleteCascade")?.toBoolValue();
        if (table != null && column != null && cascade != null) {
          foreignKeys[field.name] = ForeignKey(table, column, cascade);
        }
      }
      if (index == fields.length - 1) break;
      buffer.writeln(",");
    }

    if (foreignKeys.isEmpty) return buffer.toString();
    buffer.writeln(",");
    for (final MapEntry<String, ForeignKey> entry in foreignKeys.entries) {
      buffer.write(
        "${tabs}FOREIGN KEY (${entry.key}) REFERENCES ${entry.value.table}(${entry.value.column})",
      );
      if (entry.value.onDeleteCascade) buffer.write(" ON DELETE CASCADE");
    }
    return buffer.toString();
  }

  /// Get the sqlite type from the dart type.
  String _sqliteType(final DartType dartType) {
    final bool isRequired;
    isRequired = dartType.nullabilitySuffix != NullabilitySuffix.question;
    final String baseType = dartType.getDisplayString(withNullability: false);
    final String sqliteType;
    switch (baseType) {
      case "int":
        sqliteType = "INTEGER";
      case "String":
        sqliteType = "TEXT";
      case "bool":
        sqliteType = "INTEGER";
      case "Double":
        sqliteType = "REAL";
      default:
        throw StateError("The dart type $dartType is unsupported.");
    }
    return isRequired ? "$sqliteType NOT NULL" : sqliteType;
  }
}
