import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

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
  
  String fullExtractedText = "እባክዎ ፋይል ይምረጡ።";
  List<String> displayPages = ['እባክዎ ፋይል ይምረጡ።'];
  int currentPage = 1;

  final TextEditingController _pasteController = TextEditingController();
  String pastedTranslatedText = '';

  File? _pickedImage;
  String imageTranslatedText = '';

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String recordedText = "ማይክራፎኑን በመጫን ይናገሩ...";
  String translatedVoiceText = '';
  final FlutterTts _flutterTts = FlutterTts();

  final ImagePicker _imagePicker = ImagePicker();

  // 🔑 የጂሚኒ ኤፒአይ ቁልፍ
  final String geminiApiKey = "AQ.Ab8RN6JGF5Rfu6UnSKitOm956cEW4Nb49ghNNTVVYETv-AozYw"; 

  // አስተማማኝ እና ፈጣኑ የ gemini-1.5-flash ሞዴል
  GenerativeModel get _aiModel => GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

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
    'Amharic', 'Afar', 'Tigrinya', 'Afaan Oromo', 'English', 
    'Spanish', 'French', 'Arabic', 'Italian', 'German', 'Chinese',
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
            extractedText = extractedText.replaceAll(RegExp(r'[^\x20-\x7E\nአ-ፚ]'), ' ');
          } catch (e) {
            extractedText = "ፋይል: $fileName\nይዘቱ ተጭኗል።";
          }
        }

        if (extractedText.trim().isEmpty) {
          extractedText = "ፋይሉ ተጭኗል ($fileName)።";
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

    setState(() => isTranslating = true);

    try {
      String textToTranslate = fullExtractedText;
      if (textToTranslate.length > 2500) {
        textToTranslate = textToTranslate.substring(0, 2500);
      }

      String prompt = 'Translate and summarize this text into $selectedTargetLang under category "$selectedCategory":\n$textToTranslate';

      final response = await _aiModel.generateContent([Content.text(prompt)]);

      setState(() {
        isTranslating = false;
        displayPages = [response.text ?? 'ትርጉም አልተገኘም።'];
        currentPage = 1;
      });
    } catch (e) {
      setState(() => isTranslating = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('የስህተት ዝርዝር (Error)'),
            content: Text('ትርጉም አልተሳካም:\n$e'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('እሺ'))],
          ),
        );
      }
    }
  }

  void translatePastedText() async {
    if (_pasteController.text.trim().isEmpty) return;
    
    setState(() => pastedTranslatedText = "በመተርጎም ላይ... እባክዎ ይጠብቁ...");

    try {
      final prompt = 'Translate into $selectedTargetLang with key points:\n${_pasteController.text}';
      final response = await _aiModel.generateContent([Content.text(prompt)]);
      
      setState(() => pastedTranslatedText = response.text ?? 'ትርጉም አልተገኘም');
    } catch (e) {
      setState(() => pastedTranslatedText = "ስህተት አጋጥሟል:\n$e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
        imageTranslatedText = "ፎቶው እየተነበበ እና እየተተረጎመ ነው...";
      });

      try {
        final bytes = await image.readAsBytes();
        final response = await _aiModel.generateContent([
          Content.multi([
            DataPart('image/jpeg', bytes), 
            TextPart('Extract text from this image and translate it into $selectedTargetLang.')
          ])
        ]);

        setState(() => imageTranslatedText = response.text ?? 'ትርጉም አልተገኘም።');
      } catch (e) {
        setState(() => imageTranslatedText = "ስህተት: $e");
      }
    }
  }

  void _listenVoice() async {
    try {
      if (!_isListening) {
        bool available = await _speech.initialize();
        if (available) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (val) async {
              setState(() => recordedText = val.recognizedWords);
              if (val.recognizedWords.isNotEmpty) {
                final response = await _aiModel.generateContent([Content.text('Translate into $selectedTargetLang: ${val.recognizedWords}')]);
                setState(() => translatedVoiceText = response.text ?? '');
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
    String langCode = selectedTargetLang == 'English' ? 'en-US' : 'am-ET';
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.speak(text);
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'ምድብ'),
                  items: categories.map((cat) => DropdownMenuItem(value: cat['name'] as String, child: Text(cat['name'] as String))).toList(),
                  onChanged: (val) => setState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
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
                    const SizedBox(width: 8),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: isTranslating ? null : startTranslation,
                  child: isTranslating
                      ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.white), SizedBox(width: 12), Text('በመተርጎም ላይ...')])
                      : const Text('Analyze & Translate', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('የትርጉም ውጤት:', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.volume_up, color: Colors.indigo), onPressed: () => _speakText(displayPages[0])),
                  ],
                ),
                Container(
                  height: 280,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                  child: SingleChildScrollView(child: Text(displayPages.isNotEmpty ? displayPages[0] : '', style: const TextStyle(fontSize: 13, height: 1.4))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                  label: const Text('Translate Text'),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
                    child: SingleChildScrollView(child: Text(pastedTranslatedText.isEmpty ? 'ትርጉሙ እዚህ ይታያል...' : pastedTranslatedText, style: const TextStyle(fontSize: 15))),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('Camera')),
                    ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white), onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.image), label: const Text('Gallery')),
                  ],
                ),
                const SizedBox(height: 12),
                if (_pickedImage != null) SizedBox(height: 70, child: Image.file(_pickedImage!, fit: BoxFit.cover)),
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
          Padding(
            padding: constပြင်صall(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_isListening ? Icons.mic : Icons.mic_none, size: 64, color: _isListening ? Colors.red : Colors.indigo),
                const SizedBox(height: 16),
                Text(recordedText, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _isListening ? Colors.red : Colors.indigo, foregroundColor: Colors.white),
                  onPressed: _listenVoice,
                  icon: Icon(_isListening ? Icons.stop : Icons.mic),
                  label: Text(_isListening ? 'መቅረጽ አቁም' : 'ድምፅ መቅረጽ ጀምር'),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300)),
                    child: SingleChildScrollView(child: Text(translatedVoiceText.isEmpty ? 'የድምፅ ትርጉሙ እዚህ ይታያል...' : translatedVoiceText, style: const TextStyle(fontSize: 15))),
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
