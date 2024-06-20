library sqlite_orm_generator;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:sqlite_orm/generators/code_gen/schema_generator.dart';

Builder getSqlOrmGenerator(final BuilderOptions options) {
  return SharedPartBuilder([SchemaGenerator()], "sqlite_orm_generator");
}