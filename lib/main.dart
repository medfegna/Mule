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
  bool isTranslating = false;
  double progress = 0.0;
  
  String fullExtractedText = "እባክዎ መጀመሪያ ፋይል ይምረጡ።";
  List<String> displayPages = ['እባክዎ መጀመሪያ ፋይል ይምረጡ።'];
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

  // 🔑 የጂሚኒ ኤፒአይ ቁልፍ
  final String geminiApiKey = "AQ.Ab8RN6JGF5Rfu6UnSKitOm956cEW4Nb49ghNNTVVYETv-AozYw"; 

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
            // ጽሁፉን ከቆሻሻ ምልክቶች ማጽዳት
            extractedText = extractedText.replaceAll(RegExp(r'[^\x20-\x7E\nአ-ፚ]'), ' ');
          } catch (e) {
            extractedText = "ፋይል: $fileName\nይዘቱ ተጭኗል። እባክዎ በቀጥታ ትርጉም ይጀምሩ።";
          }
        }

        if (extractedText.trim().isEmpty || extractedText.length < 10) {
          extractedText = "ፋይሉ ተጭኗል ($fileName)። እባክዎ Analyze ቁልፍን ይጫኑ።";
        }

        setState(() {
          selectedFileName = fileName;
          fullExtractedText = extractedText;
          displayPages = [extractedText];
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
      progress = 0.3;
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-flash-latest',
        apiKey: geminiApiKey,
      );

      String textToTranslate = fullExtractedText;
      if (textToTranslate.length > 3000) {
        textToTranslate = textToTranslate.substring(0, 3000); // ለፍጥነት እና ለግንኙነት መቋረጥ እንዳይጋለጥ ማሳጠር
      }

      String prompt = '''
        Translate and analyze this text into $selectedTargetLang under category "$selectedCategory". 
        Provide clear summary, key points, and translation:
        $textToTranslate
      ''';

      setState(() => progress = 0.6);

      final response = await model.generateContent([Content.text(prompt)]);

      setState(() {
        isTranslating = false;
        progress = 1.0;
        displayPages = [response.text ?? 'ትርጉም አልተገኘም።'];
        currentPage = 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ትርጉም በተሳካ ሁኔታ ተጠናቋል!')),
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
            content: Text('ትርጉም አልተሳካም:\n$e'),
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
      final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: geminiApiKey);
      final prompt = 'Translate into $selectedTargetLang with key points:\n${_pasteController.text}';
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
        imageExtractedText = "ፎቶው እየተነበበ ነው...";
        imageTranslatedText = "በመተርጎም ላይ...";
      });

      try {
        final bytes = await image.readAsBytes();
        final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: geminiApiKey);
        
        final response = await model.generateContent([
          Content.multi([
            DataPart('image/jpeg', bytes), 
            TextPart('Extract text from this image and translate it into $selectedTargetLang with key points.')
          ])
        ]);

        setState(() {
          imageExtractedText = "ፎቶው ተነቧል።";
          imageTranslatedText = response.text ?? 'ትርጉም አልተገኘም።';
        });
      } catch (e) {
        setState(() {
          imageTranslatedText = "ስህተት: $e";
        });
      }
    }
  }

  void _listenVoice() async {
    try {
      if (!_isListening) {
        bool available = await _speech.initialize(
          onStatus: (status) => print('status: $status'),
          onError: (error) => print('error: $error'),
        );
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (val) async {
              setState(() => recordedText = val.recognizedWords);
              if (val.recognizedWords.isNotEmpty) {
                final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: geminiApiKey);
                final response = await model.generateContent([Content.text('Translate into $selectedTargetLang: ${val.recognizedWords}')]);
                setState(() {
                  translatedVoiceText = response.text ?? '';
                });
              }
            },
          );
        } else {
          setState(() => recordedText = "ማይክራፎን መጠቀም አልተቻለም።");
        }
      } else {
        setState(() => _isListening = false);
        _speech.stop();
      }
    } catch (e) {
      setState(() {
        _isListening = false;
        recordedText = "የድምፅ ስህተት: $e";
      });
    }
  }

  Future<void> _speakText(String text) async {
    if (text.trim().isEmpty) return;
    String langCode = 'am-ET';
    if (selectedTargetLang == 'English') langCode = 'en-US';
    else if (selectedTargetLang == 'Arabic') langCode = 'ar-SA';
    else if (selectedTargetLang == 'French') langCode = 'fr-FR';

    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
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
                const Text('የፋይል ምድብ ይምረጡ:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: categories.map((cat) => DropdownMenuItem(value: cat['name'] as String, child: Text(cat['name'] as String))).toList(),
                  onChanged: (val) => setState(() => selectedCategory = val!),
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
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Colors.white),
                            const SizedBox(width: 12),
                            Text('በመተርጎም ላይ... ${(progress * 100).toInt()}%'),
                          ],
                        )
                      : const Text('Analyze & Translate Fast', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('የትርጉም ውጤት:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.indigo),
                      onPressed: () => _speakText(displayPages[0]),
                      tooltip: 'ያንብብልኝ',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: Text(displayPages.isNotEmpty ? displayPages[0] : '', style: const TextStyle(fontSize: 13, height: 1.4)),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(child: Text('Developed by Mulugeta Abye', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
          ),

          // 2. ጽሁፍ ኮፒ ፔስት
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
                  decoration: const InputDecoration(hintText: 'Enter text here...', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  onPressed: translatePastedText,
                  icon: const Icon(Icons.translate),
                  label: const Text('Translate Text Fast'),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
                    child: SingleChildScrollView(
                      child: Text(pastedTranslatedText.isEmpty ? 'ትርጉሙ እዚህ ይታያል...' : pastedTranslatedText, style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. ካሜራ OCR
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
                  SizedBox(height: 80, child: Image.file(_pickedImage!, fit: BoxFit.cover)),
                const SizedBox(height: 12),
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

          // 4. ድምፅ ሪከርድ (Voice)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isListening ? Icons.mic : Icons.mic_none, size: 64, color: _isListening ? Colors.red : Colors.indigo),
                const SizedBox(height: 16),
                Text(recordedText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.red : Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _listenVoice,
                  icon: Icon(_isListening ? Icons.stop : Icons.mic),
                  label: Text(_isListening ? 'ማቆም' : 'ድምፅ መቅረጽ ጀምር'),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
                    child: SingleChildScrollView(child: Text(translatedVoiceText, style: const TextStyle(fontSize: 15))),
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
