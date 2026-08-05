## Flutter GitHub Actions 自动构建 APK 常见坑点
1. drift ORM框架生成的`*.g.dart`文件不要手写，必须在CI流程中执行`dart run build_runner build`自动生成，手写的版本极易出现类型不匹配、API缺失等编译错误。
2. 项目根目录下必须存在`test/`目录和至少一个测试文件，否则`flutter test`步骤会直接报错退出，可新增简单的冒烟测试文件规避。
3. 不要自定义Dart扩展方法覆盖Flutter SDK内置的同名方法，比如List类的`asMap()`，会直接导致类型冲突编译失败。
4. 建议显式新增`analysis_options.yaml`文件配置linter宽松规则，否则默认严格模式下大量无意义的格式警告会升级为错误导致构建终止。
5. services层导入models目录下的数据库定义文件时，注意相对路径不要写为`import 'database.dart'`，必须写为`import '../models/database.dart'`，否则路径解析失败。
6. 使用本地通知插件的`zonedSchedule`方法时，必须传入`TZDateTime`类型而非普通DateTime，需要导入timezone库做类型转换，避免类型不匹配错误。
7. 使用drift的delete/insert/update操作时，注意调用对应的`.go()`方法执行，不要混用`.get()`方法，否则会返回Future对象直接赋值给int类型时报错。
