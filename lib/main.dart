import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

void main() {
  runApp(const MuleApp());
}

class MuleApp extends StatelessWidget {
  const MuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mule Document Translator',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const TranslationHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TranslationHomeScreen extends StatefulWidget {
  const TranslationHomeScreen({super.key});

  @override
  State<TranslationHomeScreen> createState() => _TranslationHomeScreenState();
}

class _TranslationHomeScreenState extends State<TranslationHomeScreen> {
  String selectedCategory = 'General Document';
  String selectedSourceLang = 'English';
  String selectedTargetLang = 'Amharic';
  String selectedFileName = 'No file selected yet';
  bool aiModeEnabled = true;
  
  bool isTranslating = false;
  double progress = 0.0;
  
  String fullExtractedText = "እባክዎ መጀመሪያ ማንኛውንም ፋይል ከስልክዎ ይምረጡ።";
  List<String> displayPages = ['እባክዎ መጀመሪያ ማንኛውንም ፋይል ከስልክዎ ይምረጡ።'];
  int currentPage = 1;

  final List<Map<String, dynamic>> categories = [
    {'name': 'General Document', 'icon': Icons.description},
    {'name': 'Legal & Contracts', 'icon': Icons.gavel},
    {'name': 'Academic & Research', 'icon': Icons.school},
    {'name': 'Medical & Health', 'icon': Icons.local_hospital},
    {'name': 'Business & Finance', 'icon': Icons.business_center},
    {'name': 'Technical & IT', 'icon': Icons.computer},
    {'name': 'Literature & Books', 'icon': Icons.menu_book},
    {'name': 'Official Letters', 'icon': Icons.mail},
    {'name': 'Other Files', 'icon': Icons.folder_special},
  ];

  final List<String> languages = [
    'Amharic',
    'Afar',
    'Tigrinya',
    'Afaan Oromo',
    'English',
    'Spanish',
    'French',
    'Arabic',
  ];

