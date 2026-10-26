import 'package:flutter/services.dart';

/// 用户从文件管理器挑出来的一个词库文件
class PickedBankFile {
  final String name;
  final String content;

  const PickedBankFile(this.name, this.content);
}

/// 词库持久化接口。
///
/// 抽出来有两个用处：测试里换成内存实现；以后换存储方式（文档目录、云同步）
/// 只改这一层，注册表和界面都不用动。
abstract class BankStorage {
  /// 已导入词库的 id 列表
  Future<List<String>> listImported();

  /// 读某个导入词库的原始 JSON；不存在返回 null
  Future<String?> read(String id);

  /// 写入或覆盖
  Future<void> write(String id, String json);

  /// 删除；不存在也算成功
  Future<void> delete(String id);

  /// 导入库的索引（只有元信息，启动时读这个就能列出词库，不用读全部单词）
  Future<String?> readIndex();
  Future<void> writeIndex(String json);

  /// 让用户从系统文件管理器挑一个词库文件；取消返回 null
  Future<PickedBankFile?> pickFile();
}

/// Android 实现：文件放在 App 私有目录 `files/banks/` 下，
/// 走 MainActivity 的 MethodChannel（不引第三方插件）。
class PlatformBankStorage implements BankStorage {
  static const MethodChannel _channel = MethodChannel('langobei/bank');

  const PlatformBankStorage();

  @override
  Future<List<String>> listImported() async {
    final ids = await _channel.invokeMethod<List<Object?>>('listBanks') ?? const [];
    return [
      for (final id in ids)
        if (id is String) id,
    ];
  }

  @override
  Future<String?> read(String id) async =>
      await _channel.invokeMethod<String>('readBank', {'id': id});

  @override
  Future<void> write(String id, String json) async {
    await _channel.invokeMethod<void>('writeBank', {'id': id, 'content': json});
  }

  @override
  Future<void> delete(String id) async {
    await _channel.invokeMethod<void>('deleteBank', {'id': id});
  }

  @override
  Future<String?> readIndex() async => await _channel.invokeMethod<String>('readIndex');

  @override
  Future<void> writeIndex(String json) async {
    await _channel.invokeMethod<void>('writeIndex', {'content': json});
  }

  @override
  Future<PickedBankFile?> pickFile() async {
    final data = await _channel.invokeMapMethod<String, Object?>('pickBankFile');
    if (data == null) return null;
    final content = data['content'];
    if (content is! String) return null;
    final name = data['name'];
    return PickedBankFile(
      name is String && name.trim().isNotEmpty ? name.trim() : 'imported.json',
      content,
    );
  }
}

/// 测试用：全部放内存里
class MemoryBankStorage implements BankStorage {
  final Map<String, String> banks = {};
  String? index;
  PickedBankFile? pickResult;
  int pickCalls = 0;

  @override
  Future<List<String>> listImported() async => banks.keys.toList()..sort();

  @override
  Future<String?> read(String id) async => banks[id];

  @override
  Future<void> write(String id, String json) async {
    banks[id] = json;
  }

  @override
  Future<void> delete(String id) async {
    banks.remove(id);
  }

  @override
  Future<String?> readIndex() async => index;

  @override
  Future<void> writeIndex(String json) async {
    index = json;
  }

  @override
  Future<PickedBankFile?> pickFile() async {
    pickCalls++;
    return pickResult;
  }
}
