# Flutter drift + Riverpod 常见编译错误修复经验

## drift 数据库修复
1. 数据库初始化：File对象需用`NativeDatabase.createInBackground()`包装为QueryExecutor，导入`package:drift/native.dart`
2. 删除操作：DeleteStatement无`.get()`方法，替换为`.go()`执行返回影响行数
3. 时区通知：zonedSchedule需传入TZDateTime，导入timezone包，初始化调用`initializeTimeZones()`，转换为`TZDateTime.from(xxx, local)`
4. 扩展方法未定义：Dart Extension需显式导入定义扩展的文件，仅导入类型文件不生效
5. 自定义模型未导出：业务组合模型需手动import，drift生成的database.dart不会自动导出
6. Value&lt;T&gt;类型错误：insert Companion所有字段统一用Value()包装

## Riverpod 2.x 修复
1. StateNotifierProvider构造函数若无需参数，不要用`.new`，传入lambda`(ref) => Notifier()`避免签名不匹配
2. 带参数场景必须用`StateNotifierProvider.family`，不能直接把Notifier类当函数传ref.watch
3. 控制器类名（xxxNotifier）不能直接作为Provider使用，必须定义全局小写开头的Provider变量

## lint清理
移除所有unused import、unused variable警告，校验所有相对导入路径正确性