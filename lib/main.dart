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
  bool aiModeEnabled = true; // በAI ሞድ ለመጠቀም
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

  // የጂሚኒ ኤፒአይ ማዋቀሪያ (እዚህ ጋር የርስዎን API Key ያስገቡ)
  final String geminiApiKey = "YOUR_GEMINI_API_KEY_HERE"; 

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

  // ፋይል መምረጫ
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ፋይሉ ተጭኗል: $fileName')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ስህተት: $e')));
    }
  }

  // ** የጂሚኒ ኤፒአይ በመጠቀም ልክ እንደ ፎቶው በጥልቀት የመተንተን እና የመተርጎም ሂደት **
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
    bool hasError = hasError = false;

    try {
      // ጂሚኒ ሞዴልን ማዋቀር
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: geminiApiKey,
      );

      for (int i = 0; i < displayPages.length; i++) {
        String pageText = displayPages[i];

        // ልክ እንደ ላኩት ፎቶ በቅደም ተከተል እንዲያቀናጅ ትዕዛዝ መስጠት (Prompt Engineering)
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
    } catch (e) {
      hasError = true;
      // ኤፒአይ ከሌለ ወይም ስህተት ካጋጠመ በመደበኛ Google Translator መተካት
      for (var page in displayPages) {
        var trans = await translator.translate(page, to: selectedTargetLang == 'Amharic' ? 'am' : 'en');
        translatedPages.add("--- [የትርጉም ማስታወሻ] ---\n${trans.text}");
      }
    }

    setState(() {
      isTranslating = false;
      displayPages = translatedPages;
      currentPage = 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(hasError ? 'በኔትወርክ ወይም ኤፒአይ ችግር በመደበኛ ተተርጉሟል!' : 'AI ትንተና እና ትርጉም በተሳካ ሁኔታ ተጠናቋል!')),
    );
  }

  // ጽሁፍ ኮፒ ፔስት አድርጎ በጂሚኒ መተርጎም
  void translatePastedText() async {
    if (_pasteController.text.trim().isEmpty) return;
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: geminiApiKey);
      final prompt = 'Analyze and translate the following text into $selectedTargetLang with key points and full translation:\n${_pasteController.text}';
      final response = await model.generateContent([Content.text(prompt)]);
      setState(() {
        pastedTranslatedText = response.text ?? 'ትርጉም አልተገኘም';
      });
    } catch (e) {
      var trans = await translator.translate(_pasteController.text, to: 'am');
      setState(() {
        pastedTranslatedText = trans.text;
      });
    }
  }

  // ካሜራ ወይም ጋለሪ ፎቶ መምረጫ
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _pickedImage = File(image.path);
        imageExtractedText = "ከፎቶው ላይ ጽሁፍ በማውጣት ላይ...";
        imageTranslatedText = "በጂሚኒ AI በመተንተን ላይ...";
      });

      // ፎቶውን ወደ ጂሚኒ መላክ ይቻላል (Multimodal capability)
      try {
        final bytes = await image.readAsBytes();
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: geminiApiKey);
        final prompt = PromptPiece.text('Extract all text from this image and translate/analyze it into $selectedTargetLang with key points.');
        
        final response = await model.generateContent([
          Content.multi([DataPart('image/jpeg', bytes), TextPart('Extract text from this image, summarize it, and translate it into $selectedTargetLang')])
        ]);

        setState(() {
          imageExtractedText = "ፎቶው በተሳካ ሁኔታ ተነቧል።";
          imageTranslatedText = response.text ?? 'ትርጉም አልተገኘም።';
        });
      } catch (e) {
        setState(() {
          imageTranslatedText = "የስህተት ዝርዝር: $e (እባክዎ API Key ያስገቡ)";
        });
      }
    }
  }

  // ድምፅ ሪከርድ እና ስፒች-ቱ-ቴክስት
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
    await _flutterTts.setLanguage('am-ET');
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
            Tab(icon: Icon(Icons.camera_alt), text: 'ካሜራ ፎቶ (AI OCR)'),
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  onPressed: isTranslating ? null : startTranslation,
                  child: isTranslating
                      ? Text('በጂሚኒ AI በመተንተን ላይ... ${(progress * 100).toInt()}%')
                      : const Text('Analyze & Translate with Gemini AI'),
                ),
                const SizedBox(height: 20),
                const Text('የጂሚኒ ትንተና እና የትርጉም ውጤት (AI Result):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                Container(
                  height: 320,
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400)),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: Text(displayPages.isNotEmpty ? displayPages[currentPage - 1] : '', style: const TextStyle(fontSize: 14, height: 1.5)),
                  ),
                ),
              ],
            ),
          ),
          // 2. ፔስት ታብ
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(controller: _pasteController, maxLines: 4, decoration: const InputDecoration(hintText: 'ጽሁፍ ይለጥፉ...', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: translatePastedText, child: const Text('Analyze & Translate Text')),
                const SizedBox(height: 10),
                Expanded(child: SingleChildScrollView(child: Text(pastedTranslatedText))),
              ],
            ),
          ),
          // 3. ካሜራ ታብ
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera), label: const Text('ካሜራ')),
                    ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.image), label: const Text('ጋለሪ')),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(child: SingleChildScrollView(child: Text(imageTranslatedText))),
              ],
            ),
          ),
          // 4. ድምፅ ታብ
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, size: 50, color: Colors.indigo), onPressed: _listenVoice),
                Text(recordedText),
                const SizedBox(height: 20),
                Expanded(child: SingleChildScrollView(child: Text(translatedVoiceText))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