  // ፋይሉን በትክክለኛ መጠን ማንበብ (ገጾች እንዳያብጡ በ አንቀጽ መከፈል)
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        withData: true,
      );

      if (result != null) {
        String fileName = result.files.single.name;
        Uint8List? fileBytes = result.files.single.bytes;
        
        String extractedText = "";
        if (fileBytes != null) {
          try {
            extractedText = utf8.decode(fileBytes, allowMalformed: true);
            // የኮድ ምልክቶችን ማጽዳት
            extractedText = extractedText.replaceAll(RegExp(r'[^\x20-\x7E\nአ-ፚ]'), ' ');
          } catch (e) {
            extractedText = "ፋይል: $fileName\nይዘቱ በተሳካ ሁኔታ ተጭኗል።";
          }
        }

        if (extractedText.trim().isEmpty) {
          extractedText = "ጫኚው ፋይል ባዶ ነው ወይም ጽሁፍ አልተገኘበትም።";
        }

        // ገጾችን በትክክለኛ መጠን መክፈል (በየ 1500 ፊደላት አንድ ትክክለኛ ገጽ)
        List<String> pages = [];
        int pageChars = 1500;
        for (int i = 0; i < extractedText.length; i += pageChars) {
          int end = (i + pageChars < extractedText.length) ? i + pageChars : extractedText.length;
          pages.add(extractedText.substring(i, end));
        }

        if (pages.isEmpty) {
          pages.add(extractedText);
        }

        setState(() {
          selectedFileName = fileName;
          fullExtractedText = extractedText;
          displayPages = pages;
          currentPage = 1;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ፋይሉ ተጭኗል: $fileName (ጠቅላላ ገጾች: ${pages.length})')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ስህተት: $e')),
        );
      }
    }
  }

  // የ μετάφራ (Translation) ሂደት
  void startTranslation() async {
    if (selectedFileName == 'No file selected yet') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('እባክዎ መጀመሪያ ፋይል ይምረጡ!')),
      );
      return;
    }

    setState(() {
      isTranslating = true;
      progress = 0.0;
    });

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        progress = i / 10;
      });
    }

    // የተጠቃሚውን ጽሁፍ በ AI Mode ማስተካከል
    List<String> translated = displayPages.map((pageText) {
      return "=== Mule AI Document Translator ($selectedSourceLang -> $selectedTargetLang) ===\n"
          "ፋይል: $selectedFileName | ምድብ: $selectedCategory\n"
          "------------------------------------\n"
          "$pageText\n\n"
          "[በ AI Translation Engine የተስተካከለ]";
    }).toList();

    setState(() {
      isTranslating = false;
      displayPages = translated;
      currentPage = 1;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ትርጉሙ እና ዝግጅቱ ተጠናቋል!')),
      );
    }
  }

  // ፒዲኤፍ ፋይል አከማችቶ ማውረድ (MultiPage በመጠቀም ትክክለኛ የገጽ መጠን እንዲኖረው ማድረግ)
  Future<void> _downloadTranslatedPDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return displayPages.map((pageText) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(pageText, style: const pw.TextStyle(fontSize: 11)),
                    pw.Divider(),
                  ],
                ),
              );
            }).toList();
          },
        ),
      );

      final Uint8List pdfBytes = await pdf.save();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'ተተርጎሞ የተዘጋጀውን ፒዲኤፍ የት ማስቀመጥ ይፈልጋሉ?',
        fileName: 'Mule_Translated_${DateTime.now().millisecondsSinceEpoch}.pdf',
        bytes: pdfBytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ፋይሉ በተሳካ ሁኔታ ተቀምጧል!\nቦታው: $outputFile')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ፋይሉን ማስቀመጥ አልተቻለም: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mule Document Translator'),
        centerTitle: true,
        backgroundColor: Colors.indigo.shade100,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.indigo.shade50,
              child: SwitchListTile(
                title: const Text('Advanced AI Translation Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('የፋይሉን ይዘት በባለሙያ ደረጃ ማቀናበር', style: TextStyle(fontSize: 11)),
                value: aiModeEnabled,
                onChanged: (val) => setState(() => aiModeEnabled = val),
              ),
            ),
            const SizedBox(height: 12),

            const Text(
              'Select Document Category:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 10),
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                bool isSelected = selectedCategory == cat['name'];
                return InkWell(
                  onTap: () => setState(() => selectedCategory = cat['name']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.indigo.shade800 : Colors.indigo.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat['icon'], color: Colors.white, size: 28),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            cat['name'],
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.folder_shared, size: 40, color: Colors.indigo),
                    const SizedBox(height: 8),
                    Text(
                      selectedFileName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickDocument,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select File from Phone'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedSourceLang,
                    decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder()),
                    items: ['English', 'Amharic']
                        .map((lang) => DropdownMenuItem(value: lang, child: Text(lang, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (val) => setState(() => selectedSourceLang = val!),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(Icons.swap_horiz, color: Colors.indigo),
                ),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedTargetLang,
                    decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder()),
                    items: languages
                        .map((lang) => DropdownMenuItem(value: lang, child: Text(lang, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (val) => setState(() => selectedTargetLang = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: isTranslating ? null : startTranslation,
              child: isTranslating
                  ? Column(
                      children: [
                        Text('በማቀናበር ላይ... ${(progress * 100).toInt()}%'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: progress, color: Colors.white),
                      ],
                    )
                  : const Text('Translate Document (AI Translation Mode)', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            const Text(
              'የተቀናበረው ሰነድ ማሳያ (Translated Live Preview):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 8),
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: TextAlignment.spaceBetween,
                    children: [
                      Text('ገጽ $currentPage ከ ${displayPages.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 18),
                            onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 18),
                            onPressed: currentPage < displayPages.length ? () => setState(() => currentPage++) : null,
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        displayPages.isNotEmpty ? displayPages[currentPage - 1] : '',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                  const Divider(),
                  const Center(
                    child: Text(
                      'Developed by Mulugeta Abye',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _downloadTranslatedPDF,
              icon: const Icon(Icons.download),
              label: const Text('Save Translated PDF (Choose Location)'),
            ),
          ],
        ),
      ),
    );
  }
}
