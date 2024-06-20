import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/visitor.dart';

class ClassVisitor extends SimpleElementVisitor<void> {
  String name = "";
  final Map<String, String> fields = <String, String>{};

  @override
  void visitConstructorElement(ConstructorElement element) {
    final String type = element.returnType.toString();
    name = type;
  }

  @override
  void visitFieldElement(final FieldElement element) {
    fields[element.name] = element.type.toString();
  }
}
