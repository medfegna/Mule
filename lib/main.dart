import 'package:flutter/material.dart';

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
  String selectedSourceLang = 'እንግሊዝኛ (English)';
  String selectedTargetLang = 'አማርኛ (Amharic)';
  String selectedFileName = 'እስካሁን ምንም ፋይል አልተመረጠም';
  
  bool isTranslating = false;
  double progress = 0.0;
  int currentPage = 1;
  int totalPages = 500;

  // የተተረጎመውን ጽሁፍ በስክሪኑ ላይ ለማሳየት የተቀመጠ ናሙና
  List<String> translatedPages = List.generate(
    500,
    (index) => "ገጽ ${index + 1}\n\n"
        "ይህ በ Mulugeta Abye የተገነባው የ Mule Document Translator መተግበሪያ የተረጎመው ሰነድ ገጽ ${index + 1} ነው፡፡\n\n"
        "ሰነዱ ከ $index እስከ ${index + 1} ያሉትን ይዘቶች በሙሉ በተመረጠው ቋንቋ በትክክል በመተርጎም ዝግጁ አድርጎታል።",
  );

  final List<String> languages = [
    'አማርኛ (Amharic)',
    'አፋርኛ (Afar)',
    'ትግርኛ (Tigrinya)',
    'ኦሮምኛ (Afaan Oromo)',
    'እንግሊዝኛ (English)',
    'ስፓኒሽ (Spanish)',
    'ፈረንሳይኛ (French)',
    'አረብኛ (Arabic)',
  ];

  void startTranslation() async {
    setState(() {
      isTranslating = true;
      progress = 0.0;
    });

    for (int i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() {
        progress = i / 10;
      });
    }

    setState(() {
      isTranslating = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ትርጉሙ በተሳካ ሁኔታ ተጠናቋል! ከታች ማየት ይችላሉ።')),
      );
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
            // 1. ፋይል መምረጫ ክፍል
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 48, color: Colors.indigo),
                    const SizedBox(height: 8),
                    Text(
                      selectedFileName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedFileName = ' sample_500_pages_document.pdf (500 ገጾች)';
                        });
                      },
                      icon: const Icon(Icons.folder_open),
                      label: const Text('ሰነድ ይምረጡ (PDF, Word, TXT)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. ቋንቋ መምረጫ
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedSourceLang,
                    decoration: const InputDecoration(labelText: 'ከ (From)', border: OutlineInputBorder()),
                    items: ['እንግሊዝኛ (English)', 'አማርኛ (Amharic)']
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
                    decoration: const InputDecoration(labelText: 'ወደ (To)', border: OutlineInputBorder()),
                    items: languages
                        .map((lang) => DropdownMenuItem(value: lang, child: Text(lang, style: const TextStyle(fontSize: 12))))
                        .toList(),
                    onChanged: (val) => setState(() => selectedTargetLang = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 3. የትርጉም ማስጀመሪያ ቁልፍ
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
                        Text('በመተርጎም ላይ... ${(progress * 100).toInt()}%'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: progress, color: Colors.white),
                      ],
                    )
                  : const Text('ሰነዱን ተርጉም (Translate Document)', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),

            // 4. የተተረጎመውን ፋይል ማሳያ ገጽ (Document Viewer)
            const Text(
              'የተተረጎመው ሰነድ ቅድመ-ዕይታ (Live Preview):',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            const SizedBox(height: 8),

            Container(
              height: 350,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ገጽ $currentPage ከ $totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 18),
                            onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 18),
                            onPressed: currentPage < totalPages ? () => setState(() => currentPage++) : null,
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        translatedPages[currentPage - 1],
                        style: const TextStyle(fontSize: 15, height: 1.5),
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

            // 5. PDF አውርድ ቁልፍ
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF ፋይሉ በስኬት ወርዷል!')),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('የተተረጎመውን 500 ገጽ PDF አውርድ'),
            ),
          ],
        ),
      ),
    );
  }
}
