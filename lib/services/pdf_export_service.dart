import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/mistake.dart';

/// PDF 导出服务 - 将易错点导出为 PDF 文件
class PdfExportService {
  /// 按科目导出易错点为 PDF
  /// [subjectName] 科目名称
  /// [mistakes] 该科目下的易错点列表
  /// 返回生成的 PDF 文件路径，失败返回 null
  static Future<String?> exportSubjectToPdf({
    required String subjectName,
    required List<MistakeWithSubject> mistakes,
  }) async {
    try {
      final pdf = pw.Document();

      // 封面/标题页
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(children: _buildTitlePage(subjectName, mistakes.length)),
        ),
      );

      // 内容页 - 每个易错点一个 section
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => _buildContentPages(mistakes),
        ),
      );

      // 保存到本地
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${subjectName}_错题本_$timestamp.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      debugPrint('PDF 导出成功: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('PDF 导出失败: $e');
      return null;
    }
  }

  /// 构建标题页
  static List<pw.Widget> _buildTitlePage(String subjectName, int count) {
    return [
      pw.SizedBox(height: 100),
      pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.SizedBox(height: 30),
            pw.Text(
              '$subjectName 错题本',
              style: pw.TextStyle(
                fontSize: 36,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              '共 $count 个易错点',
              style: const pw.TextStyle(
                fontSize: 18,
                color: PdfColors.grey,
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              '导出时间: ${_formatNow()}',
              style: const pw.TextStyle(
                fontSize: 14,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              '学助 App 生成',
              style: const pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey400,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// 构建内容页
  static List<pw.Widget> _buildContentPages(List<MistakeWithSubject> mistakes) {
    final widgets = <pw.Widget>[];

    for (var i = 0; i < mistakes.length; i++) {
      final item = mistakes[i];
      final mistake = item.mistake;

      // 标题
      widgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${i + 1}. ${mistake.title}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      widgets.add(pw.SizedBox(height: 8));

      // 元信息
      final metaParts = <String>[];
      if (mistake.chapter.isNotEmpty) {
        metaParts.add('章节: ${mistake.chapter}');
      }
      metaParts.add('难度: ${"*" * mistake.difficultyLevel}${"-" * (5 - mistake.difficultyLevel)}');
      metaParts.add('复习: ${mistake.reviewCount} 次');
      metaParts.add(mistake.nextReviewDate == null ? '状态: 待复习' : '状态: 已安排');

      widgets.add(
        pw.Text(
          metaParts.join('  |  '),
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      );
      widgets.add(pw.SizedBox(height: 6));

      // 描述
      if (mistake.description.isNotEmpty) {
        widgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              mistake.description,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));
      }

      // 标签
      final tags = item.tagList;
      if (tags.isNotEmpty) {
        widgets.add(
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: tags.map((tag) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                tag,
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            )).toList(),
          ),
        );
        widgets.add(pw.SizedBox(height: 6));
      }

      // 分割线
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 12),
          child: pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ),
      );
    }

    // 底部统计
    widgets.add(pw.SizedBox(height: 20));
    final reviewCompleted = mistakes.where((m) => !m.needsReview).length;
    widgets.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(16),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '统计摘要',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('总易错点: ${mistakes.length} 个', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('已掌握: $reviewCompleted 个', style: const pw.TextStyle(fontSize: 12)),
            pw.Text('待复习: ${mistakes.length - reviewCompleted} 个', style: const pw.TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );

    return widgets;
  }

  static String _formatNow() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }
}
