import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:translator/translator.dart';

void main() {
  runApp(const MuleApp());
}

class MuleApp extends StatelessWidget {
  const MuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mule AI Document Translator',
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

class _TranslationHomeScreenState extends State<TranslationHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  final TextEditingController _pasteController = TextEditingController();
  String pastedTranslatedText = '';

  File? _pickedImage;
  String imageExtractedText = '';
  String imageTranslatedText = '';

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String recordedText = "ማይክራፎኑን በመጫን ማውራት ይጀምሩ...";
  String translatedVoiceText = '';
  final FlutterTts _flutterTts = FlutterTts();

  final GoogleTranslator translator = GoogleTranslator();
  final ImagePicker _imagePicker = ImagePicker();

  // 🔑 የሰጡት ትክክለኛ የጂሚኒ ኤፒአይ ቁልፍ እዚህ ገብቷል
  final String geminiApiKey = "AQ.Ab8RN6JGF5Rfu6UnSKitOm956cEW4Nb49ghNNTVVYETv-AozYw"; 

  // የካቴጎሪ ዝርዝር
  final categories = [
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
    'Italian',
    'German',
    'Chinese',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _speech = stt.SpeechToText();
  }

  String getTargetCode(String lang) {
    switch (lang) {
      case 'Tigrinya': return 'ti';
      case 'Afaan Oromo': return 'om';
      case 'Arabic': return 'ar';
      case 'French': return 'fr';
      case 'Spanish': return 'es';
      case 'English': return 'en';
      case 'Italian': return 'it';
      case 'German': return 'de';
      case 'Chinese': return 'zh-cn';
      case 'Afar': return 'aa';
      default: return 'am';
    }
  }

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
            extractedText = extractedText.replaceAll(RegExp(r'[^\x20-\x7E\nአ-ፚ]'), ' ');
          } catch (e) {
            extractedText = "ፋይል: $fileName\nይዘቱ በተሳካ ሁኔታ ተጭኗል።";
          }
        }

        if (extractedText.trim().isEmpty) {
          extractedText = "ጫኚው ፋይል ባዶ ነው ወይም ጽሁፍ አልተገኘበትም።";
        }

        List<String> pages = [];
        int pageChars = 1500;
        for (int i = 0; i < extractedText.length; i += pageChars) {
          int end = (i + pageChars < extractedText.length) ? i + pageChars : extractedText.length;
          pages.add(extractedText.substring(i, end));
        }

        if (pages.isEmpty) pages.add(extractedText);

        setState(() {
          selectedFileName = fileName;
          fullExtractedText = extractedText;
          displayPages = pages;
          currentPage = 1;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ፋይሉ ተጭኗል: $fileName')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ስህተት: $e')));
      }
    }
  }

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

    List<String> translatedPages = [];

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      for (int i = 0; i < displayPages.length; i++) {
        String pageText = displayPages[i];

        String prompt = '''
          You are an expert AI translator and analyst. Analyze the following text under the category "$selectedCategory".
          Provide your response in $selectedTargetLang following this professional structure:
          1. Brief Analysis / Summary of the text (ጥልቅ ትንተና ወይም ማጠቃለያ)
          2. Key Points in bullet points (ዋና ዋና ነጥቦች)
          3. Full structured Translation (የጽሁፍ ትርጉም)
          
          Text to process:
          $pageText
        ''';

        final content = [Content.text(prompt)];
        final response = await model.generateContent(content);

        if (response.text != null) {
          translatedPages.add(response.text!);
        } else {
          translatedPages.add(pageText);
        }

        setState(() {
          progress = (i + 1) / displayPages.length;
        });
      }

      setState(() {
        isTranslating = false;
        displayPages = translatedPages;
        currentPage = 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI ትንተና እና ትርጉም በተሳካ ሁኔታ ተጠናቋል!')),
        );
      }
    } catch (e) {
      setState(() {
        isTranslating = false;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('የስህተት ዝርዝር (Error)'),
            content: Text('AI ትርጉም አልተሳካም:\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('እሺ'),
              ),
            ],
          ),
        );
      }
    }
  }

  void translatePastedText() async {
    if (_pasteController.text.trim().isEmpty) return;
    
    setState(() {
      pastedTranslatedText = "በመተርጎም ላይ... እባክዎ ይጠብቁ...";
    });

    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: geminiApiKey);
      final prompt = 'Analyze and translate the following text into $selectedTargetLang with key points and full translation:\n${_pasteController.text}';
      final response = await model.generateContent([Content.text(prompt)]);
      
      setState(() {
        pastedTranslatedText = response.text ?? 'ትርጉም አልተገኘም';
      });
    } catch (e) {
      setState(() {
        pastedTranslatedText = "ስህተት አጋጥሟል:\n$e";
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
        imageExtractedText = "ከፎቶው ላይ ጽሁፍ በማውጣት ላይ...";
        imageTranslatedText = "በጂሚኒ AI በመተንተን ላይ...";
      });

      try {
        final bytes = await image.readAsBytes();
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: geminiApiKey);
        
        final response = await model.generateContent([
          Content.multi([
            DataPart('image/jpeg', bytes), 
            TextPart('Extract text from this image, summarize it, and translate it into $selectedTargetLang with key points.')
          ])
        ]);

        setState(() {
          imageExtractedText = "ፎቶው በተሳካ ሁኔታ ተነቧል።";
          imageTranslatedText = response.text ?? 'ትርጉም አልተገኘም።';
        });
      } catch (e) {
        setState(() {
          imageTranslatedText = "የስህተት ዝርዝር: $e";
        });
      }
    }
  }

  void _listenVoice() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) async {
            setState(() => recordedText = val.recognizedWords);
            if (val.recognizedWords.isNotEmpty) {
              final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: geminiApiKey);
              final response = await model.generateContent([Content.text('Translate and explain this spoken text in $selectedTargetLang: ${val.recognizedWords}')]);
              setState(() {
                translatedVoiceText = response.text ?? '';
              });
            }
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _speakText(String text) async {
    if (text.trim().isEmpty) return;
    String langCode = 'am-ET';
    if (selectedTargetLang == 'English') langCode = 'en-US';
    else if (selectedTargetLang == 'Arabic') langCode = 'ar-SA';
    else if (selectedTargetLang == 'French') langCode = 'fr-FR';
    else if (selectedTargetLang == 'Spanish') langCode = 'es-ES';

    await _flutterTts.setLanguage(langCode);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
  }

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
        dialogTitle: 'ተተርጎሞ የተዘጋጀውን ፒዲኤፍ ማስቀመጫ ቦታ ይምረጡ',
        fileName: 'Mule_Translated_${DateTime.now().millisecondsSinceEpoch}.pdf',
        bytes: pdfBytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ፋይሉ ተቀምጧል: $outputFile')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ስህተት: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mule AI Document Translator'),
        centerTitle: true,
        backgroundColor: Colors.indigo.shade100,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'ፋይል (AI File)'),
            Tab(icon: Icon(Icons.paste), text: 'ኮፒ/ፔስት (Paste)'),
            Tab(icon: Icon(Icons.camera_alt), text: 'ካሜራ (AI OCR)'),
            Tab(icon: Icon(Icons.mic), text: 'ድምፅ (Voice)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. ፋይል ታብ
          SingleChildScrollView(
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
                const Text('Select Document Category:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final catName = cat['name'] as String;
                    final catIcon = cat['icon'] as IconData;
                    bool isSelected = selectedCategory == catName;

                    return InkWell(
                      onTap: () => setState(() => selectedCategory = catName),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigo.shade800 : Colors.indigo.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(catIcon, color: Colors.white, size: 26),
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                catName,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.folder_shared, size: 36, color: Colors.indigo),
                        const SizedBox(height: 6),
                        Text(selectedFileName, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickDocument,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Select File from Phone'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedSourceLang,
                        decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder()),
                        items: languages.map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
                        onChanged: (val) => setState(() => selectedSourceLang = val!),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.swap_horiz)),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedTargetLang,
                        decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder()),
                        items: languages.map((lang) => DropdownMenuItem(value: lang, child: Text(lang))).toList(),
                        onChanged: (val) => setState(() => selectedTargetLang = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                            Text('በጂሚኒ AI በመተንተን ላይ... ${(progress * 100).toInt()}%'),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: progress, color: Colors.white),
                          ],
                        )
                      : const Text('Analyze & Translate with Gemini AI', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('የጂሚኒ ትንተና እና የትርጉም ውጤት:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.volume_up, color: Colors.indigo),
                          onPressed: () => _speakText(displayPages[currentPage - 1]),
                          tooltip: 'ያንብብልኝ',
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop, color: Colors.red),
                          onPressed: _stopSpeaking,
                          tooltip: 'አቁም',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 320,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ገጽ $currentPage ከ ${displayPages.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios, size: 16),
                                onPressed: currentPage > 1 ? () => setState(() => currentPage--) : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                                onPressed: currentPage < displayPages.length ? () => setState(() => currentPage++) : null,
                              ),
                            ],
                          )
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(displayPages.isNotEmpty ? displayPages[currentPage - 1] : '', style: const TextStyle(fontSize: 13, height: 1.4)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _downloadTranslatedPDF,
                  icon: const Icon(Icons.download),
                  label: const Text('Save Translated PDF'),
                ),
                const SizedBox(height: 10),
                const Center(child: Text('Developed by Mulugeta Abye', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
          ),

          // 2. ጽሁፍ ኮፒ ፔስት አድርጎ መተርጎም
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ጽሁፍዎን እዚህ ጋር ይለጥፉ (Paste Text):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _pasteController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Enter or paste text here...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  onPressed: translatePastedText,
                  icon: const Icon(Icons.translate),
                  label: const Text('Analyze & Translate Text'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('የትርጉም ውጤት:', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.indigo),
                      onPressed: () => _speakText(pastedTranslatedText),
                      tooltip: 'ያንብብልኝ',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Text(pastedTranslatedText.isEmpty ? 'ትርጉሙ እዚህ ይታያል...' : pastedTranslatedText, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. ካሜራ እና ምስል AI OCR
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.image),
                      label: const Text('Gallery'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_pickedImage != null)
                  SizedBox(
                    height: 100,
                    child: Image.file(_pickedImage!, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 12),
                const Text('የተገኘው ጽሁፍ ሁኔታ:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(imageExtractedText, style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('የጂሚኒ ትንተና እና ትርጉም:', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.indigo),
                      onPressed: () => _speakText(imageTranslatedText),
                      tooltip: 'ያንብብልኝ',
                    ),
                  ],
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
                    child: SingleChildScrollView(child: Text(imageTranslatedText, style: const TextStyle(fontSize: 14))),
                  ),
                ),
              ],
            ),
          ),

          // 4. ድምፅ ሪከርድ እና ትርጉም
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 64,
                  color: _isListening ? Colors.red : Colors.indigo,
                ),
                const SizedBox(height: 16),
                Text(
                  _isListening ? "🎙️ እያዳመጥኩ ነው... ይናገሩ..." : recordedText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _listenVoice,
                  icon: Icon(_isListening ? Icons.stop : Icons.mic),
                  label: Text(_isListening ? 'መቅረጽ አቁም' : 'ድምፅ መቅረጽ ጀምር'),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('የትርጉም ውጤት:', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.indigo),
                      onPressed: () => _speakText(translatedVoiceText),
                      tooltip: 'ያንብብልኝ',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      translatedVoiceText.isEmpty ? 'የድምፅ ትርጉሙ እዚህ ይታያል...' : translatedVoiceText,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
